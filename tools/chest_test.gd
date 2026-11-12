extends SceneTree
var frames := 0
var sc: Node
var ch: Node
var lp: Node
var out := "/tmp/claude-0/-home-claude/dc0fae54-8a83-52be-878a-e01eee3d19d7/scratchpad/"
func _initialize() -> void:
	sc = (load("res://scenes/louka.tscn") as PackedScene).instantiate()
	get_root().add_child(sc)
	for n in sc.find_children("*", "Node3D", true, false):
		if n.get_script() != null and n.get_script().resource_path.ends_with("chest.gd") and ch == null:
			ch = n
	var p := sc.get_node("Player") as Node3D
	p.global_position = ch.global_position + Vector3(0, 0.1, 1.4)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 30:
		ch.interact(null)
		for c in get_root().get_children():
			if c.get_script() != null and c.get_script().resource_path.ends_with("lockpick.gd"):
				lp = c
		print("lock level ", lp.level, " sweet ", lp.sweet)
		lp.pick = lp.sweet + 40.0
		var e := InputEventKey.new(); e.keycode = KEY_SPACE; e.pressed = true
		Input.parse_input_event(e)
	if frames == 50:
		get_root().get_texture().get_image().save_png(out + "lp1.png")
		print("turn ", lp.turn, " hp ", lp.hp)
		lp.pick = lp.sweet
	if frames == 140:
		print("after sweet: turn ", lp.turn, " valid ", is_instance_valid(lp), " unlocked ", ch.unlocked)
	if frames == 150:
		get_root().get_texture().get_image().save_png(out + "lp2.png")
		print("opened ", ch.opened, " gold ", get_root().get_node("Inventory").gold)
		ch._take()
		print("bag ", get_root().get_node("Inventory").bag)
		var e2 := InputEventKey.new(); e2.keycode = KEY_I; e2.pressed = true
		get_root().get_node("Inventory")._toggle()
	if frames == 170:
		get_root().get_texture().get_image().save_png(out + "lp3.png")
		quit()
	return false
