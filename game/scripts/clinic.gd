extends Node3D
## Mahalle kliniği haritası. Her şey basit kutu/silindir şekillerden kodla
## kurulur; ileride hazır modellerle (ör. Kenney paketleri) değiştirilebilir.
## Görünüm çizgi film tarzıdır (Toon malzemeler + siyah kontur); itilebilen
## fizik eşyaları, gezen muz kabukları ve kaygan zeminler kaosu artırır.
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
##
## Label3D'nin okunan yüzü +Z'dir. Duvar yazılarında rot_y: 0 = +z'ye bakar,
## PI = -z'ye, PI/2 = +x'e, -PI/2 = -x'e.

const WALL_H := 3.0
const WALL_T := 0.2
const DOOR_H := 2.3
## Duvarların alt renkli bandı
const BAND_H := 1.1
const WALL_COLOR := Color("ffe6c4")
const BAND_COLOR := Color("74d3ae")
const DOOR_FRAME := Color("ff9f1c")
const WOOD := Color("d68c45")
const WHITE := Color("f8f9fa")
const DARK := Color("3d405b")
const CHAIR_COLORS := [Color("ff595e"), Color("ffca3a"), Color("1982c4")]
const PLAYER_COLOR := Color("e76f51")
const PATIENT_COLORS := [Color("06d6a0"), Color("9b5de5"), Color("f15bb5"), Color("00bbf9"), Color("fb8500")]
const DOCTOR_COAT := Color("f1faee")
const PHARMACIST_COLOR := Color("2ec4b6")
const RECEPTIONIST_COLOR := Color("ff70a6")
const MEDICINE_COLORS := [Color("e63946"), Color("f4a261"), Color("2a9d8f"), Color("ffb703"), Color("8ecae6"), Color("b5179e")]
const BANANA_YELLOW := Color("ffd60a")
## Muz/ıslak zeminde art arda kaydırmayı engelleyen bekleme süresi (sn)
const SLIP_COOLDOWN := 1.5
const BANANA_HOP_TIME := 0.7
const BANANA_HOP_HEIGHT := 1.3

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
var npcs: Array[Npc] = []
## İtilebilen/savrulabilen fizik eşyaları
var props: Array[RigidBody3D] = []
## Gezen muz kabukları (üstüne basan kayar, kabuk başka yere sıçrar)
var bananas: Array[Area3D] = []

var _rooms_inside: Array = []
var _complications: Array = []
var _npc_timer := 6.0
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
	_build_bananas()
	_spawn_player()
	_spawn_npcs()
	_build_room_areas()
	_build_hud()


func _process(delta: float) -> void:
	_hint_label.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast_label.modulate.a = clampf(_toast_left, 0.0, 1.0)

	# Boştaki bir NPC ara sıra rastgele komplikasyon geçirir
	_npc_timer -= delta
	if _npc_timer <= 0.0:
		_npc_timer = randf_range(8.0, 14.0)
		var idle := npcs.filter(func(n: Npc) -> bool: return n.model != null and n.model.action == "")
		if not idle.is_empty() and not _complications.is_empty():
			var npc: Npc = idle.pick_random()
			npc.model.play_complication(_complications.pick_random()["id"])


## Ekranın üstünde kısa süre görünen yazı.
func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_left = 2.5
	_toast_label.modulate.a = 1.0


# --- Yapı ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("bde0fe")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Gölgesiz güneş: tavana rağmen her yeri eşit aydınlatır
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	add_child(sun)


func _build_structure() -> void:
	_floor(ROOMS["room_waiting"], Color("ffe8a3"), Color("f7c873"))
	_floor(ROOMS["room_corridor"], Color("dfe7ec"), Color("c3cfd9"))
	_floor(ROOMS["room_exam"], Color("bde0fe"), Color("a2d2ff"))
	_floor(ROOMS["room_pharmacy"], Color("d8f3dc"), Color("b7e4c7"))
	_floor(ROOMS["room_wc"], Color("caf0f8"), Color("90e0ef"))
	ceiling = _box(Vector3(24.4, 0.1, 20.4), Vector3(0, WALL_H + 0.05, 0), Color("fffdf5"), true, 0.0)

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
	# İki blok sandalye, ortada koridor; her sıra başka renk
	for row in 3:
		for i in 5:
			var color: Color = CHAIR_COLORS[(row + i) % CHAIR_COLORS.size()]
			_chair(Vector3(-10.0 + i * 1.1, 0, 4.0 + row * 2.0), color)
			_chair(Vector3(0.0 + i * 1.1, 0, 4.0 + row * 2.0), CHAIR_COLORS[(row + i + 1) % CHAIR_COLORS.size()])

	# Danışma
	_box(Vector3(3.2, 1.1, 0.8), Vector3(9, 0.55, 2.2), Color("ef476f"))
	_box(Vector3(3.4, 0.06, 1.0), Vector3(9, 1.13, 2.2), WHITE, false, 0.0)
	_box(Vector3(0.5, 0.35, 0.05), Vector3(8.2, 1.35, 2.0), DARK, false)
	_sign(Loc.t("sign_reception"), Vector3(9, 1.85, 2.2), 40)
	_poster(Loc.t("poster_queue"), Vector3(11.88, 1.75, 4.0), -PI * 0.5, Color("ffbe0b"), DARK, 0.05)

	# Sıra ekranı ve tabela
	_box(Vector3(2.4, 1.2, 0.08), Vector3(0, 2.0, 0.16), DARK, false)
	_sign(Loc.t("sign_queue"), Vector3(0, 2.0, 0.21), 44, 0.0, Color("ffb703"))
	_sign(Loc.t("sign_waiting"), Vector3(-6, 2.65, 0.12), 36)

	# Posterler (güney duvarı kuzeye, batı duvarı doğuya bakar)
	_poster(Loc.t("poster_fakers"), Vector3(-6, 1.8, 9.88), PI, Color("e63946"), Color.WHITE, -0.06)
	_poster(Loc.t("poster_quiet"), Vector3(4, 1.8, 9.88), PI, Color("457b9d"), Color.WHITE, 0.04)
	_poster(Loc.t("poster_banana"), Vector3(-11.88, 1.8, 7.0), PI * 0.5, BANANA_YELLOW, DARK, -0.08)

	# Saksılar ve su sebili
	_plant(Vector3(-11.3, 0, 9.3), 0)
	_plant(Vector3(11.3, 0, 9.3), 1)
	_plant(Vector3(-11.3, 0, 0.7), 2)
	_plant(Vector3(11.3, 0, 6.5), 0)
	_box(Vector3(0.5, 1.1, 0.5), Vector3(-11.5, 0.55, 4), WHITE)
	_cylinder(0.18, 0.45, Vector3(-11.5, 1.33, 4), Color("4cc9f0"), false)
	_wet_floor(Vector3(-10.8, 0, 3.1), Vector3(-11.4, 0, 2.2), PI * 0.35)

	# Fizik eşyaları: plaj topları, danışma yanında koliler, çöp kovası
	_beach_ball(Vector3(-9.0, 0, 1.6), Color("ff595e"), Color("ffca3a"))
	_beach_ball(Vector3(-0.5, 0, 1.3), Color("1982c4"), Color("8ac926"))
	_beach_ball(Vector3(4.2, 0, 2.0), Color("6a4c93"), Color("ff924c"))
	_cardboard(Vector3(11.35, 0, 2.0))
	_cardboard(Vector3(11.35, 0, 2.7))
	_cardboard(Vector3(11.35, 0.6, 2.35), 0.3)
	_trash_bin(Vector3(-11.5, 0, 5.0), Color("3a86ff"))


func _build_corridor() -> void:
	_box(Vector3(2.2, 0.45, 0.5), Vector3(-3.8, 0.225, -2.6), WOOD)
	_box(Vector3(2.2, 0.45, 0.5), Vector3(4.8, 0.225, -2.6), WOOD)
	_sign(Loc.t("sign_exam"), Vector3(-7, 2.65, -2.88), 36)
	_sign(Loc.t("sign_pharmacy"), Vector3(1.5, 2.65, -2.88), 36)
	_sign(Loc.t("sign_wc"), Vector3(8.5, 2.65, -2.88), 36)
	_poster(Loc.t("poster_sneeze"), Vector3(-3.8, 1.75, -2.88), 0.0, Color("80ffdb"), DARK, 0.05)

	# Duvar diplerinde koliler, dubalar ve çöp kovası
	_cardboard(Vector3(-11.55, 0, -2.55))
	_cardboard(Vector3(-11.5, 0, -1.7), -0.2)
	_cone(Vector3(-2.6, 0, -0.48))
	_cone(Vector3(-1.7, 0, -0.48))
	_cone(Vector3(3.1, 0, -0.48))
	_trash_bin(Vector3(11.55, 0, -2.55), Color("8ac926"))


func _build_exam_room() -> void:
	_box(Vector3(2.2, 0.8, 1.0), Vector3(-7, 0.4, -7.6), WOOD)
	_box(Vector3(0.7, 0.45, 0.05), Vector3(-7, 1.05, -7.9), DARK, false)
	_chair(Vector3(-7, 0, -6.3), CHAIR_COLORS[2])
	# Masada dosya yığını (biraz yamuk). Çarpışma kutusu görselden biraz kalın:
	# motor üst üste duran ince kutuları ~1 cm iç içe geçiriyor.
	for i in 3:
		var color: Color = [Color("ffd166"), Color("ef476f"), Color("118ab2")][i]
		var file := _rigid_box(Vector3(0.34, 0.072, 0.26), Vector3(-6.3, 0.8 + 0.037 + i * 0.075, -7.45),
				color, 0.4, 0.0, randf_range(-0.12, 0.12))
		(file.get_child(1) as MeshInstance3D).scale.y = 0.06 / 0.072
	# Muayene yatağı, üstünde lastik ördek; dolap
	_box(Vector3(1.0, 0.6, 2.2), Vector3(-11.2, 0.3, -6.5), WHITE)
	_box(Vector3(0.8, 0.15, 0.4), Vector3(-11.2, 0.67, -7.4), Color("caf0f8"), false, 0.0)
	_duck(Vector3(-11.2, 0.6, -5.9))
	_box(Vector3(0.6, 2.0, 1.2), Vector3(-2.45, 1.0, -8.5), Color("adb5bd"))
	_poster(Loc.t("poster_book"), Vector3(-7, 2.0, -9.88), 0.0, Color("fefae0"), DARK)
	_poster(Loc.t("poster_doctor"), Vector3(-11.88, 1.9, -6.5), PI * 0.5, Color("ff70a6"), Color.WHITE, 0.06)
	_syringe(Vector3(-10.2, 1.9, -9.78))
	_plant(Vector3(-2.6, 0, -3.6), 1)


func _build_pharmacy() -> void:
	_box(Vector3(5.0, 1.05, 0.6), Vector3(1.5, 0.525, -6.2), Color("52b788"))
	_box(Vector3(5.1, 0.12, 0.08), Vector3(1.5, 0.75, -5.88), Color("ffffff"), false, 0.0)
	# Tezgahın üstünde devrilmeye hazır ilaç kutuları
	for i in 8:
		var color: Color = MEDICINE_COLORS[i % MEDICINE_COLORS.size()]
		_medicine(Vector3(-0.6 + i * 0.6, 1.05, -6.2 + randf_range(-0.08, 0.08)), color)
	# Raflar ve ilaç kutuları
	_box(Vector3(6.4, 2.4, 0.4), Vector3(1.5, 1.2, -9.7), WOOD)
	for row in 4:
		for col in 10:
			var color: Color = MEDICINE_COLORS[(row * 3 + col) % MEDICINE_COLORS.size()]
			_box(Vector3(0.35, 0.3, 0.25), Vector3(-1.2 + col * 0.6, 0.55 + row * 0.5, -9.4), color, false, 0.012)
	_poster(Loc.t("poster_pharmacy"), Vector3(-1.88, 1.8, -5.5), PI * 0.5, Color("e63946"), Color.WHITE, -0.05)
	_plant(Vector3(4.4, 0, -3.6), 1)


func _build_wc() -> void:
	for x in [7.0, 9.0, 11.0]:
		_box(Vector3(0.08, 2.0, 1.8), Vector3(x, 1.0, -9.1), Color("00bbf9"), true, 0.01)
	for x in [6.0, 8.0, 10.0]:
		_cylinder(0.22, 0.45, Vector3(x, 0.225, -9.4), WHITE)
		_box(Vector3(0.5, 0.5, 0.2), Vector3(x, 0.65, -9.8), WHITE)
	_box(Vector3(0.5, 0.85, 0.6), Vector3(11.65, 0.425, -5.5), WHITE)
	_box(Vector3(0.05, 0.9, 1.0), Vector3(11.87, 1.6, -5.5), Color("caf0f8"), false, 0.0)
	_sign(Loc.t("poster_mirror"), Vector3(11.85, 2.35, -5.5), 24, -PI * 0.5, Color("e63946"))
	_wet_floor(Vector3(10.9, 0, -5.2), Vector3(10.4, 0, -4.1), -PI * 0.25)
	# Tuvalet kâğıtları: biri rezervuarın üstünde, biri kaçmış
	_toilet_roll(Vector3(10.3, 0, -7.6))
	_toilet_roll(Vector3(10.55, 0, -7.65))
	_toilet_roll(Vector3(6.0, 0.9, -9.8))
	_toilet_roll(Vector3(6.4, 0, -7.3))


func _spawn_player() -> void:
	player = Player.new()
	player.body_color = PLAYER_COLOR
	player.position = PLAYER_SPAWN
	add_child(player)
	player.complication_triggered.connect(_on_player_complication)
	player.toast_requested.connect(show_toast)


## Sabit personel (doktor, eczacı, danışma) ve Npc.AREAS içinde dolaşan hastalar.
func _spawn_npcs() -> void:
	_npc(Vector3(-7, 0, -8.7), DOCTOR_COAT, true, PI, true)
	_npc(Vector3(1.5, 0, -7.2), PHARMACIST_COLOR, true, PI)
	_npc(Vector3(9, 0, 1.3), RECEPTIONIST_COLOR, true, PI)

	var spots := [Vector3(-8.5, 0, 1.8), Vector3(1.8, 0, 1.6), Vector3(-3.6, 0, 8.7),
			Vector3(-9.5, 0, -1.4), Vector3(9.0, 0, -1.2)]
	for i in spots.size():
		_npc(spots[i], PATIENT_COLORS[i % PATIENT_COLORS.size()], false, randf() * TAU)


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


## Test tuşlarıyla tetiklenen komplikasyon: sadece adı gösterilir
## (ses efekti yalnızca doktorun yanlış tedavisinde olur).
func _on_player_complication(comp: Dictionary) -> void:
	show_toast(Loc.t("complication_toast", [comp["name"]]))


func _hud_label(size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color("1d3557"))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# --- Kaos: muz kabukları ve kaygan zemin ----------------------------------

func _build_bananas() -> void:
	for p in [Vector3(-7.5, 0, 1.4), Vector3(2.8, 0, 2.2), Vector3(-1.7, 0, 6.0), Vector3(-0.5, 0, -1.6)]:
		bananas.append(_banana(p))


## Muz kabuğu: basan kayar, kabuk havada takla atıp aynı alanda başka yere düşer.
func _banana(pos: Vector3) -> Area3D:
	var area := _slip_area(Vector3(0.5, 0.3, 0.5), pos, true)
	var peel := Node3D.new()
	peel.name = "Peel"
	peel.rotation.y = randf() * TAU
	area.add_child(peel)
	var middle := _mesh_child(peel, _sphere_mesh(0.1), BANANA_YELLOW, 0.012)
	middle.position.y = 0.05
	middle.scale = Vector3(1.0, 0.7, 1.0)
	# Dört yana açılmış kabuk dilimleri
	for k in 4:
		var flap_pivot := Node3D.new()
		flap_pivot.rotation.y = k * PI * 0.5 + randf_range(-0.3, 0.3)
		peel.add_child(flap_pivot)
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.055
		capsule.height = 0.3
		var flap := _mesh_child(flap_pivot, capsule, BANANA_YELLOW, 0.012)
		flap.rotation.x = PI * 0.5 - 0.15
		flap.position = Vector3(0, 0.035, -0.15)
		flap.scale = Vector3(1.0, 1.0, 0.45)
		var tip := _mesh_child(flap_pivot, _sphere_mesh(0.03), Color("7f5539"), 0.0)
		tip.position = Vector3(0, 0.06, -0.29)
	var stem := _mesh_child(peel, _cylinder_mesh(0.025, 0.08), Color("7f5539"), 0.008)
	stem.position.y = 0.13
	return area


## Islak zemin: su birikintisi + üstünde uyarı yazılı sarı A tabela (itilebilir).
func _wet_floor(puddle_pos: Vector3, sign_pos: Vector3, sign_rot: float) -> void:
	var area := _slip_area(Vector3(1.3, 0.3, 1.0), puddle_pos, false)
	var water := Toon.flat(Color("7fd8f5"))
	for blob in [[Vector3.ZERO, 0.6], [Vector3(0.35, 0, 0.2), 0.4], [Vector3(-0.4, 0, -0.15), 0.35]]:
		var mi := MeshInstance3D.new()
		mi.mesh = _cylinder_mesh(blob[1], 0.02)
		mi.material_override = water
		mi.position = blob[0] + Vector3(0, 0.012, 0)
		area.add_child(mi)

	# A tabela: prizma, iki yüzünde de yazı
	# PrismMesh'in eğik yüzleri ±x'e bakar; 90° çevrilip ±z'ye getirilir
	var prism := PrismMesh.new()
	prism.size = Vector3(0.42, 0.8, 0.6)
	# Şekil elle kurulur (create_convex_shape ekransız modda boş döner)
	var prism_shape := ConvexPolygonShape3D.new()
	prism_shape.points = PackedVector3Array([Vector3(-0.3, -0.4, -0.21), Vector3(0.3, -0.4, -0.21),
			Vector3(-0.3, -0.4, 0.21), Vector3(0.3, -0.4, 0.21), Vector3(-0.3, 0.4, 0), Vector3(0.3, 0.4, 0)])
	var body := _prop(prism_shape, sign_pos + Vector3(0, 0.405, 0), 1.0)
	body.rotation.y = sign_rot
	_mesh_child(body, prism, BANANA_YELLOW).rotation.y = PI * 0.5
	var slope := atan2(0.21, 0.8)
	for side in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = Loc.t("sign_wet_floor")
		lbl.font_size = 34
		lbl.pixel_size = 0.0018
		lbl.modulate = DARK
		lbl.outline_size = 0
		lbl.double_sided = false
		lbl.position = Vector3(0, -0.08, side * 0.13)
		lbl.rotation = Vector3(-slope, 0.0 if side > 0.0 else PI, 0.0)
		body.add_child(lbl)


## Basanı kaydıran alan. hops: muz gibi kaydırdıktan sonra başka yere sıçrar.
func _slip_area(size: Vector3, pos: Vector3, hops: bool) -> Area3D:
	var area := Area3D.new()
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position.y = size.y * 0.5
	area.add_child(cs)
	area.position = pos
	add_child(area)
	area.body_entered.connect(_on_slip_area_entered.bind(area, hops))
	return area


func _on_slip_area_entered(body: Node3D, area: Area3D, hops: bool) -> void:
	if not body.has_method("slip"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(area.get_meta("ready_at", 0.0)):
		return
	area.set_meta("ready_at", now + SLIP_COOLDOWN)
	body.slip()
	if hops:
		_hop_banana(area)


## Muz kabuğu havada dönerek bulunduğu yürüme alanında rastgele bir yere düşer.
func _hop_banana(banana: Area3D) -> void:
	var from := banana.position
	var p := Vector2(from.x, from.z)
	var rect := Rect2()
	for key in Npc.AREAS:
		if (Npc.AREAS[key] as Rect2).has_point(p):
			rect = (Npc.AREAS[key] as Rect2).grow(-0.4)
			break
	if rect.size == Vector2.ZERO:
		# Alan dışındaysa yakınlara, bulunduğu odanın içinde kalacak şekilde
		rect = Rect2(p - Vector2(1.5, 1.5), Vector2(3.0, 3.0))
		for key in ROOMS:
			if (ROOMS[key] as Rect2).has_point(p):
				rect = rect.intersection((ROOMS[key] as Rect2).grow(-0.6))
				break
	var to := Vector3(randf_range(rect.position.x, rect.end.x), from.y, randf_range(rect.position.y, rect.end.y))
	var peel: Node3D = banana.get_node("Peel")
	var arc := func(t: float) -> void:
		banana.position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * BANANA_HOP_HEIGHT
	var tween := create_tween()
	tween.tween_method(arc, 0.0, 1.0, BANANA_HOP_TIME)
	tween.parallel().tween_property(peel, "rotation", peel.rotation + Vector3(TAU * 2.0, PI, 0.0), BANANA_HOP_TIME)


# --- Fizik eşyaları -----------------------------------------------------

## Serbest fizik gövdesi; görseli çağıran ekler.
func _prop(shape: Shape3D, pos: Vector3, mass: float, bounce := 0.1) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass
	var pm := PhysicsMaterial.new()
	pm.bounce = bounce
	pm.friction = 0.7
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	add_child(body)
	props.append(body)
	return body


## center: kutunun merkezi.
func _rigid_box(size: Vector3, center: Vector3, color: Color, mass: float, outline := Toon.DEFAULT_OUTLINE, rot_y := 0.0) -> RigidBody3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var body := _prop(shape, center, mass)
	body.rotation.y = rot_y
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_child(body, mesh, color, outline)
	return body


func _beach_ball(pos: Vector3, c1: Color, c2: Color) -> void:
	var r := 0.42
	var shape := SphereShape3D.new()
	shape.radius = r
	var body := _prop(shape, pos + Vector3(0, r + 0.01, 0), 0.5, 0.75)
	body.angular_damp = 0.5
	_mesh_child(body, _sphere_mesh(r), c1)
	# Kesişen iki şerit ve beyaz tepe
	for rot in [Vector3.ZERO, Vector3(PI * 0.5, 0, 0), Vector3(0, 0, PI * 0.5)]:
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.06
		torus.outer_radius = r + 0.015
		var stripe := _mesh_child(body, torus, c2 if rot != Vector3.ZERO else WHITE, 0.0)
		stripe.rotation = rot
	for y in [r - 0.01, -(r - 0.01)]:
		var cap := _mesh_child(body, _sphere_mesh(0.09), WHITE, 0.0)
		cap.position.y = y
		cap.scale = Vector3(1.0, 0.4, 1.0)


func _cardboard(pos: Vector3, rot_y := 0.0) -> void:
	var size := Vector3(0.6, 0.6, 0.6)
	var body := _rigid_box(size, pos + Vector3(0, size.y * 0.5 + 0.005, 0), Color("c8955c"), 2.0, Toon.DEFAULT_OUTLINE, rot_y)
	var tape := BoxMesh.new()
	tape.size = Vector3(0.14, 0.01, 0.61)
	_mesh_child(body, tape, Color("f2d398"), 0.0).position.y = size.y * 0.5 + 0.003


## Trafik dubası (koni + kare taban + beyaz şerit).
func _cone(pos: Vector3) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 0.2
	cone.height = 0.6
	var body := _prop(_convex_cylinder(0.2, 0.6, 0.03), pos + Vector3(0, 0.36, 0), 0.8)
	body.rotation.y = randf() * TAU
	_mesh_child(body, cone, Color("ff7b00"))
	var stripe := _mesh_child(body, _cylinder_mesh(0.11, 0.1, 0.128), WHITE, 0.0)
	stripe.position.y = 0.0
	var base := BoxMesh.new()
	base.size = Vector3(0.48, 0.06, 0.48)
	_mesh_child(body, base, Color("ff7b00")).position.y = -0.33
	var base_shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = base.size
	base_shape.shape = bs
	base_shape.position.y = -0.33
	body.add_child(base_shape)


func _trash_bin(pos: Vector3, color: Color) -> void:
	# Fizik motoru ~1 cm gömdüğü için şekil görselden biraz uzun
	var body := _prop(_convex_cylinder(0.26, 0.72), pos + Vector3(0, 0.365, 0), 3.0)
	_mesh_child(body, _cylinder_mesh(0.26, 0.7, 0.22), color)
	_mesh_child(body, _cylinder_mesh(0.29, 0.06), Color("ffbe0b")).position.y = 0.36
	# Kapaktan taşan buruşuk kâğıt
	_mesh_child(body, _sphere_mesh(0.08), WHITE, 0.01).position = Vector3(0.1, 0.42, 0.05)


## pos: kutunun durduğu yüzeyin noktası (tezgah üstü).
func _medicine(pos: Vector3, color: Color) -> void:
	var size := Vector3(0.22, 0.28, 0.12)
	var body := _rigid_box(size, pos + Vector3(0, size.y * 0.5 + 0.004, 0), color, 0.2, 0.012, randf_range(-0.3, 0.3))
	body.continuous_cd = true
	var label := BoxMesh.new()
	label.size = Vector3(0.14, 0.1, 0.005)
	for z in [size.z * 0.5 + 0.003, -(size.z * 0.5 + 0.003)]:
		_mesh_child(body, label, WHITE, 0.0).position = Vector3(0, 0.03, z)


func _toilet_roll(pos: Vector3) -> void:
	var body := _prop(_convex_cylinder(0.1, 0.14), pos + Vector3(0, 0.072, 0), 0.15)
	body.continuous_cd = true
	_mesh_child(body, _cylinder_mesh(0.1, 0.12), WHITE, 0.012)
	_mesh_child(body, _cylinder_mesh(0.035, 0.125), Color("a98467"), 0.0)


## Lastik ördek (muayene yatağında).
func _duck(pos: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	var body := _prop(shape, pos + Vector3(0, 0.125, 0), 0.2, 0.5)
	body.rotation.y = PI * 0.3
	var yellow := Color("ffd60a")
	_mesh_child(body, _sphere_mesh(0.13), yellow, 0.012).scale = Vector3(1.0, 0.8, 1.25)
	_mesh_child(body, _sphere_mesh(0.08), yellow, 0.012).position = Vector3(0, 0.12, -0.08)
	var beak := _mesh_child(body, _sphere_mesh(0.04), Color("fb8500"), 0.008)
	beak.position = Vector3(0, 0.11, -0.16)
	beak.scale = Vector3(1.0, 0.5, 1.3)
	for side in [-1.0, 1.0]:
		_mesh_child(body, _sphere_mesh(0.015), DARK, 0.0).position = Vector3(side * 0.04, 0.15, -0.14)


# --- Süsler -------------------------------------------------------------

## Duvara asılı dev şırınga (x ekseni boyunca yatay).
func _syringe(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.z = 0.12
	add_child(holder)
	var barrel := _mesh_child(holder, _cylinder_mesh(0.12, 1.0), Color("caf0f8"))
	barrel.rotation.z = PI * 0.5
	var liquid := _mesh_child(holder, _cylinder_mesh(0.09, 0.55), Color("ef476f"), 0.0)
	liquid.rotation.z = PI * 0.5
	liquid.position.x = 0.2
	var plunger := _mesh_child(holder, _cylinder_mesh(0.03, 0.45), Color("adb5bd"))
	plunger.rotation.z = PI * 0.5
	plunger.position.x = -0.7
	var thumb := _mesh_child(holder, _cylinder_mesh(0.14, 0.04), Color("adb5bd"))
	thumb.rotation.z = PI * 0.5
	thumb.position.x = -0.93
	var needle := _mesh_child(holder, _cylinder_mesh(0.012, 0.45), Color("6c757d"), 0.008)
	needle.rotation.z = PI * 0.5
	needle.position.x = 0.72


## Saksı bitkisi. kind: 0 = top çalı, 1 = kollu kaktüs, 2 = papatya
func _plant(pos: Vector3, kind: int) -> void:
	_cylinder(0.3, 0.5, pos + Vector3(0, 0.25, 0), Color("e07a5f"))
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	match kind:
		0:
			_mesh_child(holder, _sphere_mesh(0.55), Color("6a994e")).position.y = 1.0
			_mesh_child(holder, _sphere_mesh(0.35), Color("90be6d")).position = Vector3(0.25, 1.45, 0.1)
		1:
			var green := Color("52b788")
			_mesh_child(holder, _capsule_mesh(0.18, 1.2), green).position.y = 1.0
			for side in [-1.0, 1.0]:
				var arm := Node3D.new()
				arm.position = Vector3(side * 0.18, 1.0 + side * 0.12, 0)
				holder.add_child(arm)
				_mesh_child(arm, _capsule_mesh(0.09, 0.35), green).position.x = side * 0.15
				_mesh_child(arm, _capsule_mesh(0.09, 0.4), green).position = Vector3(side * 0.28, 0.17, 0)
			_mesh_child(holder, _sphere_mesh(0.07), Color("ff70a6"), 0.01).position.y = 1.62
		2:
			for k in 3:
				var stem := Node3D.new()
				stem.rotation = Vector3(0, k * TAU / 3.0, 0.25)
				holder.add_child(stem)
				_mesh_child(stem, _cylinder_mesh(0.025, 0.9), Color("6a994e"), 0.008).position.y = 0.85
				var head := _mesh_child(stem, _sphere_mesh(0.16), WHITE)
				head.position.y = 1.3
				head.scale = Vector3(1.0, 0.35, 1.0)
				_mesh_child(stem, _sphere_mesh(0.07), Color("ffca3a"), 0.0).position.y = 1.34


# --- Yapı taşları -------------------------------------------------------

## x ekseni boyunca uzanan duvar (sabit z). doors: [[merkez_x, genişlik], ...]
func _wall_x(z: float, x0: float, x1: float, doors: Array = []) -> void:
	_wall(true, z, x0, x1, doors)


## z ekseni boyunca uzanan duvar (sabit x). doors: [[merkez_z, genişlik], ...]
func _wall_z(x: float, z0: float, z1: float, doors: Array = []) -> void:
	_wall(false, x, z0, z1, doors)


## Duvar parçaları: çarpışmalı gövde + çarpışmasız renkli alt bant,
## kapılarda üst lento ve turuncu kapı çerçevesi.
func _wall(along_x: bool, fixed: float, a: float, b: float, doors: Array) -> void:
	for seg in _segments(a, b, doors):
		var mid := (seg.x + seg.y) * 0.5
		var length := seg.y - seg.x
		_wall_part(along_x, fixed, mid, length, WALL_H, WALL_T, WALL_COLOR, true)
		_wall_part(along_x, fixed, mid, length, BAND_H, WALL_T + 0.06, BAND_COLOR, false)
	for d in doors:
		var center: float = d[0]
		var width: float = d[1]
		var lintel := _wall_part(along_x, fixed, center, width, WALL_H - DOOR_H, WALL_T, WALL_COLOR, true)
		lintel.position.y = (WALL_H + DOOR_H) * 0.5
		var top := _wall_part(along_x, fixed, center, width + 0.24, 0.12, WALL_T + 0.08, DOOR_FRAME, false)
		top.position.y = DOOR_H + 0.06
		for side in [-1.0, 1.0]:
			_wall_part(along_x, fixed, center + side * (width * 0.5 + 0.06), 0.12, DOOR_H, WALL_T + 0.08, DOOR_FRAME, false)


## Tabanı y=0'da duran duvar kutusu; along_x ise x boyunca uzanır.
func _wall_part(along_x: bool, fixed: float, mid: float, length: float, height: float,
		thickness: float, color: Color, collide: bool) -> Node3D:
	if along_x:
		return _box(Vector3(length, height, thickness), Vector3(mid, height * 0.5, fixed), color, collide)
	return _box(Vector3(thickness, height, length), Vector3(fixed, height * 0.5, mid), color, collide)


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


## Damalı, çarpışmalı zemin.
func _floor(rect: Rect2, c1: Color, c2: Color) -> void:
	var c := rect.get_center()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x, 0.2, rect.size.y)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	_place(mesh, shape, Vector3(c.x, -0.1, c.y), Toon.checker_material(c1, c2))


func _lamp(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(pos.x, WALL_H - 0.3, pos.z)
	light.omni_range = 8.0
	light.light_energy = 0.3
	light.light_color = Color("fff3d6")
	add_child(light)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.05, 0.9)
	_place(mesh, null, Vector3(pos.x, WALL_H - 0.03, pos.z), Toon.flat(Color("fffbe6")))


## Sandalye; oturan kişi -z yönüne (kuzeye) bakar.
func _chair(pos: Vector3, color: Color) -> void:
	_box(Vector3(0.7, 0.42, 0.6), pos + Vector3(0, 0.21, 0), DARK)
	_box(Vector3(0.8, 0.08, 0.7), pos + Vector3(0, 0.46, 0), color, false)
	_box(Vector3(0.8, 0.65, 0.08), pos + Vector3(0, 0.82, 0.32), color)


func _npc(pos: Vector3, color: Color, stationary: bool, face_y: float, doctor := false) -> Npc:
	var npc := Npc.new()
	npc.body_color = color
	npc.is_doctor = doctor
	npc.stationary = stationary
	npc.face_y = face_y
	npc.position = pos
	add_child(npc)
	npcs.append(npc)
	return npc


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


## Duvar posteri; tilt ile biraz yamuk asılır (çizgi film havası).
func _poster(text: String, pos: Vector3, rot_y: float, bg: Color, fg: Color = Color.WHITE, tilt := 0.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation = Vector3(0, rot_y, tilt)
	add_child(holder)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6, 1.2, 0.03)
	_mesh_child(holder, mesh, bg, 0.012)
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.modulate = fg
	lbl.outline_size = 0
	lbl.position.z = 0.03
	lbl.double_sided = false
	holder.add_child(lbl)


func _box(size: Vector3, pos: Vector3, color: Color, collide := true, outline := Toon.DEFAULT_OUTLINE) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	return _place(mesh, shape if collide else null, pos, Toon.material(color, outline))


func _cylinder(radius: float, height: float, pos: Vector3, color: Color, collide := true, outline := Toon.DEFAULT_OUTLINE) -> Node3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	return _place(_cylinder_mesh(radius, height), shape if collide else null, pos, Toon.material(color, outline))


## Mesh'i sahneye koyar; shape verilirse çarpışmalı bir StaticBody3D içine alır.
func _place(mesh: Mesh, shape: Shape3D, pos: Vector3, mat: Material) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
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


## Silindir/koni çarpışma şekli. CylinderShape3D bu motorda titreyip devrildiği
## için çokgen yaklaşımı kullanılır (create_convex_shape ekransız modda boş döner).
func _convex_cylinder(radius: float, height: float, top_radius := -1.0) -> ConvexPolygonShape3D:
	var top := radius if top_radius < 0.0 else top_radius
	var points := PackedVector3Array()
	for i in 16:
		var dir := Vector3(cos(i * TAU / 16.0), 0, sin(i * TAU / 16.0))
		points.append(dir * radius + Vector3(0, -height * 0.5, 0))
		points.append(dir * top + Vector3(0, height * 0.5, 0))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	return shape


## parent'a Toon malzemeli bir mesh ekler.
func _mesh_child(parent: Node3D, mesh: Mesh, color: Color, outline := Toon.DEFAULT_OUTLINE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Toon.material(color, outline)
	parent.add_child(mi)
	return mi


func _sphere_mesh(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


func _cylinder_mesh(radius: float, height: float, bottom := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius if bottom < 0.0 else bottom
	m.height = height
	return m


func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	return m
