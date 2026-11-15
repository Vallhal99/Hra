class_name BattleScene
extends Node3D
## Tahový souboj jako Octopath Traveler: nepřátelé vlevo, hrdinové vpravo.
## Menu: Útok / Dovednost / Obrana / Útěk. Ovládání: šipky + Enter/E, Esc = zpět.

signal _cmd_chosen(cmd: String)
signal _target_chosen(unit: BattleUnit)

const HERO_X := 4.2
const ENEMY_X := -3.2

var party: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var autoplay := false ## test: hrdinové hrají sami
var round_no := 0

var _cam: HD2DCamera
var _center: Node3D
var ui: OTUI
var _pending_boost := 0
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
		if (u.hero_anim or not u.anims.is_empty()) and u.sprite:
			_tick_anim(u, dt)
		elif u.proc and u.sprite and u.alive():
			u.anim_t += dt
			var k := sin(u.anim_t * 2.4 + u.phase)
			u.sprite.scale = Vector3(1.0 - 0.012 * k, 1.0 + 0.026 * k, 1.0)
		if u.sprite and u.alive():
			u.sprite.position.y = _base_y(u) + sin(_t * 2.2 + u.spd) * 0.025
	if _cursor and _cursor.visible and _mode == "target" and not _target_list.is_empty():
		var tu := _target_list[_target_idx]
		_cursor.global_position = tu.node.global_position + Vector3(0, _height(tu) + 0.9 + sin(_t * 6.0) * 0.1, 0)


# ---------------------------------------------------------------- svět
const ANIM_FPS := {"Idle": 6.0, "Swordslash": 12.0, "Castspell": 10.0, "Hurt": 10.0, "Death": 8.0, "Victory": 8.0, "Block": 8.0, "Chargeup": 10.0}


const ANIM_MAP := {"Swordslash": "Attack", "Attackcombo3hit": "Attack", "Castspell": "Attack", "Hurt": "Hurt", "Death": "Death", "Idle": "Idle", "Victory": "Idle"}


func hero_anim(u: BattleUnit, anim: String, loop := true) -> void:
	if u.sprite == null:
		return
	if not u.anims.is_empty():
		var nm: String = ANIM_MAP.get(anim, "Idle")
		if not u.anims.has(nm):
			return
		var d: Dictionary = u.anims[nm]
		u.anim_name = nm
		u.anim_loop = loop
		u.anim_t = 0.0
		u.sprite.texture = d["tex"]
		u.sprite.hframes = d["frames"]
		u.sprite.frame = 0
		u.sprite.position.y = (d["tex"] as Texture2D).get_height() * 0.5 / u.ppm
		return
	if not u.hero_anim:
		return
	var sh: Dictionary = load("res://hero/hero_sprite.gd").sheet(anim, "W", get_node("/root/Inventory").equip)
	if sh.is_empty():
		return
	u.anim_name = anim
	u.anim_loop = loop
	u.anim_t = 0.0
	u.sprite.texture = sh.tex
	u.sprite.hframes = sh.frames
	u.sprite.frame = 0
	u.sprite.position.y = (sh.tex as Texture2D).get_height() * 0.5 / u.ppm


func _tick_anim(u: BattleUnit, dt: float) -> void:
	var fps := float(u.anims[u.anim_name]["fps"]) if u.anims.has(u.anim_name) else float(ANIM_FPS.get(u.anim_name, 10.0))
	u.anim_t += dt * fps
	var n: int = u.sprite.hframes
	var f := int(u.anim_t)
	if f >= n:
		if u.anim_loop:
			f = f % n
		elif u.anim_name == "Death":
			f = n - 1
		else:
			hero_anim(u, "Idle")
			return
	u.sprite.frame = f


func _height(u: BattleUnit) -> float:
	return (u.texture.get_height() if u.texture else 64.0) / u.ppm


func _base_y(u: BattleUnit) -> float:
	return _height(u) * 0.5


func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	_center = Node3D.new()
	_center.position = Vector3(0, 0, 0)
	add_child(_center)
	# podlaha: tráva + hliněná aréna
	_floor(90.0, "res://textures/ground/trava.png", 0.0)
	_floor(7.5, "res://textures/ground/hlina.png", 0.02, true)
	# les v pozadí: husté řady vysokých jehličnatých stromů (rozmazané hloubkou ostrosti)
	var scenes := ["res://props/strom_smrk.tscn", "res://props/strom_smrk.tscn", "res://props/strom_listnaty.tscn", "res://props/strom_smrk.tscn"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for row in 6:
		var zrow := -7.0 - row * 4.2
		var x := -34.0
		while x < 34.0:
			var ps := load(scenes[rng.randi() % scenes.size()]) as PackedScene
			if ps:
				var tr := ps.instantiate() as Node3D
				var sc := rng.randf_range(1.9, 2.8) + row * 0.18
				tr.scale = Vector3.ONE * sc
				tr.position = Vector3(x + rng.randf_range(-1.2, 1.2), 0, zrow + rng.randf_range(-1.5, 1.5))
				add_child(tr)
			x += rng.randf_range(2.4, 3.6)
	# velké stromy po stranách, blízko kamery (silně rozostřené)
	for sx in [-13.5, -11.0, 12.5, 14.5]:
		var ps2 := load("res://props/strom_smrk.tscn") as PackedScene
		if ps2:
			var t2 := ps2.instantiate() as Node3D
			t2.scale = Vector3.ONE * 3.4
			t2.position = Vector3(sx, 0, rng.randf_range(-2.0, 3.0))
			add_child(t2)
	_cam = HD2DCamera.new()
	_cam.target = _center
	_cam.pitch = 9.0
	_cam.distance = 27.0
	_cam.fov = 25.0
	_cam.height_offset = 1.5
	_cam.tilt_strength = 0.9
	_cam.blur_amount = 0.22
	_cam.vignette = 0.5
	add_child(_cam)
	await get_tree().process_frame
	if _cam.environment:
		var env := _cam.environment
		env.background_color = Color(0.42, 0.58, 0.62)
		env.fog_light_color = Color(0.42, 0.58, 0.6)
		env.fog_density = 0.015
		env.ambient_light_color = Color(0.5, 0.64, 0.72)
		env.ambient_light_energy = 0.5
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
		var side := 1.0 if u.is_hero else -1.0
		u.row = i % 2
		var z := 0.9 if (i / 2 + u.row) % 2 == 0 else -1.0
		root.position = Vector3(base_x + side * u.row * 2.0 + side * (i / 2) * 1.1, 0, z)
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
		u.phase = float(i) * 1.7
		u.sprite = sp
		add_child(root)



# ---------------------------------------------------------------- UI
# ---------------------------------------------------------------- průběh
func _turn_order() -> Array:
	var all: Array = []
	for u in party + enemies:
		if u.alive():
			all.append(u)
	all.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return a.eff_spd() > b.eff_spd())
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
	for e0 in enemies:
		get_node("/root/Bestiary").record_seen(e0)
	var et := Rules.env_text()
	if et != "":
		await _say(et, 2.4)
	var bm0 := get_node_or_null("/root/BattleManager")
	var entry: String = bm0.entry if bm0 else "normal"
	if entry == "ambush":
		for e in enemies:
			e.add_st("stun", 1)
			_refresh_st(e)
		for h in party:
			h.bp = mini(h.bp + 1, 5)
		await _say("Přepadení! Nepřátelé jsou zaskočeni.", 1.4)
	elif entry == "trap":
		for e in enemies:
			e.hp = maxi(1, int(e.hp * 0.7))
			e.add_st("poison", 3)
			_refresh_st(e)
			ui.refresh_enemy(e)
		await _say("Past zabrala! Nepřátelé jsou zranění a otrávení.", 1.4)
	elif entry == "flank":
		for e in enemies:
			e.shield = maxi(e.shield - 1, 0)
			ui.refresh_enemy(e)
		await _say("Útok z boku! Obrana nepřátel je narušena.", 1.4)
	elif entry == "ambushed":
		await _say("Byli jste přepadeni!", 1.0)
		for h in party:
			h.bp = 0
		for e in _alive(enemies):
			await _enemy_turn(e)
	await _say("")
	while _state() == 0:
		round_no += 1
		var order := _turn_order()
		for u: BattleUnit in order:
			if _state() != 0:
				break
			if not u.alive():
				continue
			_show_order(order, u)
			u.defending = false
			if await _start_turn(u):
				continue
			if u.is_hero:
				await _hero_turn(u)
			else:
				await _enemy_turn(u)
			if _flee_done:
				return
	var st := _state()
	ui.hide_menu()
	ui.set_order(null, [])
	if st == 1:
		await _say("Vítězství!", 0.4)
		var bmv := get_node_or_null("/root/BattleManager")
		var rw: Dictionary = bmv.collect_rewards(enemies) if bmv else {}
		await _show_rewards(rw)
		_end(true)
	else:
		await _say("Porážka...", 0.4)
		await _wait_accept()
		for u in party:
			u.hp = u.max_hp
		_end(false)


var _flee_done := false


func _end(victory: bool) -> void:
	if victory:
		for u in party:
			if u.alive():
				hero_anim(u, "Victory", true)
		await get_tree().create_timer(1.6).timeout
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
	if _timing_open and ev.is_action_pressed("ui_accept"):
		_timing_pressed = true
		get_viewport().set_input_as_handled()
		return
	if _mode == "accept" and ev.is_action_pressed("ui_accept"):
		_target_chosen.emit(null)
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


func _enemy_turn(u: BattleUnit) -> void:
	var targets := _alive(party)
	if targets.is_empty():
		return
	if u.broken:
		u.broken_turns -= 1
		if u.broken_turns <= 0:
			u.broken = false
			u.shield = u.shield_max
			ui.refresh_enemy(u)
		await _say("%s je omráčen" % u.unit_name, 0.9)
		_say("")
		return
	if not u.ranged:
		targets = _reach(targets)
	var t: BattleUnit = targets[randi() % targets.size()]
	await get_tree().create_timer(0.25).timeout
	if u.boss:
		var n: int = int(u.get_meta("turns", 0)) + 1
		u.set_meta("turns", n)
		if n % 3 == 0:
			var all := _alive(party)
			await _perform(u, all, 0.8, 0, "Kostěný král svolává kostěnou bouři!", "", false)
			return
	await _perform(u, [t], 1.0, 0, "", "", false)


## Zbraň na blízko dosáhne jen na přední řadu, dokud v ní někdo stojí.
func _reach(list: Array[BattleUnit]) -> Array[BattleUnit]:
	var front: Array[BattleUnit] = []
	for u in list:
		if u.row == 0:
			front.append(u)
	return front if not front.is_empty() else list


var _timing_open := false
var _timing_pressed := false


## Okno „sweet spot“: stisk Enter/mezerníku v pravý čas dá bonus (hrdina) nebo blok (nepřítel).
func _timing(who: BattleUnit, cue: String) -> bool:
	_timing_pressed = false
	await get_tree().create_timer(0.07).timeout
	_timing_open = true
	_popup(who, cue, Color(1.0, 0.95, 0.4))
	await get_tree().create_timer(0.26).timeout
	_timing_open = false
	return _timing_pressed


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


func _pick_target(list: Array[BattleUnit]) -> BattleUnit:
	if list.is_empty():
		return null
	ui.hide_menu()
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
func _roll(a: BattleUnit, d: BattleUnit, power: float, kind := "") -> int:
	var base := a.eff_atk() * power - d.defense * 0.5
	base *= 1.25 if d.row == 0 else 0.8  ## přední řada schytá víc, zadní je křehká, ale kryta
	base *= float(d.resist.get(kind, 1.0)) * Rules.env_mult(kind) * d.taken_mult()
	if d.defending:
		base *= 0.5
	var cc := 0.08 + float(Rules.WEAPON_TYPES.get(kind, {}).get("crit", 0.0))
	_crit = randf() < cc
	if _crit:
		base *= 1.5
	if base <= 0.0:
		return 0
	return maxi(1, int(round(base * randf_range(0.9, 1.1))))


var limit := 0.0
var _limit_lbl: Label
var _cur_skill: Dictionary = {}


func _limit_add(v: float) -> void:
	limit = clampf(limit + v, 0.0, 100.0)
	if _limit_lbl:
		var n := int(limit / 12.5)
		_limit_lbl.text = "LIMIT  " + "▰".repeat(n) + "▱".repeat(8 - n) + "  %d %%" % int(limit)
		_limit_lbl.modulate = Color(1.0, 0.85, 0.3) if limit >= 100.0 else Color(0.85, 0.9, 1.0)


func _screen_flash(col: Color, secs: float) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 60
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(r)
	add_child(cl)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, secs)
	tw.tween_callback(cl.queue_free)


func _refresh_st(u: BattleUnit) -> void:
	if u.node == null:
		return
	var l: Label3D = u.node.get_node_or_null("St")
	if l == null:
		l = Label3D.new()
		l.name = "St"
		l.font_size = 40
		l.pixel_size = 0.01
		l.outline_size = 10
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.position = Vector3(0, 0.15, 0.5)
		u.node.add_child(l)
	var txt := ""
	for k in u.status:
		txt += Rules.STATUS[k].ico + " "
	l.text = txt
	l.visible = u.alive() and txt != ""


## Na začátku tahu: jed/popálení/obnova, odpočet statusů. Vrací true, pokud jednotka tah vynechá.
func _start_turn(u: BattleUnit) -> bool:
	var skip := false
	var why := ""
	for k in u.status.keys():
		var d: Dictionary = Rules.STATUS[k]
		if d.has("dot"):
			var dmg := maxi(1, int(u.max_hp * float(d.dot)))
			u.hp = maxi(u.hp - dmg, 0)
			_popup(u, str(dmg), d.col)
			_flash(u, d.col)
		if d.has("hot"):
			var hv := mini(maxi(1, int(u.max_hp * float(d.hot))), u.max_hp - u.hp)
			u.hp += hv
			_popup(u, "+%d" % hv, d.col)
		if d.get("skip", false):
			skip = true
			why = d.name
		u.status[k] = int(u.status[k]) - 1
		if int(u.status[k]) <= 0:
			u.status.erase(k)
	_refresh_st(u)
	ui.update_party()
	if not u.is_hero:
		ui.refresh_enemy(u)
	if not u.alive():
		_kill(u)
		await get_tree().create_timer(0.6).timeout
		return true
	if skip:
		_popup(u, why, Color(1, 1, 0.5))
		await _say("%s nemůže jednat (%s)" % [u.unit_name, why], 0.9)
		_say("")
		return true
	return false


func _show_rewards(rw: Dictionary) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 70
	add_child(cl)
	var pn := PanelContainer.new()
	pn.set_anchors_preset(Control.PRESET_CENTER)
	pn.custom_minimum_size = Vector2(520, 0)
	pn.position = Vector2(700, 280)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.12, 0.92)
	sb.border_color = Color(0.85, 0.75, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	pn.add_theme_stylebox_override("panel", sb)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.custom_minimum_size = Vector2(480, 0)
	l.add_theme_font_size_override("normal_font_size", 26)
	l.add_theme_font_size_override("bold_font_size", 30)
	var t := "[b][color=#f0d890]VÍTĚZSTVÍ[/color][/b]\n\n"
	t += "Zkušenosti: [b]+%d XP[/b]\nZlato: [b]+%d[/b]\n" % [int(rw.get("xp", 0)), int(rw.get("gold", 0))]
	var items: Dictionary = rw.get("items", {})
	for id in items:
		var nm: String = GameData.items.get(id, {}).get("name", id)
		t += "Kořist: %s ×%d\n" % [nm, items[id]]
	for lv in rw.get("levels", []):
		t += "[color=#9fe090]%s dosáhl(a) úrovně %d![/color]\n" % [lv[0], lv[1]]
	t += "\n[color=#aab]Enter — pokračovat[/color]"
	l.text = t
	pn.add_child(l)
	cl.add_child(pn)
	await _wait_accept()
	cl.queue_free()


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
	if u.is_hero and u.hero_anim:
		hero_anim(u, "Death", false)
	elif u.is_hero:
		u.sprite.modulate = Color(0.45, 0.45, 0.5)
		create_tween().tween_property(u.sprite, "rotation_degrees:z", 80.0, 0.3)
	else:
		if u.label:
			u.label.visible = false
		if not u.anims.is_empty():
			hero_anim(u, "Death", false)
			await get_tree().create_timer(0.35).timeout
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


# ---------------------------------------------------------------- HUD (Octopath)
func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	ui = OTUI.new()
	cl.add_child(ui)
	ui.setup(party, enemies, _cam)
	ui.boost_changed.connect(func(l: int) -> void: _pending_boost = l)
	_limit_lbl = Label.new()
	_limit_lbl.position = Vector2(24, 930)
	_limit_lbl.add_theme_font_size_override("font_size", 26)
	_limit_lbl.add_theme_constant_override("outline_size", 6)
	_limit_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cl.add_child(_limit_lbl)
	_limit_add(0.0)


func _say(text: String, secs: float = 0.0) -> void:
	ui.say(text)
	if secs > 0.0:
		await get_tree().create_timer(secs).timeout


func _update_label(u: BattleUnit) -> void:
	ui.refresh_enemy(u)


func _show_order(order: Array, current: BattleUnit) -> void:
	var list: Array = order.duplicate()
	if current != null and list.has(current):
		list = list.slice(list.find(current) + 1)
	list.append_array(_turn_order())
	var out: Array = []
	for u in list:
		if u.alive() and out.size() < 9:
			out.append(u)
	ui.active_unit = current if (current and current.is_hero) else null
	ui.set_order(current, out)
	ui.update_party()


var _turns := {}


func _weapon_equipped() -> bool:
	var inv := get_node_or_null("/root/Inventory")
	return inv != null and str(inv.equip.get("zbran", "")) != ""


func _attack_kind(a: BattleUnit) -> String:
	return a.wtype if a.is_hero else ""


func _hero_turn(u: BattleUnit) -> void:
	_highlight(u, true)
	if _turns.get(u, 0) > 0:
		u.bp = mini(u.bp + 1, 5)
	_turns[u] = _turns.get(u, 0) + 1
	_pending_boost = 0
	ui.active_unit = u
	_show_order(_turn_order(), u)
	var wt: Dictionary = Rules.WEAPON_TYPES.get(u.wtype, Rules.WEAPON_TYPES["fist"])
	while true:
		ui.say("")
		_cur_skill = {}
		var labels := ["Útok", "Dovednost", "Předmět", "Obrana", "Řada"]
		var keys := ["attack", "skill", "item", "defend", "row"]
		var descs := [str(wt.desc) + (" Enter = bonus." if wt.melee else ""), "Použije dovednost (SP).", "Lektvar nebo jídlo z batohu.", "Menší poškození, +1 BP.", "Přesun vpřed/vzad: vpředu víc dmg, vzadu méně. +1 BP."]
		if limit >= 100.0 and Rules.LIMITS.has(u.class_id):
			labels.append("LIMIT")
			keys.append("limit")
			descs.append(str(Rules.LIMITS[u.class_id].name) + " — ničivý útok.")
		labels.append("Útěk")
		keys.append("flee")
		descs.append("Pokus o útěk (stojí zlato).")
		var cmd := await _menu(labels, keys, descs, true, u.bp)
		if cmd == "attack":
			var pool := _alive(enemies)
			if str(wt.reach) == "front":
				pool = _reach(pool)
			var t := await _pick_target(pool)
			if t == null:
				continue
			var tg: Array[BattleUnit] = [t]
			var al := _alive(enemies)
			if str(wt.reach) == "adjacent":
				var i := al.find(t)
				var j := i + 1 if i + 1 < al.size() else i - 1
				if j >= 0 and j != i:
					tg.append(al[j])
			elif str(wt.reach) == "pierce":
				for e in al:
					if e != t and e.row != t.row:
						tg.append(e)
						break
			await _perform(u, tg, 1.0, 0, "", _attack_kind(u), false)
			break
		elif cmd == "skill":
			if u.skills.is_empty():
				continue
			var names: Array = []
			var skeys: Array = []
			var sdescs: Array = []
			for i in u.skills.size():
				var s: Dictionary = u.skills[i]
				names.append("%s    %d SP" % [s["name"], s["cost"]])
				skeys.append(str(i))
				sdescs.append(str(s.get("desc", "")))
			var k := await _menu(names, skeys, sdescs, true, u.bp)
			if k == "back":
				continue
			var sk: Dictionary = u.skills[int(k)]
			if u.sp < int(sk["cost"]):
				await _say("Nedostatek SP!", 0.8)
				continue
			var tg2: Array[BattleUnit] = []
			var tk := str(sk.get("target", ""))
			var skind := str(sk.get("kind", ""))
			if sk.has("heal") or tk == "ally":
				var ally := await _pick_target(_alive(party))
				if ally == null:
					continue
				tg2 = [ally]
			elif tk == "allies":
				tg2 = _alive(party)
			elif tk == "self":
				tg2 = [u]
			elif sk.get("all", false):
				tg2 = _alive(enemies)
			else:
				var pool2 := _alive(enemies)
				if Rules.PHYS.has(skind) and skind != "bow" and skind != "staff":
					pool2 = _reach(pool2)
				var e := await _pick_target(pool2)
				if e == null:
					continue
				tg2 = [e]
			u.sp -= int(sk["cost"])
			_cur_skill = sk
			await _perform(u, tg2, float(sk.get("power", 1.0)), int(sk.get("heal", 0)), str(sk["name"]), skind if skind != "" else _attack_kind(u), true)
			break
		elif cmd == "item":
			var invn: Node = get_node("/root/Inventory")
			var ids: Array = invn.consumables()
			if ids.is_empty():
				await _say("Nemáš žádné použitelné předměty.", 0.8)
				continue
			var inames: Array = []
			var idescs: Array = []
			for iid in ids:
				inames.append("%s  ×%d" % [invn.ITEMS[iid].name, invn.count(iid)])
				idescs.append(str(invn.ITEMS[iid].get("desc", "")))
			var ik := await _menu(inames, ids, idescs, false, u.bp)
			if ik == "back":
				continue
			var itg := await _pick_target(_alive(party))
			if itg == null:
				continue
			var use: Dictionary = invn.ITEMS[ik].use
			invn.remove(ik, 1)
			if use.has("heal"):
				var hv3 := mini(int(use.heal), itg.max_hp - itg.hp)
				itg.hp += hv3
				_popup(itg, "+%d" % hv3, Color(0.4, 1.0, 0.5))
			if use.has("sp"):
				var sv := mini(int(use.sp), itg.max_sp - itg.sp)
				itg.sp += sv
				_popup(itg, "+%d SP" % sv, Color(0.5, 0.7, 1.0))
			if use.has("st"):
				itg.add_st(str(use.st[0]), int(use.st[1]))
				_refresh_st(itg)
			_flash(itg, Color(1.4, 1.4, 0.9))
			ui.update_party()
			await _say("%s použil(a) %s" % [u.unit_name, invn.ITEMS[ik].name], 0.9)
			break
		elif cmd == "limit":
			var lim: Dictionary = Rules.LIMITS[u.class_id]
			limit = 0.0
			_limit_add(0.0)
			_cur_skill = lim
			await _perform(u, _alive(enemies), float(lim.power), 0, str(lim.name), str(lim.kind), true)
			break
		elif cmd == "defend":
			u.defending = true
			u.bp = mini(u.bp + 1, 5)
			await _say("%s se brání" % u.unit_name, 0.7)
			break
		elif cmd == "row":
			u.row = 1 - u.row
			u.bp = mini(u.bp + 1, 5)
			var tw := create_tween()
			tw.tween_property(u.node, "position:x", u.node.position.x + (2.0 if u.row == 1 else -2.0), 0.3)
			await tw.finished
			await _say("%s: %s řada" % [u.unit_name, "zadní" if u.row == 1 else "přední"], 0.7)
			break
		elif cmd == "flee":
			var bm := get_node_or_null("/root/BattleManager")
			for e in enemies:
				if e.boss:
					await _say("Z tohoto souboje nelze utéct!", 1.0)
					cmd = "no"
			if cmd == "no":
				continue
			var avg := 0.0
			for e in _alive(enemies):
				avg += e.eff_spd()
			avg /= maxf(1.0, float(_alive(enemies).size()))
			var chance := clampf(0.5 + (u.eff_spd() - avg) * 0.03, 0.25, 0.9)
			if randf() < chance:
				var inv := get_node("/root/Inventory")
				var lost := int(inv.gold * randf_range(0.08, 0.18))
				inv.gold -= lost
				await _say("Útěk se podařil! Cestou jsi ztratil %d zlata." % lost, 1.3)
				if bm:
					bm.fled = true
				_flee_done = true
				ui.hide_menu()
				_end(true)
				return
			await _say("Útěk se nezdařil! Nepřátelé využijí příležitosti.", 1.0)
			u.bp = maxi(u.bp - 1, 0)
			for e in _alive(enemies):
				if randf() < 0.5 and not e.broken:
					await _enemy_turn(e)
			break
	_highlight(u, false)
	ui.hide_menu()
	ui.active_unit = null
	ui.update_party()
	_say("")


func _menu(labels: Array, keys: Array, descs: Array, boostable := false, bp_avail := 0) -> String:
	_mode = "menu"
	if autoplay:
		var pick: String = str(keys[0])
		if keys.has("limit"):
			pick = "limit"
		if keys.has("skill") and round_no == 2:
			pick = "skill"
		elif keys.has("skill") and round_no == 3:
			pick = "defend"
		if boostable and round_no == 2 and bp_avail > 0:
			_pending_boost = 1
		get_tree().create_timer(0.35).timeout.connect(func() -> void: ui.auto_pick(pick))
	var res: String = await ui.menu(labels, keys, descs, boostable, bp_avail, _pending_boost)
	_mode = ""
	return res


func _perform(a: BattleUnit, targets: Array[BattleUnit], power: float, heal: int, text: String, kind: String, is_skill: bool) -> void:
	var boost := 0
	if a.is_hero:
		boost = mini(_pending_boost, a.bp)
		a.bp -= boost
		_pending_boost = 0
	var sk := _cur_skill
	_cur_skill = {}
	var is_limit: bool = sk.has("name") and Rules.LIMITS.has(a.class_id) and sk.get("name") == Rules.LIMITS[a.class_id].get("name")
	if text != "":
		await _say(text)
	else:
		_say("")
	var weapon := _weapon_equipped()
	var swing := "Swordslash" if weapon else "Attackcombo3hit"
	var wt: Dictionary = Rules.WEAPON_TYPES.get(a.wtype, Rules.WEAPON_TYPES["fist"])
	var buff_only := power <= 0.0 and heal == 0 and sk.has("st")
	var melee := false
	if heal == 0 and not buff_only and not is_limit:
		if not is_skill:
			melee = bool(wt.melee) if a.is_hero else not a.ranged
		else:
			melee = Rules.PHYS.has(kind) and kind != "bow" and kind != "staff" and targets.size() == 1
	var hits := 1 + (boost if (not is_skill and heal == 0) else 0)
	if is_skill and boost > 0:
		power *= 1.0 + 0.5 * boost
	var home := a.node.position
	var dir := -1.0 if a.is_hero else 1.0
	if is_limit:
		hero_anim(a, "Chargeup", false)
		_screen_flash(Color(1, 1, 1, 0.55), 0.5)
		await get_tree().create_timer(0.55).timeout
	if melee:
		var dest := targets[0].node.position + Vector3(-dir * 1.6, 0, 0)
		var tw := create_tween()
		tw.tween_property(a.node, "position", dest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	else:
		var tw2 := create_tween()
		tw2.tween_property(a.sprite, "position:y", _base_y(a) + 0.7, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw2.finished
	for h in hits:
		hero_anim(a, swing if (melee and not (is_skill and heal > 0)) else "Castspell", false)
		var tmult := 1.0
		if melee and not is_skill and not autoplay:
			if a.is_hero:
				if await _timing(a, "!"):
					tmult = 1.35
					_popup(a, "PERFEKTNĚ!", Color(1.0, 0.8, 0.2))
			elif targets[0].is_hero:
				if await _timing(targets[0], "BLOK!"):
					tmult = 0.4
		else:
			await get_tree().create_timer(0.18).timeout
		if is_limit:
			_screen_flash(Color(1.0, 0.9, 0.5, 0.35), 0.4)
		for t in targets:
			if not t.alive():
				continue
			if heal > 0:
				var hv := mini(heal, t.max_hp - t.hp)
				t.hp += hv
				_popup(t, "+%d" % hv, Color(0.4, 1.0, 0.5))
				_flash(t, Color(0.6, 1.4, 0.8))
			elif buff_only:
				_apply_status(t, sk, 1.0)
				_flash(t, Color(1.4, 1.4, 0.9))
			else:
				var miss := (0.5 if a.has_st("blind") else 0.0) + Rules.env_miss(kind, a.is_hero)
				if randf() < miss:
					_popup(t, "Vedle", Color(0.8, 0.8, 0.8))
					continue
				var mult := 1.5 if t.broken else 1.0
				var dmg := int(round(_roll(a, t, power, kind) * mult * tmult))
				if dmg == 0:
					_popup(t, "Odolává", Color(0.7, 0.7, 0.9))
					continue
				t.hp = maxi(t.hp - dmg, 0)
				t.status.erase("sleep")
				_popup(t, str(dmg) + ("!" if _crit else ""), Color(1, 0.85, 0.3) if (_crit or t.broken) else Color(1, 1, 1))
				_flash(t, Color(2.6, 2.6, 2.6))
				_shake(t)
				if t.alive():
					hero_anim(t, "Hurt", false)
				_weakness_hit(t, kind, int(wt.get("shield_break", 1)) - 1 if a.is_hero and not is_skill else 0)
				if sk.has("st") and t.alive():
					_apply_status(t, sk, 1.0)
				if t.is_hero:
					_limit_add(float(dmg) / float(t.max_hp) * 90.0)
					if t.hero_anim:
						var msg: String = get_node("/root/Inventory").hurt_gear(float(dmg) / float(t.max_hp))
						if msg != "":
							_popup(t, msg, Color(1.0, 0.55, 0.3))
							_say(msg)
				else:
					_limit_add(2.5 + (3.0 if _crit else 0.0))
			_refresh_st(t)
			ui.update_party()
			if not t.is_hero:
				ui.refresh_enemy(t)
		if is_limit and sk.has("heal_all"):
			for p in _alive(party):
				var hv2 := mini(int(sk.heal_all), p.max_hp - p.hp)
				p.hp += hv2
				_popup(p, "+%d" % hv2, Color(0.4, 1.0, 0.5))
			ui.update_party()
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.15).timeout
	var tw3 := create_tween()
	if melee:
		tw3.tween_property(a.node, "position", home, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw3.tween_property(a.sprite, "position:y", _base_y(a), 0.18)
	await tw3.finished
	for t in targets:
		if not t.alive():
			_kill(t)
	hero_anim(a, "Idle")
	await get_tree().create_timer(0.25).timeout


func _apply_status(t: BattleUnit, sk: Dictionary, boost_chance: float) -> void:
	var st: Array = sk.get("st", [])
	if st.size() < 3:
		return
	var id := str(st[0])
	if t.boss and (id == "sleep" or id == "stun"):
		_popup(t, "Imunní", Color(0.8, 0.8, 0.8))
		return
	if randf() <= float(st[2]) * boost_chance:
		t.add_st(id, int(st[1]) + (1 if t == null else 0))
		_popup(t, Rules.STATUS[id].name, Rules.STATUS[id].col)
		_refresh_st(t)


func _weakness_hit(t: BattleUnit, kind: String, extra := 0) -> void:
	if t.is_hero or kind == "" or t.shield_max <= 0 or not t.weak.has(kind):
		return
	if not t.weak_known.has(kind):
		t.weak_known.append(kind)
	if t.broken:
		ui.refresh_enemy(t)
		return
	t.shield = maxi(t.shield - 1 - extra, 0)
	if t.shield == 0:
		t.broken = true
		t.broken_turns = 1
		_popup(t, "ZLOMENÍ!", Color(1.0, 0.5, 0.3))
		_flash(t, Color(3, 3, 3))
	ui.refresh_enemy(t)
