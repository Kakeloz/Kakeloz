class_name Character3D
extends Node3D
## Basit 3D şekillerden (kapsül, küre, silindir) oluşan karakter.
## Yürüme animasyonu ve komplikasyonlar kodla, parçaların boyutu/konumu/açısı
## değiştirilerek üretilir. İleride şekiller yerine hazır modeller takılabilir.
## Karakterin önü -Z yönüdür (Godot standardı).

const SKIN := Color("ffd6a5")
const DARK := Color("1d3557")
const PANTS := Color("264653")

const HIP_Y := 0.45
const BODY_H := 1.0
const HEAD_R := 0.3

var body_color := Color("2a9d8f")
var is_doctor := false
## 0 = duruyor, 1 = yürüyor, 1.5+ = koşuyor
var walk_amount := 0.0

# Animasyonla değişen değerler
var shake := 0.0
var neck_len := 0.0
var float_height := 0.0
var arm_spread := 0.0
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
var _pupils: Array[MeshInstance3D] = []
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _time := 0.0
var _tween: Tween


func _ready() -> void:
	_time = randf() * 10.0
	_build()


func _process(delta: float) -> void:
	_time += delta
	var phase := _time * 9.0
	var swing := sin(phase) * 0.6 * minf(walk_amount, 1.5)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	_arm_r.rotation.x = swing * 0.8
	_arm_l.rotation.z = -arm_spread
	_arm_r.rotation.z = arm_spread

	var bob := absf(sin(phase)) * 0.06 * minf(walk_amount, 1.5)
	var breathe := sin(_time * 2.0) * 0.01
	var jitter := Vector3.ZERO
	if shake > 0.0:
		jitter = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake
	_visual.position = jitter + Vector3(0, float_height + bob + breathe, 0)
	if robot:
		_visual.rotation.y = snappedf(sin(_time * 3.0) * 0.6, 0.3)

	# Kafa ve boyun gövdenin tepesini takip eder (gövde şişince kafa da yükselir)
	var body_top := HIP_Y + BODY_H * _body_pivot.scale.y
	_head_pivot.position.y = body_top + neck_len
	_neck.position.y = body_top + neck_len * 0.5
	_neck.scale.y = maxf(neck_len + 0.12, 0.12) / 0.12

	_head_round.visible = not robot
	_head_box.visible = robot
	_hat.visible = is_doctor
	for i in _pupils.size():
		var side := -1.0 if i == 0 else 1.0
		var off := Vector3.ZERO
		if cross_eyes:
			off = Vector3(-side * 0.03, sin(_time * 20.0 * side) * 0.02, 0)
		_pupils[i].position = Vector3(side * 0.11, 0.36, -0.31) + off


func reset_visuals() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	shake = 0.0
	neck_len = 0.0
	float_height = 0.0
	arm_spread = 0.0
	robot = false
	cross_eyes = false
	if _visual:
		_visual.scale = Vector3.ONE
		_visual.rotation = Vector3.ZERO
		_body_pivot.scale = Vector3.ONE
		_head_pivot.scale = Vector3.ONE
		_arm_l.scale = Vector3.ONE
		_arm_r.scale = Vector3.ONE
		_mouth.scale = Vector3.ONE


## Komplikasyon animasyonunu oynatır (yaklaşık 3-4 saniye).
func play_complication(id: String) -> void:
	reset_visuals()
	_mouth.scale = Vector3(0.5, 3.0, 1.0)
	_tween = create_tween()
	match id:
		"balloon_head":
			_tween.tween_property(_head_pivot, "scale", Vector3.ONE * 3.0, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.8, 1.5).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(0.8)
			_tween.tween_property(_head_pivot, "scale", Vector3.ONE * 0.4, 0.12)
			_tween.tween_property(_head_pivot, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"long_arms":
			_tween.tween_property(self, "arm_spread", 1.3, 0.4)
			_tween.parallel().tween_property(_arm_l, "scale", Vector3(1, 4.5, 1), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_arm_r, "scale", Vector3(1, 4.5, 1), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.2)
			_tween.tween_property(_arm_l, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_arm_r, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "arm_spread", 0.0, 0.6)
		"ceiling_stick":
			# Ayaklar tavana yapışır, karakter baş aşağı sarkar
			_tween.tween_property(self, "float_height", 2.95, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(_visual, "rotation:z", PI, 0.5)
			_tween.tween_property(self, "shake", 0.04, 0.2)
			_tween.tween_interval(1.6)
			_tween.tween_property(self, "shake", 0.0, 0.1)
			_tween.tween_property(_visual, "rotation:z", 0.0, 0.3)
			_tween.parallel().tween_property(self, "float_height", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"inflate":
			_tween.tween_property(_body_pivot, "scale", Vector3(2.4, 1.5, 2.4), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "float_height", 0.7, 1.4).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(1.0)
			_tween.tween_property(_body_pivot, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
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
			_tween.tween_callback(func():
				robot = false
				_visual.rotation.y = 0.0)
		"long_neck":
			_tween.tween_property(self, "neck_len", 1.3, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.4)
			_tween.tween_property(self, "neck_len", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"shrink":
			_tween.tween_property(_visual, "scale", Vector3.ONE * 0.3, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			_tween.tween_interval(1.8)
			_tween.tween_property(_visual, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_:
			push_warning("Bilinmeyen komplikasyon: %s" % id)
	_tween.tween_callback(func(): _mouth.scale = Vector3.ONE)


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	# Bacaklar (kalçadan sallanır)
	_leg_l = _limb(_visual, Vector3(-0.15, HIP_Y, 0), 0.1, 0.45, PANTS)
	_leg_r = _limb(_visual, Vector3(0.15, HIP_Y, 0), 0.1, 0.45, PANTS)

	# Gövde
	_body_pivot = Node3D.new()
	_body_pivot.position.y = HIP_Y
	_visual.add_child(_body_pivot)
	var body := _mesh(_body_pivot, _capsule(0.33, BODY_H), body_color)
	body.position.y = BODY_H * 0.5

	# Kollar (omuzdan sallanır, gövdeyle birlikte şişer)
	_arm_l = _limb(_body_pivot, Vector3(-0.42, BODY_H * 0.78, 0), 0.08, 0.55, body_color.lightened(0.15))
	_arm_r = _limb(_body_pivot, Vector3(0.42, BODY_H * 0.78, 0), 0.08, 0.55, body_color.lightened(0.15))
	for arm in [_arm_l, _arm_r]:
		var hand := _mesh(arm, _sphere(0.1), SKIN)
		hand.position.y = -0.6

	# Boyun
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.09
	neck_mesh.bottom_radius = 0.09
	neck_mesh.height = 0.12
	_neck = _mesh(_visual, neck_mesh, SKIN)

	# Kafa (pivot kafanın altında, böylece büyüyünce yukarı doğru şişer)
	_head_pivot = Node3D.new()
	_visual.add_child(_head_pivot)
	_head_round = _mesh(_head_pivot, _sphere(HEAD_R), SKIN)
	_head_round.position.y = HEAD_R
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE * HEAD_R * 2.0
	_head_box = _mesh(_head_pivot, box_mesh, Color("adb5bd"))
	_head_box.position.y = HEAD_R

	for side in [-1.0, 1.0]:
		var eye := _mesh(_head_pivot, _sphere(0.075), Color.WHITE)
		eye.position = Vector3(side * 0.11, 0.36, -0.25)
		_pupils.append(_mesh(_head_pivot, _sphere(0.035), DARK))
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(0.14, 0.025, 0.02)
	_mouth = _mesh(_head_pivot, mouth_mesh, DARK)
	_mouth.position = Vector3(0, 0.2, -0.29)

	# Doktor başlığı
	_hat = Node3D.new()
	_hat.position.y = HEAD_R * 1.85
	_head_pivot.add_child(_hat)
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.22
	hat_mesh.bottom_radius = 0.24
	hat_mesh.height = 0.16
	_mesh(_hat, hat_mesh, Color.WHITE)
	var cross_v := BoxMesh.new()
	cross_v.size = Vector3(0.04, 0.12, 0.02)
	var cross_h := BoxMesh.new()
	cross_h.size = Vector3(0.12, 0.04, 0.02)
	_mesh(_hat, cross_v, Color("e63946")).position.z = -0.235
	_mesh(_hat, cross_h, Color("e63946")).position.z = -0.235


func _limb(parent: Node3D, pos: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var m := _mesh(pivot, _capsule(radius, length), color)
	m.position.y = -length * 0.5
	return pivot


func _mesh(parent: Node3D, mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
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
