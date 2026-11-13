extends SceneTree
var frames := 0
var out := "/tmp/claude-0/-home-claude/dc0fae54-8a83-52be-878a-e01eee3d19d7/scratchpad/"
func _initialize() -> void:
	var m = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(m)
	current_scene = m
func _process(_d: float) -> bool:
	frames += 1
	var SG = get_root().get_node("SaveGame")
	if frames == 10:
		get_root().get_texture().get_image().save_png(out + "menu.png")
		get_root().get_node("Hero").skip_select = true
		SG.new_game()
	if frames == 150:
		print("scene1 ", current_scene.scene_file_path)
		get_root().get_node("Inventory").gold = 77
		var p = get_first_node_in_group("player")
		p.global_position = Vector3(20, 3, 30)
		print("save ", SG.save(1))
		get_root().get_node("SceneManager").go("res://scenes/rozcesti.tscn", "Ze_severu")
	if frames == 260:
		print("scene2 ", current_scene.scene_file_path, " ", get_first_node_in_group("player").global_position)
		get_root().get_node("Inventory").gold = 1
		SG.load_slot(1)
	if frames == 400:
		print("scene3 ", current_scene.scene_file_path, " gold ", get_root().get_node("Inventory").gold, " ", get_first_node_in_group("player").global_position)
		get_root().get_node("SceneManager").go("res://scenes/vesnice.tscn", "Ze_zapadu")
	if frames == 520:
		print("scene4 ", current_scene.scene_file_path, " ", get_first_node_in_group("player").global_position)
		quit()
	return false
