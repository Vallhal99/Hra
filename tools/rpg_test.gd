extends SceneTree
var frames := 0
var out := "/tmp/claude-0/-home-claude/dc0fae54-8a83-52be-878a-e01eee3d19d7/scratchpad/"
func _initialize() -> void:
	get_root().get_node("Hero").skip_select = true
	var sc = (load("res://scenes/louka.tscn") as PackedScene).instantiate()
	get_root().add_child(sc)
func _process(_d: float) -> bool:
	frames += 1
	var H = get_root().get_node("Hero"); var Q = get_root().get_node("Quests"); var I = get_root().get_node("Inventory"); var DR = get_root().get_node("DialogueRunner")
	if frames == 5:
		H.show_select()
	if frames == 15:
		get_root().get_texture().get_image().save_png(out + "r1.png")
		H.choose("mag"); H._ui.queue_free(); paused = false
		print("class ", H.class_id, " hp ", H.max_hp(), " sp ", H.max_sp(), " atk ", H.atk(), " bag ", I.bag)
		H.add_xp(100); print("level ", H.level, " points ", H.points, " xp ", H.xp, "/", H.xp_next())
		H.spend("sila"); print("sila ", H.stat("sila"))
		DR.start("obchodnik")
	if frames == 25:
		get_root().get_texture().get_image().save_png(out + "r2.png")
		# vybrat 2. volbu (Nemáš práci)
		DR._box.get_child(1).pressed.emit()
	if frames == 30:
		DR._box.get_child(0).pressed.emit()  # Postarám se
		print("quest active ", Q.is_active("kufr"))
		DR._close()
		Q.event("chest_open")
		print("ready ", Q.ready_to_complete("kufr"))
		DR.start("obchodnik")
	if frames == 40:
		print("choices: ", DR._box.get_child_count())
		DR._box.get_child(1).pressed.emit()  # Truhlu jsem otevrel (index zavisi)
	if frames == 45:
		print("quest done ", Q.is_done("kufr"), " gold ", I.gold, " xp ", H.xp, " lvl ", H.level, " bag ", I.bag)
		DR._close()
		var sh = load("res://loot/shop.gd"); sh.open(self, "obchodnik")
	if frames == 55:
		get_root().get_texture().get_image().save_png(out + "r3.png")
		I._toggle()
	if frames == 65:
		get_root().get_texture().get_image().save_png(out + "r4.png")
		quit()
	return false
