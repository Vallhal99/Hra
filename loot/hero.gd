extends Node
## Autoload "Hero": povolání, level, zkušenosti, rozdávání bodů. Na začátku hry vybereš povolání.

signal changed
signal leveled(level: int)

var class_id := ""
var level := 1
var xp := 0
var points := 0
var invested: Dictionary = {}
var skip_select := false
var _ui: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_maybe_select")


func _maybe_select() -> void:
	if class_id != "" or skip_select or DisplayServer.get_name() == "headless":
		return
	var sc := get_tree().current_scene
	if sc == null or sc.scene_file_path.find("louka") < 0:
		return
	show_select()


func cls() -> Dictionary:
	return GameData.class_by_id(class_id)


func stat(s: String) -> int:
	var c := cls()
	var v := int(c.get("stats", {}).get(s, 0)) + int(invested.get(s, 0))
	v += int(c.get("growth", {}).get(s, 0)) * (level - 1)
	return v


func bonus(k: String) -> int:
	var t := 0
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		for slot in inv.equip:
			var id = inv.equip[slot]
			if id != null and inv.ITEMS.has(id):
				t += int(inv.ITEMS[id].get(k, 0))
	return t


func max_hp() -> int:
	return 20 + stat("vitalita") * 6 + (level - 1) * 4 + bonus("hp")


func max_sp() -> int:
	return 5 + stat("inteligence") * 3 + bonus("sp")


func atk() -> int:
	return stat("sila") * 2 + bonus("atk")


func defense() -> int:
	return stat("vitalita") + bonus("def")


func spd() -> int:
	return int(stat("obratnost") * 1.5)


func xp_next() -> int:
	return int(round(float(GameData.prog.xp_base) * pow(level, float(GameData.prog.xp_exp))))


func add_xp(n: int) -> void:
	if class_id == "":
		return
	xp += n
	while level < int(GameData.prog.max_level) and xp >= xp_next():
		xp -= xp_next()
		level += 1
		points += int(GameData.prog.points_per_level)
		leveled.emit(level)
	changed.emit()


func spend(s: String) -> void:
	if points <= 0:
		return
	points -= 1
	invested[s] = int(invested.get(s, 0)) + 1
	changed.emit()


func choose(id: String) -> void:
	class_id = id
	var c := cls()
	var inv := get_node_or_null("/root/Inventory")
	if inv:
		for it in c.get("items", []):
			inv.add(it)
			if inv.ITEMS.has(it) and inv.ITEMS[it].slot != "" and inv.equip.get(inv.ITEMS[it].slot) == null:
				inv.equip[inv.ITEMS[it].slot] = it
	changed.emit()


func show_select() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 98
	add_child(_ui)
	get_tree().paused = true
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.1, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 60
	vb.offset_right = -60
	vb.offset_top = 40
	vb.offset_bottom = -40
	vb.add_theme_constant_override("separation", 16)
	bg.add_child(vb)
	var t := Label.new()
	t.text = "VYBER SI POVOLÁNÍ"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(g)
	for c in GameData.classes:
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 150)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var st := ""
		for k in c.stats:
			st += "%s %d   " % [GameData.stat_names.get(k, k), c.stats[k]]
		b.text = "%s\n\n%s\n\n%s" % [c.name, c.desc, st]
		b.add_theme_font_size_override("font_size", 19)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func():
			choose(c.id)
			_ui.queue_free()
			get_tree().paused = false)
		g.add_child(b)
