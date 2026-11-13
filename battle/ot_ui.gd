class_name OTUI
extends Control
## HUD souboje podle Octopath Traveler (1920x1080): pořadí tahů, panel družiny s BP/HP/SP,
## příkazové menu s ukazatelem, Boost, štíty a slabiny nepřátel, rychlost hry.

signal menu_done(key: String)
signal boost_changed(level: int)

const F_SERIF_I := preload("res://fonts/DejaVuSerif-Italic.ttf")
const F_SERIF_B := preload("res://fonts/DejaVuSerif-Bold.ttf")
const F_SANS := preload("res://fonts/DejaVuSans.ttf")
const WEAK_ALL := ["sword", "spear", "dagger", "axe", "bow", "staff", "fire", "ice", "lightning", "wind", "light", "dark"]

var party: Array = []
var enemies: Array = []
var cam: Camera3D
var _rows := {}
var _order_layer: Control
var _party_layer: Control
var _enemy_layer: Control
var _menu_box: Control
var _menu_items: Array[Control] = []
var _menu_keys: Array = []
var _menu_descs: Array = []
var _sel := 0
var _menu_active := false
var _pointer: Control
var _desc: Label
var _desc_bg: ColorRect
var _boost_tab: Control
var _boost_lbl: Label
var boost := 0
var boost_max := 0
var _banner: Control
var _banner_lbl: Label
var _speed_lbl: Label
var _marks := {}
var active_unit: Object = null
var _t := 0.0


# ------------------------------------------------------------------ pomocné kreslení
static func icon(kind: String, size := 28.0, col := Color(0.92, 0.94, 1.0)) -> Control:
	var c := OTIcon.new()
	c.kind = kind
	c.col = col
	c.custom_minimum_size = Vector2(size, size)
	c.size = Vector2(size, size)
	return c


static func label(text: String, size: int, col := Color.WHITE, font: Font = null, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func setup(p: Array, e: Array, camera: Camera3D) -> void:
	party = p
	enemies = e
	cam = camera
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_layer = _layer()
	_party_layer = _layer()
	_enemy_layer = _layer()
	_build_party()
	_build_menu()
	_build_banner()
	_speed_lbl = label("Rychlost hry × 1  ✚", 26, Color(0.95, 0.95, 1.0), F_SANS, 5)
	_speed_lbl.text = "Rychlost hry × 1  +"
	_speed_lbl.position = Vector2(48, 1022)
	add_child(_speed_lbl)
	for u in enemies:
		_make_enemy_mark(u)


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# ------------------------------------------------------------------ pořadí tahů
func set_order(current: Object, upcoming: Array) -> void:
	for c in _order_layer.get_children():
		c.queue_free()
	if current == null:
		return
	# vlevo nahoře: aktivní + 2 další
	var big := OTDiamond.new()
	big.setup(current, 150, true)
	big.position = Vector2(88 - 75, 24)
	_order_layer.add_child(big)
	var ln := ColorRect.new()
	ln.color = Color(0.85, 0.9, 1.0, 0.35)
	ln.position = Vector2(300, 89)
	ln.size = Vector2(1100, 2)
	_order_layer.add_child(ln)
	var x := 214.0
	for i in mini(2, upcoming.size()):
		var d := OTDiamond.new()
		d.setup(upcoming[i], 72, false)
		d.position = Vector2(x, 54)
		_order_layer.add_child(d)
		x += 78.0
	# uprostřed: NEXT TURN
	var nt := label("DALŠÍ KOLO", 22, Color(0.75, 0.78, 0.8), F_SERIF_B, 4)
	nt.position = Vector2(835, 30)
	_order_layer.add_child(nt)
	var tri := ColorRect.new()
	tri.color = Color(0.85, 0.9, 1.0, 0.35)
	tri.position = Vector2(826, 69)
	tri.size = Vector2(380, 2)
	_order_layer.add_child(tri)
	x = 880.0
	for i in range(2, mini(upcoming.size(), 9)):
		var d2 := OTDiamond.new()
		d2.setup(upcoming[i], 58, false)
		d2.position = Vector2(x, 62)
		_order_layer.add_child(d2)
		x += 46.0


# ------------------------------------------------------------------ panel družiny
func _build_party() -> void:
	var y := 34.0
	for u in party:
		var row := Control.new()
		row.position = Vector2(1635, y)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party_layer.add_child(row)
		var nm := label(u.unit_name, 30, Color(0.95, 0.96, 1.0), F_SERIF_I, 6)
		nm.position = Vector2(0, 0)
		row.add_child(nm)
		var bp := OTBP.new()
		bp.position = Vector2(150, 12)
		bp.custom_minimum_size = Vector2(160, 30)
		row.add_child(bp)
		var hpl := label("HP", 20, Color(0.7, 0.75, 0.8), F_SANS, 4)
		hpl.position = Vector2(30, 52)
		row.add_child(hpl)
		var hpv := label("", 40, Color.WHITE, F_SANS, 6)
		hpv.position = Vector2(60, 38)
		hpv.size = Vector2(205, 50)
		hpv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(hpv)
		var hpb := OTBar.new()
		hpb.col = Color(0.35, 0.8, 0.35)
		hpb.position = Vector2(30, 90)
		hpb.size = Vector2(235, 5)
		row.add_child(hpb)
		var spl := label("SP", 20, Color(0.7, 0.75, 0.8), F_SANS, 4)
		spl.position = Vector2(60, 100)
		row.add_child(spl)
		var spv := label("", 36, Color.WHITE, F_SANS, 6)
		spv.position = Vector2(90, 90)
		spv.size = Vector2(175, 46)
		spv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(spv)
		var spb := OTBar.new()
		spb.col = Color(0.4, 0.6, 0.95)
		spb.position = Vector2(60, 134)
		spb.size = Vector2(205, 4)
		row.add_child(spb)
		var emb := OTEmblem.new()
		emb.position = Vector2(240, 8)
		emb.col = u.color
		row.add_child(emb)
		_rows[u] = {"row": row, "bp": bp, "hp": hpv, "hpb": hpb, "sp": spv, "spb": spb, "name": nm, "x0": 1635.0}
		y += 146.0
	update_party()


func update_party() -> void:
	for u in party:
		var r: Dictionary = _rows[u]
		(r["hp"] as Label).text = "%d/%d" % [u.hp, u.max_hp]
		(r["sp"] as Label).text = "%d/%d" % [u.sp, u.max_sp]
		(r["hpb"] as OTBar).set_ratio(float(u.hp) / maxf(u.max_hp, 1))
		(r["spb"] as OTBar).set_ratio(float(u.sp) / maxf(u.max_sp, 1))
		(r["bp"] as OTBP).set_bp(u.bp, active_unit == u, boost)
		(r["name"] as Label).modulate = Color(1, 1, 1) if u.alive() else Color(0.7, 0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(r["row"], "position:x", (r["x0"] as float) - (62.0 if u == active_unit else 0.0), 0.15)


# ------------------------------------------------------------------ menu
func _build_menu() -> void:
	_menu_box = Control.new()
	_menu_box.position = Vector2(1250, 618)
	_menu_box.visible = false
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_box)
	_boost_tab = OTBoostTab.new()
	_boost_tab.position = Vector2(1318, 575)
	_boost_tab.size = Vector2(205, 34)
	_menu_box.get_parent().add_child(_boost_tab)
	_boost_tab.visible = false
	_pointer = OTHand.new()
	_pointer.size = Vector2(46, 30)
	_menu_box.add_child(_pointer)
	_desc_bg = ColorRect.new()
	_desc_bg.color = Color(0.04, 0.04, 0.06, 0.72)
	_desc_bg.size = Vector2(620, 40)
	_desc_bg.visible = false
	_desc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_bg)
	_desc = label("", 23, Color(0.92, 0.93, 0.95), F_SANS, 2)
	_desc.visible = false
	add_child(_desc)


## Zobrazí menu; vrací klíč vybrané položky ("back" při Esc). descs = popisky.
func menu(labels: Array, keys: Array, descs: Array, boostable := false, bp_avail := 0, start_boost := 0) -> String:
	for c in _menu_items:
		c.queue_free()
	_menu_items.clear()
	_menu_keys = keys
	_menu_descs = descs
	boost = start_boost
	boost_max = mini(3, bp_avail) if boostable else 0
	_boost_tab.visible = boostable
	(_boost_tab as OTBoostTab).level = start_boost
	_boost_tab.queue_redraw()
	var h := 37.0 * labels.size() + 12.0
	var bg := OTMenuBg.new()
	bg.size = Vector2(300, h)
	_menu_box.add_child(bg)
	_menu_items.append(bg)
	_menu_box.move_child(bg, 0)
	for i in labels.size():
		var it := label(str(labels[i]), 27, Color(0.95, 0.95, 0.98), F_SANS, 3)
		it.position = Vector2(12, 6 + i * 37.0)
		_menu_box.add_child(it)
		_menu_items.append(it)
	_sel = 0
	_menu_box.position.y = 885.0 - h
	_boost_tab.position.y = _menu_box.position.y - 43.0
	_menu_box.visible = true
	_menu_active = true
	_refresh_sel()
	update_party()
	var res: String = await menu_done
	_menu_active = false
	_menu_box.visible = false
	_boost_tab.visible = false
	_desc.visible = false
	_desc_bg.visible = false
	boost = 0
	update_party()
	return res


func hide_menu() -> void:
	_menu_active = false
	_menu_box.visible = false
	_boost_tab.visible = false
	_desc.visible = false
	_desc_bg.visible = false


func _refresh_sel() -> void:
	_pointer.position = Vector2(-30, 10 + _sel * 37.0)
	for i in _menu_items.size() - 1:
		var it := _menu_items[i + 1] as Label
		it.modulate = Color(1, 1, 1) if i == _sel else Color(0.78, 0.8, 0.85)
	var bgc := _menu_items[0] as OTMenuBg
	bgc.sel = _sel
	bgc.queue_redraw()
	if _sel < _menu_descs.size():
		_desc.text = str(_menu_descs[_sel])
		_desc.position = Vector2(1575, _menu_box.position.y + 8 + _sel * 37.0)
		_desc_bg.position = Vector2(1565, _menu_box.position.y + 5 + _sel * 37.0)
		_desc_bg.size = Vector2(1920 - 1565, 38)
		_desc.visible = _desc.text != ""
		_desc_bg.visible = _desc.visible


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_T:
		Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
		_speed_lbl.text = "Rychlost hry × %d  +" % int(Engine.time_scale)
	if not _menu_active:
		return
	if ev.is_action_pressed("ui_down"):
		_sel = (_sel + 1) % _menu_keys.size()
		_refresh_sel()
	elif ev.is_action_pressed("ui_up"):
		_sel = (_sel - 1 + _menu_keys.size()) % _menu_keys.size()
		_refresh_sel()
	elif ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		menu_done.emit(str(_menu_keys[_sel]))
	elif ev.is_action_pressed("ui_cancel"):
		menu_done.emit("back")
	elif ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_R or ev.keycode == KEY_B):
		if boost_max > 0:
			boost = (boost + 1) % (boost_max + 1)
			(_boost_tab as OTBoostTab).level = boost
			_boost_tab.queue_redraw()
			update_party()
			boost_changed.emit(boost)


func auto_pick(key: String) -> void:
	if _menu_active:
		menu_done.emit(key)


# ------------------------------------------------------------------ banner (název schopnosti)
func _build_banner() -> void:
	_banner = Control.new()
	_banner.position = Vector2(560, 150)
	_banner.size = Vector2(800, 52)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var bg := OTMenuBg.new()
	bg.size = Vector2(800, 52)
	bg.sel = -1
	_banner.add_child(bg)
	_banner_lbl = label("", 30, Color.WHITE, F_SANS, 3)
	_banner_lbl.size = Vector2(800, 52)
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_lbl)


func say(text: String) -> void:
	_banner_lbl.text = text
	_banner.visible = text != ""


# ------------------------------------------------------------------ štíty a slabiny nepřátel
func _make_enemy_mark(u: Object) -> void:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_layer.add_child(c)
	var shield := OTShield.new()
	shield.position = Vector2(-60, 0)
	shield.size = Vector2(44, 52)
	c.add_child(shield)
	var vt := label("SLABINY", 22, Color(0.92, 0.94, 1.0), F_SANS, 4)
	vt.position = Vector2(-10, -4)
	c.add_child(vt)
	var slots: Array = []
	for i in 4:
		var s := OTSlot.new()
		s.position = Vector2(-4 + i * 34, 28)
		s.size = Vector2(30, 30)
		c.add_child(s)
		slots.append(s)
	_marks[u] = {"c": c, "shield": shield, "slots": slots, "title": vt}
	refresh_enemy(u)


func refresh_enemy(u: Object) -> void:
	if not _marks.has(u):
		return
	var m: Dictionary = _marks[u]
	(m["shield"] as OTShield).value = u.shield
	(m["shield"] as OTShield).broken = u.broken
	(m["shield"] as OTShield).queue_redraw()
	(m["title"] as Label).text = "ZLOMENÝ" if u.broken else "SLABINY"
	(m["title"] as Label).modulate = Color(1, 0.55, 0.45) if u.broken else Color.WHITE
	for i in 4:
		var s := (m["slots"] as Array)[i] as OTSlot
		var w: String = u.weak[i] if i < u.weak.size() else ""
		s.kind = w if (w != "" and u.weak_known.has(w)) else ""
		s.known = w == "" or u.weak_known.has(w)
		s.queue_redraw()


func _process(dt: float) -> void:
	_t += dt
	if cam == null:
		return
	for u in _marks.keys():
		var m: Dictionary = _marks[u]
		var c := m["c"] as Control
		if not u.alive() or u.node == null:
			c.visible = false
			continue
		c.visible = not cam.is_position_behind(u.node.global_position)
		var p := cam.unproject_position(u.node.global_position + Vector3(0, -0.15, 0))
		c.position = p + Vector2(-60, 12) * 1.0 + Vector2(0, 0)


static func _sc(pts: Array, u: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append((p as Vector2) * u)
	return out


static func _di(ci: CanvasItem, kind: String, u: float, col: Color) -> void:
	match kind:
		"sword":
			ci.draw_line(Vector2(6, 22) * u, Vector2(22, 6) * u, col, 3.0 * u)
			ci.draw_line(Vector2(5, 14) * u, Vector2(14, 23) * u, col, 2.5 * u)
			ci.draw_line(Vector2(5, 23) * u, Vector2(8, 20) * u, col, 3.0 * u)
		"spear":
			ci.draw_line(Vector2(5, 23) * u, Vector2(20, 8) * u, col, 2.5 * u)
			ci.draw_colored_polygon(_sc([Vector2(18, 4), Vector2(25, 3), Vector2(24, 10), Vector2(20, 8)], u), col)
		"dagger":
			ci.draw_line(Vector2(8, 20) * u, Vector2(20, 8) * u, col, 4.0 * u)
			ci.draw_line(Vector2(6, 14) * u, Vector2(14, 22) * u, col, 2.0 * u)
		"axe":
			ci.draw_line(Vector2(8, 24) * u, Vector2(19, 5) * u, col, 2.5 * u)
			ci.draw_colored_polygon(_sc([Vector2(14, 6), Vector2(25, 8), Vector2(23, 17), Vector2(17, 13)], u), col)
		"bow":
			ci.draw_arc(Vector2(10, 14) * u, 12.0 * u, -1.1, 1.1, 14, col, 2.5 * u)
			ci.draw_line(Vector2(15, 4) * u, Vector2(15, 24) * u, col, 1.2 * u)
			ci.draw_line(Vector2(8, 14) * u, Vector2(26, 14) * u, col, 1.5 * u)
		"staff":
			ci.draw_line(Vector2(7, 25) * u, Vector2(18, 9) * u, col, 2.5 * u)
			ci.draw_circle(Vector2(20, 7) * u, 4.0 * u, col)
		"fire":
			ci.draw_colored_polygon(_sc([Vector2(14, 2), Vector2(21, 12), Vector2(22, 20), Vector2(14, 26), Vector2(6, 20), Vector2(8, 12), Vector2(12, 15)], u), Color(1.0, 0.45, 0.25))
		"ice":
			for a in 3:
				var d := Vector2.from_angle(a * PI / 3.0) * 11.0 * u
				ci.draw_line(Vector2(14, 14) * u - d, Vector2(14, 14) * u + d, Color(0.6, 0.9, 1.0), 2.4 * u)
		"lightning":
			ci.draw_colored_polygon(_sc([Vector2(16, 2), Vector2(7, 16), Vector2(13, 16), Vector2(10, 26), Vector2(21, 11), Vector2(15, 11)], u), Color(1.0, 0.9, 0.3))
		"wind":
			ci.draw_arc(Vector2(13, 12) * u, 7.0 * u, 3.4, 7.2, 14, Color(0.6, 1.0, 0.75), 2.4 * u)
			ci.draw_arc(Vector2(15, 17) * u, 5.0 * u, 0.2, 4.0, 12, Color(0.6, 1.0, 0.75), 2.2 * u)
		"light":
			ci.draw_circle(Vector2(14, 14) * u, 5.0 * u, Color(1.0, 0.97, 0.7))
			for a in 8:
				var d2 := Vector2.from_angle(a * PI / 4.0)
				ci.draw_line(Vector2(14, 14) * u + d2 * 8.0 * u, Vector2(14, 14) * u + d2 * 12.0 * u, Color(1.0, 0.97, 0.7), 2.0 * u)
		"dark":
			ci.draw_circle(Vector2(14, 14) * u, 10.0 * u, Color(0.7, 0.45, 0.9))
			ci.draw_circle(Vector2(18, 11) * u, 9.0 * u, Color(0.08, 0.06, 0.14))


# ================================================================== vlastní Controly
class OTIcon:
	extends Control
	var kind := "sword"
	var col := Color(0.92, 0.94, 1.0)

	func _draw() -> void:
		OTUI._di(self, kind, size.x / 28.0, col)


class OTDiamond:
	extends Control
	var unit: Object
	var big := false

	func setup(u: Object, sz: float, is_big: bool) -> void:
		unit = u
		big = is_big
		size = Vector2(sz, sz)

	func _draw() -> void:
		var h := size.x * 0.5
		var pts := PackedVector2Array([Vector2(h, 0), Vector2(size.x, h), Vector2(h, size.y), Vector2(0, h)])
		var edge := Color(0.95, 0.95, 1.0, 0.95) if unit.is_hero else Color(0.85, 0.2, 0.22, 0.95)
		var inner := PackedVector2Array([Vector2(h, 3), Vector2(size.x - 3, h), Vector2(h, size.y - 3), Vector2(3, h)])
		draw_colored_polygon(inner, Color(0.12, 0.14, 0.2, 0.95) if unit.is_hero else Color(0.14, 0.1, 0.1, 0.95))
		var tex: Texture2D = unit.texture
		if tex != null:
			var fw := tex.get_width() / float(maxi(unit.hframes, 1))
			var fh := float(tex.get_height())
			# hlava hrdiny / střed nepřítele
			var src := Rect2(0, 0, fw, fh * 0.5) if unit.is_hero and unit.hero_anim else Rect2(0, 0, fw, fh)
			var uv := PackedVector2Array()
			for p in inner:
				var fx := p.x / size.x
				var fy := p.y / size.y
				uv.append(Vector2((src.position.x + fx * src.size.x) / tex.get_width(), (src.position.y + fy * src.size.y) / fh))
			draw_colored_polygon(inner, Color.WHITE, uv, tex)
		else:
			draw_colored_polygon(inner, unit.color)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), edge, 3.0 if big else 2.0)
		if big:
			var o := PackedVector2Array([Vector2(h, -9), Vector2(size.x + 9, h), Vector2(h, size.y + 9), Vector2(-9, h), Vector2(h, -9)])
			draw_polyline(o, Color(0.85, 0.9, 1.0, 0.45), 1.5)


class OTBar:
	extends Control
	var col := Color.GREEN
	var ratio := 1.0

	func set_ratio(r: float) -> void:
		ratio = clampf(r, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.15, 0.85))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * ratio, size.y)), col)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.85, 0.9, 0.5), false, 1.0)


class OTBP:
	extends Control
	var bp := 1
	var active := false
	var pend := 0

	func set_bp(v: int, act: bool, pending: int) -> void:
		bp = v
		active = act
		pend = pending if act else 0
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, 18), "BP", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.75, 0.78, 0.82))
		for i in 5:
			var c := Vector2(36 + i * 17, 11)
			if i < bp:
				var lit := i >= bp - pend
				draw_circle(c, 4.5, Color(1.0, 0.45, 0.3) if lit else Color(0.85, 0.2, 0.2))
			else:
				draw_circle(c, 2.0, Color(0.7, 0.72, 0.78, 0.8))


class OTEmblem:
	extends Control
	var col := Color.WHITE

	func _draw() -> void:
		draw_arc(Vector2(26, 26), 24.0, 0, TAU, 32, Color(0.9, 0.92, 1.0, 0.95), 3.0)
		draw_arc(Vector2(26, 26), 15.0, 0, TAU, 32, col.lightened(0.3), 3.0)
		draw_circle(Vector2(26, 26), 6.0, col.lightened(0.15))


class OTMenuBg:
	extends Control
	var sel := 0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.62))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.85, 0.5), false, 1.5)
		if sel >= 0:
			var r := Rect2(4, 5 + sel * 37.0, size.x - 8, 36)
			draw_rect(r, Color(0.28, 0.3, 0.38, 0.85))
			draw_rect(r, Color(1, 1, 1, 0.95), false, 2.0)
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 8)), Color(1, 1, 1, 0.12))


class OTHand:
	extends Control

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 14), Vector2(10, 6), Vector2(20, 7), Vector2(34, 6), Vector2(40, 12), Vector2(34, 19), Vector2(20, 20), Vector2(10, 22)])
		draw_colored_polygon(pts, Color(0.97, 0.97, 1.0))
		draw_polyline(PackedVector2Array(pts + PackedVector2Array([pts[0]])), Color(0.1, 0.1, 0.15), 1.5)


class OTBoostTab:
	extends Control
	var level := 0

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(14, 0), Vector2(size.x - 14, 0), Vector2(size.x, size.y * 0.5), Vector2(size.x - 14, size.y), Vector2(14, size.y), Vector2(0, size.y * 0.5)])
		draw_colored_polygon(pts, Color(0.1, 0.1, 0.14, 0.8) if level == 0 else Color(0.55, 0.2, 0.1, 0.9))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.85, 0.88, 0.95, 0.9), 1.5)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, 24), "Boost", HORIZONTAL_ALIGNMENT_CENTER, size.x - 30, 22, Color.WHITE)
		draw_rect(Rect2(size.x - 50, 7, 28, 20), Color(0.9, 0.92, 1.0))
		draw_string(f, Vector2(size.x - 50, 24), "R", HORIZONTAL_ALIGNMENT_CENTER, 28, 18, Color(0.1, 0.1, 0.15))


class OTShield:
	extends Control
	var value := 0
	var broken := false

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(2, 2), Vector2(42, 2), Vector2(42, 28), Vector2(22, 50), Vector2(2, 28)])
		draw_colored_polygon(pts, Color(0.2, 0.28, 0.6, 0.95) if not broken else Color(0.4, 0.15, 0.15, 0.95))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.9, 0.93, 1.0), 2.5)
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(0, 33), "×" if broken else str(value), HORIZONTAL_ALIGNMENT_CENTER, 44, 30, Color.WHITE)


class OTSlot:
	extends Control
	var kind := ""
	var known := true

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.1, 0.8))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.74, 0.82, 0.7), false, 1.0)
		if kind != "":
			OTUI._di(self, kind, 1.0, Color.WHITE)
		elif not known:
			draw_string(ThemeDB.fallback_font, Vector2(0, 22), "?", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.8, 0.82, 0.9))
