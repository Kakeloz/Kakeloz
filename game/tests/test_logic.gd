extends SceneTree
## Oyun kurallarının otomatik testi.
## Çalıştırma: godot --headless --path game -s res://tests/test_logic.gd

var _failures := 0


func _initialize() -> void:
	var diseases := DataLoader.load_diseases()
	var complications := DataLoader.load_complications()
	_check_data(diseases, complications)
	_check_player_limits(diseases, complications)
	for players in range(GameLogic.MIN_PLAYERS, GameLogic.MAX_PLAYERS + 1):
		for seed_value in 25:
			_play_full_game(diseases, complications, players, seed_value)
	_check_invalid_actions(diseases, complications)
	if _failures == 0:
		print("TÜM TESTLER GEÇTİ")
	else:
		print("BAŞARISIZ TEST SAYISI: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("HATA: " + msg)


func _names(n: int) -> Array:
	var names: Array = []
	for i in n:
		names.append("P%d" % i)
	return names


func _check_data(diseases: Array, complications: Array) -> void:
	_expect(diseases.size() >= GameLogic.MAX_PLAYERS, "her tura farklı hastalık yetmeli")
	var comp_ids := {}
	for c in complications:
		comp_ids[c["id"]] = true
	for d in diseases:
		_expect(d["symptoms"].size() == 3, "%s: 3 belirti olmalı" % d["id"])
		_expect(comp_ids.has(d["complication"]), "%s: bilinmeyen komplikasyon" % d["id"])


func _check_player_limits(diseases: Array, complications: Array) -> void:
	var logic := GameLogic.new(diseases, complications, 1)
	_expect(not logic.start_game(_names(4)), "4 oyuncu reddedilmeli")
	_expect(not logic.start_game(_names(9)), "9 oyuncu reddedilmeli")
	_expect(logic.start_game(_names(5)), "5 oyuncu kabul edilmeli")


func _play_full_game(diseases: Array, complications: Array, n: int, seed_value: int) -> void:
	var logic := GameLogic.new(diseases, complications, seed_value)
	_expect(logic.start_game(_names(n)), "oyun başlamalı")
	var seen_doctors := {}
	var seen_diseases := {}
	var expected_scores := []
	for i in n:
		expected_scores.append(0)
	var rounds := 0
	while true:
		logic.start_round()
		rounds += 1
		var ctx := "n=%d seed=%d tur=%d" % [n, seed_value, logic.round_index]
		seen_doctors[logic.doctor_idx] = true
		seen_diseases[logic.disease["id"]] = true

		# Roller: 1 doktor, 1 gerçek hasta, geri kalanı simülant
		var counts := {GameLogic.Role.DOCTOR: 0, GameLogic.Role.REAL_PATIENT: 0, GameLogic.Role.FAKE_PATIENT: 0}
		for i in n:
			counts[logic.role_of(i)] += 1
			var view := logic.role_view(i)
			if logic.role_of(i) == GameLogic.Role.FAKE_PATIENT:
				_expect(view["symptoms"].is_empty(), "simülant belirtileri görmemeli " + ctx)
			else:
				_expect(view["symptoms"].size() == 3, "doktor/gerçek hasta belirtileri görmeli " + ctx)
		_expect(counts[GameLogic.Role.DOCTOR] == 1, "1 doktor olmalı " + ctx)
		_expect(counts[GameLogic.Role.REAL_PATIENT] == 1, "1 gerçek hasta olmalı " + ctx)
		_expect(counts[GameLogic.Role.FAKE_PATIENT] == n - 2, "geri kalanı simülant olmalı " + ctx)

		# İlaç seçenekleri: 4 farklı ilaç, doğru ilaç içinde
		var drug_names := {}
		for d in logic.drug_choices:
			drug_names[d["drug"]] = true
		_expect(logic.drug_choices.size() == GameLogic.DRUG_CHOICES, "4 ilaç seçeneği olmalı " + ctx)
		_expect(drug_names.size() == logic.drug_choices.size(), "ilaçlar farklı olmalı " + ctx)
		_expect(drug_names.has(logic.disease["drug"]), "doğru ilaç seçeneklerde olmalı " + ctx)

		# Muayene: soru sınırı ve doktora soru sorulamaması
		logic.begin_exam()
		_expect(not logic.ask_question(logic.doctor_idx), "doktora soru sorulamamalı " + ctx)
		var patients := logic.patient_indices()
		for q in GameLogic.QUESTIONS_PER_ROUND:
			_expect(logic.ask_question(patients[q % patients.size()]), "soru sorulabilmeli " + ctx)
		_expect(not logic.ask_question(patients[0]), "6. soru reddedilmeli " + ctx)
		logic.end_exam()
		logic.begin_diagnosis()

		# Teşhis: tur sırasına göre doğru/yanlış dönüşümlü
		var target: int = logic.real_patient_idx
		if logic.round_index % 2 == 1:
			for p in patients:
				if p != logic.real_patient_idx:
					target = p
					break
		var result := logic.diagnose(target, 0)
		_expect(not result.is_empty(), "teşhis geçerli olmalı " + ctx)
		if target == logic.real_patient_idx:
			_expect(result["correct"], "doğru teşhis " + ctx)
			_expect(result["afflicted"].is_empty(), "doğru teşhiste komplikasyon olmamalı " + ctx)
			expected_scores[logic.doctor_idx] += GameLogic.SCORE_DOCTOR_CORRECT
			expected_scores[logic.real_patient_idx] += GameLogic.SCORE_REAL_PATIENT_CORRECT
		else:
			_expect(not result["correct"], "yanlış teşhis " + ctx)
			_expect(result["afflicted"].size() == 2, "yanlışta doktor+simülant etkilenmeli " + ctx)
			expected_scores[logic.doctor_idx] += GameLogic.SCORE_DOCTOR_WRONG
			expected_scores[target] += GameLogic.SCORE_FAKE_CHOSEN
		_expect(logic.complications.has(result["complication"]), "komplikasyon tanımlı olmalı " + ctx)
		_expect(logic.diagnose(target, 0).is_empty(), "ikinci teşhis reddedilmeli " + ctx)

		if not logic.has_next_round():
			break

	_expect(rounds == n, "her oyuncu bir kez doktor olmalı (tur sayısı)")
	_expect(seen_doctors.size() == n, "her oyuncu doktor olmalı")
	_expect(seen_diseases.size() == n, "aynı oyunda hastalık tekrarlanmamalı")
	for i in n:
		_expect(logic.players[i]["score"] == expected_scores[i], "puan hesabı tutmalı (oyuncu %d)" % i)
	var ranking := logic.ranking()
	for k in range(1, ranking.size()):
		_expect(ranking[k - 1]["score"] >= ranking[k]["score"], "sıralama azalan olmalı")


func _check_invalid_actions(diseases: Array, complications: Array) -> void:
	var logic := GameLogic.new(diseases, complications, 7)
	logic.start_game(_names(6))
	logic.start_round()
	_expect(not logic.ask_question(logic.patient_indices()[0]), "rol gösteriminde soru sorulamamalı")
	_expect(logic.diagnose(logic.real_patient_idx, 0).is_empty(), "muayeneden önce teşhis konamamalı")
	logic.begin_exam()
	logic.end_exam()
	logic.begin_diagnosis()
	_expect(logic.diagnose(logic.doctor_idx, 0).is_empty(), "doktor kendini seçememeli")
	_expect(logic.diagnose(logic.real_patient_idx, 99).is_empty(), "geçersiz ilaç reddedilmeli")
	_expect(logic.diagnose(-1, 0).is_empty(), "geçersiz hasta reddedilmeli")
