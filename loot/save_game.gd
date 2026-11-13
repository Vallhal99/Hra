extends Node
## Autoload "SaveGame": 3 sloty ukládání, nová hra, načtení, pauza (Esc) s menu.

const SLOTS := 3
const FIRST_SCENE := "res://scenes/louka.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
var _layer: CanvasLayer
var _panel: Control
var _msg: Label


func path(slot: int) -> String:
	return "user://save_%d.json" % slot


func info(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return d if d is Dictionary else {}


func any_save() -> bool:
	for i in SLOTS:
		if not info(i + 1).is_empty():
			return true
	return false


func reset_state() -> void:
	Hero.class_id = ""
	Hero.level = 1
	Hero.xp = 0
	Hero.points = 0
	Hero.invested = {}
	Inventory.bag = {"paklic": 3}
	Inventory.equip = {}
	Inventory.gold = 25
	Quests.state = {}
	Quests.flags = {}
	Inventory.changed.emit()
	Hero.changed.emit()
	Quests.changed.emit()


func save(slot: int) -> bool:
	var sc := get_tree().current_scene
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if sc == null or p == null:
		return false
	var d := {
		"time": Time.get_datetime_string_from_system(false, true),
		"scene": sc.scene_file_path,
		"pos": [p.global_position.x, p.global_position.y, p.global_position.z],
		"hero": {"class_id": Hero.class_id, "level": Hero.level, "xp": Hero.xp, "points": Hero.points, "invested": Hero.invested},
		"inv": {"bag": Inventory.bag, "equip": Inventory.equip, "gold": Inventory.gold},
		"quests": {"state": Quests.state, "flags": Quests.flags},
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


func new_game() -> void:
	reset_state()
	_close()
	await SceneManager.go(FIRST_SCENE, "Start")
	Hero.show_select()


func load_slot(slot: int) -> void:
	var d := info(slot)
	if d.is_empty():
		return
	reset_state()
	var h: Dictionary = d.get("hero", {})
	Hero.class_id = h.get("class_id", "")
	Hero.level = int(h.get("level", 1))
	Hero.xp = int(h.get("xp", 0))
	Hero.points = int(h.get("points", 0))
	Hero.invested = h.get("invested", {})
	var iv: Dictionary = d.get("inv", {})
	Inventory.bag = {}
	for k in iv.get("bag", {}):
		Inventory.bag[k] = int(iv["bag"][k])
	Inventory.equip = iv.get("equip", {})
	Inventory.gold = int(iv.get("gold", 0))
	var q: Dictionary = d.get("quests", {})
	Quests.state = q.get("state", {})
	Quests.flags = q.get("flags", {})
	_close()
	await SceneManager.go(d.get("scene", FIRST_SCENE), "")
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var a: Array = d.get("pos", [])
	if p and a.size() == 3:
		p.global_position = Vector3(a[0], a[1] + 0.2, a[2])
		get_tree().call_group("camera_follow", "snap")
	Inventory.changed.emit()
	Hero.changed.emit()
	Quests.changed.emit()


func to_menu() -> void:
	_close()
	await SceneManager.go(MENU_SCENE, "")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		var sc := get_tree().current_scene
		if sc == null or sc.scene_file_path == MENU_SCENE or not get_tree().get_first_node_in_group("player"):
			return
		if _panel:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_layer.add_child(_panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(320, 0)
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var t := Label.new()
	t.text = "Pauza"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	v.add_child(t)
	var b := Button.new()
	b.text = "Pokračovat"
	b.pressed.connect(_close)
	v.add_child(b)
	for i in SLOTS:
		var sl := i + 1
		var bs := Button.new()
		bs.text = "Uložit do slotu %d  %s" % [sl, _slot_text(sl)]
		bs.pressed.connect(func():
			_msg.text = "Uloženo do slotu %d." % sl if save(sl) else "Uložení selhalo."
			bs.text = "Uložit do slotu %d  %s" % [sl, _slot_text(sl)])
		v.add_child(bs)
	var bm := Button.new()
	bm.text = "Hlavní menu"
	bm.pressed.connect(to_menu)
	v.add_child(bm)
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_msg)
	_panel.position -= Vector2(160, 150)
	b.grab_focus()


func _slot_text(sl: int) -> String:
	var d := info(sl)
	if d.is_empty():
		return "(prázdný)"
	return "(%s, úr. %d)" % [str(d.get("time", "")).replace("T", " "), int(d.get("hero", {}).get("level", 1))]


func _close() -> void:
	get_tree().paused = false
	if _layer:
		_layer.queue_free()
	_layer = null
	_panel = null
