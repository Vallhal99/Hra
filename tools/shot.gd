extends SceneTree
var frames := 0
var out := "/home/claude/shot.png"
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	var ps := load(OS.get_environment("MAP") if OS.get_environment("MAP") != "" else "res://scenes/louka.tscn") as PackedScene
	var sc := ps.instantiate()
	get_root().add_child(sc)
	if args.size() > 1:
		var p := sc.get_node("Player") as Node3D
		var parts := args[1].split(",")
		p.global_position = Vector3(float(parts[0]), 6.0, float(parts[1]))
	if args.size() > 2:
		var cam := sc.get_node("Camera") as HD2DCamera
		cam.distance = float(args[2])
		if args.size() > 3: cam.pitch = float(args[3])
func _process(_d: float) -> bool:
	frames += 1
	if frames == 70:
		get_root().get_texture().get_image().save_png(out)
		quit()
	return false
