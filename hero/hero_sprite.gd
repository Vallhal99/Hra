class_name HeroSprite3D
extends Sprite3D
## Animovaný hrdina složený z vrstev (nahé tělo + kusy brnění) podle Inventory.equip.
## Atlasy jsou v res://hero/atlas (export z Dílny postav). Směry: S SE E NE N NW W SW.

const SLOTS := ["helma", "telo", "rukavice", "kalhoty", "boty", "zbran"]
const PPM := 115.0  ## pixelů na metr (hrdina je vysoký 252 px = 1,9 m)
const FPS := {"Idle": 6.0, "Walk": 10.0, "Run": 13.0, "Swordslash": 12.0, "Attackthrust": 12.0, "Attackranged": 10.0, "Castspell": 10.0, "Attackcombo3hit": 12.0, "Block": 8.0, "Hurt": 10.0, "Death": 8.0, "Chargeup": 10.0, "Climb": 8.0, "Victory": 8.0}
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


static func _dlevel(slot: String) -> int:
	var l := Engine.get_main_loop() as SceneTree
	var inv = l.root.get_node_or_null("Inventory") if l else null
	return inv.dura_level(slot) if inv else 0


static func layers_for(equip: Dictionary) -> Array:
	var out := []
	for s in SLOTS.slice(0, 5):
		if equip.get(s) == null or (s != "zbran" and _dlevel(s) >= 3):
			out.append("nahe_" + s)
	for s in SLOTS:
		if equip.get(s) != null and not (s != "zbran" and _dlevel(s) >= 3):
			out.append(s)
	return out


## Poškozený kus: ztmavení a praskliny (level 1 = pár trhlin, 2 = hodně).
static func _damage(img: Image, lv: int, seed_: int, w: int, n: int, h: int) -> void:
	var rng := RandomNumberGenerator.new()
	for f in n:
		rng.seed = seed_ + lv * 7919
		var x0 := f * w
		for yy in h:
			for xx in w:
				var c := img.get_pixel(x0 + xx, yy)
				if c.a > 0.5:
					var k := 1.0 - 0.1 * lv - (0.12 if ((xx / 5 + yy / 5) * 2654435761 >> 3) % 7 == 0 else 0.0) * lv
					img.set_pixel(x0 + xx, yy, Color(c.r * k, c.g * k, c.b * k, c.a))
		for i in 3 * lv + 2:
			var p := Vector2.ZERO
			var ok := false
			for t in 30:
				p = Vector2(rng.randi_range(10, w - 10), rng.randi_range(20, h - 40))
				if img.get_pixel(x0 + int(p.x), int(p.y)).a > 0.5:
					ok = true
					break
			if not ok:
				continue
			var ang := rng.randf() * TAU
			for st in rng.randi_range(6, 12 + 4 * lv):
				ang += rng.randf_range(-0.6, 0.6)
				p += Vector2(cos(ang), sin(ang)) * 1.4
				var px := int(p.x)
				var py := int(p.y)
				if px >= 0 and px < w and py >= 0 and py < h and img.get_pixel(x0 + px, py).a > 0.5:
					img.set_pixel(x0 + px, py, Color(0.06, 0.05, 0.08, 1.0))


## Meč v ruce při stání/chůzi (atlas zbraně tyto animace nemá) – kreslí se do snímků.
## [posun ruky x od středu, y ruky, úhel od svislice ve stupních (+ doprava), délka, 1 = za tělem]
const SWORD := {
	"S": [-47, 150, -22, 74, 0], "SE": [-30, 152, 28, 74, 0], "E": [12, 152, 55, 74, 0],
	"NE": [28, 150, 40, 74, 1], "N": [47, 150, 22, 74, 1], "NW": [30, 150, -40, 74, 1],
	"W": [-12, 152, -55, 74, 0], "SW": [-30, 152, -28, 74, 0]}


static func _wtype(equip: Dictionary) -> String:
	var z = equip.get("zbran")
	if z == null or z == "":
		return "fist"
	return Rules.weapon_type_of(str(z))


static func _has_sword(equip: Dictionary) -> bool:
	var z = equip.get("zbran")
	return z != null and z != ""


static func _put(img: Image, x: int, y: int, c: Color, x0: int, w: int) -> void:
	if x >= x0 and x < x0 + w and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)


static var _hands: Dictionary = {}


## pozice ruky po framech (tools/retarget/sword_hand.py) -> hero/sword_hand.json
static func _hand_track(a: String, d: String) -> Array:
	if _hands.is_empty():
		var p := "res://hero/sword_hand.json"
		_hands = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {"_": []}
	return _hands.get("%s (%s)" % [a, d], [])


## usecka (tlusta) do snimku
static func _stroke(img: Image, a: Vector2, b: Vector2, half: float, col: Color, x0: int, w: int) -> void:
	var ln := a.distance_to(b)
	var dirv := (b - a) / maxf(ln, 0.001)
	var side := Vector2(-dirv.y, dirv.x)
	var t := 0.0
	while t <= ln:
		var k := -half
		while k <= half:
			var q := a + dirv * t + side * k
			_put(img, int(round(q.x)), int(round(q.y)), col, x0, w)
			k += 0.5
		t += 0.5


const STEEL := Color(0.82, 0.86, 0.92)
const OUTL := Color(0.08, 0.08, 0.1)
const WOOD := Color(0.45, 0.28, 0.14)
const GOLD := Color(0.86, 0.68, 0.25)


## Ostatni zbrane (kopi, sekera, dyka, hul, luk) - kresli se stejne do ruky jako mec.
static func _draw_other(img: Image, o: Vector2, up: Vector2, wt: String, x0: int, w: int) -> void:
	var side := Vector2(-up.y, up.x)
	for pass_i in 2:
		var ol := pass_i == 0
		var g := 1.2 if ol else 0.0
		match wt:
			"spear":
				_stroke(img, o - up * 32.0, o + up * 78.0, 1.7 + g, OUTL if ol else WOOD, x0, w)
				var tip := o + up * 104.0
				_stroke(img, o + up * 78.0, tip, 4.0 + g, OUTL if ol else STEEL, x0, w)
				_stroke(img, o + up * 94.0, tip, 2.0 + g, OUTL if ol else Color(0.95, 0.97, 1.0), x0, w)
			"axe":
				_stroke(img, o - up * 14.0, o + up * 70.0, 1.9 + g, OUTL if ol else WOOD, x0, w)
				for i in 9:
					var u := 52.0 + i * 2.4
					var wd := 3.0 + 9.0 * sin(float(i) / 8.0 * PI)
					_stroke(img, o + up * u + side * 1.5, o + up * u + side * (1.5 + wd), 1.4 + g, OUTL if ol else STEEL, x0, w)
				_stroke(img, o + up * 70.0, o + up * 74.0, 2.0 + g, OUTL if ol else GOLD, x0, w)
			"dagger":
				_stroke(img, o - up * 8.0, o + up * 2.0, 1.7 + g, OUTL if ol else WOOD, x0, w)
				_stroke(img, o + up * 2.0 - side * 4.0, o + up * 2.0 + side * 4.0, 1.0 + g, OUTL if ol else GOLD, x0, w)
				_stroke(img, o + up * 3.0, o + up * 36.0, 2.0 + g, OUTL if ol else STEEL, x0, w)
			"staff":
				_stroke(img, o - up * 30.0, o + up * 74.0, 1.8 + g, OUTL if ol else WOOD, x0, w)
				var orb := o + up * 82.0
				_stroke(img, orb - side * 5.0, orb + side * 5.0, 5.0 + g, OUTL if ol else Color(0.45, 0.7, 1.0), x0, w)
				if not ol:
					_stroke(img, orb - side * 2.0 - up * 1.0, orb - side * 2.0 + up * 1.0, 1.5, Color(0.9, 1.0, 1.0), x0, w)
			"bow":
				var prev := o - up * 38.0
				for i in range(1, 17):
					var t := -38.0 + float(i) * (76.0 / 16.0)
					var bul := 15.0 * (1.0 - pow(t / 38.0, 2.0))
					var q := o + up * t + side * bul
					_stroke(img, prev, q, 1.5 + g, OUTL if ol else Color(0.55, 0.34, 0.16), x0, w)
					prev = q
				if not ol:
					_stroke(img, o - up * 38.0, o + up * 38.0, 0.5, Color(0.92, 0.92, 0.85), x0, w)


static func _draw_sword(img: Image, w: int, h: int, n: int, a: String, d: String, wt := "sword") -> void:
	var cfg: Array = SWORD[d]
	var track := _hand_track(a, d)
	for f in n:
		var x0 := f * w
		var bob := 0.0
		if a != "Idle":
			bob = sin(float(f) / float(n) * TAU * 2.0) * 3.0
		var hx: float = x0 + w * 0.5 + float(cfg[0])
		var hy: float = float(cfg[1]) + bob
		var ang := deg_to_rad(float(cfg[2]))
		var up := Vector2(sin(ang), -cos(ang))
		if track.size() == n and track[f].size() > 2:
			ang = deg_to_rad(clampf(float(track[f][2]), -100.0, 100.0))
			up = Vector2(sin(ang), -cos(ang))
		if track.size() == n:
			hx = x0 + float(track[f][0]) + up.x * 5.0
			hy = float(track[f][1]) + up.y * 5.0
		if wt != "sword":
			_draw_other(img, Vector2(hx, hy), up, wt, x0, w)
			continue
		var side := Vector2(-up.y, up.x)
		var L: float = cfg[3]
		# obrys, čepel, záštita, rukojeť, hlavice
		for pass_i in 2:
			var t := -14.0
			while t < L + 4.0:
				var p := Vector2(hx, hy) + up * t
				var half := 2.5
				var col := Color(0.08, 0.08, 0.1)
				if t < 0.0:
					half = 1.6
					col = Color(0.35, 0.22, 0.12)
				elif t < 4.0:
					half = 6.0
					col = Color(0.86, 0.68, 0.25)
				elif t > L - 8.0:
					half = maxf(0.6, (L - t) * 0.3)
					col = Color(0.85, 0.88, 0.92)
				else:
					col = Color(0.82, 0.86, 0.92)
				if t < -11.0:
					half = 2.4
					col = Color(0.86, 0.68, 0.25)
				if pass_i == 0:
					half += 1.3
					col = Color(0.08, 0.08, 0.1)
				var k := -half
				while k <= half:
					var q := p + side * k
					var cc := col
					if pass_i == 1 and t >= 4.0 and k > half * 0.35:
						cc = Color(0.5, 0.56, 0.66)
					_put(img, int(round(q.x)), int(round(q.y)), cc, x0, w)
					k += 0.5
				t += 0.5


static func sheet(a: String, d: String, equip: Dictionary) -> Dictionary:
	_ensure()
	var key := "%s (%s)" % [a, d]
	var layers := layers_for(equip)
	var sw := _has_sword(equip) and a in ["Idle", "Walk", "Run"]
	var wt := _wtype(equip)
	var dl := ""
	for l in layers:
		dl += str(_dlevel(l))
	var ck := key + "|" + ",".join(layers) + (("|sw_" + wt) if sw else "") + "|" + dl
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
	var back: bool = sw and SWORD[d][4] == 1
	if back:
		_draw_sword(img, w, h, n, a, d, wt)
	for l in layers:
		var m: Dictionary = _atlas[l].meta.get(key, {})
		if m.is_empty():
			continue
		var lv := _dlevel(l) if l != "zbran" and not l.begins_with("nahe_") else 0
		if lv > 0:
			var tmp: Image = _atlas[l].img.get_region(Rect2i(int(m.x), int(m.y), w * n, h))
			_damage(tmp, lv, l.hash(), w, n, h)
			img.blend_rect(tmp, Rect2i(0, 0, w * n, h), Vector2i.ZERO)
		else:
			img.blend_rect(_atlas[l].img, Rect2i(int(m.x), int(m.y), w * n, h), Vector2i.ZERO)
	if sw and not back:
		_draw_sword(img, w, h, n, a, d, wt)
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
