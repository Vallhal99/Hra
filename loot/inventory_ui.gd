class_name InventoryUI
extends Control
## RPG inventář: figurka postavy s oblečenými sloty, záložky, mřížka s ikonami, popis s porovnáním.

const GOLD := Color(0.9, 0.72, 0.32)
const FILTERS := [["Vše", ""], ["Zbraně", "Zbraně"], ["Brnění", "Brnění"], ["Spotřební", "Spotřební"], ["Suroviny", "Suroviny"], ["Ostatní", "x"]]
const STAT_NAMES := {"atk": "Útok", "def": "Obrana", "hp": "Život", "sp": "Mana"}
var inv: Node
var filter := ""
var _detail: RichTextLabel
var _title: Label
var _pending_close := false
var _cols := 8
signal close_requested


static func rarity(it: Dictionary) -> Color:
	var p := int(it.get("price", 0))
	if p <= 0 and (int(it.get("atk", 0)) > 0 or int(it.get("def", 0)) > 0):
		return Color(1.0, 0.6, 0.2)
	if p < 40:
		return Color(0.8, 0.82, 0.88)
	if p < 120:
		return Color(0.45, 0.85, 0.45)
	if p < 300:
		return Color(0.4, 0.65, 1.0)
	return Color(0.75, 0.5, 1.0)


func _sb(bg: Color, border: Color, bw := 2, r := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	return s


func build(inv_: Node) -> void:
	inv = inv_
	for c in get_children():
		c.queue_free()
	position = Vector2.ZERO
	size = get_viewport().get_visible_rect().size
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.07, 0.14, 0.98), GOLD, 3, 10))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var vp := size
	var pw := clampf(vp.x * 0.92, 900.0, 1500.0)
	var ph := clampf(vp.y * 0.92, 560.0, 860.0)
	_cols = maxi(6, int((pw - 380.0 - 70.0) / 78.0))
	panel.custom_minimum_size = Vector2(pw, ph)
	panel.offset_left = -pw * 0.5
	panel.offset_right = pw * 0.5
	panel.offset_top = -ph * 0.5
	panel.offset_bottom = ph * 0.5
	add_child(panel)
	var mg := MarginContainer.new()
	for k in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + k, 16)
	panel.add_child(mg)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	mg.add_child(root)
	root.add_child(_header())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	body.add_child(_left())
	body.add_child(_right())
	var hint := Label.new()
	hint.text = "Klik = obléct / sundat   ·   Najetí = popis   ·   I / Tab / Esc = zavřít"
	hint.add_theme_color_override("font_color", Color(0.6, 0.68, 0.85))
	hint.add_theme_font_size_override("font_size", 13)
	root.add_child(hint)


func _fit() -> void:
	size = get_viewport().get_visible_rect().size


func _header() -> Control:
	var h := HBoxContainer.new()
	var t := Label.new()
	t.text = "INVENTÁŘ"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var coin := ColorRect.new()
	coin.color = Color(0.95, 0.78, 0.25)
	coin.custom_minimum_size = Vector2(18, 18)
	h.add_child(coin)
	var g := Label.new()
	g.text = "  %d" % inv.gold
	g.add_theme_font_size_override("font_size", 22)
	g.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	h.add_child(g)
	return h


func _left() -> Control:
	var H := inv.get_node("/root/Hero")
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.add_theme_constant_override("separation", 10)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sb(Color(0.1, 0.11, 0.22), Color(0.3, 0.33, 0.55), 2, 8))
	v.add_child(pc)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	pc.add_child(hb)
	var lc := VBoxContainer.new()
	lc.add_theme_constant_override("separation", 6)
	for s in ["helma", "telo", "rukavice"]:
		lc.add_child(_equip_slot(s))
	hb.add_child(lc)
	hb.add_child(_portrait())
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 6)
	for s in ["kalhoty", "boty", "zbran"]:
		rc.add_child(_equip_slot(s))
	hb.add_child(rc)
	# statistiky
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", _sb(Color(0.1, 0.11, 0.22), Color(0.3, 0.33, 0.55), 2, 8))
	v.add_child(sp)
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	var nm := Label.new()
	if H.class_id != "":
		nm.text = "%s  ·  úroveň %d" % [H.cls().name, H.level]
	else:
		nm.text = "Hrdina"
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", GOLD)
	sv.add_child(nm)
	if H.class_id != "":
		sv.add_child(_xp_bar(H))
		var gr := GridContainer.new()
		gr.columns = 2
		gr.add_theme_constant_override("h_separation", 28)
		sv.add_child(gr)
		for e in [["Život", H.max_hp(), H.bonus("hp")], ["Mana", H.max_sp(), H.bonus("sp")], ["Útok", H.atk(), H.bonus("atk")], ["Obrana", H.defense(), H.bonus("def")], ["Rychlost", H.spd(), 0]]:
			var l := RichTextLabel.new()
			l.bbcode_enabled = true
			l.fit_content = true
			l.scroll_active = false
			l.custom_minimum_size = Vector2(160, 0)
			l.text = "%s  [b]%d[/b]%s" % [e[0], e[1], "  [color=#7fe07f](+%d)[/color]" % e[2] if e[2] > 0 else ""]
			gr.add_child(l)
		if H.points > 0:
			var pl := Label.new()
			pl.text = "Volné body: %d" % H.points
			pl.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
			sv.add_child(pl)
			var sr := HBoxContainer.new()
			sv.add_child(sr)
			for s in inv.get_node("/root/GameData").stat_names:
				var b := Button.new()
				b.text = "%s %d +" % [inv.get_node("/root/GameData").stat_names[s], H.stat(s)]
				b.pressed.connect(func():
					H.spend(s)
					build(inv))
				sr.add_child(b)
	return v


func _xp_bar(H: Node) -> Control:
	var pb := ProgressBar.new()
	pb.max_value = maxf(H.xp_next(), 1)
	pb.value = H.xp
	pb.custom_minimum_size = Vector2(0, 16)
	pb.show_percentage = false
	pb.add_theme_stylebox_override("background", _sb(Color(0.04, 0.04, 0.1), Color(0.3, 0.33, 0.55), 1, 4))
	pb.add_theme_stylebox_override("fill", _sb(Color(0.35, 0.55, 1.0), Color(0.35, 0.55, 1.0), 0, 4))
	var l := Label.new()
	l.text = "XP %d / %d" % [H.xp, H.xp_next()]
	l.add_theme_font_size_override("font_size", 11)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb.add_child(l)
	return pb


func _portrait() -> Control:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(170, 270)
	var hs: Dictionary = HeroSprite3D.sheet("Idle", "S", inv.equip)
	if not hs.is_empty():
		var at := AtlasTexture.new()
		at.atlas = hs.tex
		at.region = Rect2(0, 0, hs.w, hs.h)
		var tr := TextureRect.new()
		tr.texture = at
		tr.custom_minimum_size = Vector2(170, 260)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cc.add_child(tr)
	return cc


func _equip_slot(slot: String) -> Control:
	var id = inv.equip.get(slot)
	var b := _slot_button(id if id != null else "", 0, id != null, slot)
	b.pressed.connect(func():
		if inv.equip.get(slot) != null:
			inv.equip[slot] = null
			inv.changed.emit()
			build(inv))
	return b


func _slot_button(id: String, count: int, equipped: bool, slot_hint := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 72)
	b.focus_mode = Control.FOCUS_ALL
	var it: Dictionary = inv.ITEMS.get(id, {})
	var col := Color(0.3, 0.33, 0.55)
	if id != "":
		col = rarity(it)
	var normal := _sb(Color(0.05, 0.06, 0.13), col if id != "" else Color(0.22, 0.25, 0.42), 2, 6)
	var hover := _sb(Color(0.12, 0.14, 0.28), GOLD, 3, 6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", normal)
	if id != "":
		var tr := TextureRect.new()
		tr.texture = ItemIcons.get_icon(id, it)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 6
		tr.offset_top = 6
		tr.offset_right = -6
		tr.offset_bottom = -6
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
	elif slot_hint != "":
		var l := Label.new()
		l.text = inv.SLOT_NAMES[slot_hint]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(0.4, 0.45, 0.65))
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
	if count > 1:
		var q := Label.new()
		q.text = "%d" % count
		q.add_theme_font_size_override("font_size", 14)
		q.add_theme_color_override("font_color", Color(1, 1, 1))
		q.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		q.add_theme_constant_override("outline_size", 4)
		q.position = Vector2(48, 50)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
	if equipped and slot_hint == "":
		var e := Label.new()
		e.text = "E"
		e.add_theme_font_size_override("font_size", 12)
		e.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		e.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		e.add_theme_constant_override("outline_size", 4)
		e.position = Vector2(5, 3)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(e)
	if slot_hint != "" and id != "":
		var dura: float = inv.dura_of(slot_hint)
		if dura < 100.0:
			var bar := ColorRect.new()
			bar.color = Color(0.3, 0.9, 0.3) if dura >= 60.0 else (Color(0.95, 0.75, 0.2) if dura >= 30.0 else Color(0.95, 0.25, 0.2))
			bar.position = Vector2(5, 66)
			bar.size = Vector2(62.0 * dura / 100.0, 3)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(bar)
	if id != "":
		b.mouse_entered.connect(func(): _show(id, slot_hint != ""))
		b.focus_entered.connect(func(): _show(id, slot_hint != ""))
	return b


func _right() -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for f in FILTERS:
		var b := Button.new()
		b.text = f[0]
		b.toggle_mode = true
		b.button_pressed = (filter == f[1])
		var on := _sb(Color(0.25, 0.2, 0.08), GOLD, 2, 5)
		var off := _sb(Color(0.08, 0.09, 0.18), Color(0.3, 0.33, 0.55), 2, 5)
		b.add_theme_stylebox_override("normal", off)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover", on)
		b.add_theme_stylebox_override("focus", on)
		var fv: String = f[1]
		b.pressed.connect(func():
			filter = fv
			build(inv))
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = _cols
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	sc.add_child(g)
	var ids: Array = []
	for id in inv.bag:
		if int(inv.bag[id]) <= 0 or not inv.ITEMS.has(id):
			continue
		var cat: String = str(inv.ITEMS[id].get("category", ""))
		var ok := filter == ""
		if filter == "x":
			ok = not (cat.begins_with("Zbraně") or cat.begins_with("Brnění") or cat.begins_with("Spotřební") or cat.begins_with("Suroviny"))
		elif filter != "":
			ok = cat.begins_with(filter)
		if ok:
			ids.append(id)
	ids.sort_custom(func(a, b): return str(inv.ITEMS[a].category) + str(inv.ITEMS[a].name) < str(inv.ITEMS[b].category) + str(inv.ITEMS[b].name))
	var shown := 0
	for id in ids:
		var it: Dictionary = inv.ITEMS[id]
		var on: bool = it.get("slot", "") != "" and inv.equip.get(it.slot) == id
		var b := _slot_button(id, int(inv.bag[id]), on)
		b.pressed.connect(func():
			if it.get("slot", "") != "":
				inv.toggle_equip(id)
				build(inv)
			else:
				_show(id, false))
		g.add_child(b)
		shown += 1
	for i in maxi(0, _cols * 5 - shown):
		g.add_child(_slot_button("", 0, false))
	var dp := PanelContainer.new()
	dp.custom_minimum_size = Vector2(0, 150)
	dp.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.09, 0.19), Color(0.3, 0.33, 0.55), 2, 8))
	v.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	_title = Label.new()
	_title.text = "Vyber předmět"
	_title.add_theme_font_size_override("font_size", 20)
	dv.add_child(_title)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.scroll_active = false
	dv.add_child(_detail)
	return v


func _show(id: String, equipped_now: bool) -> void:
	var it: Dictionary = inv.ITEMS.get(id, {})
	if _title == null or _detail == null:
		return
	_title.text = str(it.get("name", id))
	_title.add_theme_color_override("font_color", rarity(it))
	var t := "[color=#8a93b8]%s[/color]\n" % str(it.get("category", "")).replace("/", " – ")
	var slot: String = str(it.get("slot", ""))
	var cur = inv.equip.get(slot) if slot != "" else null
	for k in STAT_NAMES:
		var v := int(it.get(k, 0))
		if k == "atk" and slot == "zbran":
			v += int(inv.wlevel.get(id, 0)) * 3
		var old := 0
		if cur != null and cur != id and inv.ITEMS.has(cur):
			old = int(inv.ITEMS[cur].get(k, 0)) + (int(inv.wlevel.get(cur, 0)) * 3 if (k == "atk" and slot == "zbran") else 0)
		if v == 0 and old == 0:
			continue
		var d := ""
		if slot != "" and cur != id and not equipped_now:
			var diff := v - old
			if diff > 0:
				d = "  [color=#7fe07f](+%d)[/color]" % diff
			elif diff < 0:
				d = "  [color=#ff7f7f](%d)[/color]" % diff
		t += "%s [b]%d[/b]%s    " % [STAT_NAMES[k], v, d]
	var use: Dictionary = it.get("use", {})
	if use.has("heal"):
		t += "Léčí [b]%d[/b] ŽP    " % int(use.heal)
	if use.has("sp"):
		t += "Obnoví [b]%d[/b] SP    " % int(use.sp)
	if int(inv.wlevel.get(id, 0)) > 0:
		t += "\n[color=#e0c060]Vylepšení +%d[/color]" % int(inv.wlevel[id])
	t += "\n[color=#c0c8e0]%s[/color]" % str(it.get("desc", ""))
	if int(it.get("price", 0)) > 0:
		t += "\n[color=#8a93b8]Cena: %d zl.[/color]" % int(it.price)
	_detail.text = t
