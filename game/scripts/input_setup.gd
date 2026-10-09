class_name InputSetup
extends RefCounted
## Tuş atamaları. Fiziksel tuş konumu kullanılır, böylece Türkçe Q/F klavyede
## de WASD aynı yerde çalışır.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
}
const COMPLICATION_KEYS := 8


static func ensure_actions() -> void:
	for action in KEYS:
		_add(action, KEYS[action])
	for i in COMPLICATION_KEYS:
		_add("complication_%d" % (i + 1), [KEY_1 + i])


static func _add(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
