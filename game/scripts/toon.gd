class_name Toon
extends RefCounted
## Çizgi film görünümü: düz renk bantlı (toon) gölgelendirme + siyah kontur.
## Kontur, nesnenin biraz şişirilmiş ve içi dışa çevrilmiş bir kopyası olarak
## çizilir (inverted hull yöntemi).

const OUTLINE_COLOR := Color("1b1b2f")
const DEFAULT_OUTLINE := 0.018

static var _cache: Dictionary = {}


static func material(color: Color, outline: float = DEFAULT_OUTLINE) -> StandardMaterial3D:
	var key := "%s|%.3f" % [color.to_html(), outline]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.8
	if outline > 0.0:
		mat.next_pass = outline_material(outline)
	_cache[key] = mat
	return mat


static func outline_material(width: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = OUTLINE_COLOR
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = width
	return mat


## Dünya koordinatına göre döşenen damalı zemin (1 kare = 1 metre).
static func checker_material(c1: Color, c2: Color) -> StandardMaterial3D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(c1)
	var half := size / 2
	img.fill_rect(Rect2i(half, 0, half, half), c2)
	img.fill_rect(Rect2i(0, half, half, half), c2)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.roughness = 0.9
	return mat


## Işık almayan düz renk (parçacıklar, parlayan lambalar için).
static func flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat
