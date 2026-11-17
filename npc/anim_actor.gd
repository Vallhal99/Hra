class_name AnimActor
extends Sprite3D
## Animovaná postava z packeru (tools/retarget/pack_sheets.py): sheet radky = smery, sloupce = framy.
## Pouziti: var a := AnimActor.new(); a.char_id = "obyvatel"; add_child(a); a.play("Walk", "SE")
signal finished

const DIR8 := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
static var _meta: Dictionary = {}
static var _tex: Dictionary = {}

@export var char_id := ""
@export var ppm := 115.0
var anim := ""
var dir := "S"
var loop := true
var speed_scale := 1.0
var _t := 0.0
var _m: Dictionary = {}
var _dirs: Array = []


static func has_char(c: String) -> bool:
	return ResourceLoader.exists("res://npc/anim/%s.json" % c)


static func meta(c: String) -> Dictionary:
	if not _meta.has(c):
		var p := "res://npc/anim/%s.json" % c
		_meta[c] = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
	return _meta[c]


static func tex(c: String, a: String) -> Texture2D:
	var k := c + "_" + a
	if not _tex.has(k):
		_tex[k] = load("res://npc/anim/%s.png" % k)
	return _tex[k]


## smer pohybu (svetovy vektor) -> jmeno smeru z pohledu kamery (S = k obrazovce dolu)
static func dir_of(world_v: Vector3, cam: Camera3D, last := "S") -> String:
	var v := Vector2(world_v.x, world_v.z)
	if v.length() < 0.001:
		return last
	var yaw := cam.global_rotation.y if cam else 0.0
	v = v.rotated(yaw)  # = inverzni rotace oproti Player3D (move = dir.rotated(UP, yaw))
	var a := rad_to_deg(atan2(v.x, v.y))
	return DIR8[int(round(wrapf(a, 0.0, 360.0) / 45.0)) % 8]


func _ready() -> void:
	pixel_size = 1.0 / ppm
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = true
	double_sided = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if anim == "":
		play("Idle", dir)


func has_anim(a: String) -> bool:
	return meta(char_id).has(a)


func _pick(a: String) -> String:
	if has_anim(a):
		return a
	for f in ["Idle", "Breath", "Walk"]:
		if has_anim(f):
			return f
	return a


func play(a: String, d := "S", lp := true, restart := false) -> void:
	a = _pick(a)
	var m: Dictionary = meta(char_id).get(a, {})
	if m.is_empty():
		return
	var dirs: Array = m.dirs
	if not dirs.has(d):
		d = d.substr(d.length() - 1, 1) if d.length() == 2 else "S"   # diagonala -> E/W/N/S
		if not dirs.has(d):
			d = "S"
	if a == anim and d == dir and not restart and lp == loop:
		return
	if a != anim or restart:
		_t = 0.0
	anim = a
	dir = d
	loop = lp
	_m = m
	_dirs = dirs
	texture = tex(char_id, a)
	hframes = int(m.frames)
	vframes = dirs.size()
	position.y = float(m.h) / ppm * 0.5
	_apply()


func _apply() -> void:
	if _m.is_empty():
		return
	var n := int(_m.frames)
	frame = _dirs.find(dir) * n + clampi(int(_t), 0, n - 1)


func _process(dt: float) -> void:
	if _m.is_empty():
		return
	_t += dt * float(_m.fps) * speed_scale
	var n := int(_m.frames)
	if _t >= n:
		if loop:
			_t = fmod(_t, float(n))
		else:
			_t = float(n) - 0.001
			finished.emit()
	_apply()
