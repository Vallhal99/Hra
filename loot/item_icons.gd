class_name ItemIcons
extends RefCounted
## Procedurálně kreslené ikonky předmětů, které nemají vlastní obrázek (pixel-art 32×32).

static var _cache: Dictionary = {}
const OUT := Color(0.07, 0.06, 0.09)


static func get_icon(id: String, it: Dictionary) -> Texture2D:
	var p: String = str(it.get("icon", ""))
	if p != "":
		var full := p if p.begins_with("res://") else "res://" + p
		if ResourceLoader.exists(full):
			return load(full)
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	_draw(img, id, str(it.get("category", "")))
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < 32 and y < 32:
		img.set_pixel(x, y, c)


static func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, outline := true) -> void:
	for y in range(int(cy - ry - 2), int(cy + ry + 3)):
		for x in range(int(cx - rx - 2), int(cx + rx + 3)):
			var d := pow((x - cx) / rx, 2.0) + pow((y - cy) / ry, 2.0)
			if d <= 1.0:
				var shade := 1.0 - 0.28 * clampf(((y - cy) / ry + (x - cx) / rx * 0.4) * 0.5 + 0.3, 0.0, 1.0)
				_px(img, x, y, Color(c.r * shade, c.g * shade, c.b * shade, 1.0))
			elif outline and d <= 1.35:
				if img.get_pixel(clampi(x, 0, 31), clampi(y, 0, 31)).a < 0.5:
					_px(img, x, y, OUT)


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0 - 1, y1 + 2):
		for x in range(x0 - 1, x1 + 2):
			if x < x0 or x > x1 or y < y0 or y > y1:
				if img.get_pixel(clampi(x, 0, 31), clampi(y, 0, 31)).a < 0.5:
					_px(img, x, y, OUT)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, w := 1.0) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for dx in range(-int(w), int(w) + 1):
			for dy in range(-int(w), int(w) + 1):
				_px(img, int(p.x) + dx, int(p.y) + dy, c)


static func _draw(img: Image, id: String, cat: String) -> void:
	match id:
		"lektvar", "lektvar_many":
			var c := Color(0.85, 0.15, 0.2) if id == "lektvar" else Color(0.2, 0.4, 0.95)
			_ell(img, 16, 21, 8, 8, c)
			_rect(img, 13, 6, 18, 13, Color(0.8, 0.85, 0.9))
			_rect(img, 12, 4, 19, 6, Color(0.55, 0.35, 0.2))
			_ell(img, 13, 19, 2, 2, Color(1, 1, 1, 1), false)
		"ruda":
			_ell(img, 14, 19, 9, 7, Color(0.5, 0.52, 0.58))
			_ell(img, 20, 15, 6, 5, Color(0.62, 0.64, 0.7))
			for p in [Vector2(11, 18), Vector2(19, 21), Vector2(21, 14)]:
				_px(img, int(p.x), int(p.y), Color(0.95, 0.6, 0.2))
				_px(img, int(p.x) + 1, int(p.y), Color(0.95, 0.6, 0.2))
		"kost":
			_line(img, Vector2(9, 22), Vector2(23, 9), OUT, 3.0)
			_line(img, Vector2(9, 22), Vector2(23, 9), Color(0.92, 0.9, 0.82), 2.0)
			for p in [Vector2(8, 24), Vector2(11, 25), Vector2(22, 7), Vector2(25, 9)]:
				_ell(img, p.x, p.y, 2.6, 2.6, Color(0.92, 0.9, 0.82))
		"zele":
			_ell(img, 16, 20, 10, 8, Color(0.3, 0.85, 0.4))
			_ell(img, 16, 13, 6, 6, Color(0.4, 0.92, 0.5))
			_px(img, 13, 12, Color(1, 1, 1))
		"maso":
			_ell(img, 14, 17, 9, 7, Color(0.85, 0.3, 0.3))
			_rect(img, 20, 20, 27, 22, Color(0.95, 0.92, 0.85))
			_ell(img, 27, 21, 2.5, 2.5, Color(0.95, 0.92, 0.85))
		"ryba":
			_ell(img, 14, 16, 10, 6, Color(0.5, 0.7, 0.9))
			_line(img, Vector2(23, 16), Vector2(29, 10), Color(0.4, 0.6, 0.85), 1.0)
			_line(img, Vector2(23, 16), Vector2(29, 22), Color(0.4, 0.6, 0.85), 1.0)
			_px(img, 8, 15, Color(0, 0, 0))
		"bylina":
			_line(img, Vector2(16, 28), Vector2(16, 8), OUT, 2.0)
			_line(img, Vector2(16, 28), Vector2(16, 8), Color(0.25, 0.6, 0.25), 1.0)
			for p in [Vector2(11, 12), Vector2(21, 12), Vector2(10, 19), Vector2(22, 19)]:
				_ell(img, p.x, p.y, 4, 2.5, Color(0.35, 0.75, 0.3))
		"houba":
			_rect(img, 13, 17, 19, 27, Color(0.92, 0.88, 0.78))
			_ell(img, 16, 15, 11, 7, Color(0.78, 0.3, 0.22))
			for p in [Vector2(11, 14), Vector2(17, 11), Vector2(21, 15)]:
				_px(img, int(p.x), int(p.y), Color(1, 1, 1))
		"koreni":
			_ell(img, 16, 20, 9, 8, Color(0.75, 0.55, 0.3))
			_rect(img, 12, 8, 20, 12, Color(0.5, 0.3, 0.15))
			for p in [Vector2(13, 20), Vector2(18, 22), Vector2(16, 17)]:
				_px(img, int(p.x), int(p.y), Color(0.9, 0.2, 0.15))
		"gulas", "ryb_polevka", "houbova_panev", "bylinny_caj", "zele_dezert":
			var col: Color = {"gulas": Color(0.75, 0.3, 0.15), "ryb_polevka": Color(0.9, 0.7, 0.4), "houbova_panev": Color(0.65, 0.5, 0.35), "bylinny_caj": Color(0.4, 0.75, 0.35), "zele_dezert": Color(0.35, 0.9, 0.5)}[id]
			_ell(img, 16, 21, 12, 7, Color(0.55, 0.55, 0.6))
			_ell(img, 16, 18, 10, 4, col, false)
			for x in [11, 16, 21]:
				_line(img, Vector2(x, 12), Vector2(x + 1, 6), Color(1, 1, 1, 0.5), 0.0)
		"past":
			_line(img, Vector2(5, 24), Vector2(27, 24), OUT, 3.0)
			_line(img, Vector2(6, 24), Vector2(16, 12), Color(0.7, 0.72, 0.78), 1.0)
			_line(img, Vector2(26, 24), Vector2(16, 12), Color(0.7, 0.72, 0.78), 1.0)
			_ell(img, 16, 24, 11, 3, Color(0.45, 0.45, 0.5), false)
		"paklic":
			_line(img, Vector2(8, 24), Vector2(22, 10), OUT, 2.0)
			_line(img, Vector2(8, 24), Vector2(22, 10), Color(0.75, 0.78, 0.85), 1.0)
			_line(img, Vector2(22, 10), Vector2(26, 11), Color(0.75, 0.78, 0.85), 1.0)
			_rect(img, 5, 23, 11, 27, Color(0.5, 0.3, 0.15))
		"klic_mauzolea":
			_ell(img, 10, 11, 6, 6, Color(0.82, 0.68, 0.25))
			_ell(img, 10, 11, 2.2, 2.2, Color(0.1, 0.1, 0.1), false)
			_rect(img, 14, 10, 28, 12, Color(0.82, 0.68, 0.25))
			_rect(img, 24, 12, 26, 17, Color(0.82, 0.68, 0.25))
		_:
			_ell(img, 16, 16, 9, 9, Color(0.6, 0.55, 0.85))
			_ell(img, 13, 13, 3, 3, Color(1, 1, 1), false)
