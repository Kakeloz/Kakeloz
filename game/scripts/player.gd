class_name Player
extends CharacterBody3D
## Üçüncü şahıs kontrol: WASD ile kameraya göre yürüme, fareyle kamera,
## Shift ile koşma, Boşluk ile zıplama. 1-8 tuşları komplikasyonları dener.

signal complication_triggered(complication: Dictionary)

const WALK_SPEED := 3.5
const RUN_SPEED := 6.5
const ACCELERATION := 30.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025
const CAMERA_DISTANCE := 3.2
const PITCH_MIN := -1.1
const PITCH_MAX := 0.3

var body_color := Color("e76f51")
var model: Character3D
var camera: Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam_pivot: Node3D
var _spring: SpringArm3D
var _complications: Array = []


func _ready() -> void:
	_complications = DataLoader.load_complications()

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)

	model = Character3D.new()
	model.body_color = body_color
	add_child(model)

	_cam_pivot = Node3D.new()
	_cam_pivot.position.y = 1.6
	add_child(_cam_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = CAMERA_DISTANCE
	_spring.rotation.x = -0.3
	_spring.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	_spring.shape = probe
	_spring.add_excluded_object(get_rid())
	_cam_pivot.add_child(_spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	_spring.add_child(camera)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_pivot.rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		_spring.rotation.x = clampf(_spring.rotation.x - event.relative.y * MOUSE_SENSITIVITY, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		for i in mini(_complications.size(), InputSetup.COMPLICATION_KEYS):
			if event.is_action_pressed("complication_%d" % (i + 1)):
				trigger_complication(i)


func trigger_complication(index: int) -> void:
	var comp: Dictionary = _complications[index]
	model.play_complication(comp["id"])
	complication_triggered.emit(comp)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _cam_pivot.global_transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_toward(velocity.x, dir.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, ACCELERATION * delta)
	move_and_slide()

	if dir.length() > 0.05:
		var target := atan2(-dir.x, -dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, 12.0 * delta)
	model.walk_amount = Vector2(velocity.x, velocity.z).length() / WALK_SPEED
	# Dar yerde kamera karaktere yapışınca karakter ekranı kapatmasın
	model.visible = _spring.get_hit_length() > 0.9
