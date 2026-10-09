extends SceneTree
## 3D klinik duman testi: harita yükleniyor mu, oyuncu yürüyebiliyor mu,
## duvardan geçemiyor mu, odalar algılanıyor mu, komplikasyonlar çalışıyor mu?
## Çalıştırma: godot --path game -s res://tests/smoke_3d.gd
## (Ekransız --headless modda Godot'un sahte çizim katmanı zararsız
## "Parameter m is null" uyarıları basar.)

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("HATA: " + msg)


func _physics_frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var clinic: Node3D = load("res://scenes/clinic.tscn").instantiate()
	root.add_child(clinic)
	await _physics_frames(10)
	var player: Player = clinic.player
	_expect(player != null, "oyuncu oluşmalı")
	_expect(player.is_on_floor(), "oyuncu yerde durmalı")
	_expect(clinic.current_room == "room_waiting", "başlangıç odası bekleme salonu olmalı (%s)" % clinic.current_room)

	# İleri yürü (kamera kuzeye, -z yönüne bakıyor)
	var start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(60)
	Input.action_release("move_forward")
	var moved := start.z - player.global_position.z
	_expect(moved > 2.0, "ileri yürüyünce -z yönünde ilerlemeli (%.2f m)" % moved)
	_expect(player.model.walk_amount > 0.0 or moved > 0.0, "yürüme animasyonu çalışmalı")

	# Koşma daha hızlı olmalı
	await _physics_frames(20)
	var p0 := player.global_position
	Input.action_press("move_right")
	await _physics_frames(30)
	var walk_dist := player.global_position.distance_to(p0)
	Input.action_press("sprint")
	p0 = player.global_position
	await _physics_frames(30)
	var run_dist := player.global_position.distance_to(p0)
	Input.action_release("sprint")
	Input.action_release("move_right")
	_expect(run_dist > walk_dist * 1.3, "koşma yürümeden hızlı olmalı (%.2f / %.2f)" % [run_dist, walk_dist])

	# Duvardan geçememeli: bekleme salonunun güney duvarına doğru uzun süre yürü
	player.global_position = Vector3(-8.0, 0.1, 8.0)
	await _physics_frames(5)
	Input.action_press("move_back")
	await _physics_frames(150)
	Input.action_release("move_back")
	_expect(player.global_position.z < 10.0, "güney duvarından geçmemeli (z=%.2f)" % player.global_position.z)

	# Oda algılama: kapıdan muayene odasına gir
	player.global_position = Vector3(-7.0, 0.1, -1.5)
	await _physics_frames(10)
	_expect(clinic.current_room == "room_corridor", "koridor algılanmalı (%s)" % clinic.current_room)
	Input.action_press("move_forward")
	await _physics_frames(90)
	Input.action_release("move_forward")
	_expect(clinic.current_room == "room_exam", "kapıdan muayene odasına girilmeli (%s, z=%.2f)" % [clinic.current_room, player.global_position.z])

	for key in ["room_pharmacy", "room_wc", "room_waiting"]:
		var rect: Rect2 = clinic.ROOMS[key]
		player.global_position = Vector3(rect.get_center().x, 0.1, rect.get_center().y + 1.5)
		await _physics_frames(10)
		_expect(clinic.current_room == key, "%s algılanmalı (%s)" % [key, clinic.current_room])

	# Komplikasyonlar
	for i in InputSetup.COMPLICATION_KEYS:
		player.trigger_complication(i)
		await _physics_frames(15)
	_expect(clinic.npcs.size() >= 5, "NPC'ler oluşmalı")

	if _failures == 0:
		print("3D TESTİ GEÇTİ")
	quit(1 if _failures > 0 else 0)
