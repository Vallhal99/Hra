class_name PartyTrail
extends Node
## Druzina chodi za hrdinou po mape: kazdy clen jde po stope hrdiny se zpozdenim.
## Vytvari ho Player3D; clenove jsou deti rodice hrace (ne hrace), aby se neotacela kamera.

const DELAY := 0.75        ## s mezi cleny
const SAMPLE := 0.05
var player: Node3D
var _hist: Array = []      ## [{t, p}]
var _t := 0.0
var _acc := 0.0
var _fol: Array = []       ## [{id, node, act, last}]


func _ready() -> void:
	player = get_parent() as Node3D
	call_deferred("_spawn")


func _spawn() -> void:
	var P := get_node_or_null("/root/Party")
	if P == null or player == null or not player.is_inside_tree():
		return
	var i := 0
	for id in P.order:
		var d: Dictionary = P.DEFS[id]
		var n := Node3D.new()
		n.name = "Follower_" + str(id)
		player.get_parent().add_child(n)
		n.global_position = player.global_position
		var act: AnimActor = null
		if d.has("char") and AnimActor.has_char(d.char):
			act = AnimActor.new()
			act.char_id = d.char
			act.ppm = float(d.get("ppm", 115.0))
			n.add_child(act)
		else:
			var s := HD2DSprite.make(load(d.tex), 1, 1)
			s.pixel_size = 1.0 / float(d.ppm)
			s.position.y = s.texture.get_height() * 0.5 / float(d.ppm)
			s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			n.add_child(s)
		n.add_child(HD2DSprite.blob_shadow())
		_fol.append({"node": n, "act": act, "delay": DELAY * (i + 1), "last": n.global_position, "dir": "S"})
		i += 1
	for k in 4:
		_hist.append({"t": _t, "p": player.global_position})


func _process(dt: float) -> void:
	if player == null or not player.is_inside_tree():
		return
	_t += dt
	_acc += dt
	if _acc >= SAMPLE:
		_acc = 0.0
		_hist.append({"t": _t, "p": player.global_position})
		while _hist.size() > 2 and _t - float(_hist[1].t) > DELAY * 5.0:
			_hist.pop_front()
	var cam := get_viewport().get_camera_3d()
	for f in _fol:
		var tgt: Vector3 = _sample(_t - float(f.delay))
		var n: Node3D = f.node
		var d: Vector3 = tgt - n.global_position
		d.y = 0.0
		if d.length() > 6.0:                  # ztracena (teleport / nova scena) -> skoc k hraci
			n.global_position = tgt
			f.last = tgt
			continue
		var off: Vector3 = tgt - player.global_position
		off.y = 0.0
		if off.length() < 0.95:      # nesmi stat na hrdinovi
			var nd := off.normalized() if off.length() > 0.02 else Vector3(-1.0, 0.0, 0.35).normalized()
			tgt.x = player.global_position.x + nd.x * 0.95
			tgt.z = player.global_position.z + nd.z * 0.95
		n.global_position = tgt
		var mv: Vector3 = tgt - (f.last as Vector3)
		mv.y = 0.0
		var speed := mv.length() / maxf(dt, 0.001)
		var act: AnimActor = f.act
		if act != null:
			if speed > 0.35:
				f.dir = AnimActor.dir_of(mv, cam, f.dir)
				act.play("Walk", f.dir)
				act.speed_scale = clampf(speed / 2.6, 0.6, 1.8)
			else:
				act.play("Idle", f.dir)
				act.speed_scale = 1.0
		f.last = tgt


func _sample(t: float) -> Vector3:
	if _hist.is_empty():
		return player.global_position
	if t <= float(_hist[0].t):
		return _hist[0].p
	for i in range(_hist.size() - 1, 0, -1):
		var a: Dictionary = _hist[i - 1]
		var b: Dictionary = _hist[i]
		if t >= float(a.t):
			var u := (t - float(a.t)) / maxf(float(b.t) - float(a.t), 0.0001)
			return (a.p as Vector3).lerp(b.p, clampf(u, 0.0, 1.0))
	return _hist[_hist.size() - 1].p
