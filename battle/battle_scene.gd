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
		if u.hero_anim and u.sprite:
			_tick_anim(u, dt)
		if u.sprite and u.alive():
			u.sprite.position.y = _base_y(u) + sin(_t * 2.2 + u.spd) * 0.025
	if _cursor and _cursor.visible and _mode == "target" and not _target_list.is_empty():
		var tu := _target_list[_target_idx]
		_cursor.global_position = tu.node.global_position + Vector3(0, _height(tu) + 0.9 + sin(_t * 6.0) * 0.1, 0)


# ---------------------------------------------------------------- svět
const ANIM_FPS := {"Idle": 6.0, "Swordslash": 12.0, "Castspell": 10.0, "Hurt": 10.0, "Death": 8.0, "Victory": 8.0, "Block": 8.0, "Chargeup": 10.0}


func hero_anim(u: BattleUnit, anim: String, loop := true) -> void:
	if not u.hero_anim or u.sprite == null:
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


func _tick_anim(u: BattleUnit, dt: float) -> void:
	u.anim_t += dt * float(ANIM_FPS.get(u.anim_name, 10.0))
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
		var z := 0.9 if i % 2 == 0 else -1.0
		root.position = Vector3(base_x + side * i * 1.9, 0, z)
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



# ---------------------------------------------------------------- UI
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
			_show_order(order, u)
			u.defending = false
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
	var t: BattleUnit = targets[randi() % targets.size()]
	await get_tree().create_timer(0.25).timeout
	await _perform(u, [t], 1.0, 0, "", "", false)


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
func _roll(a: BattleUnit, d: BattleUnit, power: float) -> int:
	var base := a.atk * power - d.defense * 0.5
	if d.defending:
		base *= 0.5
	_crit = randf() < 0.08
	if _crit:
		base *= 1.5
	return maxi(1, int(round(base * randf_range(0.9, 1.1))))


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
	if a.is_hero and a.hero_anim:
		return "sword" if _weapon_equipped() else "fist"
	return "sword" if a.is_hero else ""


func _hero_turn(u: BattleUnit) -> void:
	_highlight(u, true)
	if _turns.get(u, 0) > 0:
		u.bp = mini(u.bp + 1, 5)
	_turns[u] = _turns.get(u, 0) + 1
	_pending_boost = 0
	ui.active_unit = u
	_show_order(_turn_order(), u)
	while true:
		ui.say("")
		var cmd := await _menu(["Útok", "Dovednost", "Obrana", "Útěk"], ["attack", "skill", "defend", "flee"],
			["Útok zbraní na jednoho.", "Použije dovednost (SP).", "Menší poškození, +1 BP.", "Pokus o útěk."], true, u.bp)
		if cmd == "attack":
			var t := await _pick_target(_alive(enemies))
			if t == null:
				continue
			await _perform(u, [t], 1.0, 0, "", _attack_kind(u), false)
			break
		elif cmd == "skill":
			if u.skills.is_empty():
				continue
			var names: Array = []
			var keys: Array = []
			var descs: Array = []
			for i in u.skills.size():
				var s: Dictionary = u.skills[i]
				names.append("%s    %d SP" % [s["name"], s["cost"]])
				keys.append(str(i))
				descs.append("Léčí spojence." if s.has("heal") else ("Zasáhne všechny." if s.get("all", false) else "Silný útok na jednoho."))
			var k := await _menu(names, keys, descs, true, u.bp)
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
			await _perform(u, tg, float(sk.get("power", 1.0)), int(sk.get("heal", 0)), str(sk["name"]), str(sk.get("kind", _attack_kind(u))), true)
			break
		elif cmd == "defend":
			u.defending = true
			u.bp = mini(u.bp + 1, 5)
			await _say("%s se brání" % u.unit_name, 0.7)
			break
		elif cmd == "flee":
			if randf() < 0.7:
				await _say("Útěk se podařil!", 0.8)
				_flee_done = true
				ui.hide_menu()
				_end(true)
				return
			await _say("Útěk se nezdařil!", 0.8)
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
	if text != "":
		await _say(text)
	else:
		_say("")
	var weapon := _weapon_equipped()
	var swing := "Swordslash" if weapon else "Attackcombo3hit"
	var melee := heal == 0 and targets.size() == 1
	var hits := 1 + (boost if (melee and not is_skill) else 0)
	if is_skill and boost > 0:
		power *= 1.0 + 0.5 * boost
	var home := a.node.position
	var dir := -1.0 if a.is_hero else 1.0
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
		await get_tree().create_timer(0.18).timeout
		for t in targets:
			if not t.alive():
				continue
			if heal > 0:
				var hv := mini(heal, t.max_hp - t.hp)
				t.hp += hv
				_popup(t, "+%d" % hv, Color(0.4, 1.0, 0.5))
				_flash(t, Color(0.6, 1.4, 0.8))
			else:
				var mult := 1.5 if t.broken else 1.0
				var dmg := int(round(_roll(a, t, power) * mult))
				t.hp = maxi(t.hp - dmg, 0)
				_popup(t, str(dmg) + ("!" if _crit else ""), Color(1, 0.85, 0.3) if (_crit or t.broken) else Color(1, 1, 1))
				_flash(t, Color(2.6, 2.6, 2.6))
				_shake(t)
				if t.alive():
					hero_anim(t, "Hurt", false)
				_weakness_hit(t, kind)
			ui.update_party()
			if not t.is_hero:
				ui.refresh_enemy(t)
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


func _weakness_hit(t: BattleUnit, kind: String) -> void:
	if t.is_hero or kind == "" or t.shield_max <= 0 or not t.weak.has(kind):
		return
	if not t.weak_known.has(kind):
		t.weak_known.append(kind)
	if t.broken:
		ui.refresh_enemy(t)
		return
	t.shield = maxi(t.shield - 1, 0)
	if t.shield == 0:
		t.broken = true
		t.broken_turns = 1
		_popup(t, "ZLOMENÍ!", Color(1.0, 0.5, 0.3))
		_flash(t, Color(3, 3, 3))
	ui.refresh_enemy(t)
