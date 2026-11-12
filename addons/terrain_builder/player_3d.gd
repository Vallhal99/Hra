@tool
class_name Player3D
extends CharacterBody3D
## Hráč. WASD/šipky, Shift = běh, E/Enter/mezerník = mluvit.
## Spritesheet: vframes = 4 řádky (0 dolů, 1 nahoru, 2 vlevo, 3 vpravo), hframes = políčka chůze (sloupec 0 = stání).
## Bez spritesheetu (vframes = 1) se postava při chůzi doleva překlápí.

@export var sprite_texture: Texture2D
@export var hframes := 1
@export var vframes := 1
@export var anim_fps := 8.0
@export var speed := 4.0
@export var run_speed := 7.0
@export var step_height := 0.55
@export var gravity := 20.0

var sprite: Sprite3D
var _t := 0.0
var _row := 0


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.9
	cs.shape = cap
	cs.position.y = 0.45
	add_child(cs)
	sprite = HD2DSprite.make(sprite_texture if sprite_texture else HD2DSprite.placeholder(Color(0.8, 0.3, 0.2)), hframes, vframes)
	add_child(sprite)
	add_child(HD2DSprite.blob_shadow())


func _k(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _unhandled_input(ev: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.active:
		return
	var press: bool = ev.is_action_pressed("ui_accept") or (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_E)
	if not press:
		return
	var best: Node = null
	var bd := 1.8
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null:
			continue
		var d := Vector2(n3.global_position.x - global_position.x, n3.global_position.z - global_position.z).length()
		if d < bd:
			bd = d
			best = n
	if best and best.has_method("interact"):
		best.interact(self)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var sm := get_node_or_null("/root/SceneManager")
	var dlg := get_node_or_null("/root/Dialogue")
	var dir := Vector2.ZERO
	if not ((sm and sm.busy) or (dlg and dlg.active)):
		if _k(KEY_W) or _k(KEY_UP): dir.y -= 1
		if _k(KEY_S) or _k(KEY_DOWN): dir.y += 1
		if _k(KEY_A) or _k(KEY_LEFT): dir.x -= 1
		if _k(KEY_D) or _k(KEY_RIGHT): dir.x += 1
	dir = dir.normalized()
	var cam := get_viewport().get_camera_3d()
	var yaw := cam.global_rotation.y if cam else 0.0
	var move := Vector3(dir.x, 0, dir.y).rotated(Vector3.UP, yaw)
	var sp := run_speed if _k(KEY_SHIFT) else speed
	velocity.x = move.x * sp
	velocity.z = move.z * sp
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	if is_on_floor() and move.length() > 0.0:
		var mo := move * sp * delta * 2.0
		if test_move(global_transform, mo) and not test_move(global_transform.translated(Vector3.UP * step_height), mo):
			global_position.y += step_height
	move_and_slide()
	_animate(dir, delta)


func _animate(dir: Vector2, delta: float) -> void:
	var rows := vframes >= 4
	if dir != Vector2.ZERO:
		if rows:
			if absf(dir.x) > absf(dir.y):
				_row = 2 if dir.x < 0 else 3
			else:
				_row = 1 if dir.y < 0 else 0
		elif dir.x != 0.0:
			sprite.flip_h = dir.x < 0.0
		_t += delta * anim_fps
		var col := 0
		if hframes > 1:
			col = 1 + int(_t) % (hframes - 1)
		sprite.frame_coords = Vector2i(col, _row if rows else 0)
	else:
		_t = 0.0
		sprite.frame_coords = Vector2i(0, _row if rows else 0)
