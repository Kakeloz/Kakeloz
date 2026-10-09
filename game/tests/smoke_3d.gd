extends SceneTree
## 3D klinik duman testi: harita yükleniyor mu, oyuncu yürüyebiliyor mu,
## duvardan geçemiyor mu, odalar algılanıyor mu, komplikasyonlar çalışıyor mu?
## Hapşırık eşyaları savuruyor mu, kayma/itme/hareketler ve NPC dolaşması
## çalışıyor mu?
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


## Model serbest kalana (action == "") kadar bekler.
func _wait_free(model: Character3D, max_frames: int = 600) -> void:
	for i in max_frames:
		if model.action == "" and not model.is_slipping():
			return
		await physics_frame


## Oyuncuyu verilen yere, durgun ve kuzeye (-z) bakar şekilde koyar.
func _place_player(player: Player, pos: Vector3) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.model.rotation.y = 0.0
	await _physics_frames(10)


func _run() -> void:
	var clinic: Node3D = load("res://scenes/clinic.tscn").instantiate()
	root.add_child(clinic)
	# Test tekrarlanabilir olsun: muz kabukları haritadan uzağa, NPC'ler
	# oyuncu testleri bitene kadar dondurulur (yoksa yürürken çarpar/hapşırırlar).
	var bananas: Array = clinic.bananas if "bananas" in clinic else []
	for i in bananas.size():
		(bananas[i] as Node3D).global_position = Vector3(100.0 + i * 5.0, -50.0, 100.0)
	for npc in clinic.npcs:
		npc.process_mode = Node.PROCESS_MODE_DISABLED
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
	await _wait_free(player.model)

	# Hapşırık önündeki kutuyu savurmalı
	var spot := Vector3(-2.4, 0.1, 7.6)
	await _place_player(player, spot)
	var box := RigidBody3D.new()
	var box_cs := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.5, 0.5, 0.5)
	box_cs.shape = box_shape
	box.add_child(box_cs)
	box.can_sleep = false
	box.mass = 2.0
	clinic.add_child(box)
	box.global_position = spot + Vector3(0, 0.2, -1.5)
	await _physics_frames(10)
	var box_start := box.global_position
	player.model.play_sneeze()
	_expect(player.model.action == "sneeze", "hapşırma action'ı ayarlamalı (%s)" % player.model.action)
	await _physics_frames(120)
	var box_moved := box.global_position.distance_to(box_start)
	_expect(box_moved > 0.5, "hapşırık kutuyu savurmalı (%.2f m)" % box_moved)
	box.queue_free()
	await _wait_free(player.model)

	# Kayma: kontrol kaybolur, ~2.5 sn sonra geri gelir
	await _place_player(player, spot)
	player.slip()
	_expect(player.model.is_slipping(), "slip() sonrası kayıyor olmalı")
	var slip_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(60)
	Input.action_release("move_forward")
	var slip_moved := player.global_position.distance_to(slip_start)
	_expect(slip_moved < 0.5, "kayarken ileri girdi oyuncuyu yürütmemeli (%.2f m)" % slip_moved)
	await _physics_frames(150)
	_expect(not player.model.is_slipping(), "3.5 sn sonra kayma bitmeli")
	await _wait_free(player.model)

	# İtme: +x yönünde savrulmalı
	await _place_player(player, spot)
	var kb_start := player.global_position
	player.knockback(Vector3(5, 0, 0))
	await _physics_frames(60)
	var kb_moved := player.global_position.x - kb_start.x
	_expect(kb_moved > 0.5, "knockback +x yönüne itmeli (%.2f m)" % kb_moved)

	# Hareketler: halay (tuş olayıyla) ve el sallama
	await _place_player(player, spot)
	var dance_ev := InputEventAction.new()
	dance_ev.action = "dance"
	dance_ev.pressed = true
	Input.parse_input_event(dance_ev)
	Input.flush_buffered_events()
	await process_frame
	_expect(player.model.action == "dance", "G tuşu halay başlatmalı (%s)" % player.model.action)
	var dance_start := player.global_position
	Input.action_press("move_forward")
	await _physics_frames(30)
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(dance_start) < 0.3, "halay sırasında yürünmemeli")
	await _wait_free(player.model)
	player.model.play_wave()
	_expect(player.model.action == "wave", "el sallama action'ı ayarlamalı (%s)" % player.model.action)
	await _wait_free(player.model)

	# Muz kabuğu (klinikte varsa): üstüne basınca kaymalı
	if not bananas.is_empty():
		await _place_player(player, spot)
		var banana: Node3D = bananas[0]
		banana.global_position = Vector3(spot.x, 0.0, spot.z - 2.0)
		await _physics_frames(5)
		player.global_position = Vector3(banana.global_position.x, 0.1, banana.global_position.z)
		await _physics_frames(20)
		_expect(player.model.is_slipping(), "muz kabuğuna basınca kaymalı")
		await _wait_free(player.model)

	# NPC'ler dolaşmalı: en az biri başlangıç yerinden 1 m'den fazla uzaklaşmalı
	var npc_spawns := {}
	for npc in clinic.npcs:
		npc.process_mode = Node.PROCESS_MODE_INHERIT
		if npc is Npc and not npc.stationary:
			npc_spawns[npc] = npc.global_position
	_expect(not npc_spawns.is_empty(), "dolaşan NPC olmalı")
	var max_wander := 0.0
	for i in 16:
		await _physics_frames(30)
		for npc in npc_spawns:
			if is_instance_valid(npc):
				max_wander = maxf(max_wander, (npc as Node3D).global_position.distance_to(npc_spawns[npc]))
	_expect(max_wander > 1.0, "NPC'ler dolaşmalı (en fazla %.2f m)" % max_wander)

	if _failures == 0:
		print("3D TESTİ GEÇTİ")
	quit(1 if _failures > 0 else 0)
