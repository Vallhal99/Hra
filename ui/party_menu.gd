class_name PartyMenu
extends RefCounted
## Menu družiny (klávesa C nebo z pauzy): Družina, Dovednosti, Výbava, Nastavení.

static func open(tree: SceneTree, tab := 0) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 95
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	cl.name = "PartyMenu"
	tree.root.add_child(cl)
	tree.paused = true
	_build(tree, cl, tab)


const GOLD := Color(0.93, 0.78, 0.42)
const INK := Color(0.05, 0.06, 0.11)


static func _sbox(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 6, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


## Jednotný vzhled menu: tmavé sklo, zlaté akcenty, zaoblené karty
static func _theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", _sbox(Color(0.07, 0.08, 0.15, 0.92), Color(0.93, 0.78, 0.42, 0.55), 1, 8, 14))
	t.set_stylebox("panel", "TabContainer", _sbox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 6))
	var tab_n := _sbox(Color(0.1, 0.11, 0.2, 0.7), Color(1, 1, 1, 0.08), 1, 6, 10)
	tab_n.border_width_bottom = 0
	tab_n.corner_radius_bottom_left = 0
	tab_n.corner_radius_bottom_right = 0
	tab_n.content_margin_left = 16
	tab_n.content_margin_right = 16
	var tab_s := _sbox(Color(0.2, 0.17, 0.1, 0.95), GOLD, 2, 6, 10)
	tab_s.border_width_bottom = 0
	tab_s.border_width_top = 3
	tab_s.corner_radius_bottom_left = 0
	tab_s.corner_radius_bottom_right = 0
	tab_s.content_margin_left = 16
	tab_s.content_margin_right = 16
	var tab_h := tab_n.duplicate()
	tab_h.bg_color = Color(0.18, 0.18, 0.3, 0.9)
	t.set_stylebox("tab_unselected", "TabContainer", tab_n)
	t.set_stylebox("tab_selected", "TabContainer", tab_s)
	t.set_stylebox("tab_hovered", "TabContainer", tab_h)
	t.set_stylebox("tab_focus", "TabContainer", StyleBoxEmpty.new())
	t.set_color("font_selected_color", "TabContainer", Color(1.0, 0.92, 0.6))
	t.set_color("font_unselected_color", "TabContainer", Color(0.7, 0.74, 0.88))
	t.set_color("font_hovered_color", "TabContainer", Color(1, 1, 1))
	t.set_font_size("font_size", "TabContainer", 19)
	t.set_constant("h_separation", "TabContainer", 4)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var b := _sbox(Color(0.13, 0.14, 0.26, 0.9), Color(1, 1, 1, 0.14), 1, 6, 8)
		match st:
			"hover":
				b.bg_color = Color(0.22, 0.2, 0.12, 0.95)
				b.border_color = GOLD
			"pressed":
				b.bg_color = Color(0.3, 0.24, 0.1, 1.0)
				b.border_color = GOLD
			"focus":
				b.bg_color = Color(0.2, 0.19, 0.14, 0.95)
				b.border_color = GOLD
				b.set_border_width_all(2)
			"disabled":
				b.bg_color = Color(0.08, 0.08, 0.12, 0.7)
				b.border_color = Color(1, 1, 1, 0.05)
		t.set_stylebox(st, "Button", b)
		t.set_stylebox(st, "OptionButton", b)
	t.set_color("font_color", "Button", Color(0.9, 0.92, 1.0))
	t.set_color("font_hover_color", "Button", Color(1.0, 0.93, 0.62))
	t.set_color("font_focus_color", "Button", Color(1.0, 0.93, 0.62))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.6))
	t.set_font_size("font_size", "Button", 18)
	t.set_font_size("font_size", "OptionButton", 17)
	t.set_stylebox("background", "ProgressBar", _sbox(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12), 1, 4, 0))
	t.set_stylebox("fill", "ProgressBar", _sbox(GOLD, Color(0, 0, 0, 0), 0, 4, 0))
	var gr := _sbox(Color(0.93, 0.78, 0.42, 0.5), Color(0, 0, 0, 0), 0, 4, 0)
	t.set_stylebox("grabber", "VScrollBar", gr)
	t.set_stylebox("grabber_highlight", "VScrollBar", gr)
	t.set_stylebox("grabber_pressed", "VScrollBar", gr)
	t.set_stylebox("scroll", "VScrollBar", _sbox(Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0, 4, 0))
	return t


static func _gauge(col: Color, v: float, cap: float, w := 130) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0
	pb.max_value = cap
	pb.value = clampf(v, 0.0, cap)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, 10)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("fill", _sbox(col, Color(0, 0, 0, 0), 0, 4, 0))
	return pb


## portrét z animovaného spritu (hlava a ramena)
static func _portrait(m: Dictionary) -> Control:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(110, 110)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = null
	var rect := Rect2(0, 0, 148, 130)
	var P: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Party")
	if m.get("hero", false):
		var inv: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Inventory")
		var sh: Dictionary = load("res://hero/hero_sprite.gd").sheet("Idle", "S", inv.equip)
		tex = sh.tex
		rect = Rect2(0, 0, 148, 130)
	else:
		var d: Dictionary = P.DEFS.get(m.get("id", ""), {})
		if d.has("char") and AnimActor.has_char(d.char):
			var mt: Dictionary = AnimActor.meta(d.char)["Idle"]
			tex = AnimActor.tex(d.char, "Idle")
			rect = Rect2(0, 0, mt.w, mt.h * 0.55)
		elif d.has("tex"):
			tex = load(d.tex)
			rect = Rect2(0, 0, tex.get_width(), tex.get_height() * 0.55)
	if tex != null:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = rect
		tr.texture = at
	var fr := PanelContainer.new()
	fr.add_theme_stylebox_override("panel", _sbox(Color(0.02, 0.03, 0.07, 0.9), GOLD, 2, 8, 2))
	fr.add_child(tr)
	return fr


static func _panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _sbox(Color(0.09, 0.1, 0.19, 0.9), Color(0.93, 0.78, 0.42, 0.45), 1, 8, 14))
	return pc


static func _lbl(t: String, size := 20, col := Color(0.92, 0.93, 1.0), wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
	return l


static func _build(tree: SceneTree, cl: CanvasLayer, tab: int) -> void:
	for c in cl.get_children():
		c.queue_free()
	# pozadí: ztmavení + vinětace
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(dim)
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.9)
	var gg := Gradient.new()
	gg.colors = PackedColorArray([Color(0.25, 0.2, 0.1, 0.0), Color(0.0, 0.0, 0.0, 0.65)])
	gt.gradient = gg
	var vig := TextureRect.new()
	vig.texture = gt
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cl.add_child(vig)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 90)
	root.add_theme_constant_override("margin_top", 36)
	root.add_theme_constant_override("margin_bottom", 30)
	root.theme = _theme()
	cl.add_child(root)
	var pc := _panel()
	root.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	pc.add_child(vb)
	# hlavička: název, zlato, čas
	var head := HBoxContainer.new()
	vb.add_child(head)
	var ttl := _lbl("◆  MENU", 30, GOLD)
	head.add_child(ttl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var inv: Node = tree.root.get_node("Inventory")
	var at: Node = tree.root.get_node_or_null("Atmo")
	var info := "◈ %d zlata" % int(inv.gold)
	if at:
		info += "      %s  ·  Den %d" % [at.clock_text(), at.day]
	head.add_child(_lbl(info, 20, Color(0.95, 0.9, 0.7)))
	var line := ColorRect.new()
	line.color = Color(0.93, 0.78, 0.42, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	vb.add_child(line)
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tc)
	tc.add_child(_tab_party(tree, cl))
	tc.add_child(_tab_skills())
	tc.add_child(_tab_gear(tree, cl))
	tc.add_child(_tab_cook(tree, cl, tab))
	tc.add_child(_tab_bestiary(tree))
	tc.add_child(_tab_chars())
	tc.add_child(_tab_settings(tree, cl))
	for i in 7:
		tc.set_tab_title(i, ["Družina", "Dovednosti", "Výbava", "Vaření", "Bestiář", "Postavy", "Nastavení"][i])
	tc.current_tab = tab
	var close := Button.new()
	close.text = "Zavřít  (Esc)"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func():
		cl.queue_free()
		tree.paused = false)
	vb.add_child(close)
	close.grab_focus.call_deferred()


static func _members() -> Array:
	var out: Array = []
	var H: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Hero")
	var P: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Party")
	if H.class_id != "":
		out.append({"name": "Hrdina", "cls": H.class_id, "lv": H.level, "sub": H.sub, "hero": true,
			"st": [H.max_hp(), H.max_sp(), H.atk(), H.defense(), H.spd()], "xp": H.xp, "need": H.xp_next(), "bio": H.cls().get("desc", "")})
	for id in P.order:
		var s: Dictionary = P.stats(id)
		out.append({"name": P.DEFS[id].name, "cls": P.DEFS[id].cls, "lv": int(P.members[id].level), "sub": str(P.members[id].sub), "id": id,
			"st": [s.hp, s.sp, s.atk, s.def, s.spd], "xp": int(P.members[id].xp), "need": 0, "bio": P.DEFS[id].bio})
	return out


static func _cname(id: String) -> String:
	return str(_gd().class_by_id(id).get("name", id))


static func _tab_party(tree: SceneTree, cl: CanvasLayer) -> Control:
	var sc := ScrollContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_theme_constant_override("separation", 12)
	for m in _members():
		var pc := _panel()
		v.add_child(pc)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		pc.add_child(row)
		row.add_child(_portrait(m))
		var b := VBoxContainer.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("separation", 6)
		row.add_child(b)
		var hd := HBoxContainer.new()
		b.add_child(hd)
		hd.add_child(_lbl(str(m.name), 26, Color(1, 0.9, 0.5)))
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(sp2)
		hd.add_child(_lbl("%s  ·  úr. %d" % [_cname(m.cls), m.lv], 19, Color(0.75, 0.8, 1.0)))
		if int(m.need) > 0:
			var xb := _gauge(Color(0.93, 0.78, 0.42), float(m.xp), float(m.need), 300)
			xb.custom_minimum_size = Vector2(0, 8)
			xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_child(xb)
		var gd := GridContainer.new()
		gd.columns = 5
		gd.add_theme_constant_override("h_separation", 18)
		b.add_child(gd)
		var names := ["ŽP", "SP", "Útok", "Obrana", "Rychlost"]
		var caps := [200.0, 100.0, 60.0, 40.0, 20.0]
		var cols := [Color(0.9, 0.3, 0.32), Color(0.35, 0.6, 1.0), Color(1.0, 0.65, 0.25), Color(0.5, 0.85, 0.5), Color(0.8, 0.5, 1.0)]
		for i in 5:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.add_child(_lbl("%s  %d" % [names[i], int(m.st[i])], 17))
			cell.add_child(_gauge(cols[i], float(m.st[i]), caps[i], 110))
			gd.add_child(cell)
		b.add_child(_lbl(str(m.bio), 16, Color(0.68, 0.73, 0.88), true))
		var hb := HBoxContainer.new()
		b.add_child(hb)
		hb.add_child(_lbl("Podpovolání:", 18))
		var ob := OptionButton.new()
		ob.add_item("— žádné —")
		var ids: Array = []
		for c in _gd().classes:
			if c.id != m.cls:
				ob.add_item(c.name)
				ids.append(c.id)
		var cur := ids.find(m.sub) + 1
		ob.selected = maxi(cur, 0)
		ob.disabled = int(m.lv) < 4
		ob.tooltip_text = "Od úrovně 4: dvě dovednosti navíc z jiného povolání."
		ob.item_selected.connect(func(i: int):
			var nid: String = "" if i == 0 else ids[i - 1]
			if m.get("hero", false):
				tree.root.get_node("Hero").sub = nid
			else:
				tree.root.get_node("Party").members[m.id].sub = nid)
		hb.add_child(ob)
	return _named(sc, "Družina")


static func _named(c: Control, n: String) -> Control:
	c.name = n
	return c


static func _tab_skills() -> Control:
	var sc := ScrollContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for m in _members():
		v.add_child(_lbl("%s (%s)" % [m.name, _cname(m.cls)], 22, Color(1, 0.9, 0.5)))
		var all: Array = Rules.SKILLS.get(m.cls, []).duplicate()
		var unlocked := Rules.skills_for(m.cls, m.sub, m.lv)
		for s in all + (Rules.SKILLS.get(m.sub, []).slice(0, 2) if m.sub != "" else []):
			var ok := unlocked.has(s)
			var el: String = Rules.KIND_NAMES.get(str(s.get("kind", "")), "")
			var t := "%s  •  %d SP  •  %s%s" % [s.name, s.cost, str(s.get("desc", "")), ("  [%s]" % el) if el != "" else ""]
			if not ok:
				t = "🔒 %s (od úrovně %d)" % [s.name, s.lvl]
			v.add_child(_lbl(t, 18, Color(0.9, 0.92, 1.0) if ok else Color(0.5, 0.52, 0.6)))
		var lim: Dictionary = Rules.LIMITS.get(m.cls, {})
		if not lim.is_empty():
			v.add_child(_lbl("LIMIT: %s — ničivý útok na všechny (plní se zásahy)." % lim.name, 18, Color(1.0, 0.8, 0.4)))
		v.add_child(HSeparator.new())
	return _named(sc, "Dovednosti")


static func _tab_gear(tree: SceneTree, cl: CanvasLayer) -> Control:
	var v := VBoxContainer.new()
	v.name = "Výbava"
	var inv: Node = tree.root.get_node("Inventory")
	for s in inv.SLOTS:
		var id = inv.equip.get(s)
		var row := HBoxContainer.new()
		v.add_child(row)
		var nm := _lbl("%s: %s" % [inv.SLOT_NAMES[s], inv.ITEMS[id].name if id != null and inv.ITEMS.has(id) else "—"], 19)
		nm.custom_minimum_size = Vector2(330, 0)
		row.add_child(nm)
		if id != null:
			var pb := ProgressBar.new()
			pb.custom_minimum_size = Vector2(220, 20)
			pb.value = inv.dura_of(s)
			pb.show_percentage = false
			row.add_child(pb)
			var lv: int = inv.dura_level(s)
			row.add_child(_lbl(["v pořádku", "poškozeno", "kriticky poškozeno", "ZNIČENO"][lv], 17, [Color(0.6, 1, 0.7), Color(1, 0.9, 0.4), Color(1, 0.6, 0.3), Color(1, 0.4, 0.4)][lv]))
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Zásahy v boji poškozují brnění. Poškozené kusy dávají méně obrany, zničené odpadnou. Opravit je může kovář (%d zl.)." % inv.repair_cost(), 17, Color(0.7, 0.75, 0.9), true))
	var wt: String = Rules.weapon_type_of(str(inv.equip.get("zbran", "")) if inv.equip.get("zbran") != null else "")
	v.add_child(_lbl("Zbraň: %s — %s" % [Rules.KIND_NAMES.get(wt, wt), Rules.WEAPON_TYPES[wt].desc], 18))
	var ib := Button.new()
	ib.text = "Otevřít inventář"
	ib.pressed.connect(func():
		cl.queue_free()
		tree.paused = false
		tree.root.get_node("Inventory")._toggle())
	v.add_child(ib)
	return v


static func _tab_cook(tree: SceneTree, cl: CanvasLayer, tab: int) -> Control:
	var inv: Node = tree.root.get_node("Inventory")
	var v := VBoxContainer.new()
	v.name = "Vaření"
	var pl := tree.get_first_node_in_group("player") as Node3D
	var fire: bool = Crafting.near_fire(pl)
	v.add_child(_lbl("Vaření u ohniště – suroviny seženeš na lovu, u obchodníků a v lese." if fire else "Nejsi u ohniště. Přistup k táboráku (např. v jeskyni nebo na tábořišti).", 17))
	for r in Crafting.RECIPES:
		var it: Dictionary = inv.ITEMS[r.id]
		var parts := ""
		for k in r.ing:
			parts += "%s %d/%d  " % [inv.ITEMS[k].name, inv.count(k), r.ing[k]]
		var b := Button.new()
		b.text = "%s  (máš ×%d)  –  %s" % [it.name, inv.count(r.id), parts]
		b.tooltip_text = str(it.get("desc", ""))
		b.disabled = not (fire and Crafting.can_cook(r))
		b.pressed.connect(func():
			Crafting.cook(r)
			open(tree, 3))
		v.add_child(b)
		v.add_child(_lbl("    " + str(it.get("desc", "")), 14))
	return v


static func _tab_bestiary(tree: SceneTree) -> Control:
	var B: Node = tree.root.get_node("Bestiary")
	var sc := ScrollContainer.new()
	sc.name = "Bestiář"
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for n in B.INFO:
		var e: Dictionary = B.seen.get(n, {})
		if e.is_empty():
			v.add_child(_lbl("???  (zatím nespatřen)", 18))
			continue
		var t := "%s  –  poražen ×%d, životy %d\n" % [n, e.kills, e.hp]
		t += str(B.INFO[n].desc) + "\nVyskytuje se: " + str(B.INFO[n].where)
		t += "\nSlabiny: " + (", ".join(e.weak) if e.weak.size() > 0 else "neznámé (zaútoč na něj)")
		if e.drops.size() > 0:
			t += "\nKořist: " + ", ".join(e.drops.map(func(d): return str(tree.root.get_node("Inventory").ITEMS[d].name)))
		v.add_child(_lbl(t, 16))
	return sc


static func _tab_chars() -> Control:
	var sc := ScrollContainer.new()
	sc.name = "Postavy"
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for c in Lore.CHARS:
		var t := "%s  –  %s\nCharakter: %s\nŽivot: %s\nCíl: %s" % [c.name, c.role, c.char, c.life, c.goal]
		v.add_child(_lbl(t, 15))
		v.add_child(HSeparator.new())
	return sc


static func _tab_settings(tree: SceneTree, cl: CanvasLayer) -> Control:
	var S: Node = tree.root.get_node("Settings")
	var v := VBoxContainer.new()
	v.name = "Nastavení"
	var h1 := HBoxContainer.new()
	v.add_child(h1)
	h1.add_child(_lbl("Kvalita grafiky:", 19))
	var q := OptionButton.new()
	for n in S.QUALITY_NAMES:
		q.add_item(n)
	q.selected = S.quality
	q.item_selected.connect(func(i: int):
		S.quality = i
		S.apply_global()
		S.save())
	h1.add_child(q)
	var cb := CheckButton.new()
	cb.text = "Celá obrazovka"
	cb.button_pressed = S.fullscreen
	cb.toggled.connect(func(b: bool):
		S.fullscreen = b
		S.apply_global()
		S.save())
	v.add_child(cb)
	var vs := CheckButton.new()
	vs.text = "Vertikální synchronizace"
	vs.button_pressed = S.vsync
	vs.toggled.connect(func(b: bool):
		S.vsync = b
		S.apply_global()
		S.save())
	v.add_child(vs)
	var wf := CheckButton.new()
	wf.text = "Počasí a částice (déšť, listí, světlušky)"
	wf.button_pressed = S.weather_fx
	wf.toggled.connect(func(b: bool):
		S.weather_fx = b
		S.apply_global()
		S.save())
	v.add_child(wf)
	for spec in [["Hlasitost", "volume", 0.0, 1.0], ["Rozlišení vykreslování", "res_scale", 0.5, 1.0]]:
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(_lbl(spec[0] + ":", 19))
		var sl := HSlider.new()
		sl.min_value = spec[2]
		sl.max_value = spec[3]
		sl.step = 0.05
		sl.value = S.get(spec[1])
		sl.custom_minimum_size = Vector2(260, 24)
		sl.value_changed.connect(func(x: float):
			S.set(spec[1], x)
			S.apply_global()
			S.save())
		h.add_child(sl)
	v.add_child(_lbl("Ovládání: WASD/šipky chůze, Shift běh, E/Enter/mezerník mluvit, I inventář, J úkoly, C družina, T položit past, Esc pauza.", 17, Color(0.7, 0.75, 0.9), true))
	return v


static func _gd() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
