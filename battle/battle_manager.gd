extends Node
## Autoload "BattleManager": spouští souboje. Použití z kódu:
##   BattleManager.start(party, enemies)      (obě pole = Array[BattleUnit]; prázdné = výchozí)
## Zkouška v běžící hře: klávesa F9.

signal battle_finished(victory: bool)
var party: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var active := false
var return_scene := ""
var return_pos := Vector3.ZERO
var has_return_pos := false
var entry := "normal"   ## normal | ambush | ambushed | flank | trap
var fled := false
var source_key := ""   ## klíč nepřítele z mapy, který boj spustil


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F9 and not active:
		start([], [])


func start(p: Array, e: Array, how := "normal") -> void:
	entry = how
	if active:
		return
	active = true
	party.assign(p if not p.is_empty() else (party if not party.is_empty() else BattleUnit.default_party()))
	enemies.assign(e if not e.is_empty() else BattleUnit.default_enemies())
	for u in enemies:
		u.reset()
	var sc := get_tree().current_scene
	return_scene = sc.scene_file_path if sc else ""
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	has_return_pos = pl != null
	if pl:
		return_pos = pl.global_position
	SceneManager.go("res://battle/battle.tscn")


func collect_rewards(list: Array) -> Dictionary:
	var xp := 0
	var gold := 0
	var items := {}
	var inv := get_node("/root/Inventory")
	for u in list:
		xp += u.xp_value if u.xp_value > 0 else 20 + u.atk
		gold += u.gold_value if u.gold_value > 0 else 8 + u.max_hp / 10
		for d in u.drops:
			if randf() < float(d[1]):
				items[d[0]] = int(items.get(d[0], 0)) + 1
		get_node("/root/Quests").event("kill")
		get_node("/root/Quests").event("kill:" + u.unit_name)
	var H := get_node("/root/Hero")
	var P := get_node("/root/Party")
	var before := {"hero": H.level}
	for id in P.members:
		before[id] = int(P.members[id].level)
	H.add_xp(xp)
	P.add_xp(xp)
	var levels: Array = []
	if H.level > int(before["hero"]):
		levels.append([H.cls().get("name", "Hrdina"), H.level])
	for id in P.members:
		if int(P.members[id].level) > int(before[id]):
			levels.append([P.DEFS[id].name, int(P.members[id].level)])
	inv.add("gold", gold)
	for id in items:
		inv.add(id, items[id])
	return {"xp": xp, "gold": gold, "items": items, "levels": levels}


func finish(victory: bool) -> void:
	if not victory:
		for u in party:
			u.hp = maxi(u.hp, 1)
	active = false
	var was_fled := fled
	fled = false
	MapEnemy.resolve(source_key, victory, was_fled)
	source_key = ""
	if return_scene != "":
		await SceneManager.go(return_scene)
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl and has_return_pos:
			pl.global_position = return_pos
			get_tree().call_group("camera_follow", "snap")
	battle_finished.emit(victory)
