class_name Player
extends CharacterBody3D
## Üçüncü şahıs kontrol: WASD ile kameraya göre yürüme, fareyle kamera,
## Shift ile koşma, Boşluk ile zıplama. E hapşırma, G halay, Q el sallama.
## 1-8 tuşları komplikasyonları dener.
##
## Halay sırasında yürüme/zıplama girdisi yok sayılır: oyuncu halaya
## başladıysa bitirmek zorunda (daha komik, ayrıca animasyon yarıda kesilmez).

signal complication_triggered(complication: Dictionary)
## Ekranda kısa bir yazı gösterilmesini ister (klinik bunu kendi toast'una bağlar).
signal toast_requested(text: String)

const WALK_SPEED := 3.5
const RUN_SPEED := 6.5
const ACCELERATION := 30.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0025
const CAMERA_DISTANCE := 3.2
const PITCH_MIN := -1.1
const PITCH_MAX := 0.3
## Kayarken yavaşlama (m/s²): düşük tutulur ki biraz kaysın
const SLIP_FRICTION := 4.0
## Dış itmenin (hapşırık vb.) sönümlenme hızı (1/s)
const PUSH_DECAY := 4.0
## İtmenin dikey kısmından ne kadarı zıplamaya dönüşür
const PUSH_HOP := 0.6

var body_color := Color("e76f51")
var model: Character3D
var camera: Camera3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam_pivot: Node3D
var _spring: SpringArm3D
var _complications: Array = []
## Girdiden gelen yatay hız
var _move := Vector3.ZERO
## Dışarıdan gelen, hızla sönen yatay itme
var _push := Vector3.ZERO
var _was_on_floor := true


func _ready() -> void:
	_complications = DataLoader.load_complications()

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)

	model = Character3D.new()
	model.body_color = body_color
	add_child(model)
	model.sneezed.connect(_on_sneezed)

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
	elif event.is_action_pressed("sneeze"):
		if _can_emote():
			model.play_sneeze()
	elif event.is_action_pressed("dance"):
		if _can_emote():
			model.play_dance()
	elif event.is_action_pressed("wave"):
		if _can_emote():
			model.play_wave()
	else:
		for i in mini(_complications.size(), InputSetup.COMPLICATION_KEYS):
			if event.is_action_pressed("complication_%d" % (i + 1)):
				trigger_complication(i)


func trigger_complication(index: int) -> void:
	var comp: Dictionary = _complications[index]
	model.play_complication(comp["id"])
	complication_triggered.emit(comp)


## Muz kabuğu vb.: sırtüstü düşer, bir süre kontrol kaybolur.
func slip() -> void:
	if model.is_slipping():
		return
	model.play_slip()
	toast_requested.emit(_t("toast_slip"))


## Dışarıdan itme (ör. birinin hapşırığı). Yatay kısmı hızla söner,
## dikey kısmı küçük bir zıplama olur.
func knockback(impulse: Vector3) -> void:
	_push += Vector3(impulse.x, 0.0, impulse.z)
	if impulse.y > 0.0:
		velocity.y = maxf(velocity.y, impulse.y * PUSH_HOP)


## Loc'a ağaç üzerinden erişilir: test betikleri (-s) autoload'lar kaydolmadan
## derlendiği için doğrudan "Loc" adı burada derleme hatası verir.
func _t(key: String) -> String:
	var loc := get_node_or_null("/root/Loc")
	return loc.t(key) if loc else key


func _can_emote() -> bool:
	return model.action == ""


func _on_sneezed(origin: Vector3, forward: Vector3) -> void:
	Chaos.sneeze_push(self, origin, forward)
	toast_requested.emit(_t("toast_sneeze"))


func _physics_process(delta: float) -> void:
	var slipping := model.is_slipping()
	# Halay ve kayma sırasında yürüme girdisi yok sayılır
	var locked := slipping or model.action == "dance"

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif not locked and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	var dir := Vector3.ZERO
	if locked:
		_move = _move.move_toward(Vector3.ZERO, SLIP_FRICTION * delta)
	else:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = _cam_pivot.global_transform.basis * Vector3(input.x, 0.0, input.y)
		dir.y = 0.0
		dir = dir.normalized() * minf(input.length(), 1.0)
		var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		_move = _move.move_toward(dir * speed, ACCELERATION * delta)
	_push = _push.lerp(Vector3.ZERO, clampf(PUSH_DECAY * delta, 0.0, 1.0))
	if _push.length_squared() < 0.0004:
		_push = Vector3.ZERO

	velocity.x = _move.x + _push.x
	velocity.z = _move.z + _push.z
	var fall_speed := velocity.y
	move_and_slide()
	Chaos.push_from_slides(self, 0.8)
	# Duvara takılan yürüme hızı birikmesin
	if get_slide_collision_count() > 0:
		_move.x = minf(absf(_move.x), absf(velocity.x)) * signf(_move.x)
		_move.z = minf(absf(_move.z), absf(velocity.z)) * signf(_move.z)

	# Havadan yere iniş: ezilme efekti
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and fall_speed < -1.0:
		model.land(clampf(-fall_speed / 8.0, 0.2, 1.5))
	_was_on_floor = on_floor

	if dir.length() > 0.05:
		var target := atan2(-dir.x, -dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, 12.0 * delta)
	model.walk_amount = 0.0 if slipping else Vector2(_move.x, _move.z).length() / WALK_SPEED
	# Dar yerde kamera karaktere yapışınca karakter ekranı kapatmasın
	model.visible = _spring.get_hit_length() > 0.9
