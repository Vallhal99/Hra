extends Control
## Úvodní menu: Nová hra, Načíst, Nastavení (hlasitost / celá obrazovka), Konec.

var _main: VBoxContainer
var _load: VBoxContainer
var _opt: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# pozadí: vyrenderovaná louka (SubViewport) – jednoduchý přechod barev
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.95, 0.78, 0.45, 1), Color(0.35, 0.55, 0.3, 1), Color(0.07, 0.12, 0.08, 1)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(grad)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 10)
	cc.add_child(box)
	var title := Label.new()
	title.text = "Babrak"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "HD-2D dobrodružství"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(Control.new())
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 8)
	box.add_child(_main)
	_btn(_main, "Nová hra", func(): SaveGame.new_game())
	var bl := _btn(_main, "Načíst hru", func(): _show(_load))
	bl.disabled = not SaveGame.any_save()
	_btn(_main, "Nastavení", func(): _show(_opt))
	_btn(_main, "Konec", func(): get_tree().quit())
	_load = VBoxContainer.new()
	_load.add_theme_constant_override("separation", 8)
	box.add_child(_load)
	for i in SaveGame.SLOTS:
		var sl := i + 1
		var d := SaveGame.info(sl)
		var b := _btn(_load, "Slot %d  %s" % [sl, SaveGame._slot_text(sl)], func(): SaveGame.load_slot(sl))
		b.disabled = d.is_empty()
	_btn(_load, "Zpět", func(): _show(_main))
	_opt = VBoxContainer.new()
	_opt.add_theme_constant_override("separation", 8)
	box.add_child(_opt)
	var vl := Label.new()
	vl.text = "Hlasitost"
	_opt.add_child(vl)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	sl.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001))))
	_opt.add_child(sl)
	var fs := CheckButton.new()
	fs.text = "Celá obrazovka"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	_opt.add_child(fs)
	_btn(_opt, "Zpět", func(): _show(_main))
	_show(_main)


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _show(v: Control) -> void:
	for c in [_main, _load, _opt]:
		c.visible = c == v
	for ch in v.get_children():
		if ch is Button and not ch.disabled:
			ch.grab_focus()
			break
