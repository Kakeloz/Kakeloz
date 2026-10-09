extends Control
## Prototip ekran akışı: tek bilgisayarda sırayla oynanır (hot-seat).
## Kurallar GameLogic'te; bu dosya sadece ekranları gösterir ve oyuncu
## seçimlerini GameLogic'e iletir. Online sürümde aynı ekranlar, GameLogic'e
## doğrudan değil ağ üzerinden bağlanacak.

const STAGE_Y := 320.0
const STAGE_LEFT := 150.0
const STAGE_RIGHT := 1130.0
const PALETTE := [
	Color("e76f51"), Color("2a9d8f"), Color("457b9d"), Color("9b5de5"),
	Color("f4a261"), Color("e5989b"), Color("6a994e"), Color("bc6c25"),
]
const DOCTOR_COAT := Color("f1faee")
const TEXT_COLOR := Color("1d3557")

const ANSWER_SECONDS := 20.0
const DISCUSSION_SECONDS := 30.0
const DIAGNOSIS_SECONDS := 15.0

var logic: GameLogic
var characters: Array[Character] = []

var _diseases: Array = []
var _complications: Array = []
var _names: Array = []
var _player_count := GameLogic.MIN_PLAYERS
var _name_edits: Array[LineEdit] = []

var _stage: Node2D
var _top_label: Label
var _center_panel: PanelContainer
var _center_vbox: VBoxContainer
var _bottom_panel: PanelContainer
var _bottom_vbox: VBoxContainer

var _timer_active := false
var _timer_left := 0.0
var _timer_label: Label
var _timer_cb: Callable

var _asking := -1
var _selected_patient := -1
var _selected_drug := -1
var _confirm_btn: Button
## Oyuncu sırası -> ses efekti. Sadece yanlış tedavi edilen hastaya, o tur boyunca.
var _voice_fx: Dictionary = {}


func _ready() -> void:
	_diseases = DataLoader.load_diseases()
	_complications = DataLoader.load_complications()
	for i in GameLogic.MAX_PLAYERS:
		_names.append(Loc.t("default_player", [i + 1]))
	_build_base_ui()
	_show_menu()


func _process(delta: float) -> void:
	if not _timer_active:
		return
	_timer_left -= delta
	if is_instance_valid(_timer_label):
		_timer_label.text = Loc.t("timer", [maxi(0, ceili(_timer_left))])
	if _timer_left <= 0.0:
		_timer_active = false
		_timer_cb.call()


# --- Ekranlar -----------------------------------------------------------

func _show_menu() -> void:
	_stop_timer()
	_stage.visible = false
	_bottom_panel.visible = false
	_top_label.text = ""
	_open_center()
	_center_vbox.add_child(_label(Loc.t("title"), 56))
	_center_vbox.add_child(_label(Loc.t("subtitle"), 22))
	_center_vbox.add_child(_wrapped_label(Loc.t("rules_short"), 17, 720))

	var count_row := _hbox()
	count_row.add_child(_label(Loc.t("player_count"), 20))
	var spin := SpinBox.new()
	spin.min_value = GameLogic.MIN_PLAYERS
	spin.max_value = GameLogic.MAX_PLAYERS
	spin.value = _player_count
	count_row.add_child(spin)
	_center_vbox.add_child(count_row)

	_center_vbox.add_child(_label(Loc.t("player_names"), 18))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_name_edits.clear()
	for i in GameLogic.MAX_PLAYERS:
		var edit := LineEdit.new()
		edit.text = _names[i]
		edit.max_length = 14
		edit.custom_minimum_size = Vector2(170, 0)
		edit.visible = i < _player_count
		edit.text_changed.connect(func(t: String): _names[i] = t)
		grid.add_child(edit)
		_name_edits.append(edit)
	_center_vbox.add_child(grid)

	spin.value_changed.connect(func(v: float):
		_player_count = int(v)
		for i in _name_edits.size():
			_name_edits[i].visible = i < _player_count)

	_center_vbox.add_child(_button(Loc.t("start_game"), _start_game))


func _start_game() -> void:
	var names: Array = []
	for i in _player_count:
		var n: String = String(_names[i]).strip_edges()
		if n.is_empty():
			n = Loc.t("default_player", [i + 1])
		names.append(n)
	logic = GameLogic.new(_diseases, _complications)
	if not logic.start_game(names):
		return
	_voice_fx.clear()
	_build_stage()
	_begin_round()


func _begin_round() -> void:
	logic.start_round()
	_voice_fx.clear()
	for i in characters.size():
		var ch := characters[i]
		ch.reset_visuals()
		ch.highlight = false
		ch.is_doctor = i == logic.doctor_idx
		ch.body_color = DOCTOR_COAT if ch.is_doctor else PALETTE[i % PALETTE.size()]
	_refresh_stage()
	_show_role_pass(0)


func _show_role_pass(idx: int) -> void:
	_stop_timer()
	_stage.visible = false
	_bottom_panel.visible = false
	_set_round_header()
	_open_center()
	_center_vbox.add_child(_label(Loc.t("pass_device", [_player_name(idx)]), 32))
	_center_vbox.add_child(_label(Loc.t("pass_hint"), 20))
	_center_vbox.add_child(_button(Loc.t("show_role"), func(): _show_role_card(idx)))


func _show_role_card(idx: int) -> void:
	_open_center()
	var view := logic.role_view(idx)
	var symptoms := _symptom_lines(view["symptoms"])
	var title := ""
	var body := ""
	match view["role"]:
		GameLogic.Role.DOCTOR:
			title = Loc.t("role_doctor_title")
			body = Loc.t("role_doctor_text", [view["disease_name"], symptoms])
		GameLogic.Role.REAL_PATIENT:
			title = Loc.t("role_real_title")
			body = Loc.t("role_real_text", [view["disease_name"], symptoms])
		_:
			title = Loc.t("role_fake_title")
			body = Loc.t("role_fake_text", [view["disease_name"]])
	_center_vbox.add_child(_label(_player_name(idx), 22))
	_center_vbox.add_child(_label(title, 40))
	_center_vbox.add_child(_wrapped_label(body, 20, 640))
	var is_last := idx + 1 >= logic.players.size()
	if is_last:
		_center_vbox.add_child(_button(Loc.t("hide_and_start"), _start_exam))
	else:
		_center_vbox.add_child(_button(Loc.t("hide_and_continue"), func(): _show_role_pass(idx + 1)))


func _start_exam() -> void:
	logic.begin_exam()
	_asking = -1
	_center_panel.visible = false
	_stage.visible = true
	_set_round_header()
	_build_exam_bottom()


func _build_exam_bottom() -> void:
	_open_bottom()
	_refresh_stage()
	for i in characters.size():
		characters[i].highlight = i == _asking

	if _asking >= 0:
		_bottom_vbox.add_child(_label(Loc.t("answering", [_player_name(_asking)]), 26))
		_timer_label = _label("", 30)
		_bottom_vbox.add_child(_timer_label)
		_bottom_vbox.add_child(_button(Loc.t("answer_done"), _end_answer))
		_start_timer(ANSWER_SECONDS, _end_answer)
		return

	_bottom_vbox.add_child(_label(Loc.t("questions_left", [logic.questions_left]), 24))
	if logic.questions_left > 0:
		_bottom_vbox.add_child(_label(Loc.t("ask_hint"), 16))
		var row := _hbox()
		for i in logic.patient_indices():
			var text := Loc.t("ask_button", [_player_name(i), logic.questions_asked[i]])
			row.add_child(_button(text, func(): _ask(i), 0.0))
		_bottom_vbox.add_child(row)
	else:
		_bottom_vbox.add_child(_label(Loc.t("no_questions"), 18))
	_bottom_vbox.add_child(_book_row())
	_bottom_vbox.add_child(_button(Loc.t("end_exam"), _show_discussion))


func _ask(idx: int) -> void:
	if logic.ask_question(idx):
		_asking = idx
		_build_exam_bottom()


func _end_answer() -> void:
	_asking = -1
	_build_exam_bottom()


func _show_discussion() -> void:
	logic.end_exam()
	_asking = -1
	_clear_highlights()
	_open_bottom()
	_bottom_vbox.add_child(_label(Loc.t("discussion_title"), 28))
	_bottom_vbox.add_child(_label(Loc.t("discussion_hint"), 18))
	_timer_label = _label("", 30)
	_bottom_vbox.add_child(_timer_label)
	_bottom_vbox.add_child(_book_row())
	_bottom_vbox.add_child(_button(Loc.t("to_diagnosis"), _show_diagnosis))
	_start_timer(DISCUSSION_SECONDS, _show_diagnosis)


func _show_diagnosis() -> void:
	logic.begin_diagnosis()
	_selected_patient = -1
	_selected_drug = -1
	_open_bottom()

	_bottom_vbox.add_child(_label(Loc.t("diag_who"), 22))
	var patient_group := ButtonGroup.new()
	var patient_row := _hbox()
	for i in logic.patient_indices():
		var b := _toggle_button(_player_name(i), patient_group)
		b.pressed.connect(func():
			_selected_patient = i
			for j in characters.size():
				characters[j].highlight = j == i
			_update_confirm())
		patient_row.add_child(b)
	_bottom_vbox.add_child(patient_row)

	_bottom_vbox.add_child(_label(Loc.t("diag_drug"), 22))
	var drug_group := ButtonGroup.new()
	var drug_row := _hbox()
	for k in logic.drug_choices.size():
		var b := _toggle_button(logic.drug_choices[k]["drug"], drug_group)
		b.pressed.connect(func():
			_selected_drug = k
			_update_confirm())
		drug_row.add_child(b)
	_bottom_vbox.add_child(drug_row)

	var confirm_row := _hbox()
	_confirm_btn = _button(Loc.t("diag_confirm"), _confirm_diagnosis)
	_confirm_btn.disabled = true
	confirm_row.add_child(_confirm_btn)
	_timer_label = _label("", 22)
	confirm_row.add_child(_timer_label)
	_bottom_vbox.add_child(confirm_row)
	_start_timer(DIAGNOSIS_SECONDS, func(): _timer_label.text = Loc.t("time_up"))


func _update_confirm() -> void:
	if is_instance_valid(_confirm_btn):
		_confirm_btn.disabled = _selected_patient < 0 or _selected_drug < 0


func _confirm_diagnosis() -> void:
	var result := logic.diagnose(_selected_patient, _selected_drug)
	if result.is_empty():
		return
	_show_result(result)


func _show_result(result: Dictionary) -> void:
	_clear_highlights()
	_open_bottom()
	var chosen: int = result["chosen_idx"]
	var real: int = result["real_idx"]
	var doctor: int = result["doctor_idx"]
	var comp: Dictionary = logic.complications.get(result["complication"], {})

	if result["correct"]:
		_bottom_vbox.add_child(_label(Loc.t("result_correct"), 36, Color("2a9d8f")))
		_bottom_vbox.add_child(_label(Loc.t("result_correct_text", [_player_name(real), result["disease_name"]]), 20))
		characters[doctor].play_happy()
		characters[real].play_happy()
	else:
		_bottom_vbox.add_child(_label(Loc.t("result_wrong"), 36, Color("e63946")))
		_bottom_vbox.add_child(_wrapped_label(Loc.t("result_wrong_text", [
			_player_name(chosen), _player_name(real), result["disease_name"],
			result["drug"], comp.get("name", "?"),
		]), 20, 1100))
		_bottom_vbox.add_child(_label(Loc.t("result_voice", [_player_name(chosen), comp.get("voice", "?")]), 16))
		for idx in result["afflicted"]:
			characters[idx].play_complication(result["complication"])
		_voice_fx[result["voice_idx"]] = comp.get("voice", "?")
		characters[real].play_sad()

	var parts: Array = []
	for idx in result["deltas"]:
		parts.append("%s %+d" % [_player_name(idx), result["deltas"][idx]])
	_bottom_vbox.add_child(_label(Loc.t("result_scores", [" | ".join(parts)]), 18))

	if logic.has_next_round():
		_bottom_vbox.add_child(_button(Loc.t("next_round"), _begin_round))
	else:
		_bottom_vbox.add_child(_button(Loc.t("final_scores"), _show_game_over))
	_refresh_stage()


func _show_game_over() -> void:
	logic.finish()
	_stop_timer()
	_stage.visible = false
	_bottom_panel.visible = false
	_top_label.text = ""
	_open_center()
	_center_vbox.add_child(_label(Loc.t("game_over_title"), 48))
	var ranking := logic.ranking()
	var best: int = ranking[0]["score"]
	var winners: Array = []
	for entry in ranking:
		if entry["score"] == best:
			winners.append(entry["name"])
	_center_vbox.add_child(_label(Loc.t("winner_line", [", ".join(winners)]), 30, Color("2a9d8f")))
	for place in ranking.size():
		var entry: Dictionary = ranking[place]
		_center_vbox.add_child(_label(Loc.t("rank_line", [place + 1, entry["name"], entry["score"]]), 22))
	_center_vbox.add_child(_button(Loc.t("new_game"), _show_menu))


# --- Sahne ve yardımcılar ------------------------------------------------

func _build_base_ui() -> void:
	var th := Theme.new()
	th.default_font_size = 20
	th.set_color("font_color", "Label", TEXT_COLOR)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		th.set_stylebox(state, "Button", _button_style(state))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(state, "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.7))
	theme = th

	var bg := ColorRect.new()
	bg.color = Color("fdf3e0")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_stage = Node2D.new()
	add_child(_stage)

	_top_label = Label.new()
	_top_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top_label.offset_top = 12
	_top_label.offset_bottom = 52
	_top_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_label.add_theme_font_size_override("font_size", 26)
	add_child(_top_label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_center_panel = PanelContainer.new()
	_center_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_center_panel)
	_center_vbox = _vbox()
	_center_panel.add_child(_center_vbox)

	_bottom_panel = PanelContainer.new()
	_bottom_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_bottom_panel)
	_bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_panel.offset_left = 16
	_bottom_panel.offset_right = -16
	_bottom_panel.offset_bottom = -10
	_bottom_vbox = _vbox()
	_bottom_panel.add_child(_bottom_vbox)


func _build_stage() -> void:
	for c in _stage.get_children():
		c.queue_free()
	characters.clear()
	var n := logic.players.size()
	for i in n:
		var ch := Character.new()
		ch.display_name = _player_name(i)
		ch.body_color = PALETTE[i % PALETTE.size()]
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		ch.position = Vector2(lerpf(STAGE_LEFT, STAGE_RIGHT, t), STAGE_Y)
		_stage.add_child(ch)
		characters.append(ch)


func _refresh_stage() -> void:
	for i in characters.size():
		var info := Loc.t("score_line", [logic.players[i]["score"]])
		if i == logic.doctor_idx:
			info = Loc.t("doctor_tag") + " | " + info
		if _voice_fx.has(i):
			info += "\n" + Loc.t("voice_line", [_voice_fx[i]])
		characters[i].set_info(info)


func _clear_highlights() -> void:
	for ch in characters:
		ch.highlight = false


func _set_round_header() -> void:
	_top_label.text = Loc.t("header_round", [
		logic.round_index + 1, logic.round_count(), _player_name(logic.doctor_idx),
	])


func _book_row() -> Control:
	var row := _hbox()
	var btn := Button.new()
	btn.text = Loc.t("book_button")
	var lbl := _label(Loc.t("book_hidden"), 18)
	var secret := Loc.t("book_text", [logic.disease["name"], " | ".join(logic.disease["symptoms"])])
	btn.button_down.connect(func(): lbl.text = secret)
	btn.button_up.connect(func(): lbl.text = Loc.t("book_hidden"))
	row.add_child(btn)
	row.add_child(lbl)
	return row


func _symptom_lines(symptoms: Array) -> String:
	var lines: Array = []
	for s in symptoms:
		lines.append(Loc.t("symptom_line", [s]))
	return "\n".join(lines)


func _player_name(idx: int) -> String:
	return logic.players[idx]["name"]


func _start_timer(seconds: float, on_timeout: Callable) -> void:
	_timer_left = seconds
	_timer_cb = on_timeout
	_timer_active = true
	if is_instance_valid(_timer_label):
		_timer_label.text = Loc.t("timer", [ceili(seconds)])


func _stop_timer() -> void:
	_timer_active = false


func _open_center() -> void:
	_stop_timer()
	_center_panel.visible = true
	_clear(_center_vbox)


func _open_bottom() -> void:
	_stop_timer()
	_bottom_panel.visible = true
	_clear(_bottom_vbox)


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = TEXT_COLOR
	sb.set_content_margin_all(16)
	return sb


func _button_style(state: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match state:
		"hover":
			sb.bg_color = Color("1d3557")
		"pressed", "hover_pressed":
			sb.bg_color = Color("e76f51")
		"disabled":
			sb.bg_color = Color("adb5bd")
		"focus":
			sb.draw_center = false
			sb.set_border_width_all(2)
			sb.border_color = Color("ffb703")
		_:
			sb.bg_color = Color("457b9d")
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _vbox() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	return box


func _hbox() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	return box


func _label(text: String, size: int = 20, color: Color = TEXT_COLOR) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _wrapped_label(text: String, size: int, width: float) -> Label:
	var lbl := _label(text, size)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(width, 0)
	return lbl


func _button(text: String, on_press: Callable, min_width: float = 240.0) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_width, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(on_press)
	return btn


func _toggle_button(text: String, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(0, 44)
	return btn
