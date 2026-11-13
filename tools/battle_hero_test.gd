extends SceneTree
# Test boje: godot --path . -s res://tools/battle_test.gd -- vystup_prefix
var t := 0.0
var shots := [1.5, 3.0, 5.0, 8.0, 12.0, 17.0, 24.0, 32.0]
var idx := 0
var sc: Node
var prefix := "/tmp/battle"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: prefix = a[0]
	get_root().get_node("Hero").class_id = "valecnik"
	sc = (load("res://battle/battle.tscn") as PackedScene).instantiate()
	sc.autoplay = OS.get_cmdline_user_args().size() < 2
	get_root().add_child(sc)
	for u in sc.enemies: u.hp = 40
func _process(d: float) -> bool:
	t += d
	if idx < shots.size() and t >= shots[idx]:
		get_root().get_texture().get_image().save_png("%s_%d.png" % [prefix, idx])
		idx += 1
	if (not sc.autoplay and t > 7.0) or t > 45.0 or (sc and sc.round_no > 0 and sc._state() != 0 and t > 10.0):
		get_root().get_texture().get_image().save_png(prefix + '_end.png')
		print("END state=", sc._state(), " round=", sc.round_no, " t=", t)
		for u in sc.party + sc.enemies: print(u.unit_name, " hp=", u.hp)
		quit()
	return false
