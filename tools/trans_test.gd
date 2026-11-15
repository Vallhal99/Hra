extends SceneTree
var t := 0.0
var shots := [0.25, 0.45]
var i := 0
func _initialize() -> void:
	var sc: Node = (load(OS.get_environment("FROM")) as PackedScene).instantiate()
	get_root().add_child(sc)
	current_scene = sc
func _process(d: float) -> bool:
	if t == 0.0:
		get_root().get_node("SceneManager").go(OS.get_environment("TO"), "")
	t += d
	if i < shots.size() and t >= shots[i]:
		get_root().get_texture().get_image().save_png("%s_%d.png" % [OS.get_cmdline_user_args()[0], i])
		i += 1
	if t > 2.5:
		print("scene=", current_scene.scene_file_path)
		quit()
	return false
