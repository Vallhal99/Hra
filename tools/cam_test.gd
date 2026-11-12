extends SceneTree
# Test kamery: godot --path . -s res://tools/cam_test.gd -- vystup.png x,z
var n := 0
var sc: Node
var out := "/tmp/cam.png"
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	sc = (load("res://scenes/louka.tscn") as PackedScene).instantiate()
	get_root().add_child(sc)
	if a.size() > 1:
		var p := a[1].split(",")
		sc.get_node("Player").global_position = Vector3(float(p[0]), 0.5, float(p[1]))
func _process(_d: float) -> bool:
	n += 1
	if n == 4:
		get_first_node_in_group_cam().snap()
	if n == 30:
		get_root().get_texture().get_image().save_png(out)
		print("CAM ", sc.get_node("Camera").global_position)
		quit()
	return false
func get_first_node_in_group_cam() -> Node:
	return sc.get_node("Camera")
