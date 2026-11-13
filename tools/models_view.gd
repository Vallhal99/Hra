extends SceneTree
var frames := 0
func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var names := ["House_Cabin", "House_Shop1", "House_Shop2", "Tree_Oak", "Tree_Pine"]
	for i in names.size():
		var m := (load("res://models/%s.glb" % names[i]) as PackedScene).instantiate() as Node3D
		m.position = Vector3(i * 9.0, 0, 0)
		root.add_child(m)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.8)
	root.add_child(env)
	var c := Camera3D.new()
	c.position = Vector3(18, 7, 26)
	c.look_at(Vector3(18, 2.5, 0))
	c.fov = 50
	root.add_child(c)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		get_root().get_texture().get_image().save_png("/tmp/claude-0/-home-claude/dc0fae54-8a83-52be-878a-e01eee3d19d7/scratchpad/models.png")
		quit()
	return false
