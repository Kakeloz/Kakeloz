class_name DataLoader
extends RefCounted
## Oyun verilerini (hastalıklar, komplikasyonlar, metinler) JSON dosyalarından okur.


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Dosya açılamadı: %s" % path)
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		push_error("JSON okunamadı: %s" % path)
	return data


static func load_diseases() -> Array:
	return load_json("res://data/diseases.json")


static func load_complications() -> Array:
	return load_json("res://data/complications.json")
