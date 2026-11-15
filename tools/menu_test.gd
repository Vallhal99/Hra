extends SceneTree
var t := 0
func _initialize() -> void:
	get_root().get_node("Hero").class_id = "mag"
	get_root().get_node("Hero").level = 6
	get_root().get_node("Inventory").equip = {"helma": "helma", "telo": "telo", "zbran": "luk"}
	get_root().get_node("Inventory").dura = {"helma": 40.0, "telo": 12.0}
	var P := get_root().get_node("Party")
	P.recruit("brum", true)
	print("ITEMS ", get_root().get_node("Inventory").ITEMS.size())
	PartyMenu.open(self, int(OS.get_cmdline_user_args()[1]))
func _process(_d: float) -> bool:
	t += 1
	if t == 8:
		get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		quit()
	return false
