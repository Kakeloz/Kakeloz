class_name Npc
extends CharacterBody3D
## Klinikte dolaşan ya da yerinde duran NPC. Basit durum makinesi:
## boşta bekle -> rastgele bir yere yürü / halay çek / hapşır / el salla.
## Sabit (stationary) NPC'ler hiç yürümez, yerinde ara sıra hareket yapar.

enum State { IDLE, WALK }

## Kliniğin yürünebilir açık alanları (x, z dikdörtgenleri).
## Zincir: aisle <-> front <-> corridor
const AREAS := {
	"aisle": Rect2(-4.4, 3.2, 3.2, 6.0),
	"front": Rect2(-11.0, 0.7, 17.0, 2.1),
	"corridor": Rect2(-11.3, -2.3, 22.6, 1.8),
}
const AREA_CHAIN := ["aisle", "front", "corridor"]
## Komşu alanlar arası geçiş noktaları: "nereden>nereye"
const LINKS := {
	"aisle>front": [Vector2(-2.8, 2.6)],
	"front>aisle": [Vector2(-2.8, 3.4)],
	"front>corridor": [Vector2(-6.0, 1.0), Vector2(-6.0, -1.0)],
	"corridor>front": [Vector2(-6.0, -1.0), Vector2(-6.0, 1.0)],
}
const WALK_SPEED := 1.6
const ACCELERATION := 12.0
const TURN_SPEED := 8.0
const ARRIVE_DIST := 0.3
## Hedef noktaları alan kenarından bu kadar içeride seçilir
const AREA_MARGIN := 0.3
## Bu süre içinde STUCK_MIN_MOVE'dan az ilerlerse yürümekten vazgeçer
const STUCK_TIME := 1.5
const STUCK_MIN_MOVE := 0.4
const SLIP_FRICTION := 4.0
const PUSH_DECAY := 4.0
const PUSH_HOP := 0.6

var body_color := Color("2a9d8f")
var is_doctor := false
var stationary := false
## Modelin başlangıçta baktığı yön (radyan)
var face_y := 0.0
var model: Character3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _rng := RandomNumberGenerator.new()
var _state := State.IDLE
var _idle_left := 0.0
var _path: Array[Vector2] = []
var _move := Vector3.ZERO
var _push := Vector3.ZERO
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _was_on_floor := true


func _ready() -> void:
	_rng.randomize()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	add_child(shape)

	model = Character3D.new()
	model.body_color = body_color
	model.is_doctor = is_doctor
	model.rotation.y = face_y
	add_child(model)
	model.sneezed.connect(_on_sneezed)
	_idle_left = _rng.randf_range(0.5, 3.0)


## Muz kabuğu vb.: yürümeyi bırakır, sırtüstü düşer.
func slip() -> void:
	if model.is_slipping():
		return
	_stop_walking()
	model.play_slip()


## Dışarıdan itme (ör. hapşırık): yürümeyi bırakır, savrulur.
func knockback(impulse: Vector3) -> void:
	_stop_walking()
	_push += Vector3(impulse.x, 0.0, impulse.z)
	if impulse.y > 0.0:
		velocity.y = maxf(velocity.y, impulse.y * PUSH_HOP)


func _on_sneezed(origin: Vector3, forward: Vector3) -> void:
	Chaos.sneeze_push(self, origin, forward)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var dir := Vector3.ZERO
	if model.is_slipping():
		_move = _move.move_toward(Vector3.ZERO, SLIP_FRICTION * delta)
	else:
		match _state:
			State.IDLE:
				_move = _move.move_toward(Vector3.ZERO, ACCELERATION * delta)
				_update_idle(delta)
			State.WALK:
				dir = _walk_direction(delta)
				_move = _move.move_toward(dir * WALK_SPEED, ACCELERATION * delta)

	_push = _push.lerp(Vector3.ZERO, clampf(PUSH_DECAY * delta, 0.0, 1.0))
	if _push.length_squared() < 0.0004:
		_push = Vector3.ZERO
	velocity.x = _move.x + _push.x
	velocity.z = _move.z + _push.z
	var fall_speed := velocity.y
	move_and_slide()
	Chaos.push_from_slides(self, 0.4)

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and fall_speed < -1.0:
		model.land(clampf(-fall_speed / 8.0, 0.2, 1.5))
	_was_on_floor = on_floor

	if dir.length() > 0.05:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z), TURN_SPEED * delta)
	model.walk_amount = 0.0 if model.is_slipping() else Vector2(_move.x, _move.z).length() / WALK_SPEED


# --- Davranış -----------------------------------------------------------

func _update_idle(delta: float) -> void:
	# Bir hareket sürüyorsa bitmesini bekle
	if model.action != "":
		return
	_idle_left -= delta
	if _idle_left > 0.0:
		return
	_idle_left = _rng.randf_range(1.0, 3.0) if not stationary else _rng.randf_range(3.0, 7.0)
	var roll := _rng.randf()
	if stationary:
		# Yürümez; ara sıra el sallar, hapşırır ya da halay çeker
		if roll < 0.3:
			model.play_wave()
		elif roll < 0.5:
			model.play_sneeze()
		elif roll < 0.62:
			model.play_dance(_rng.randf_range(3.0, 5.0))
		return
	if roll < 0.5:
		_start_walk()
	elif roll < 0.65:
		model.play_dance(_rng.randf_range(3.0, 5.0))
	elif roll < 0.8:
		model.play_sneeze()
	elif roll < 0.9:
		model.play_wave()


func _start_walk() -> void:
	var to_area: String = AREA_CHAIN[_rng.randi_range(0, AREA_CHAIN.size() - 1)]
	var rect: Rect2 = AREAS[to_area].grow(-AREA_MARGIN)
	var target := Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))
	_path = route(Vector2(global_position.x, global_position.z), target)
	_state = State.WALK
	_stuck_t = 0.0
	_stuck_pos = global_position


func _stop_walking() -> void:
	_path.clear()
	_state = State.IDLE
	_idle_left = _rng.randf_range(1.0, 3.0)


## Sıradaki ara noktaya doğru yatay birim yön; varınca bir sonrakine geçer.
func _walk_direction(delta: float) -> Vector3:
	var pos := Vector2(global_position.x, global_position.z)
	while not _path.is_empty() and pos.distance_to(_path[0]) < ARRIVE_DIST:
		_path.remove_at(0)
	if _path.is_empty():
		_stop_walking()
		return Vector3.ZERO

	# Takılma kontrolü: uzun süre ilerleyemezse vazgeç
	_stuck_t += delta
	if _stuck_t >= STUCK_TIME:
		var progress := global_position.distance_to(_stuck_pos)
		_stuck_t = 0.0
		_stuck_pos = global_position
		if progress < STUCK_MIN_MOVE:
			_stop_walking()
			return Vector3.ZERO

	var to := _path[0] - pos
	return Vector3(to.x, 0.0, to.y).normalized()


# --- Yol bulma ----------------------------------------------------------

## Noktanın içinde bulunduğu (yoksa en yakın) alanın adı.
static func area_of(p: Vector2) -> String:
	var best := ""
	var best_dist := INF
	for key in AREAS:
		var rect: Rect2 = AREAS[key]
		if rect.has_point(p):
			return key
		var closest := p.clamp(rect.position, rect.end)
		var d := closest.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = key
	return best


## from'dan to'ya alan zinciri üzerinden geçen ara noktalar (to dahil).
static func route(from: Vector2, to: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var a: int = AREA_CHAIN.find(area_of(from))
	var b: int = AREA_CHAIN.find(area_of(to))
	var step := 1 if b > a else -1
	while a != b:
		var key := "%s>%s" % [AREA_CHAIN[a], AREA_CHAIN[a + step]]
		for p in LINKS[key]:
			result.append(p)
		a += step
	result.append(to)
	return result
