extends CanvasLayer
## Autoload "Dialogue": okno s textem ve stylu Octopath. Dialogue.say(PackedStringArray, "Jméno")

signal finished
var active := false
var _panel: PanelContainer
var _name: Label
var _text: Label
var _lines := PackedStringArray()
var _i := 0
var _tw: Tween


func _ready() -> void:
	layer = 90
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.93)
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
	_panel.offset_top = -170
	_panel.offset_bottom = -24
	var vb := VBoxContainer.new()
	_name = Label.new()
	_name.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vb.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 70)
	vb.add_child(_text)
	_panel.add_child(vb)
	_panel.visible = false
	add_child(_panel)


func say(lines: PackedStringArray, speaker := "") -> void:
	if active or lines.is_empty():
		return
	active = true
	_lines = lines
	_i = 0
	_name.text = speaker
	_panel.visible = true
	_show()


func _show() -> void:
	_text.text = _lines[_i]
	_text.visible_ratio = 0.0
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_text, "visible_ratio", 1.0, maxf(0.2, _lines[_i].length() * 0.03))


func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	var press: bool = ev.is_action_pressed("ui_accept") or (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_E)
	if not press:
		return
	get_viewport().set_input_as_handled()
	if _text.visible_ratio < 1.0:
		if _tw:
			_tw.kill()
		_text.visible_ratio = 1.0
		return
	_i += 1
	if _i >= _lines.size():
		active = false
		_panel.visible = false
		finished.emit()
	else:
		_show()
