extends Node
## Autoload "Quests": stav úkolů, události, odměny. Klávesa J = deník úkolů.

signal changed

var state: Dictionary = {}  # id -> {"state": "active"/"done", "prog": {index: počet}}
var flags: Dictionary = {}
var _ui: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = CanvasLayer.new()
	_ui.layer = 81
	_ui.visible = false
	add_child(_ui)
	call_deferred("_hook")


func _hook() -> void:
	get_node("/root/Inventory").changed.connect(func(): changed.emit())


func start(id: String) -> void:
	if GameData.quests.has(id) and not state.has(id):
		state[id] = {"state": "active", "prog": {}}
		changed.emit()


func is_active(id: String) -> bool:
	return state.has(id) and state[id].state == "active"


func is_done(id: String) -> bool:
	return state.has(id) and state[id].state == "done"


func progress(id: String, i: int) -> int:
	var q: Dictionary = GameData.quests.get(id, {})
	var o: Dictionary = q.objectives[i]
	match o.get("type", "event"):
		"collect":
			return mini(get_node("/root/Inventory").count(o.target), int(o.get("count", 1)))
		"flag":
			return 1 if flags.get(o.target, false) else 0
		_:
			return mini(int(state[id].prog.get(str(i), 0)), int(o.get("count", 1)))


func ready_to_complete(id: String) -> bool:
	if not is_active(id):
		return false
	var q: Dictionary = GameData.quests[id]
	for i in q.objectives.size():
		var need := 1 if q.objectives[i].get("type", "event") == "flag" else int(q.objectives[i].get("count", 1))
		if progress(id, i) < need:
			return false
	return true


func event(ev_name: String, n := 1) -> void:
	for id in state:
		if state[id].state != "active":
			continue
		var q: Dictionary = GameData.quests[id]
		for i in q.objectives.size():
			var o: Dictionary = q.objectives[i]
			if o.get("type", "event") in ["event", "kill"] and o.target == ev_name:
				state[id].prog[str(i)] = int(state[id].prog.get(str(i), 0)) + n
	changed.emit()


func set_flag(f: String, v := true) -> void:
	flags[f] = v
	changed.emit()


func complete(id: String) -> bool:
	if not ready_to_complete(id):
		return false
	var q: Dictionary = GameData.quests[id]
	for o in q.objectives:
		if o.get("type", "") == "collect" and o.get("take", true):
			get_node("/root/Inventory").remove(o.target, int(o.get("count", 1)))
	state[id].state = "done"
	var r: Dictionary = q.get("rewards", {})
	var inv := get_node("/root/Inventory")
	inv.gold += int(r.get("gold", 0))
	for it in r.get("items", []):
		inv.add(it[0], int(it[1]))
	get_node("/root/Hero").add_xp(int(r.get("xp", 0)))
	inv.changed.emit()
	changed.emit()
	return true


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_J:
		_ui.visible = not _ui.visible
		get_tree().paused = _ui.visible
		if _ui.visible:
			_build()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and _ui.visible:
		_ui.visible = false
		get_tree().paused = false


func _build() -> void:
	for c in _ui.get_children():
		c.queue_free()
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.95)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -330
	pc.offset_right = 330
	pc.offset_top = -200
	pc.offset_bottom = 200
	_ui.add_child(pc)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var t := Label.new()
	t.text = "DENÍK ÚKOLŮ   (J / Esc = zavřít)"
	t.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vb.add_child(t)
	var any := false
	for id in state:
		any = true
		var q: Dictionary = GameData.quests[id]
		var l := Label.new()
		l.text = "%s %s" % ["✔" if state[id].state == "done" else "◆", q.name]
		l.add_theme_font_size_override("font_size", 20)
		vb.add_child(l)
		var d := Label.new()
		d.text = q.get("desc", "")
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.add_theme_color_override("font_color", Color(0.75, 0.82, 1))
		vb.add_child(d)
		if state[id].state == "active":
			for i in q.objectives.size():
				var o: Dictionary = q.objectives[i]
				var o_l := Label.new()
				o_l.text = "   • %s  (%d/%d)" % [o.text, progress(id, i), int(o.get("count", 1))]
				vb.add_child(o_l)
			if ready_to_complete(id):
				var r := Label.new()
				r.text = "   → Vrať se za zadavatelem: %s" % q.get("giver", "")
				r.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
				vb.add_child(r)
	if not any:
		var e := Label.new()
		e.text = "Zatím nemáš žádné úkoly."
		vb.add_child(e)
