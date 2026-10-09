extends SceneTree
## Arayüzü baştan sona otomatik oynayan duman testi: hata çıkmadan bir oyun
## bitebiliyor mu, tüm komplikasyon animasyonları çalışıyor mu?
## Çalıştırma: godot --headless --path game -s res://tests/smoke_ui.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("HATA: " + msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var main: Control = load("res://scenes/prototype_2d.tscn").instantiate()
	root.add_child(main)
	await _frames(2)

	# Her komplikasyon animasyonu hatasız oynamalı
	for c in DataLoader.load_complications():
		var ch := Character.new()
		root.add_child(ch)
		ch.play_complication(c["id"])
		await _frames(5)
		ch.queue_free()

	main._player_count = 6
	main._start_game()
	var n: int = main.logic.players.size()
	_expect(n == 6, "6 oyuncuyla başlamalı")

	for round in n:
		await _frames(1)
		# Rol kartları
		for i in n:
			main._show_role_card(i)
			await _frames(1)
		main._start_exam()
		_expect(main.logic.phase == GameLogic.Phase.EXAM, "muayene aşaması")
		var patients: Array = main.logic.patient_indices()
		for q in GameLogic.QUESTIONS_PER_ROUND:
			main._ask(patients[q % patients.size()])
			await _frames(1)
			main._end_answer()
		_expect(main.logic.questions_left == 0, "soru hakkı bitmeli")
		main._show_discussion()
		await _frames(1)
		main._show_diagnosis()
		_expect(main.logic.phase == GameLogic.Phase.DIAGNOSIS, "teşhis aşaması")
		# Tek turlarda yanlış teşhis koy ki komplikasyonlar da ekranda oynasın
		var target: int = main.logic.real_patient_idx
		if round % 2 == 1:
			for p in patients:
				if p != target:
					target = p
					break
		main._selected_patient = target
		main._selected_drug = 0
		main._confirm_diagnosis()
		_expect(main.logic.phase == GameLogic.Phase.RESULT, "sonuç aşaması")
		await _frames(10)
		if main.logic.has_next_round():
			main._begin_round()

	main._show_game_over()
	_expect(main.logic.phase == GameLogic.Phase.GAME_OVER, "oyun bitmeli")
	await _frames(2)
	main._show_menu()
	await _frames(2)

	if _failures == 0:
		print("ARAYÜZ TESTİ GEÇTİ")
	quit(1 if _failures > 0 else 0)
