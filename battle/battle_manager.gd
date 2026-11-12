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


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F9 and not active:
		start([], [])


func start(p: Array, e: Array) -> void:
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


func finish(victory: bool) -> void:
	if not victory:
		for u in party:
			u.hp = maxi(u.hp, 1)
	active = false
	if return_scene != "":
		await SceneManager.go(return_scene)
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl and has_return_pos:
			pl.global_position = return_pos
			get_tree().call_group("camera_follow", "snap")
	battle_finished.emit(victory)
