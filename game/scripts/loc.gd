extends Node
## Metin çevirileri. Tüm arayüz metinleri buradan okunur, böylece ileride
## başka bir dil dosyası eklemek yeterli olur.

const DEFAULT_LANGUAGE := "tr"

var _strings: Dictionary = {}


func _ready() -> void:
	load_language(DEFAULT_LANGUAGE)


func load_language(code: String) -> void:
	_strings = DataLoader.load_json("res://data/strings_%s.json" % code)


func t(key: String, args: Array = []) -> String:
	var text: String = _strings.get(key, key)
	if args.is_empty():
		return text
	return text % args
