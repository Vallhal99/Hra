class_name Ending
extends RefCounted
## Závěrečná obrazovka dema.


static func show_ending(tree: SceneTree, kind: String) -> void:
	if tree.root.has_node("EndingScreen"):
		return
	var cl := CanvasLayer.new()
	cl.name = "EndingScreen"
	cl.layer = 95
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.06, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		m.add_theme_constant_override("margin_" + k, 220)
	for k in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 90)
	bg.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	m.add_child(v)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.text = Lore.ending_text(kind)
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(rt)
	var b := Button.new()
	b.text = "Pokračovat ve hře"
	b.pressed.connect(func():
		tree.paused = false
		cl.queue_free())
	v.add_child(b)
	tree.root.add_child(cl)
	tree.paused = true
	tree.create_tween().tween_property(bg, "color:a", 0.93, 1.4)
	b.grab_focus.call_deferred()
