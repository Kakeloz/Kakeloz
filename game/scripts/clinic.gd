extends Node3D
## Mahalle kliniği haritası. Her şey basit kutu/silindir şekillerden kodla
## kurulur; ileride hazır modellerle (ör. Kenney paketleri) değiştirilebilir.
##
## Kuşbakışı yerleşim (x sağa, z aşağı doğru artar):
##
##  z=-10 +-----------+---------+---------+
##        |  Muayene  | Eczane  |   WC    |
##  z=-3  +---kapı----+--kapı---+--kapı---+
##        |            Koridor            |
##  z=0   +----kapı-------------kapı------+
##        |        Bekleme Salonu         |
##  z=10  +-------------------------------+
##       x=-12       x=-2      x=5      x=12

const WALL_H := 3.0
const WALL_T := 0.2
const DOOR_H := 2.3
const WALL_COLOR := Color("f1e9da")
const WOOD := Color("a47148")
const WHITE := Color("f8f9fa")
const CHAIR := Color("e76f51")
const DARK := Color("343a40")
const PLAYER_COLOR := Color("e76f51")
const NPC_COLORS := [Color("2a9d8f"), Color("457b9d"), Color("9b5de5"), Color("f4a261"), Color("6a994e"), Color("e5989b")]
const DOCTOR_COAT := Color("f1faee")
const MEDICINE_COLORS := [Color("e63946"), Color("f4a261"), Color("2a9d8f"), Color("ffb703"), Color("8ecae6"), Color("b5179e")]

const ROOMS := {
	"room_waiting": Rect2(-12, 0, 24, 10),
	"room_corridor": Rect2(-12, -3, 24, 3),
	"room_exam": Rect2(-12, -10, 10, 7),
	"room_pharmacy": Rect2(-2, -10, 7, 7),
	"room_wc": Rect2(5, -10, 7, 7),
}
const PLAYER_SPAWN := Vector3(-2.8, 0.1, 6.5)

var player: Player
var ceiling: Node3D
## Oyuncunun şu an bulunduğu odanın anahtarı (ör. "room_exam")
var current_room := ""
var npcs: Array[Character3D] = []

var _materials: Dictionary = {}
var _rooms_inside: Array = []
var _complications: Array = []
var _npc_timer := 4.0
var _room_label: Label
var _toast_label: Label
var _hint_label: Label
var _toast_left := 0.0


func _ready() -> void:
	InputSetup.ensure_actions()
	_complications = DataLoader.load_complications()
	_build_environment()
	_build_structure()
	_build_waiting_room()
	_build_corridor()
	_build_exam_room()
	_build_pharmacy()
	_build_wc()
	_spawn_player()
	_build_room_areas()
	_build_hud()


func _process(delta: float) -> void:
	_hint_label.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast_label.modulate.a = clampf(_toast_left, 0.0, 1.0)

	# NPC'ler ara sıra rastgele komplikasyon geçirir
	_npc_timer -= delta
	if _npc_timer <= 0.0 and not npcs.is_empty():
		_npc_timer = randf_range(5.0, 9.0)
		var npc: Character3D = npcs.pick_random()
		npc.play_complication(_complications.pick_random()["id"])


# --- Yapı ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bde0fe")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Gölgesiz güneş: tavana rağmen her yeri eşit aydınlatır
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = false
	add_child(sun)


func _build_structure() -> void:
	_floor(ROOMS["room_waiting"], Color("e9d8a6"))
	_floor(ROOMS["room_corridor"], Color("cfd8dc"))
	_floor(ROOMS["room_exam"], Color("a8dadc"))
	_floor(ROOMS["room_pharmacy"], Color("b7e4c7"))
	_floor(ROOMS["room_wc"], Color("bde0fe"))
	ceiling = _box(Vector3(24.4, 0.1, 20.4), Vector3(0, WALL_H + 0.05, 0), WHITE)

	# Dış duvarlar
	_wall_x(-10.0, -12.0, 12.0)
	_wall_x(10.0, -12.0, 12.0)
	_wall_z(-12.0, -10.0, 10.0)
	_wall_z(12.0, -10.0, 10.0)
	# İç duvarlar: [kapı merkezi, kapı genişliği]
	_wall_x(-3.0, -12.0, 12.0, [[-7.0, 1.4], [1.5, 1.4], [8.5, 1.4]])
	_wall_x(0.0, -12.0, 12.0, [[-6.0, 2.6], [6.0, 2.6]])
	_wall_z(-2.0, -10.0, -3.0)
	_wall_z(5.0, -10.0, -3.0)

	for p in [Vector3(-6, 0, 5), Vector3(6, 0, 5), Vector3(-6, 0, -1.5), Vector3(6, 0, -1.5),
			Vector3(-7, 0, -6.5), Vector3(1.5, 0, -6.5), Vector3(8.5, 0, -6.5)]:
		_lamp(p)


func _build_waiting_room() -> void:
	# İki blok sandalye, ortada koridor
	for row in 3:
		for i in 5:
			_chair(Vector3(-10.0 + i * 1.1, 0, 4.0 + row * 2.0))
			_chair(Vector3(0.0 + i * 1.1, 0, 4.0 + row * 2.0))

	# Danışma
	_box(Vector3(3.2, 1.1, 0.8), Vector3(9, 0.55, 2.2), WOOD)
	_box(Vector3(3.4, 0.06, 1.0), Vector3(9, 1.13, 2.2), WHITE, false)
	_sign(Loc.t("sign_reception"), Vector3(9, 1.75, 2.2), 40)
	_npc(Vector3(9, 0, 1.3), NPC_COLORS[3], PI)

	# Sıra ekranı ve tabela
	_box(Vector3(2.4, 1.2, 0.08), Vector3(0, 2.0, 0.16), DARK, false)
	_sign(Loc.t("sign_queue"), Vector3(0, 2.0, 0.21), 44, 0.0, Color("ffb703"))
	_sign(Loc.t("sign_waiting"), Vector3(-6, 2.65, 0.12), 36)

	# Posterler (güney duvarı, kuzeye bakar)
	_poster(Loc.t("poster_fakers"), Vector3(-6, 1.8, 9.88), PI, Color("e63946"))
	_poster(Loc.t("poster_quiet"), Vector3(4, 1.8, 9.88), PI, Color("457b9d"))

	# Saksılar ve su sebili
	for p in [Vector3(-11.3, 0, 9.3), Vector3(11.3, 0, 9.3), Vector3(-11.3, 0, 0.7), Vector3(11.3, 0, 6.5)]:
		_plant(p)
	_box(Vector3(0.5, 1.1, 0.5), Vector3(-11.5, 0.55, 4), WHITE)
	_cylinder(0.18, 0.45, Vector3(-11.5, 1.33, 4), Color("8ecae6"), false)

	# Bekleyen hastalar ve volta atan biri
	_npc(Vector3(-8.9, 0, 5.0), NPC_COLORS[0], 0.0)
	_npc(Vector3(1.1, 0, 7.0), NPC_COLORS[1], 0.0)
	_npc(Vector3(3.3, 0, 5.0), NPC_COLORS[2], 0.0)
	_pacing_npc(Vector3(-9.0, 0, 2.0), -9.0, -1.0, NPC_COLORS[4])


func _build_corridor() -> void:
	_box(Vector3(2.2, 0.45, 0.5), Vector3(-3.8, 0.225, -2.6), WOOD)
	_box(Vector3(2.2, 0.45, 0.5), Vector3(4.8, 0.225, -2.6), WOOD)
	_cylinder(0.12, 0.55, Vector3(11.7, 0.275, -1.5), Color("e63946"))
	_sign(Loc.t("sign_exam"), Vector3(-7, 2.65, -2.88), 36)
	_sign(Loc.t("sign_pharmacy"), Vector3(1.5, 2.65, -2.88), 36)
	_sign(Loc.t("sign_wc"), Vector3(8.5, 2.65, -2.88), 36)


func _build_exam_room() -> void:
	_box(Vector3(2.2, 0.8, 1.0), Vector3(-7, 0.4, -7.6), WOOD)
	_box(Vector3(0.7, 0.45, 0.05), Vector3(-7, 1.05, -7.9), DARK, false)
	_chair(Vector3(-7, 0, -6.3))
	_npc(Vector3(-7, 0, -8.7), DOCTOR_COAT, PI, true)
	# Muayene yatağı ve dolap
	_box(Vector3(1.0, 0.6, 2.2), Vector3(-11.2, 0.3, -6.5), WHITE)
	_box(Vector3(0.8, 0.15, 0.4), Vector3(-11.2, 0.67, -7.4), Color("caf0f8"), false)
	_box(Vector3(0.6, 2.0, 1.2), Vector3(-2.45, 1.0, -8.5), Color("adb5bd"))
	_poster(Loc.t("poster_book"), Vector3(-7, 2.0, -9.88), 0.0, Color("fefae0"), DARK)


func _build_pharmacy() -> void:
	_box(Vector3(5.0, 1.05, 0.6), Vector3(1.5, 0.525, -6.2), Color("52b788"))
	_npc(Vector3(1.5, 0, -7.2), NPC_COLORS[5], PI)
	# Raflar ve ilaç kutuları
	_box(Vector3(6.4, 2.4, 0.4), Vector3(1.5, 1.2, -9.7), WOOD)
	for row in 4:
		for col in 10:
			var color: Color = MEDICINE_COLORS[(row * 3 + col) % MEDICINE_COLORS.size()]
			_box(Vector3(0.35, 0.3, 0.25), Vector3(-1.2 + col * 0.6, 0.55 + row * 0.5, -9.4), color, false)
	_poster(Loc.t("poster_pharmacy"), Vector3(-1.88, 1.8, -5.5), PI * 0.5, Color("e63946"))


func _build_wc() -> void:
	for x in [7.0, 9.0, 11.0]:
		_box(Vector3(0.08, 2.0, 1.8), Vector3(x, 1.0, -9.1), Color("90e0ef"))
	for x in [6.0, 8.0, 10.0]:
		_cylinder(0.22, 0.45, Vector3(x, 0.225, -9.4), WHITE)
		_box(Vector3(0.5, 0.5, 0.2), Vector3(x, 0.65, -9.8), WHITE)
	_box(Vector3(0.5, 0.85, 0.6), Vector3(11.65, 0.425, -5.5), WHITE)
	_box(Vector3(0.05, 0.9, 1.0), Vector3(11.87, 1.6, -5.5), Color("caf0f8"), false)
	_sign(Loc.t("poster_mirror"), Vector3(11.85, 2.35, -5.5), 24, -PI * 0.5, Color("e63946"))


func _spawn_player() -> void:
	player = Player.new()
	player.body_color = PLAYER_COLOR
	player.position = PLAYER_SPAWN
	add_child(player)
	player.complication_triggered.connect(_on_player_complication)


func _build_room_areas() -> void:
	for key in ROOMS:
		var rect: Rect2 = ROOMS[key]
		var area := Area3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(rect.size.x, WALL_H, rect.size.y)
		cs.shape = shape
		area.add_child(cs)
		area.position = Vector3(rect.get_center().x, WALL_H * 0.5, rect.get_center().y)
		area.body_entered.connect(func(body: Node3D):
			if body == player:
				_rooms_inside.append(key)
				_update_room())
		area.body_exited.connect(func(body: Node3D):
			if body == player:
				_rooms_inside.erase(key)
				_update_room())
		add_child(area)


func _update_room() -> void:
	current_room = _rooms_inside.back() if not _rooms_inside.is_empty() else ""
	_room_label.text = Loc.t(current_room) if current_room != "" else ""


# --- Arayüz -------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_room_label = _hud_label(30, Color.WHITE)
	_room_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_room_label.offset_top = 16
	layer.add_child(_room_label)

	_toast_label = _hud_label(44, Color("ffb703"))
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast_label.offset_top = 90
	_toast_label.modulate.a = 0.0
	layer.add_child(_toast_label)

	_hint_label = _hud_label(36, Color.WHITE)
	_hint_label.text = Loc.t("click_to_play")
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(_hint_label)

	var help := _hud_label(16, Color.WHITE)
	help.text = Loc.t("controls_help")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_left = 16
	help.offset_bottom = -12
	layer.add_child(help)


func _on_player_complication(comp: Dictionary) -> void:
	_toast_label.text = Loc.t("complication_toast", [comp["name"]]) + "\n" + Loc.t("complication_voice", [comp["voice"]])
	_toast_left = 2.5
	_toast_label.modulate.a = 1.0


func _hud_label(size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color("1d3557"))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# --- Yapı taşları -------------------------------------------------------

## x ekseni boyunca uzanan duvar (sabit z). doors: [[merkez_x, genişlik], ...]
func _wall_x(z: float, x0: float, x1: float, doors: Array = []) -> void:
	for seg in _segments(x0, x1, doors):
		_box(Vector3(seg.y - seg.x, WALL_H, WALL_T), Vector3((seg.x + seg.y) * 0.5, WALL_H * 0.5, z), WALL_COLOR)
	for d in doors:
		_box(Vector3(d[1], WALL_H - DOOR_H, WALL_T), Vector3(d[0], (WALL_H + DOOR_H) * 0.5, z), WALL_COLOR)


## z ekseni boyunca uzanan duvar (sabit x). doors: [[merkez_z, genişlik], ...]
func _wall_z(x: float, z0: float, z1: float, doors: Array = []) -> void:
	for seg in _segments(z0, z1, doors):
		_box(Vector3(WALL_T, WALL_H, seg.y - seg.x), Vector3(x, WALL_H * 0.5, (seg.x + seg.y) * 0.5), WALL_COLOR)
	for d in doors:
		_box(Vector3(WALL_T, WALL_H - DOOR_H, d[1]), Vector3(x, (WALL_H + DOOR_H) * 0.5, d[0]), WALL_COLOR)


## Kapı boşluklarını çıkararak duvarın dolu parçalarını döndürür.
func _segments(a: float, b: float, doors: Array) -> Array[Vector2]:
	var sorted_doors := doors.duplicate()
	sorted_doors.sort_custom(func(p, q): return p[0] < q[0])
	var result: Array[Vector2] = []
	var cur := a
	for d in sorted_doors:
		var start: float = d[0] - d[1] * 0.5
		if start > cur:
			result.append(Vector2(cur, start))
		cur = d[0] + d[1] * 0.5
	if cur < b:
		result.append(Vector2(cur, b))
	return result


func _floor(rect: Rect2, color: Color) -> void:
	var c := rect.get_center()
	_box(Vector3(rect.size.x, 0.2, rect.size.y), Vector3(c.x, -0.1, c.y), color)


func _lamp(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(pos.x, WALL_H - 0.3, pos.z)
	light.omni_range = 8.0
	light.light_energy = 0.8
	light.light_color = Color("fff3d6")
	add_child(light)
	var panel := _box(Vector3(0.9, 0.05, 0.9), Vector3(pos.x, WALL_H - 0.03, pos.z), Color("fffbe6"), false)
	var mat: StandardMaterial3D = (panel as MeshInstance3D).material_override.duplicate()
	mat.emission_enabled = true
	mat.emission = Color("fff3d6")
	(panel as MeshInstance3D).material_override = mat


## Sandalye; oturan kişi -z yönüne (kuzeye) bakar.
func _chair(pos: Vector3) -> void:
	_box(Vector3(0.7, 0.42, 0.6), pos + Vector3(0, 0.21, 0), DARK)
	_box(Vector3(0.8, 0.08, 0.7), pos + Vector3(0, 0.46, 0), CHAIR, false)
	_box(Vector3(0.8, 0.65, 0.08), pos + Vector3(0, 0.82, 0.32), CHAIR)


func _plant(pos: Vector3) -> void:
	_cylinder(0.3, 0.5, pos + Vector3(0, 0.25, 0), Color("9c6644"))
	_sphere(0.55, pos + Vector3(0, 1.0, 0), Color("6a994e"))


func _npc(pos: Vector3, color: Color, face_y: float, doctor := false) -> Character3D:
	var body := StaticBody3D.new()
	return _attach_npc(body, pos, color, face_y, doctor)


## Bekleme salonunda x ekseninde volta atan NPC.
func _pacing_npc(pos: Vector3, x_min: float, x_max: float, color: Color) -> void:
	var body := AnimatableBody3D.new()
	var ch := _attach_npc(body, pos, color, 0.0, false)
	var tween := create_tween().set_loops()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var duration := (x_max - x_min) / 2.0
	tween.tween_callback(_set_walk.bind(ch, -PI * 0.5, 1.0))
	tween.tween_property(body, "position:x", x_max, duration)
	tween.tween_callback(_set_walk.bind(ch, -PI * 0.5, 0.0))
	tween.tween_interval(1.2)
	tween.tween_callback(_set_walk.bind(ch, PI * 0.5, 1.0))
	tween.tween_property(body, "position:x", x_min, duration)
	tween.tween_callback(_set_walk.bind(ch, PI * 0.5, 0.0))
	tween.tween_interval(1.2)


func _set_walk(ch: Character3D, face_y: float, amount: float) -> void:
	ch.rotation.y = face_y
	ch.walk_amount = amount


func _attach_npc(body: PhysicsBody3D, pos: Vector3, color: Color, face_y: float, doctor: bool) -> Character3D:
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	cs.shape = capsule
	cs.position.y = 0.95
	body.add_child(cs)
	var ch := Character3D.new()
	ch.body_color = color
	ch.is_doctor = doctor
	ch.rotation.y = face_y
	body.add_child(ch)
	body.position = pos
	add_child(body)
	npcs.append(ch)
	return ch


func _sign(text: String, pos: Vector3, font_size: int, rot_y: float = 0.0, color: Color = Color("1d3557")) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = font_size
	lbl.pixel_size = 0.006
	lbl.modulate = color
	lbl.outline_size = 0
	lbl.position = pos
	lbl.rotation.y = rot_y
	lbl.double_sided = false
	add_child(lbl)
	return lbl


func _poster(text: String, pos: Vector3, rot_y: float, bg: Color, fg: Color = Color.WHITE) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	add_child(holder)
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6, 1.2, 0.03)
	panel.mesh = mesh
	panel.material_override = _mat(bg)
	holder.add_child(panel)
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.modulate = fg
	lbl.outline_size = 0
	lbl.position.z = 0.03
	lbl.double_sided = false
	holder.add_child(lbl)


func _box(size: Vector3, pos: Vector3, color: Color, collide := true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	return _place(mesh, shape if collide else null, pos, color)


func _cylinder(radius: float, height: float, pos: Vector3, color: Color, collide := true) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _place(mesh, shape if collide else null, pos, color)


func _sphere(radius: float, pos: Vector3, color: Color) -> Node3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _place(mesh, null, pos, color)


## Mesh'i sahneye koyar; shape verilirse çarpışmalı bir StaticBody3D içine alır.
func _place(mesh: Mesh, shape: Shape3D, pos: Vector3, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	if shape == null:
		mi.position = pos
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.add_child(mi)
	body.position = pos
	add_child(body)
	return body


func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		_materials[color] = mat
	return _materials[color]
