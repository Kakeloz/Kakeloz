class_name Character
extends Node2D
## Basit şekillerden (daire, kutu, çizgi) oluşan karakter. Komplikasyonlar
## çizim yapmadan, parçaların boyutu/konumu/açısı değiştirilerek üretilir.
## İleride şekillerin yerine çizer tarafından hazırlanan resimler konabilir.

const HEAD_R := 28.0
const BODY_W := 56.0
const BODY_H := 76.0
const LEG_H := 16.0
const OUTLINE := Color("1d3557")
const SKIN := Color("ffd6a5")

var display_name := ""
var body_color := Color.WHITE
var is_doctor := false
var highlight := false
## "normal", "happy", "sad", "ouch"
var mood := "normal"

# Animasyonla değişen parçalar
var head_scale := 1.0
var arm_mult := 1.0
var neck_len := 0.0
var body_scale := Vector2.ONE
var uni_scale := 1.0
var visual_offset := Vector2.ZERO
var visual_rot := 0.0
var shake := 0.0
var cross_eyes := false
var square_head := false

var _name_label: Label
var _info_label: Label
var _time := 0.0
var _tween: Tween


func _ready() -> void:
	_time = randf() * 10.0
	_name_label = _make_label(display_name, 20, Vector2(-80, 8), Vector2(160, 26))
	_info_label = _make_label("", 15, Vector2(-90, 34), Vector2(180, 44))


func set_info(text: String) -> void:
	if _info_label:
		_info_label.text = text


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func reset_visuals() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	head_scale = 1.0
	arm_mult = 1.0
	neck_len = 0.0
	body_scale = Vector2.ONE
	uni_scale = 1.0
	visual_offset = Vector2.ZERO
	visual_rot = 0.0
	shake = 0.0
	cross_eyes = false
	square_head = false
	mood = "normal"


## Komplikasyon animasyonunu oynatır (yaklaşık 3 saniye).
func play_complication(id: String) -> void:
	reset_visuals()
	mood = "ouch"
	_tween = create_tween()
	match id:
		"balloon_head":
			_tween.tween_property(self, "head_scale", 3.2, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.0)
			_tween.tween_property(self, "head_scale", 0.4, 0.12)
			_tween.tween_property(self, "head_scale", 1.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"long_arms":
			_tween.tween_property(self, "arm_mult", 5.0, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.2)
			_tween.tween_property(self, "arm_mult", 1.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"ceiling_stick":
			_tween.tween_property(self, "visual_offset:y", -190.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "visual_rot", PI, 0.5)
			_tween.tween_property(self, "shake", 4.0, 0.2)
			_tween.tween_interval(1.4)
			_tween.tween_property(self, "shake", 0.0, 0.1)
			_tween.tween_property(self, "visual_offset:y", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "visual_rot", 0.0, 0.4)
		"inflate":
			_tween.tween_property(self, "body_scale", Vector2(2.2, 2.0), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "visual_offset:y", -40.0, 1.2).set_trans(Tween.TRANS_SINE)
			_tween.tween_interval(1.0)
			_tween.tween_property(self, "body_scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tween.parallel().tween_property(self, "visual_offset:y", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"tremor":
			_tween.tween_callback(func(): cross_eyes = true)
			_tween.tween_property(self, "shake", 10.0, 0.2)
			_tween.tween_interval(2.0)
			_tween.tween_property(self, "shake", 0.0, 0.3)
			_tween.tween_callback(func(): cross_eyes = false)
		"robot":
			_tween.tween_callback(func(): square_head = true)
			_tween.tween_interval(2.8)
			_tween.tween_callback(func(): square_head = false)
		"long_neck":
			_tween.tween_property(self, "neck_len", 130.0, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_tween.tween_interval(1.2)
			_tween.tween_property(self, "neck_len", 0.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"shrink":
			_tween.tween_property(self, "uni_scale", 0.35, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			_tween.tween_interval(1.6)
			_tween.tween_property(self, "uni_scale", 1.0, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_:
			push_warning("Bilinmeyen komplikasyon: %s" % id)
	_tween.tween_callback(func(): mood = "sad")


func play_happy() -> void:
	reset_visuals()
	mood = "happy"
	_tween = create_tween()
	_tween.tween_interval(2.5)
	_tween.tween_callback(func(): mood = "normal")


func play_sad() -> void:
	reset_visuals()
	mood = "sad"


func _draw() -> void:
	var jitter := Vector2.ZERO
	if shake > 0.0:
		jitter = Vector2(sin(_time * 70.0), cos(_time * 83.0)) * shake
	var rot := visual_rot
	if square_head:
		# Robot gibi kesik kesik dönme
		rot += floorf(sin(_time * 6.0) * 2.0) * 0.12
	var bounce := 0.0
	if mood == "happy":
		bounce = -absf(sin(_time * 8.0)) * 18.0
	draw_set_transform(visual_offset + jitter + Vector2(0, bounce), rot, Vector2.ONE * uni_scale)

	if highlight:
		draw_arc(Vector2(0, -80), 88.0, 0.0, TAU, 48, Color("ffb703"), 5.0)

	# Bacaklar
	draw_rect(Rect2(-20, -LEG_H, 12, LEG_H), OUTLINE)
	draw_rect(Rect2(8, -LEG_H, 12, LEG_H), OUTLINE)

	# Gövde
	var bw := BODY_W * body_scale.x
	var bh := BODY_H * body_scale.y
	var body_rect := Rect2(-bw * 0.5, -LEG_H - bh, bw, bh)
	draw_rect(body_rect, body_color)
	draw_rect(body_rect, OUTLINE, false, 3.0)
	var body_top := -LEG_H - bh
	if is_doctor:
		# Önlükte stetoskop
		draw_arc(Vector2(0, body_top + 18), 14.0, 0.0, PI, 12, OUTLINE, 3.0)
		draw_circle(Vector2(0, body_top + 34), 5.0, Color("e63946"))

	# Kollar
	var bend := clampf((arm_mult - 1.0) / 3.0, 0.0, 1.0)
	var arm_len := 44.0 * arm_mult
	for side in [-1.0, 1.0]:
		var shoulder := Vector2(side * bw * 0.5, body_top + 14)
		var dir := Vector2(side * 0.45, 0.9).lerp(Vector2(side, 0.15), bend).normalized()
		var hand := shoulder + dir * arm_len
		draw_line(shoulder, hand, OUTLINE, 10.0)
		draw_line(shoulder, hand, body_color.lightened(0.15), 6.0)
		draw_circle(hand, 7.0, SKIN)

	# Boyun
	var neck_bottom := body_top
	var neck_top := body_top - 6.0 - neck_len
	draw_line(Vector2(0, neck_bottom), Vector2(0, neck_top), OUTLINE, 14.0)
	draw_line(Vector2(0, neck_bottom), Vector2(0, neck_top), SKIN, 9.0)

	# Kafa
	var r := HEAD_R * head_scale
	var idle := sin(_time * 2.0) * 2.0
	var head := Vector2(0, neck_top - r + idle)
	if square_head:
		var hr := Rect2(head - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_rect(hr, Color("adb5bd"))
		draw_rect(hr, OUTLINE, false, 3.0)
	else:
		draw_circle(head, r, SKIN)
		draw_arc(head, r, 0.0, TAU, 40, OUTLINE, 3.0)

	# Gözler
	for side in [-1.0, 1.0]:
		var eye := head + Vector2(side * r * 0.38, -r * 0.15)
		draw_circle(eye, r * 0.22, Color.WHITE)
		var pupil_off := Vector2.ZERO
		if cross_eyes:
			pupil_off = Vector2(-side * r * 0.1, sin(_time * 20.0 * side) * r * 0.05)
		draw_circle(eye + pupil_off, r * 0.1, OUTLINE)

	# Ağız
	var mouth := head + Vector2(0, r * 0.45)
	match mood:
		"happy":
			draw_arc(mouth - Vector2(0, r * 0.15), r * 0.35, 0.3, PI - 0.3, 12, OUTLINE, 3.0)
		"sad":
			draw_arc(mouth + Vector2(0, r * 0.2), r * 0.3, PI + 0.4, TAU - 0.4, 12, OUTLINE, 3.0)
		"ouch":
			draw_circle(mouth, r * 0.16, OUTLINE)
		_:
			draw_line(mouth - Vector2(r * 0.25, 0), mouth + Vector2(r * 0.25, 0), OUTLINE, 3.0)

	# Doktor başlığı
	if is_doctor:
		var cap := Rect2(head.x - r * 0.7, head.y - r - r * 0.35, r * 1.4, r * 0.5)
		draw_rect(cap, Color.WHITE)
		draw_rect(cap, OUTLINE, false, 2.0)
		var c := cap.get_center()
		draw_rect(Rect2(c.x - r * 0.06, c.y - r * 0.18, r * 0.12, r * 0.36), Color("e63946"))
		draw_rect(Rect2(c.x - r * 0.18, c.y - r * 0.06, r * 0.36, r * 0.12), Color("e63946"))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _make_label(text: String, font_size: int, pos: Vector2, size: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", OUTLINE)
	add_child(lbl)
	return lbl
