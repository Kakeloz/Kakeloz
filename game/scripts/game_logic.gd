class_name GameLogic
extends RefCounted
## Oyunun kuralları. Arayüzden tamamen bağımsızdır: ekrana hiçbir şey çizmez,
## sadece durumu tutar ve kuralları uygular. Online sürümde bu sınıf yalnızca
## oyunu kuran (host) bilgisayarda çalışacak; diğer oyunculara sadece
## role_view() ile görmeleri gereken bilgi gönderilecek.

enum Role { DOCTOR, REAL_PATIENT, FAKE_PATIENT }
enum Phase { LOBBY, ROLE_REVEAL, EXAM, DISCUSSION, DIAGNOSIS, RESULT, GAME_OVER }

const MIN_PLAYERS := 5
const MAX_PLAYERS := 8
const QUESTIONS_PER_ROUND := 5
const DRUG_CHOICES := 4

const SCORE_DOCTOR_CORRECT := 2
const SCORE_REAL_PATIENT_CORRECT := 1
const SCORE_FAKE_CHOSEN := 2
const SCORE_DOCTOR_WRONG := -1

var diseases: Array = []
var complications: Dictionary = {}
var players: Array = []
var phase: Phase = Phase.LOBBY
var round_index := -1
var doctor_idx := -1
var real_patient_idx := -1
var disease: Dictionary = {}
var drug_choices: Array = []
var questions_left := 0
var questions_asked: Array = []
var last_result: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _disease_deck: Array = []


func _init(p_diseases: Array, p_complications: Array, seed_value: int = -1) -> void:
	diseases = p_diseases
	for c in p_complications:
		complications[c["id"]] = c
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func start_game(names: Array) -> bool:
	if names.size() < MIN_PLAYERS or names.size() > MAX_PLAYERS:
		return false
	players.clear()
	for n in names:
		players.append({"name": String(n), "score": 0})
	round_index = -1
	doctor_idx = -1
	real_patient_idx = -1
	last_result = {}
	_disease_deck.clear()
	phase = Phase.LOBBY
	return true


func round_count() -> int:
	return players.size()


func has_next_round() -> bool:
	return round_index + 1 < round_count()


func start_round() -> void:
	round_index += 1
	doctor_idx = round_index % players.size()
	if _disease_deck.is_empty():
		_disease_deck = range(diseases.size())
		_shuffle(_disease_deck)
	disease = diseases[_disease_deck.pop_back()]
	var candidates := patient_indices()
	real_patient_idx = candidates[_rng.randi_range(0, candidates.size() - 1)]
	questions_left = QUESTIONS_PER_ROUND
	questions_asked.clear()
	for i in players.size():
		questions_asked.append(0)
	_build_drug_choices()
	last_result = {}
	phase = Phase.ROLE_REVEAL


func patient_indices() -> Array:
	var result: Array = []
	for i in players.size():
		if i != doctor_idx:
			result.append(i)
	return result


func role_of(idx: int) -> Role:
	if idx == doctor_idx:
		return Role.DOCTOR
	if idx == real_patient_idx:
		return Role.REAL_PATIENT
	return Role.FAKE_PATIENT


## Bir oyuncunun görmesine izin verilen bilgi. Simülantlar belirtileri görmez.
func role_view(idx: int) -> Dictionary:
	var role := role_of(idx)
	var view := {"role": role, "disease_name": disease["name"], "symptoms": []}
	if role != Role.FAKE_PATIENT:
		view["symptoms"] = disease["symptoms"].duplicate()
	return view


func begin_exam() -> void:
	if phase == Phase.ROLE_REVEAL:
		phase = Phase.EXAM


func ask_question(target_idx: int) -> bool:
	if phase != Phase.EXAM or questions_left <= 0:
		return false
	if target_idx == doctor_idx or target_idx < 0 or target_idx >= players.size():
		return false
	questions_left -= 1
	questions_asked[target_idx] += 1
	return true


func end_exam() -> void:
	if phase == Phase.EXAM:
		phase = Phase.DISCUSSION


func begin_diagnosis() -> void:
	if phase == Phase.DISCUSSION:
		phase = Phase.DIAGNOSIS


## Doktor bir hasta ve bir ilaç seçer. Geçersiz seçimde boş sözlük döner.
func diagnose(patient_idx: int, drug_idx: int) -> Dictionary:
	if phase != Phase.DIAGNOSIS:
		return {}
	if patient_idx == doctor_idx or patient_idx < 0 or patient_idx >= players.size():
		return {}
	if drug_idx < 0 or drug_idx >= drug_choices.size():
		return {}
	var drug: Dictionary = drug_choices[drug_idx]
	var correct := patient_idx == real_patient_idx
	var deltas := {}
	var afflicted: Array = []
	if correct:
		deltas[doctor_idx] = SCORE_DOCTOR_CORRECT
		deltas[real_patient_idx] = SCORE_REAL_PATIENT_CORRECT
	else:
		deltas[doctor_idx] = SCORE_DOCTOR_WRONG
		deltas[patient_idx] = SCORE_FAKE_CHOSEN
		afflicted = [doctor_idx, patient_idx]
	for idx in deltas:
		players[idx]["score"] += deltas[idx]
	last_result = {
		"correct": correct,
		"chosen_idx": patient_idx,
		"real_idx": real_patient_idx,
		"doctor_idx": doctor_idx,
		"disease_name": disease["name"],
		"drug": drug["drug"],
		"complication": drug["complication"],
		"afflicted": afflicted,
		"deltas": deltas,
	}
	phase = Phase.RESULT
	return last_result


func finish() -> void:
	phase = Phase.GAME_OVER


## Puana göre sıralı liste (eşitlikte oyuncu sırası korunur).
func ranking() -> Array:
	var list: Array = []
	for i in players.size():
		list.append({"idx": i, "name": players[i]["name"], "score": players[i]["score"]})
	list.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["idx"] < b["idx"])
	return list


func _build_drug_choices() -> void:
	drug_choices = [{"drug": disease["drug"], "complication": disease["complication"]}]
	var others: Array = []
	for d in diseases:
		if d["id"] != disease["id"]:
			others.append(d)
	_shuffle(others)
	for d in others:
		if drug_choices.size() >= DRUG_CHOICES:
			break
		var duplicate := false
		for existing in drug_choices:
			if existing["drug"] == d["drug"]:
				duplicate = true
		if not duplicate:
			drug_choices.append({"drug": d["drug"], "complication": d["complication"]})
	_shuffle(drug_choices)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
