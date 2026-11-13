extends SceneTree
var frames := 0
var out := "/tmp/claude-0/-home-claude/dc0fae54-8a83-52be-878a-e01eee3d19d7/scratchpad/"
var pl: Node3D
func _initialize() -> void:
	get_root().get_node("Hero").skip_select = true
	var sc = (load("res://scenes/louka.tscn") as PackedScene).instantiate()
	get_root().add_child(sc)
	pl = sc.get_node("Player")
func _process(_d: float) -> bool:
	frames += 1
	var I = get_root().get_node("Inventory")
	if frames == 20:
		pl.hero.play("Walk", "SE")
		get_root().get_texture().get_image().save_png(out + "h1.png")
	if frames == 21:
		for s in ["helma", "telo", "rukavice", "kalhoty", "boty"]:
			I.equip[s] = s
		I.equip["zbran"] = "zelezny_mec"
		I.changed.emit()
		pl.hero.play("Walk", "E")
	if frames == 40:
		get_root().get_texture().get_image().save_png(out + "h2.png")
		pl.hero.play("Swordslash", "W", false, true)
	if frames == 52:
		get_root().get_texture().get_image().save_png(out + "h3.png")
		quit()
	return false
