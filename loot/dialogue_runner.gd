extends CanvasLayer
## Autoload "DialogueRunner": větvené dialogy z gamedata.json (volby, podmínky, efekty).

var _panel: PanelContainer
var _name: Label
var _text: Label
var _box: VBoxContainer
var _dlg: Dictionary = {}
var active := false


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS


func start(id: String, speaker := "") -> void:
	if active or not GameData.dialogues.has(id):
		return
	_dlg = GameData.dialogues[id]
	active = true
	get_tree().paused = true
	_build()
	_goto(_dlg.get("start", ""), speaker)


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.95)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -280
	_panel.offset_bottom = -24
	add_child(_panel)
	var vb := VBoxContainer.new()
	_panel.add_child(vb)
	_name = Label.new()
	_name.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vb.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 60)
	_text.add_theme_font_size_override("font_size", 20)
	vb.add_child(_text)
	_box = VBoxContainer.new()
	vb.add_child(_box)


func _cond_ok(c: Dictionary) -> bool:
	var Q := get_node("/root/Quests")
	var H := get_node("/root/Hero")
	var I := get_node("/root/Inventory")
	for k in c:
		var v = c[k]
		match k:
			"quest_active":
				if not Q.is_active(v): return false
			"quest_not_started":
				if Q.state.has(v): return false
			"quest_done":
				if not Q.is_done(v): return false
			"quest_ready":
				if not Q.ready_to_complete(v): return false
			"flag":
				if not Q.flags.get(v, false): return false
			"no_flag":
				if Q.flags.get(v, false): return false
			"has_item":
				if I.count(v[0]) < int(v[1]): return false
			"level_min":
				if H.level < int(v): return false
			"class":
				if H.class_id != v: return false
			"gold_min":
				if I.gold < int(v): return false
	return true


func _apply(effects: Array) -> void:
	var Q := get_node("/root/Quests")
	var I := get_node("/root/Inventory")
	for e in effects:
		for k in e:
			var v = e[k]
			match k:
				"start_quest": Q.start(v)
				"complete_quest": Q.complete(v)
				"set_flag": Q.set_flag(v, true)
				"give_item": I.add(v[0], int(v[1]))
				"take_item": I.remove(v[0], int(v[1]))
				"gold": I.add("gold", int(v))
				"xp": get_node("/root/Hero").add_xp(int(v))
				"shop":
					_close()
					preload("res://loot/shop.gd").open(get_tree(), v)
					return


func _goto(nid: String, speaker := "") -> void:
	var n: Dictionary = _dlg._nodes.get(nid, {})
	if n.is_empty():
		_close()
		return
	_name.text = n.get("speaker", speaker)
	_text.text = n.get("text", "")
	for c in _box.get_children():
		c.queue_free()
	_apply(n.get("effects", []))
	if not active:
		return
	var shown := 0
	for ch in n.get("choices", []):
		if not _cond_ok(ch.get("cond", {})):
			continue
		shown += 1
		var b := Button.new()
		b.text = ch.text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			_apply(ch.get("effects", []))
			if active:
				_goto(ch.get("next", ""), speaker))
		_box.add_child(b)
		if shown == 1:
			b.grab_focus.call_deferred()
	if shown == 0:
		var b := Button.new()
		b.text = "Pokračovat"
		var nx: String = n.get("next", "")
		b.pressed.connect(func(): _goto(nx, speaker) if nx != "" else _close())
		_box.add_child(b)
		b.grab_focus.call_deferred()


func _close() -> void:
	active = false
	if _panel:
		_panel.queue_free()
		_panel = null
	get_tree().paused = false
