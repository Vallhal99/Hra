extends CanvasLayer
## Minihra: páčení zámku. Myš / A D = natočení paklíče, držet mezerník / E / levé tlačítko = otáčet zámkem.
## Správný úhel najdeš tak, že se válec otočí úplně. Špatný úhel = paklíč se namáhá a nakonec zlomí.

signal finished(opened: bool)

var level := 1  ## 1 lehký, 2 střední, 3 těžký
var pick := 0.0
var sweet := 0.0
var tol := 18.0
var turn := 0.0
var hp := 1.0
var shake := 0.0
var msg := ""
var msg_t := 0.0
var _c: Control
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	tol = [26.0, 18.0, 11.0][clampi(level - 1, 0, 2)]
	tol += float(get_node("/root/Hero").stat("obratnost")) * 0.9
	sweet = randf_range(-60.0, 60.0)
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.draw.connect(_draw_ui)
	add_child(_c)


func _holding() -> bool:
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_ENTER)


func _input(ev: InputEvent) -> void:
	if _done:
		return
	if ev is InputEventMouseMotion:
		var w := get_viewport().get_visible_rect().size.x
		pick = clampf((ev.position.x / w - 0.5) * 2.0 * 95.0, -90.0, 90.0)
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		_end(false)


func _process(dt: float) -> void:
	if _done:
		return
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pick = maxf(pick - 70.0 * dt, -90.0)
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pick = minf(pick + 70.0 * dt, 90.0)
	var dist := absf(pick - sweet)
	var max_turn := 1.0
	if dist > tol * 0.5:
		max_turn = 0.62 * clampf(1.0 - (dist - tol * 0.5) / (tol * 2.6), 0.0, 1.0)
	shake = 0.0
	if _holding():
		turn += 1.1 * dt
		if turn > max_turn:
			turn = max_turn
			shake = 1.0
			hp -= dt * 0.85
			if hp <= 0.0:
				_break()
		if turn >= 0.999:
			_end(true)
	else:
		turn = maxf(turn - 3.0 * dt, 0.0)
		hp = minf(hp + 0.5 * dt, 1.0)
	msg_t = maxf(msg_t - dt, 0.0)
	_c.queue_redraw()


func _break() -> void:
	var inv := get_node("/root/Inventory")
	inv.remove("paklic")
	hp = 1.0
	turn = 0.0
	if inv.count("paklic") <= 0:
		msg = "Poslední paklíč se zlomil…"
		_end(false)
	else:
		msg = "Paklíč se zlomil!"
		msg_t = 1.6


func _end(ok: bool) -> void:
	_done = true
	finished.emit(ok)
	queue_free()


func _draw_ui() -> void:
	var vs := _c.size
	_c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72))
	var ctr := vs * 0.5 + Vector2(0, -10)
	if shake > 0.0:
		ctr += Vector2(randf_range(-3, 3), randf_range(-3, 3))
	var f := ThemeDB.fallback_font
	_c.draw_circle(ctr, 150, Color(0.22, 0.2, 0.18))
	_c.draw_arc(ctr, 150, 0, TAU, 64, Color(0.7, 0.62, 0.4), 6.0)
	_c.draw_circle(ctr, 120, Color(0.12, 0.11, 0.1))
	# válec s klíčovou dírkou, otáčí se podle turn
	var ang := deg_to_rad(turn * 90.0)
	var cyl := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		cyl.append(ctr + Vector2(cos(a), sin(a)) * 100.0)
	_c.draw_colored_polygon(cyl, Color(0.55, 0.47, 0.28))
	var kx := Vector2(0, 1).rotated(ang)
	var ky := Vector2(1, 0).rotated(ang)
	var key_pts := PackedVector2Array([ctr - ky * 10.0 - kx * 38.0, ctr + ky * 10.0 - kx * 38.0, ctr + ky * 10.0 + kx * 12.0, ctr - ky * 10.0 + kx * 12.0])
	_c.draw_colored_polygon(key_pts, Color(0.05, 0.05, 0.05))
	_c.draw_circle(ctr + kx * -38.0, 14.0, Color(0.05, 0.05, 0.05))
	# paklíč
	var d := Vector2(sin(deg_to_rad(pick)), cos(deg_to_rad(pick)))
	var pc := Color(0.85, 0.85, 0.9) if hp > 0.4 else Color(1.0, 0.5, 0.4)
	var j := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 2.0 * shake
	_c.draw_line(ctr + j, ctr + d * 230.0 + j, pc, 6.0)
	_c.draw_line(ctr + j, ctr - d * 8.0 + j, pc, 8.0)
	# stav
	var inv := get_node("/root/Inventory")
	_c.draw_string(f, Vector2(vs.x * 0.5 - 300, 70), "PÁČENÍ ZÁMKU  –  %s" % ["lehký", "střední", "těžký"][clampi(level - 1, 0, 2)], HORIZONTAL_ALIGNMENT_CENTER, 600, 30, Color(1, 0.9, 0.4))
	_c.draw_string(f, Vector2(vs.x * 0.5 - 300, vs.y - 90), "Myš / A D: paklíč    Mezerník / E / levé tl.: otáčet    Esc: vzdát se", HORIZONTAL_ALIGNMENT_CENTER, 600, 18, Color(0.8, 0.85, 1))
	_c.draw_string(f, Vector2(vs.x * 0.5 - 300, vs.y - 60), "Paklíčů: %d    Pevnost paklíče:" % inv.count("paklic"), HORIZONTAL_ALIGNMENT_CENTER, 440, 18, Color.WHITE)
	_c.draw_rect(Rect2(vs.x * 0.5 + 150, vs.y - 76, 120, 14), Color(0.2, 0.2, 0.25))
	_c.draw_rect(Rect2(vs.x * 0.5 + 150, vs.y - 76, 120 * hp, 14), Color(0.5, 0.9, 0.5) if hp > 0.4 else Color(0.95, 0.4, 0.3))
	if msg_t > 0.0:
		_c.draw_string(f, Vector2(vs.x * 0.5 - 300, vs.y * 0.5 + 220), msg, HORIZONTAL_ALIGNMENT_CENTER, 600, 26, Color(1, 0.55, 0.45))
