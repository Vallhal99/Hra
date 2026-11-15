class_name MapEnemy
extends Node3D
## Nepřítel na mapě: hlídkuje, vidí v zorném poli, pronásleduje. Způsob vstupu do boje závisí na tom,
## jak se k němu hráč dostane: zezadu = záloha (ambush), z boku = flank, past = trap, utíkající hráč = ambushed.

@export var kinds: PackedStringArray = PackedStringArray(["slime"])
@export var sight := 7.0
@export var fov := 120.0
@export var patrol := 3.0
@export var speed := 1.3
@export var chase_speed := 3.0
@export var respawn := 240.0

static var gone: Dictionary = {}          ## klíč -> čas poražení (unix)
static var alert_until: Dictionary = {}   ## klíč -> do kdy je znovu na lovu (po útěku)

var _home := Vector3.ZERO
var _face := Vector3.RIGHT
var _state := "patrol"
var _wait := 0.0
var _target := Vector3.ZERO
var _spr: Sprite3D
var _anim: Dictionary = {}
var _t := 0.0
var _bang: Label3D
var _key := ""
var _done := false


static func resolve(key: String, victory: bool, fled: bool) -> void:
	if key == "":
		return
	if victory and not fled:
		gone[key] = Time.get_unix_time_from_system()
	elif fled:
		alert_until[key] = Time.get_unix_time_from_system() + 12.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_key = get_tree().current_scene.scene_file_path + "/" + String(name) if get_tree().current_scene else String(name)
	if gone.has(_key):
		if Time.get_unix_time_from_system() - float(gone[_key]) < respawn:
			queue_free()
			return
		gone.erase(_key)
	_home = global_position
	_target = _home
	var u := BattleUnit.make_kind(kinds[0])
	_spr = Sprite3D.new()
	var tex: Texture2D = u.texture
	var hf := u.hframes
	if u.anims.has("Idle"):
		tex = u.anims["Idle"]["tex"]
		hf = int(u.anims["Idle"]["frames"])
		_anim = u.anims["Idle"]
	_spr.texture = tex
	_spr.hframes = hf
	_spr.pixel_size = 1.0 / u.ppm
	_spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_spr.shaded = true
	_spr.double_sided = true
	_spr.position.y = tex.get_height() * 0.5 / u.ppm
	add_child(_spr)
	add_child(HD2DSprite.blob_shadow())
	_bang = Label3D.new()
	_bang.text = "!"
	_bang.font_size = 96
	_bang.pixel_size = 0.012
	_bang.modulate = Color(1, 0.3, 0.2)
	_bang.outline_size = 16
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.no_depth_test = true
	_bang.position.y = tex.get_height() / u.ppm + 0.5
	_bang.visible = false
	add_child(_bang)
	if alert_until.get(_key, 0.0) > Time.get_unix_time_from_system():
		_set_state("chase")


func _set_state(s: String) -> void:
	_state = s
	if s == "chase":
		_bang.visible = true
		_bang.scale = Vector3.ONE * 0.2
		create_tween().tween_property(_bang, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	else:
		_bang.visible = false


func _ground(p: Vector3) -> Vector3:
	var sp := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 4, 0), p + Vector3(0, -6, 0))
	var r := sp.intersect_ray(q)
	if r:
		p.y = r.position.y
	return p


func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint() or _spr == null or _done:
		return
	var bm := get_node_or_null("/root/BattleManager")
	if bm and bm.active:
		return
	var dlg := get_node_or_null("/root/Dialogue")
	if dlg and dlg.active:
		return
	_t += dt
	if _anim.has("fps") and _spr.hframes > 1:
		_spr.frame = int(_t * float(_anim["fps"])) % _spr.hframes
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var to := pl.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	# traps
	for tr in get_tree().get_nodes_in_group("traps"):
		if (tr as Node3D).global_position.distance_to(global_position) < 0.9:
			tr.queue_free()
			_trigger("trap")
			return
	if _state == "patrol":
		_wait -= dt
		var move := _target - global_position
		move.y = 0.0
		if move.length() < 0.2:
			if _wait <= 0.0:
				_wait = randf_range(1.5, 4.0)
				var a := randf() * TAU
				_target = _home + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, patrol)
		elif _wait <= 0.0 or true:
			_face = move.normalized()
			global_position = _ground(global_position + _face * speed * dt)
		if dist < sight and dist > 0.01:
			var ang := rad_to_deg(_face.angle_to(to.normalized()))
			if ang < fov * 0.5:
				_set_state("chase")
		if dist < 1.3:
			var ang2 := rad_to_deg(_face.angle_to(to.normalized()))
			_trigger("ambush" if ang2 > 120.0 else "flank")
			return
	elif _state == "chase":
		if dist > sight * 1.9:
			_set_state("patrol")
			return
		if dist > 0.01:
			_face = to.normalized()
			global_position = _ground(global_position + _face * chase_speed * dt)
		if dist < 1.1:
			var v := Vector3(pl.velocity.x, 0, pl.velocity.z) if "velocity" in pl else Vector3.ZERO
			var fleeing := v.length() > 1.0 and v.normalized().dot(to.normalized()) > 0.5  ## hráč běží pryč od nepřítele
			_trigger("ambushed" if fleeing else "normal")


func _trigger(how: String) -> void:
	if _done:
		return
	var bm := get_node_or_null("/root/BattleManager")
	if bm == null or bm.active:
		return
	_done = true
	var foes: Array = []
	for k in kinds:
		foes.append(BattleUnit.make_kind(k))
	bm.source_key = _key
	bm.start([], foes, how)
