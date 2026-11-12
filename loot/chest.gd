class_name Chest3D
extends Node3D
## Truhla: E / Enter / mezerník. Zamčená se páčí minihrou (potřebuješ paklíč). Pak vybereš kořist.

@export_range(0, 3) var lock_level := 1  ## 0 odemčeno, 1 lehký, 2 střední, 3 těžký zámek
@export var loot: Array = []  ## [["helma", 1], ["gold", 50]]
var opened := false
var unlocked := false
var _hint: Label3D
var _panel: CanvasLayer


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("interactable")
	unlocked = lock_level == 0
	_hint = Label3D.new()
	_hint.text = "[E] Truhla"
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = true
	_hint.font_size = 56
	_hint.pixel_size = 0.006
	_hint.outline_size = 12
	_hint.position = Vector3(0, 1.9, 0)
	_hint.visible = false
	add_child(_hint)


func _process(_dt: float) -> void:
	if _hint == null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	_hint.visible = p != null and not opened and p.global_position.distance_to(global_position) < 2.6
	_hint.text = "[E] Páčit zámek" if not unlocked else "[E] Otevřít"


func interact(_who: Node) -> void:
	var dlg := get_node("/root/Dialogue")
	var inv := get_node("/root/Inventory")
	if opened:
		dlg.say(PackedStringArray(["Truhla je prázdná."]), "")
		return
	if not unlocked:
		if inv.count("paklic") <= 0:
			dlg.say(PackedStringArray(["Truhla je zamčená.", "Potřebuješ paklíč."]), "")
			return
		var lp := preload("res://loot/lockpick.gd").new()
		lp.level = lock_level
		lp.finished.connect(_on_lock)
		get_tree().root.add_child(lp)
		get_tree().paused = true
		return
	_show_loot()


func _on_lock(ok: bool) -> void:
	get_tree().paused = false
	if ok:
		unlocked = true
		_show_loot()
	else:
		get_node("/root/Dialogue").say(PackedStringArray(["Zámek se nepodařilo otevřít."]), "")


func _show_loot() -> void:
	opened = true
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.08, 0.12)
	tw.tween_property(self, "scale", scale, 0.12)
	_panel = CanvasLayer.new()
	_panel.layer = 92
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_panel)
	get_tree().paused = true
	var inv := get_node("/root/Inventory")
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.95)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -220
	pc.offset_right = 220
	pc.offset_top = -170
	pc.offset_bottom = 170
	_panel.add_child(pc)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var t := Label.new()
	t.text = "KOŘIST"
	t.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vb.add_child(t)
	for l in loot:
		var id: String = l[0]
		var n: int = int(l[1]) if l.size() > 1 else 1
		var h := HBoxContainer.new()
		var it: Dictionary = inv.ITEMS.get(id, {})
		if it.get("icon", "") != "":
			var tr := TextureRect.new()
			tr.texture = load(it.icon)
			tr.custom_minimum_size = Vector2(48, 48)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.add_child(tr)
		var lb := Label.new()
		lb.text = ("%d zlata" % n) if id == "gold" else ("%s%s" % [it.get("name", id), " ×%d" % n if n > 1 else ""])
		h.add_child(lb)
		vb.add_child(h)
	var b := Button.new()
	b.text = "Vzít vše (E)"
	b.pressed.connect(_take)
	vb.add_child(b)
	b.grab_focus()
	_panel.set_meta("take", true)


func _unhandled_input(ev: InputEvent) -> void:
	if _panel and is_instance_valid(_panel) and ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_E or ev.keycode == KEY_ENTER or ev.keycode == KEY_ESCAPE):
		_take()


func _take() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var inv := get_node("/root/Inventory")
	for l in loot:
		inv.add(l[0], int(l[1]) if l.size() > 1 else 1)
	_panel.queue_free()
	_panel = null
	get_tree().paused = false
