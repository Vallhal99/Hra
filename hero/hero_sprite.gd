class_name HeroSprite3D
extends Sprite3D
## Animovaný hrdina složený z vrstev (nahé tělo + kusy brnění) podle Inventory.equip.
## Atlasy jsou v res://hero/atlas (export z Dílny postav). Směry: S SE E NE N NW W SW.

const SLOTS := ["helma", "telo", "rukavice", "kalhoty", "boty", "zbran"]
const PPM := 115.0  ## pixelů na metr (hrdina je vysoký 252 px = 1,9 m)
const FPS := {"Idle": 6.0, "Walk": 10.0, "Run": 13.0, "Swordslash": 12.0, "Attackthrust": 12.0, "Attackranged": 10.0, "Castspell": 10.0, "Attackcombo3hit": 12.0}
static var _atlas: Dictionary = {}
static var _cache: Dictionary = {}

var anim := "Idle"
var dir := "S"
var loop := true
var _t := 0.0
var _info: Dictionary = {}
var _sig := ""
signal finished


static func _ensure() -> void:
	if not _atlas.is_empty():
		return
	for k in ["nahe_helma", "nahe_telo", "nahe_rukavice", "nahe_kalhoty", "nahe_boty"] + SLOTS:
		var p := "res://hero/atlas/%s" % k
		var tex := load(p + ".png") as Texture2D
		var js = JSON.parse_string(FileAccess.get_file_as_string(p + ".json"))
		if tex and js:
			_atlas[k] = {"img": tex.get_image(), "meta": js}


static func has_set(a: String, d: String) -> bool:
	_ensure()
	return _atlas.has("nahe_helma") and _atlas["nahe_helma"].meta.has("%s (%s)" % [a, d])


static func layers_for(equip: Dictionary) -> Array:
	var out := []
	for s in SLOTS.slice(0, 5):
		if equip.get(s) == null:
			out.append("nahe_" + s)
	for s in SLOTS:
		if equip.get(s) != null:
			out.append(s)
	return out


static func sheet(a: String, d: String, equip: Dictionary) -> Dictionary:
	_ensure()
	var key := "%s (%s)" % [a, d]
	var layers := layers_for(equip)
	var ck := key + "|" + ",".join(layers)
	if _cache.has(ck):
		return _cache[ck]
	var res := {}
	var base: Dictionary = _atlas["nahe_helma"].meta.get(key, {})
	if base.is_empty():
		return res
	var w := int(base.frame_w)
	var h := int(base.frame_h)
	var n := int(base.frames)
	var img := Image.create(w * n, h, false, Image.FORMAT_RGBA8)
	for l in layers:
		var m: Dictionary = _atlas[l].meta.get(key, {})
		if m.is_empty():
			continue
		img.blend_rect(_atlas[l].img, Rect2i(int(m.x), int(m.y), w * n, h), Vector2i.ZERO)
	img.generate_mipmaps()
	res = {"tex": ImageTexture.create_from_image(img), "frames": n, "w": w, "h": h}
	_cache[ck] = res
	return res


func _ready() -> void:
	pixel_size = 1.0 / PPM
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = true
	double_sided = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		inv.changed.connect(refresh)
	refresh()


func equip() -> Dictionary:
	var inv := get_node_or_null("/root/Inventory")
	return inv.equip if inv else {}


func play(a: String, d: String, lp := true, restart := false) -> void:
	if a == anim and d == dir and not restart and lp == loop:
		return
	var changed := a != anim or d != dir or restart
	anim = a
	dir = d
	loop = lp
	if changed:
		_t = 0.0
	refresh()


func refresh() -> void:
	var s := sheet(anim, dir, equip())
	if s.is_empty():
		return
	_info = s
	texture = s.tex
	hframes = s.frames
	position.y = float(s.h) / PPM * 0.5
	frame = clampi(int(_t), 0, s.frames - 1)


func _process(dt: float) -> void:
	if _info.is_empty():
		return
	_t += dt * float(FPS.get(anim, 10.0))
	var n := int(_info.frames)
	if _t >= n:
		if loop:
			_t = fmod(_t, float(n))
		else:
			_t = float(n) - 0.001
			finished.emit()
	frame = clampi(int(_t), 0, n - 1)
