extends SceneTree
var t := 0.0
var sc: Node
var shots := [6.0, 12.0, 18.0, 24.0, 30.0]
var idx := 0
var prefix := "/tmp/bf"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: prefix = a[0]
	get_root().get_node("Hero").class_id = "mag"
	get_root().get_node("Hero").level = 5
	get_root().get_node("Inventory").equip["zbran"] = "zelezny_mec"
	Engine.time_scale = 3.0
	sc = (load("res://battle/battle.tscn") as PackedScene).instantiate()
	sc.autoplay = true
	get_root().add_child(sc)
	sc.limit = 100.0
	for u in sc.enemies: u.hp = 60
func _process(d: float) -> bool:
	t += d
	if idx < shots.size() and t >= shots[idx]:
		get_root().get_texture().get_image().save_png("%s_%d.png" % [prefix, idx])
		idx += 1
	if t > 40.0 or (sc.round_no > 0 and sc._state() != 0 and t > 8.0):
		get_root().get_texture().get_image().save_png(prefix + "_end.png")
		print("END state=", sc._state(), " round=", sc.round_no, " t=", t, " limit=", sc.limit)
		for u in sc.party + sc.enemies: print(u.unit_name, " hp=", u.hp, " st=", u.status, " row=", u.row)
		print("gold=", get_root().get_node("Inventory").gold, " xp=", get_root().get_node("Hero").xp, " lvl=", get_root().get_node("Hero").level)
		quit()
	return false
