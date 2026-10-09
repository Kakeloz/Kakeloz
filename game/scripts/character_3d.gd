class_name Character3D
extends Node3D
## Çizgi film tarzı, basit 3D şekillerden oluşan komik karakter.
## - Kocaman, sallanan kafa (bobblehead): hızlanınca/durunca yaylanır.
## - İçinde gözbebeği yuvarlanan oyuncak gözler.
## - Rastgele görünüm: ten, kilo, boy, burun, saç, bıyık, hasta aksesuarı.
## - Hareketler: halay, hapşırık, el sallama, kayıp düşme, komplikasyonlar.
## Karakterin önü -Z yönüdür, ayakları yerel orijindedir (boy ~2 m).

signal sneezed(origin: Vector3, forward: Vector3)
signal slipped

const SKINS := [Color("ffd6a5"), Color("f1c27d"), Color("e0ac69"), Color("c68642"), Color("ffe0bd"), Color("8d5524")]
const HAIR_COLORS := [Color("2b2d42"), Color("6f4518"), Color("f4d35e"), Color("d00000"), Color("8338ec"), Color("dee2e6")]
const NOSES := ["round", "long", "potato", "tiny"]
const HAIRS := ["none", "tuft", "afro", "mohawk", "bald"]
const ACCESSORIES := ["none", "bandage", "neck_brace", "ice_pack", "eye_patch", "thermometer", "arm_cast", "glasses"]

const DARK := Color("1b1b2f")
const PANTS := Color("264653")
const SHOES := Color("3d405b")
const OUTLINE := 0.018

const HIP_Y := 0.42
const LEG_LEN := 0.42
const BODY_H := 0.85
const BODY_R := 0.34
const HEAD_R := 0.4
const SNEEZE_CHARGE := 0.8

var body_color := Color("2a9d8f")
var is_doctor := false
## Boş bırakılırsa rastgele bir görünüm seçilir (bkz. random_look).
var look: Dictionary = {}
## 0 = duruyor, ~1 = yürüyor, 1.3+ = koşuyor (kollar havada sallanır)
var walk_amount := 0.0
## "" boşta; değilse "dance", "sneeze", "wave", "slip", "complication"
var action := ""
var mood := "normal"

# Komplikasyon ve hareketlerin tween ile değiştirdiği değerler
var shake := 0.0
var neck_len := 0.0
var float_height := 0.0
var arm_spread := 0.0
var arm_stretch := 1.0
var head_size := 1.0
var body_puff := Vector3.ONE
var uni_scale := 1.0
var tumble := 0.0
var flip := 0.0
var robot := false
var cross_eyes := false

var _visual: Node3D
var _body_pivot: Node3D
var _neck: MeshInstance3D
var _head_pivot: Node3D
var _head_round: MeshInstance3D
var _head_box: MeshInstance3D
var _hat: Node3D
var _mouth: MeshInstance3D
var _brows: Array[MeshInstance3D] = []
var _eyes: Array[MeshInstance3D] = []
var _pupils: Array[MeshInstance3D] = []
var _eye_pos: Array[Vector3] = []
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _hanky: MeshInstance3D
var _stars: Node3D

var _time := 0.0
var _tween: Tween
var _action_time := 0.0
var _action_len := 0.0
var _sneeze_done := false
var _dizzy := 0.0

var _has_last := false
var _last_pos := Vector3.ZERO
var _last_vel := Vector3.ZERO
var _wob := Vector2.ZERO
var _wob_v := Vector2.ZERO
var _pupil: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _pupil_v: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _look_target := Vector2.ZERO
var _look_timer := 0.0
var _squash := 0.0
var _squash_v := 0.0


static func random_look(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	return {
		"skin": SKINS[r.randi() % SKINS.size()],
		"width": r.randf_range(0.85, 1.4),
		"height": r.randf_range(0.9, 1.1),
		"nose": NOSES[r.randi() % NOSES.size()],
		"hair": HAIRS[r.randi() % HAIRS.size()],
		"hair_color": HAIR_COLORS[r.randi() % HAIR_COLORS.size()],
		"accessory": ACCESSORIES[r.randi() % ACCESSORIES.size()],
		"mustache": r.randf() < 0.35,
		"brow_tilt": r.randf_range(-0.3, 0.3),
	}


func _ready() -> void:
	if look.is_empty():
		look = random_look()
	if is_doctor:
		look["accessory"] = "glasses"
		look["hair"] = "bald"
	_time = randf() * 10.0
	_build()


func _process(delta: float) -> void:
	_time += delta
	_update_springs(delta)
	_update_action(delta)
	_animate(delta)


# --- Hareketler ---------------------------------------------------------

func is_slipping() -> bool:
	return action == "slip"


func play_dance(duration: float = 4.0) -> void:
	if _start_action("dance", duration):
		_hanky.visible = true


func play_wave() -> void:
	_start_action("wave", 1.6)


func play_sneeze() -> void:
	if _start_action("sneeze", SNEEZE_CHARGE + 0.7):
		_sneeze_done = false


## Muza basma / kaygan zemin: sırtüstü düşer, kafada yıldızlar döner (~2.6 sn).
func play_slip() -> void:
	if action == "slip":
		return
	reset_visuals()
	action = "slip"
	slipped.emit()
	_burst([Color("ffd166"), Color.WHITE], 14, Vector3(0, 0.3, 0), Vector3.UP, 70.0, 3.0, 0.06)
	_tween = create_tween()
	_tween.tween_property(self, "float_height", 0.9, 0.15).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "tumble", PI * 0.5, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "float_height", 0.38, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _dizzy = 1.8)
	_tween.tween_interval(1.4)
	_tween.tween_property(self, "tumble", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "float_height", 0.0, 0.4)
	_tween.tween_callback(_end_action)


## Yere iniş: karakter ezilip esner. strength ~0.2..1.5
func land(strength: float) -> void:
	_squash_v += strength * 7.0
	if strength > 0.6:
		_burst([Color("dee2e6"), Color("adb5bd")], 10, Vector3(0, 0.05, 0), Vector3.UP, 85.0, 1.5, 0.08)


func reset_visuals() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	shake = 0.0
	neck_len = 0.0
	float_height = 0.0
	arm_spread = 0.0
	arm_stretch = 1.0
	head_size = 1.0
	body_puff = Vector3.ONE
	uni_scale = 1.0
	tumble = 0.0
	flip = 0.0
	robot = false
	cross_eyes = false
	action = ""
	_dizzy = 0.0
	if _hanky:
		_hanky.visible = false


## Komplikasyon animasyonu (yaklaşık 3-4 saniye). Diğer hareketleri keser.
func play_complication(id: String) -> void:
	reset_visuals()
	action = "complication"
	_tween = create_tween()
	match id:
		"balloon_head":
			_tween.tween_property(self, "head_size", 3.0, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.8, 1.5).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(0.8)
			_tween.tween_callback(func(): _burst(
				[Color("e63946"), Color("ffb703"), Color("2a9d8f"), Color("8338ec"), Color("3a86ff")],
				40, _head_pivot.position + Vector3(0, HEAD_R * 3.0, 0), Vector3.UP, 180.0, 4.5, 0.05))
			_tween.tween_property(self, "head_size", 0.4, 0.12)
			_tween.tween_property(self, "head_size", 1.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"long_arms":
			_tween.tween_property(self, "arm_spread", 1.3, 0.4)
			_tween.parallel().tween_property(self, "arm_stretch", 4.5, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.2)
			_tween.tween_property(self, "arm_stretch", 1.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "arm_spread", 0.0, 0.6)
		"ceiling_stick":
			# Ayaklar tavana yapışır, karakter baş aşağı sarkar
			_tween.tween_property(self, "float_height", 2.95, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "flip", PI, 0.5)
			_tween.tween_property(self, "shake", 0.04, 0.2)
			_tween.tween_interval(1.6)
			_tween.tween_property(self, "shake", 0.0, 0.1)
			_tween.tween_property(self, "flip", 0.0, 0.3)
			_tween.parallel().tween_property(self, "float_height", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"inflate":
			_tween.tween_property(self, "body_puff", Vector3(2.2, 1.4, 2.2), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.7, 1.4).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(1.0)
			_tween.tween_property(self, "body_puff", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"tremor":
			_tween.tween_callback(func(): cross_eyes = true)
			_tween.tween_property(self, "shake", 0.08, 0.2)
			_tween.tween_interval(2.2)
			_tween.tween_property(self, "shake", 0.0, 0.3)
			_tween.tween_callback(func(): cross_eyes = false)
		"robot":
			_tween.tween_callback(func(): robot = true)
			_tween.tween_interval(3.0)
			_tween.tween_callback(func(): robot = false)
		"long_neck":
			_tween.tween_property(self, "neck_len", 1.3, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.4)
			_tween.tween_property(self, "neck_len", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"shrink":
			_tween.tween_property(self, "uni_scale", 0.3, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			_tween.tween_interval(1.8)
			_tween.tween_property(self, "uni_scale", 1.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_:
			push_warning("Bilinmeyen komplikasyon: %s" % id)
	_tween.tween_callback(_end_action)


func _start_action(name: String, length: float) -> bool:
	if action != "":
		return false
	action = name
	_action_time = 0.0
	_action_len = length
	return true


func _end_action() -> void:
	action = ""
	_action_len = 0.0
	if _hanky:
		_hanky.visible = false


func _update_action(delta: float) -> void:
	if _dizzy > 0.0:
		_dizzy -= delta
	if action == "" or _action_len <= 0.0:
		return
	_action_time += delta
	if action == "sneeze" and not _sneeze_done and _action_time >= SNEEZE_CHARGE:
		_sneeze_done = true
		_do_sneeze()
	if _action_time >= _action_len:
		_end_action()


func _do_sneeze() -> void:
	var local_mouth := _visual.transform * (_head_pivot.transform * _mouth.position)
	_burst([Color.WHITE, Color("c7f9cc"), Color("b7e4c7")], 36, local_mouth, Vector3.FORWARD, 22.0, 7.0, 0.07)
	_squash_v -= 4.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	sneezed.emit(_mouth.global_position, forward.normalized())


# --- Animasyon ----------------------------------------------------------

func _update_springs(delta: float) -> void:
	var dt := maxf(delta, 0.0001)
	var acc_local := Vector3.ZERO
	var pos := global_position
	if _has_last:
		var vel := (pos - _last_pos) / dt
		if vel.length() > 30.0:
			vel = Vector3.ZERO  # ışınlanma: yay patlamasın
		var acc := (vel - _last_vel) / dt
		_last_vel = vel
		acc_local = (global_transform.basis.inverse() * acc).limit_length(40.0)
	_last_pos = pos
	_has_last = true

	# Yaylar küçük adımlarla hesaplanır: FPS düşse de kararsızlaşmasın
	var steps := clampi(ceili(dt * 120.0), 1, 12)
	var h := dt / steps
	for step in steps:
		_step_springs(h, acc_local)


func _step_springs(dt: float, acc_local: Vector3) -> void:
	# Sallanan kafa: hızlanınca geriye, durunca öne yaylanır
	var target := Vector2(-acc_local.z, acc_local.x) * 0.012
	_wob_v += ((target - _wob) * 90.0 - _wob_v * 7.0) * dt
	_wob = (_wob + _wob_v * dt).limit_length(0.6)

	# Oyuncak gözler: gözbebekleri ataletle yuvarlanır, ara sıra etrafa bakar
	_look_timer -= dt
	if _look_timer <= 0.0:
		_look_timer = randf_range(0.8, 2.5)
		_look_target = Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * 0.035
	for i in 2:
		var stiffness := 55.0 if i == 0 else 80.0
		var t := _look_target + Vector2(-acc_local.x, -acc_local.y) * 0.004 + Vector2(0, -0.012)
		_pupil_v[i] += ((t - _pupil[i]) * stiffness - _pupil_v[i] * 4.0) * dt
		_pupil[i] = (_pupil[i] + _pupil_v[i] * dt).limit_length(0.055)

	# Ezilip esneme
	_squash_v += (-_squash * 220.0 - _squash_v * 9.0) * dt
	_squash = clampf(_squash + _squash_v * dt, -0.4, 0.5)


func _animate(delta: float) -> void:
	var w := clampf(walk_amount, 0.0, 2.0)
	if action == "slip":
		w = 0.0
	var phase := _time * (7.0 + w * 3.0)
	var swing := sin(phase) * 0.75 * minf(w, 1.0)
	var leg_l := swing
	var leg_r := -swing
	var arm_lx := -swing * 0.9
	var arm_rx := swing * 0.9
	var arm_lz := -(arm_spread + 0.15)
	var arm_rz := arm_spread + 0.15
	var head_x := 0.0
	var head_z := 0.0
	var extra_y := 0.0
	var extra_rz := 0.0

	if w > 1.3 and action == "":
		# Koşarken kollar havada çılgınca sallanır
		var f := _time * 20.0
		arm_lx = 1.2 + sin(f) * 1.1
		arm_rx = 1.2 - sin(f) * 1.1
		arm_lz = -(1.0 + sin(f * 1.3) * 0.5)
		arm_rz = 1.0 + cos(f * 1.3) * 0.5

	match action:
		"dance":
			var b := _time * 9.0
			arm_lx = 0.2
			arm_rx = 0.2
			arm_lz = -2.5 + sin(b) * 0.3
			arm_rz = 2.5 + sin(b) * 0.3
			leg_l = maxf(0.0, sin(b)) * 1.0
			leg_r = maxf(0.0, -sin(b)) * 1.0
			extra_y = absf(sin(b)) * 0.15
			extra_rz = sin(b) * 0.12
			head_z = -sin(b) * 0.2
		"wave":
			arm_rx = 0.0
			arm_rz = 2.6 + sin(_time * 14.0) * 0.4
			head_z = 0.12
		"sneeze":
			if not _sneeze_done:
				var k := clampf(_action_time / SNEEZE_CHARGE, 0.0, 1.0)
				head_x = 0.55 * k
				arm_lx = 0.5 * k
				arm_rx = 0.5 * k
			else:
				var k := clampf((_action_time - SNEEZE_CHARGE) / 0.6, 0.0, 1.0)
				head_x = lerpf(-0.6, 0.0, k)
		"slip":
			# Sırtüstü yatarken bacaklar havada, kollar çırpınır
			var f := _time * 16.0
			leg_l = 1.3 + sin(f) * 0.3
			leg_r = 1.3 - sin(f) * 0.3
			arm_lx = 1.2 + sin(f * 1.1) * 0.6
			arm_rx = 1.2 - sin(f * 1.1) * 0.6
			arm_lz = -0.9
			arm_rz = 0.9

	_leg_l.rotation.x = leg_l
	_leg_r.rotation.x = leg_r
	_arm_l.rotation = Vector3(arm_lx, 0.0, arm_lz)
	_arm_r.rotation = Vector3(arm_rx, 0.0, arm_rz)
	_arm_l.scale = Vector3(1.0, arm_stretch, 1.0)
	_arm_r.scale = Vector3(1.0, arm_stretch, 1.0)
	_head_pivot.rotation = Vector3(_wob.x + head_x, 0.0, _wob.y + head_z)
	_head_pivot.scale = Vector3.ONE * head_size

	var jitter := Vector3.ZERO
	if shake > 0.0:
		jitter = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake
	var bob := absf(sin(phase)) * 0.06 * minf(w, 1.0)
	_visual.position = jitter + Vector3(0, float_height + bob + extra_y, 0)
	_visual.rotation = Vector3(tumble, snappedf(sin(_time * 3.0) * 0.6, 0.3) if robot else 0.0, flip + extra_rz)
	var s := _squash + sin(phase * 2.0) * 0.03 * minf(w, 1.0)
	var height: float = look.get("height", 1.0)
	_visual.scale = Vector3(1.0 + s * 0.6, 1.0 - s, 1.0 + s * 0.6) * height * uni_scale
	var width: float = look.get("width", 1.0)
	_body_pivot.scale = Vector3(width, 1.0, width) * body_puff

	# Kafa ve boyun gövdenin tepesini takip eder
	var body_top := HIP_Y + BODY_H * _body_pivot.scale.y
	_neck.position.y = body_top + neck_len * 0.5 - 0.02
	_neck.scale.y = maxf(neck_len + 0.12, 0.12) / 0.12
	_head_pivot.position.y = body_top + neck_len - 0.04
	_head_round.visible = not robot
	_head_box.visible = robot
	_hat.visible = is_doctor

	_update_face()
	_stars.visible = _dizzy > 0.0
	if _stars.visible:
		_stars.rotation.y += delta * 7.0


func _update_face() -> void:
	var face := mood
	match action:
		"complication", "slip":
			face = "ouch"
		"dance", "wave":
			face = "happy"
		"sneeze":
			face = "squint" if not _sneeze_done else "ouch"
	var brow: float = look.get("brow_tilt", 0.0)
	var brow_y := 0.0
	var squint := 1.0
	var mouth_scale := Vector3(1.2, 0.3, 0.5)
	match face:
		"happy":
			mouth_scale = Vector3(1.9, 0.7, 0.5)
			brow_y = 0.03
		"ouch":
			mouth_scale = Vector3(0.9, 1.5, 0.5)
			brow = -0.35
			brow_y = 0.06
		"sad":
			mouth_scale = Vector3(1.0, 0.25, 0.5)
			brow = -0.45
		"squint":
			mouth_scale = Vector3(1.0, 1.2, 0.5)
			squint = 0.25
			brow = 0.3
	_mouth.scale = mouth_scale
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_eyes[i].scale.y = squint
		_brows[i].rotation.z = side * brow
		_brows[i].position.y = HEAD_R + 0.25 + brow_y
		var off: Vector2 = _pupil[i]
		if cross_eyes:
			off = Vector2(-side * 0.045, sin(_time * 25.0 * side) * 0.03)
		_pupils[i].position = _eye_pos[i] + Vector3(off.x, off.y, -0.1)
		_pupils[i].scale.y = squint


# --- Yapım --------------------------------------------------------------

func _build() -> void:
	var skin: Color = look.get("skin", SKINS[0])
	var hair_color: Color = look.get("hair_color", HAIR_COLORS[0])
	var accessory: String = look.get("accessory", "none")

	_visual = Node3D.new()
	add_child(_visual)

	# Bacaklar ve ayakkabılar
	_leg_l = _limb(_visual, Vector3(-0.15, HIP_Y, 0), 0.11, LEG_LEN, PANTS)
	_leg_r = _limb(_visual, Vector3(0.15, HIP_Y, 0), 0.11, LEG_LEN, PANTS)
	for leg in [_leg_l, _leg_r]:
		var shoe := _mesh(leg, _sphere(0.13), SHOES)
		shoe.position = Vector3(0, -LEG_LEN + 0.04, -0.06)
		shoe.scale = Vector3(1.0, 0.6, 1.4)

	# Gövde ve düğmeler
	_body_pivot = Node3D.new()
	_body_pivot.position.y = HIP_Y
	_visual.add_child(_body_pivot)
	var body := _mesh(_body_pivot, _capsule(BODY_R, BODY_H), body_color)
	body.position.y = BODY_H * 0.5
	for y in [0.35, 0.55]:
		var button := _mesh(_body_pivot, _sphere(0.035), DARK, 0.0)
		button.position = Vector3(0, y, -BODY_R + 0.01)

	# Kollar
	var sleeve := body_color.lightened(0.12)
	_arm_l = _limb(_body_pivot, Vector3(-(BODY_R + 0.07), BODY_H * 0.8, 0), 0.085, 0.5, sleeve)
	if accessory == "arm_cast":
		_arm_r = _limb(_body_pivot, Vector3(BODY_R + 0.09, BODY_H * 0.8, 0), 0.13, 0.5, Color.WHITE)
	else:
		_arm_r = _limb(_body_pivot, Vector3(BODY_R + 0.07, BODY_H * 0.8, 0), 0.085, 0.5, sleeve)
	for arm in [_arm_l, _arm_r]:
		var hand := _mesh(arm, _sphere(0.11), skin)
		hand.position.y = -0.56
	# Halay mendili
	var hanky_mesh := BoxMesh.new()
	hanky_mesh.size = Vector3(0.3, 0.02, 0.3)
	_hanky = _mesh(_arm_r, hanky_mesh, Color("e63946"), 0.0)
	_hanky.position = Vector3(0.05, -0.68, 0)
	_hanky.visible = false

	# Boyun
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.1
	neck_mesh.bottom_radius = 0.1
	neck_mesh.height = 0.12
	_neck = _mesh(_visual, neck_mesh, skin)

	# Kafa (pivot kafanın altında: büyüyünce yukarı doğru şişer)
	_head_pivot = Node3D.new()
	_visual.add_child(_head_pivot)
	_head_round = _mesh(_head_pivot, _sphere(HEAD_R), skin)
	_head_round.position.y = HEAD_R
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * HEAD_R * 2.0
	_head_box = _mesh(_head_pivot, box_mesh, Color("adb5bd"))
	_head_box.position.y = HEAD_R
	_head_box.visible = false

	# Oyuncak gözler ve kaşlar
	var brow_mesh := BoxMesh.new()
	brow_mesh.size = Vector3(0.18, 0.045, 0.05)
	for side in [-1.0, 1.0]:
		var eye_pos := Vector3(side * 0.15, HEAD_R + 0.06, -0.33)
		_eye_pos.append(eye_pos)
		var eye := _mesh(_head_pivot, _sphere(0.13), Color.WHITE, 0.01)
		eye.position = eye_pos
		_eyes.append(eye)
		_pupils.append(_mesh(_head_pivot, _sphere(0.06), DARK, 0.0))
		var b := _mesh(_head_pivot, brow_mesh, hair_color, 0.0)
		b.position = Vector3(side * 0.15, HEAD_R + 0.25, -0.31)
		_brows.append(b)

	_build_nose(look.get("nose", "round"), skin)

	var mouth_mesh := _sphere(0.1)
	_mouth = _mesh(_head_pivot, mouth_mesh, Color("6a040f"), 0.0)
	_mouth.position = Vector3(0, HEAD_R - 0.19, -0.34)

	if look.get("mustache", false):
		var m := _mesh(_head_pivot, _capsule(0.045, 0.34), hair_color, 0.0)
		m.position = Vector3(0, HEAD_R - 0.1, -0.38)
		m.rotation.z = PI * 0.5

	_build_hair(look.get("hair", "none"), hair_color)
	_build_accessory(accessory)
	_build_doctor_hat()

	# Baş dönmesi yıldızları
	_stars = Node3D.new()
	_stars.position.y = HEAD_R * 2.0 + 0.18
	_head_pivot.add_child(_stars)
	var star_mesh := SphereMesh.new()
	star_mesh.radius = 0.07
	star_mesh.height = 0.14
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	for i in 4:
		var star := MeshInstance3D.new()
		star.mesh = star_mesh
		star.material_override = Toon.flat(Color("ffd166"))
		var a := TAU * i / 4.0
		star.position = Vector3(cos(a), 0, sin(a)) * 0.38
		_stars.add_child(star)
	_stars.visible = false


func _build_nose(kind: String, skin: Color) -> void:
	var nose_color := skin.darkened(0.15)
	match kind:
		"long":
			var n := _mesh(_head_pivot, _capsule(0.05, 0.45), nose_color)
			n.position = Vector3(0, HEAD_R - 0.03, -0.55)
			n.rotation.x = PI * 0.5
		"potato":
			var n := _mesh(_head_pivot, _sphere(0.13), nose_color)
			n.position = Vector3(0, HEAD_R - 0.05, -0.4)
			n.scale = Vector3(1.3, 0.9, 1.0)
		"tiny":
			var n := _mesh(_head_pivot, _sphere(0.05), nose_color)
			n.position = Vector3(0, HEAD_R - 0.03, -0.41)
		_:
			var n := _mesh(_head_pivot, _sphere(0.1), Color("e76f51"))
			n.position = Vector3(0, HEAD_R - 0.04, -0.42)


func _build_hair(kind: String, color: Color) -> void:
	match kind:
		"tuft":
			for i in 3:
				var t := _mesh(_head_pivot, _capsule(0.045, 0.24), color)
				t.position = Vector3((i - 1) * 0.08, HEAD_R * 2.0 + 0.04, 0.02)
				t.rotation.z = (i - 1) * -0.5
		"afro":
			var a := _mesh(_head_pivot, _sphere(0.38), color)
			a.position = Vector3(0, HEAD_R + 0.24, 0.07)
		"mohawk":
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.22, 0.6)
			var m := _mesh(_head_pivot, box, color)
			m.position = Vector3(0, HEAD_R * 2.0 + 0.02, 0.03)
		"bald":
			for side in [-1.0, 1.0]:
				var tuft := _mesh(_head_pivot, _sphere(0.12), color)
				tuft.position = Vector3(side * 0.36, HEAD_R + 0.08, 0.05)


func _build_accessory(kind: String) -> void:
	match kind:
		"bandage":
			var band := CylinderMesh.new()
			band.top_radius = HEAD_R + 0.015
			band.bottom_radius = HEAD_R + 0.015
			band.height = 0.13
			var b := _mesh(_head_pivot, band, Color.WHITE)
			b.position.y = HEAD_R + 0.28
			var dot := _mesh(_head_pivot, _sphere(0.04), Color("e63946"), 0.0)
			dot.position = Vector3(0.12, HEAD_R + 0.29, -0.33)
		"neck_brace":
			var brace := CylinderMesh.new()
			brace.top_radius = 0.2
			brace.bottom_radius = 0.22
			brace.height = 0.2
			var b := _mesh(_head_pivot, brace, Color.WHITE)
			b.position.y = 0.02
		"ice_pack":
			var box := BoxMesh.new()
			box.size = Vector3(0.34, 0.09, 0.28)
			var p := _mesh(_head_pivot, box, Color("8ecae6"))
			p.position = Vector3(0.06, HEAD_R * 2.0 + 0.01, 0)
			p.rotation.z = 0.25
		"eye_patch":
			var patch := _mesh(_head_pivot, _sphere(0.14), DARK, 0.0)
			patch.position = _eye_pos[0] + Vector3(0, 0, -0.02)
			patch.scale = Vector3(1.0, 1.0, 0.5)
			_pupils[0].visible = false
		"thermometer":
			var t := _mesh(_head_pivot, _capsule(0.022, 0.32), Color.WHITE, 0.008)
			t.position = Vector3(0.14, HEAD_R - 0.2, -0.45)
			t.rotation = Vector3(PI * 0.5, 0, 0.9)
			var tip := _mesh(_head_pivot, _sphere(0.03), Color("e63946"), 0.0)
			tip.position = Vector3(0.24, HEAD_R - 0.13, -0.52)
		"glasses":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.12
			ring.outer_radius = 0.15
			for i in 2:
				var g := _mesh(_head_pivot, ring, DARK, 0.0)
				g.position = _eye_pos[i] + Vector3(0, 0, -0.08)
				g.rotation.x = PI * 0.5
			var bridge := BoxMesh.new()
			bridge.size = Vector3(0.06, 0.025, 0.025)
			var br := _mesh(_head_pivot, bridge, DARK, 0.0)
			br.position = Vector3(0, HEAD_R + 0.08, -0.43)


func _build_doctor_hat() -> void:
	_hat = Node3D.new()
	_hat.position.y = HEAD_R * 2.0 + 0.02
	_head_pivot.add_child(_hat)
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.3
	hat_mesh.bottom_radius = 0.32
	hat_mesh.height = 0.22
	_mesh(_hat, hat_mesh, Color.WHITE)
	var cross_v := BoxMesh.new()
	cross_v.size = Vector3(0.05, 0.15, 0.02)
	var cross_h := BoxMesh.new()
	cross_h.size = Vector3(0.15, 0.05, 0.02)
	_mesh(_hat, cross_v, Color("e63946"), 0.0).position.z = -0.31
	_mesh(_hat, cross_h, Color("e63946"), 0.0).position.z = -0.31


## Tek seferlik parçacık patlaması (karakterin yerel koordinatlarında).
func _burst(colors: Array, amount: int, local_pos: Vector3, direction: Vector3, spread: float, speed: float, size: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -5.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size()))
		cols.append(colors[i])
	grad.offsets = offsets
	grad.colors = cols
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = grad
	p.position = local_pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true


func _limb(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var m := _mesh(pivot, _capsule(radius, length), color)
	m.position.y = -length * 0.5
	return pivot


func _mesh(parent: Node3D, mesh: Mesh, color: Color, outline: float = OUTLINE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(color, outline)
	parent.add_child(mi)
	return mi


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m
