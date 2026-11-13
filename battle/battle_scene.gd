class_name BattleScene
extends Node3D
## Tahový souboj jako Octopath Traveler: nepřátelé vlevo, hrdinové vpravo.
## Menu: Útok / Dovednost / Obrana / Útěk. Ovládání: šipky + Enter/E, Esc = zpět.

signal _cmd_chosen(cmd: String)
signal _target_chosen(unit: BattleUnit)

const HERO_X := 4.5
const ENEMY_X := -4.5

var party: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var autoplay := false ## test: hrdinové hrají sami
var round_no := 0

var _cam: HD2DCamera
var _center: Node3D
var _cmd_panel: PanelContainer
var _cmd_box: VBoxContainer
var _party_box: VBoxContainer
var _order_box: HBoxContainer
var _banner: Label
var _banner_panel: PanelContainer
var _rows := {}
var _cursor: Label3D
var _mode := ""
var _target_list: Array[BattleUnit] = []
var _target_idx := 0
var _t := 0.0
var _crit := false


func _ready() -> void:
	var bm := get_node_or_null("/root/BattleManager")
	if bm and not bm.party.is_empty():
		party = bm.party
		enemies = bm.enemies
	else:
		party = BattleUnit.default_party()
		enemies = BattleUnit.default_enemies()
	_build_world()
	_build_ui()
	await get_tree().process_frame
	_run()


func _process(dt: float) -> void:
	_t += dt
	if _cam:
		_cam.yaw = sin(_t * 0.25) * 1.6
	for u in party + enemies:
		if u.sprite and u.alive():
			u.sprite.position.y = _base_y(u) + sin(_t * 2.2 + u.spd) * 0.025
	if _cursor and _cursor.visible and _mode == "target" and not _target_list.is_empty():
		var tu := _target_list[_target_idx]
		_cursor.global_position = tu.node.global_position + Vector3(0, _height(tu) + 0.9 + sin(_t * 6.0) * 0.1, 0)


# ---------------------------------------------------------------- svět
func _height(u: BattleUnit) -> float:
	return (u.texture.get_height() if u.texture else 64.0) / u.ppm


func _base_y(u: BattleUnit) -> float:
	return _height(u) * 0.5


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	_center = Node3D.new()
	_center.position = Vector3(0, 0, 0)
	add_child(_center)
	# podlaha: tráva + hliněná aréna
	_floor(60.0, "res://textures/ground/trava.png", 0.0)
	_floor(11.0, "res://textures/ground/hlina.png", 0.02, true)
	# stromy v pozadí
	var scenes := ["res://props/strom_listnaty.tscn", "res://props/strom_smrk.tscn"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var i := 0
	for x in range(-15, 16, 6):
		for row in 1:
			var ps := load(scenes[(i + row) % 2]) as PackedScene
			if ps:
				var tr := ps.instantiate() as Node3D
				tr.position = Vector3(x + rng.randf_range(-1.5, 1.5), 0, -9.0 - row * 4.0 + rng.randf_range(-1.0, 1.0))
				add_child(tr)
			i += 1
	_cam = HD2DCamera.new()
	_cam.target = _center
	_cam.pitch = 21.0
	_cam.distance = 19.0
	_cam.height_offset = 1.1
	add_child(_cam)
	# jednotky
	_place(party, HERO_X, 1.0)
	_place(enemies, ENEMY_X, -1.0)
	_cursor = Label3D.new()
	_cursor.text = "▼"
	_cursor.font_size = 96
	_cursor.pixel_size = 0.012
	_cursor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cursor.no_depth_test = true
	_cursor.modulate = Color(1, 0.95, 0.5)
	_cursor.outline_size = 16
	_cursor.visible = false
	add_child(_cursor)


func _floor(size: float, tex_path: String, y: float, round_: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	var tex := load(tex_path) as Texture2D
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = Vector3(size, size, 1) if not round_ else Vector3(size * 2.0, size * 2.0, 1)
	m.roughness = 1.0
	if round_:
		var c := CylinderMesh.new()
		c.top_radius = size
		c.bottom_radius = size
		c.height = 0.02
		c.radial_segments = 48
		c.material = m
		mi.mesh = c
		m.uv1_scale = Vector3(0.9, 0.9, 1)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(1, 1, 1)
		m.albedo_color = Color(0.85, 0.8, 0.72)
	else:
		var p := PlaneMesh.new()
		p.size = Vector2(size, size)
		p.material = m
		mi.mesh = p
	mi.position.y = y
	add_child(mi)


func _place(list: Array[BattleUnit], base_x: float, dir: float) -> void:
	var n := list.size()
	for i in n:
		var u := list[i]
		var root := Node3D.new()
		var z := (i - (n - 1) / 2.0) * 2.6
		root.position = Vector3(base_x + dir * -0.0 + (i % 2) * 0.9 * (1.0 if u.is_hero else -1.0), 0, z)
		var tex := u.texture if u.texture else HD2DSprite.placeholder(u.color)
		var sp := HD2DSprite.make(tex, u.hframes)
		sp.pixel_size = 1.0 / u.ppm
		sp.position.y = tex.get_height() * 0.5 / u.ppm
		if u.ppm > 100.0:
			sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.flip_h = (u.is_hero == u.faces_right)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(sp)
		root.add_child(HD2DSprite.blob_shadow())
		u.node = root
		u.sprite = sp
		add_child(root)
		if not u.is_hero:
			var lb := Label3D.new()
			lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lb.font_size = 36
			lb.pixel_size = 0.01
			lb.outline_size = 12
			lb.no_depth_test = true
			lb.position = Vector3(0, _height(u) + 0.35, 0)
			root.add_child(lb)
			lb.add_child(_bar_quad(Color(0, 0, 0, 1), 0.96, 0.14, "Back", -0.001))
			lb.add_child(_bar_quad(Color(0.9, 0.25, 0.25), 0.9, 0.09, "Fill", 0.001))
			u.label = lb
			_update_label(u)


func _update_label(u: BattleUnit) -> void:
	if u.label == null:
		return
	u.label.text = u.unit_name
	var fill := u.label.get_node_or_null("Fill") as MeshInstance3D
	if fill:
		var r := clampf(float(u.hp) / u.max_hp, 0.0, 1.0)
		fill.scale.x = maxf(r, 0.001)
		fill.position.x = -(1.0 - r) * 0.5 * 0.9


func _bar_quad(col: Color, w: float, h: float, nm: String, z: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.no_depth_test = true
	m.render_priority = 10
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.name = nm
	mi.position = Vector3(0, -0.22, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- UI
func _style(bg: Color, border: Color = Color(0.85, 0.9, 1.0, 0.9)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.04, 0.07, 0.2, 0.88)))
	return p


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	# dole: menu vlevo, družina vpravo
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -270
	bottom.offset_bottom = -30
	bottom.alignment = BoxContainer.ALIGNMENT_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_cmd_panel = _panel()
	_cmd_panel.custom_minimum_size = Vector2(380, 0)
	_cmd_panel.visible = false
	bottom.add_child(_cmd_panel)
	_cmd_box = VBoxContainer.new()
	_cmd_panel.add_child(_cmd_box)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sp)
	var pp := _panel()
	pp.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(pp)
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 8)
	pp.add_child(_party_box)
	for u in party:
		_add_party_row(u)
	# nahoře: pořadí tahů
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 40
	top.offset_right = -40
	top.offset_top = 30
	top.offset_bottom = 110
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_banner_panel = _panel()
	_banner_panel.visible = false
	top.add_child(_banner_panel)
	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 30)
	_banner_panel.add_child(_banner)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp2)
	_order_box = HBoxContainer.new()
	_order_box.add_theme_constant_override("separation", 6)
	top.add_child(_order_box)


func _add_party_row(u: BattleUnit) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var nm := Label.new()
	nm.text = u.unit_name
	nm.custom_minimum_size = Vector2(170, 0)
	nm.add_theme_font_size_override("font_size", 28)
	row.add_child(nm)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(380, 0)
	vb.add_theme_constant_override("separation", 2)
	var hp := _bar(Color(0.35, 0.85, 0.45))
	var spb := _bar(Color(0.4, 0.65, 1.0))
	var hl := Label.new()
	hl.add_theme_font_size_override("font_size", 22)
	vb.add_child(hl)
	vb.add_child(hp)
	vb.add_child(spb)
	row.add_child(vb)
	_party_box.add_child(row)
	_rows[u] = {"name": nm, "hp": hp, "sp": spb, "lbl": hl}
	_update_row(u)


func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	return b


func _update_row(u: BattleUnit) -> void:
	if not _rows.has(u):
		return
	var r: Dictionary = _rows[u]
	(r["hp"] as ProgressBar).max_value = u.max_hp
	(r["hp"] as ProgressBar).value = u.hp
	(r["sp"] as ProgressBar).max_value = u.max_sp
	(r["sp"] as ProgressBar).value = u.sp
	(r["lbl"] as Label).text = "HP %d/%d    SP %d/%d" % [u.hp, u.max_hp, u.sp, u.max_sp]
	(r["name"] as Label).modulate = Color(1, 1, 1) if u.alive() else Color(0.6, 0.3, 0.3)


func _update_order(order: Array, current: BattleUnit) -> void:
	for c in _order_box.get_children():
		c.queue_free()
	var shown := 0
	var list: Array = order.duplicate()
	if current != null and list.has(current):
		list = list.slice(list.find(current))
	# další kolo (přibližně stejné pořadí)
	list.append_array(_turn_order())
	for u: BattleUnit in list:
		if shown >= 9:
			break
		if not u.alive():
			continue
		var p := PanelContainer.new()
		var big := (shown == 0)
		var col := Color(0.15, 0.3, 0.7, 0.95) if u.is_hero else Color(0.6, 0.15, 0.15, 0.95)
		p.add_theme_stylebox_override("panel", _style(col, Color(1, 0.95, 0.6) if big else Color(0.8, 0.85, 1, 0.6)))
		p.custom_minimum_size = Vector2(58 if big else 46, 58 if big else 46)
		var l := Label.new()
		l.text = u.unit_name.substr(0, 1)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26 if big else 20)
		p.add_child(l)
		_order_box.add_child(p)
		shown += 1


func _say(text: String, secs: float = 0.0) -> void:
	_banner.text = text
	_banner_panel.visible = text != ""
	if secs > 0.0:
		await get_tree().create_timer(secs).timeout


# ---------------------------------------------------------------- průběh
func _turn_order() -> Array:
	var all: Array = []
	for u in party + enemies:
		if u.alive():
			all.append(u)
	all.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.spd > b.spd)
	return all


func _state() -> int:
	var heroes := false
	var foes := false
	for u in party:
		heroes = heroes or u.alive()
	for u in enemies:
		foes = foes or u.alive()
	if not foes:
		return 1
	if not heroes:
		return -1
	return 0


func _run() -> void:
	# úvod: nepřátelé "přiběhnou"
	for u in enemies:
		var target := u.node.position
		u.node.position.x -= 9.0
		create_tween().tween_property(u.node, "position", target, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await _say("Objevili se nepřátelé!", 1.2)
	await _say("")
	while _state() == 0:
		round_no += 1
		var order := _turn_order()
		for u: BattleUnit in order:
			if _state() != 0:
				break
			if not u.alive():
				continue
			_update_order(order, u)
			u.defending = false
			if u.is_hero:
				await _hero_turn(u)
			else:
				await _enemy_turn(u)
			if _flee_done:
				return
	var st := _state()
	_cmd_panel.visible = false
	_update_order([], null)
	if st == 1:
		await _say("Vítězství!", 0.4)
		await _wait_accept()
		_end(true)
	else:
		await _say("Porážka...", 0.4)
		await _wait_accept()
		for u in party:
			u.hp = u.max_hp
		_end(false)


var _flee_done := false


func _end(victory: bool) -> void:
	var bm := get_node_or_null("/root/BattleManager")
	if bm and bm.active:
		bm.finish(victory)
	else:
		print("BATTLE END victory=", victory)


func _wait_accept() -> void:
	if autoplay:
		await get_tree().create_timer(0.3).timeout
		return
	_mode = "accept"
	await _target_chosen
	_mode = ""


func _unhandled_input(ev: InputEvent) -> void:
	if _mode == "accept" and ev.is_action_pressed("ui_accept"):
		_target_chosen.emit(null)
		return
	if _mode == "menu" and ev.is_action_pressed("ui_cancel"):
		_cmd_chosen.emit("back")
		return
	if _mode != "target":
		return
	if ev.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_target_chosen.emit(_target_list[_target_idx])
	elif ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_target_chosen.emit(null)
	elif ev.is_action_pressed("ui_right") or ev.is_action_pressed("ui_down"):
		_target_idx = (_target_idx + 1) % _target_list.size()
	elif ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_up"):
		_target_idx = (_target_idx - 1 + _target_list.size()) % _target_list.size()


func _hero_turn(u: BattleUnit) -> void:
	_say("%s je na tahu" % u.unit_name)
	_highlight(u, true)
	while true:
		var cmd := await _menu(["Útok", "Dovednost", "Obrana", "Útěk"], ["attack", "skill", "defend", "flee"])
		if cmd == "attack":
			var t := await _pick_target(_alive(enemies))
			if t == null:
				continue
			await _perform(u, [t], 1.0, 0, "%s útočí" % u.unit_name)
			break
		elif cmd == "skill":
			if u.skills.is_empty():
				continue
			var names: Array = []
			var keys: Array = []
			for i in u.skills.size():
				var s: Dictionary = u.skills[i]
				names.append("%s  (SP %d)" % [s["name"], s["cost"]])
				keys.append(str(i))
			var k := await _menu(names, keys, true)
			if k == "back":
				continue
			var sk: Dictionary = u.skills[int(k)]
			if u.sp < int(sk["cost"]):
				await _say("Nedostatek SP!", 0.8)
				continue
			var tg: Array[BattleUnit] = []
			if sk.has("heal"):
				var ally := await _pick_target(_alive(party))
				if ally == null:
					continue
				tg = [ally]
			elif sk.get("all", false):
				tg = _alive(enemies)
			else:
				var e := await _pick_target(_alive(enemies))
				if e == null:
					continue
				tg = [e]
			u.sp -= int(sk["cost"])
			_update_row(u)
			await _perform(u, tg, float(sk.get("power", 1.0)), int(sk.get("heal", 0)), "%s: %s" % [u.unit_name, sk["name"]])
			break
		elif cmd == "defend":
			u.defending = true
			await _say("%s se brání" % u.unit_name, 0.7)
			break
		elif cmd == "flee":
			if randf() < 0.7:
				await _say("Útěk se podařil!", 0.8)
				_flee_done = true
				_cmd_panel.visible = false
				_end(true)
				return
			await _say("Útěk se nezdařil!", 0.8)
			break
	_highlight(u, false)
	_cmd_panel.visible = false
	_say("")


func _enemy_turn(u: BattleUnit) -> void:
	var targets := _alive(party)
	if targets.is_empty():
		return
	var t: BattleUnit = targets[randi() % targets.size()]
	await get_tree().create_timer(0.25).timeout
	await _perform(u, [t], 1.0, 0, "%s útočí" % u.unit_name)


func _alive(list: Array[BattleUnit]) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for u in list:
		if u.alive():
			out.append(u)
	return out


func _highlight(u: BattleUnit, on: bool) -> void:
	if u.node == null:
		return
	var tw := create_tween()
	tw.tween_property(u.node, "position:x", u.node.position.x + (-0.5 if on else 0.5), 0.15)


func _menu(labels: Array, keys: Array, can_back: bool = false) -> String:
	for c in _cmd_box.get_children():
		_cmd_box.remove_child(c)
		c.queue_free()
	var first: Button
	for i in labels.size():
		var b := _menu_button(str(labels[i]))
		b.pressed.connect(func() -> void: _cmd_chosen.emit(str(keys[i])))
		_cmd_box.add_child(b)
		if first == null:
			first = b
	_cmd_panel.visible = true
	_mode = "menu"
	if first:
		first.grab_focus()
	if autoplay:
		var pick: String = str(keys[0])
		if keys.has("skill") and round_no == 2:
			pick = "skill"
		elif keys.has("skill") and round_no == 3:
			pick = "defend"
		get_tree().create_timer(0.35).timeout.connect(func() -> void: _cmd_chosen.emit(pick))
	var res: String = await _cmd_chosen
	_mode = ""
	return res


func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var f := StyleBoxFlat.new()
	f.bg_color = Color(0.35, 0.5, 0.95, 0.45)
	f.set_corner_radius_all(6)
	f.content_margin_left = 10
	f.content_margin_top = 4
	f.content_margin_bottom = 4
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_stylebox_override("hover", f)
	b.add_theme_stylebox_override("pressed", f)
	return b


func _pick_target(list: Array[BattleUnit]) -> BattleUnit:
	if list.is_empty():
		return null
	_cmd_panel.visible = false
	_target_list = list
	_target_idx = 0
	_cursor.global_position = list[0].node.global_position + Vector3(0, _height(list[0]) + 0.9, 0)
	_cursor.visible = true
	await get_tree().process_frame
	_mode = "target"
	var res: BattleUnit
	if autoplay:
		await get_tree().create_timer(0.4).timeout
		res = list[0]
	else:
		res = await _target_chosen
	_mode = ""
	_cursor.visible = false
	return res


# ---------------------------------------------------------------- akce a animace
func _roll(a: BattleUnit, d: BattleUnit, power: float) -> int:
	var base := a.atk * power - d.defense * 0.5
	if d.defending:
		base *= 0.5
	_crit = randf() < 0.08
	if _crit:
		base *= 1.5
	return maxi(1, int(round(base * randf_range(0.9, 1.1))))


func _perform(a: BattleUnit, targets: Array[BattleUnit], power: float, heal: int, text: String) -> void:
	await _say(text)
	var home := a.node.position
	var dir := -1.0 if a.is_hero else 1.0 # hrdina běží doleva, nepřítel doprava
	var multi := targets.size() > 1
	if heal == 0 and not multi:
		var dest := targets[0].node.position + Vector3(-dir * 1.6, 0, 0)
		var tw := create_tween()
		tw.tween_property(a.node, "position", dest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	else:
		var tw2 := create_tween()
		tw2.tween_property(a.sprite, "position:y", _base_y(a) + 0.7, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw2.finished
	for t in targets:
		if heal > 0:
			var h := mini(heal, t.max_hp - t.hp)
			t.hp += h
			_popup(t, "+%d" % h, Color(0.4, 1.0, 0.5))
			_flash(t, Color(0.6, 1.4, 0.8))
		else:
			var dmg := _roll(a, t, power)
			t.hp = maxi(t.hp - dmg, 0)
			_popup(t, str(dmg) + ("!" if _crit else ""), Color(1, 0.85, 0.3) if _crit else Color(1, 1, 1))
			_flash(t, Color(2.6, 2.6, 2.6))
			_shake(t)
		_update_row(t)
		_update_label(t)
	await get_tree().create_timer(0.4).timeout
	var tw3 := create_tween()
	if heal == 0 and not multi:
		tw3.tween_property(a.node, "position", home, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw3.tween_property(a.sprite, "position:y", _base_y(a), 0.18)
	await tw3.finished
	for t in targets:
		if not t.alive():
			_kill(t)
	await get_tree().create_timer(0.25).timeout


func _flash(u: BattleUnit, col: Color) -> void:
	u.sprite.modulate = col
	create_tween().tween_property(u.sprite, "modulate", Color(1, 1, 1), 0.3)


func _shake(u: BattleUnit) -> void:
	var x0 := u.node.position.x
	var tw := create_tween()
	for i in 4:
		tw.tween_property(u.node, "position:x", x0 + (0.14 if i % 2 == 0 else -0.14), 0.04)
	tw.tween_property(u.node, "position:x", x0, 0.04)


func _kill(u: BattleUnit) -> void:
	if u.is_hero:
		u.sprite.modulate = Color(0.45, 0.45, 0.5)
		create_tween().tween_property(u.sprite, "rotation_degrees:z", 80.0, 0.3)
	else:
		if u.label:
			u.label.visible = false
		var tw := create_tween()
		tw.tween_property(u.sprite, "modulate", Color(3, 3, 3, 0), 0.45)


func _popup(u: BattleUnit, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.012
	l.outline_size = 18
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	l.global_position = u.node.global_position + Vector3(0, _height(u) + 0.3, 0.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.1, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)
