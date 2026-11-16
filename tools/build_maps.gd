extends SceneTree
## Generátor map: Rozcestí, Louka u řeky, Vesnice.  Spuštění (po build_sample.gd):
##   godot --headless --path . -s res://tools/build_maps.gd

const SUN := Vector3(-48, -38, 0)
var rng := RandomNumberGenerator.new()
var nz := FastNoiseLite.new()
var nzb := FastNoiseLite.new()
var mats: Array[TerrainMat] = []
var vtypes: Array[VegType] = []
var tm: TerrainMap
var kind := {}  # 0 les, 1 louka, 2 cesta/dlažba, 3 břeh, 4 kopec
var scn: Node3D
var props: Node3D
var marks: Node3D
var noveg: Array[Rect2] = []
var bx0 := 0
var bx1 := 0
var bz0 := 0
var bz1 := 0
var lights_energy := 1.3
var indoor := false
var sun_energy := 0.95
var enemy_cfg: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	nz.seed = 5
	nz.frequency = 0.11
	nzb.seed = 21
	nzb.frequency = 0.25
	for r in Lib.list(TerrainMap.MAT_DIR):
		mats.append(r as TerrainMat)
	for r in Lib.list(VegetationLayer.VEG_DIR):
		vtypes.append(r as VegType)
	_rozcesti()
	_reka()
	_vesnice()
	_obchod()
	_hvozd()
	_jezero()
	_jeskyne()
	_hrbitov()
	_hrobka()
	print("HOTOVO")
	quit()


# ---------------- společné ----------------
func _begin(nm: String, x0: int, x1: int, z0: int, z1: int, seed_: int) -> void:
	enemy_cfg.clear()
	rng.seed = seed_
	kind.clear()
	noveg.clear()
	bx0 = x0
	bx1 = x1
	bz0 = z0
	bz1 = z1
	scn = Node3D.new()
	scn.name = nm
	tm = TerrainMap.new()
	tm.name = "TerrainMap"
	tm.materials = mats
	scn.add_child(tm)
	tm.owner = scn
	props = PropLayer.new()
	props.name = "Props"
	marks = Node3D.new()
	marks.name = "Marks"
	tm.add_child(props)
	props.owner = scn
	tm.add_child(marks)
	marks.owner = scn


func _forest(c: Vector2i, hi := 3) -> void:
	var lvl := hi + (1 if nz.get_noise_2d(c.x * 0.45, c.y * 0.45) > 0.1 else 0)
	tm.cells[c] = Vector2i(lvl, 7 if nzb.get_noise_2d(c.x, c.y) > -0.15 else 1)
	kind[c] = 0


func _mark(nm: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	marks.add_child(m)
	m.owner = scn


func _exit(nm: String, pos: Vector3, size: Vector3, scene: String, spawn: String) -> void:
	var ex := SceneExit.new()
	ex.name = nm
	ex.size = size
	ex.position = pos
	ex.target_scene = scene
	ex.target_spawn = spawn
	marks.add_child(ex)
	ex.owner = scn


func _aabb_of(n: Node, t: Transform3D, first := false) -> AABB:
	var tt := t
	if n is Node3D and not first:
		tt = t * (n as Node3D).transform
	var res := AABB()
	var have := false
	if n is MeshInstance3D:
		res = tt * (n as MeshInstance3D).get_aabb()
		have = true
	for c in n.get_children():
		var a := _aabb_of(c, tt)
		if a.size != Vector3.ZERO:
			res = a if not have else res.merge(a)
			have = true
	return res


func _h(x: float, z: float) -> float:
	var h := tm.height_at(x, z)
	return 0.0 if is_inf(h) else h


func _vi(arr: PackedFloat32Array, x: float, z: float, t: int) -> void:
	for r in noveg:
		if r.has_point(Vector2(x, z)):
			return
	var h := tm.height_at(x, z)
	if is_inf(h):
		return
	var v := vtypes[t]
	arr.push_back(x)
	arr.push_back(h)
	arr.push_back(z)
	arr.push_back(rng.randf_range(v.scale_min, v.scale_max))
	arr.push_back(float(t))


func _scatter() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for c in tm.cells:
		var v: Vector2i = tm.cells[c]
		var k: int = kind.get(c, 0)
		var m := v.y & 255
		if (v.y >> 8) != 0:
			continue
		var fx := float(c.x)
		var fz := float(c.y)
		if k == 0:
			var ed := 9
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					if kind.get(Vector2i(c.x + dx, c.y + dz), 0) != 0:
						ed = mini(ed, maxi(absi(dx), absi(dz)))
			var p := 0.62 if ed <= 3 else 0.3
			if rng.randf() < p:
				_vi(a, fx + rng.randf(), fz + rng.randf(), [8, 9, 9, 8, 9, 8, 9, 9][rng.randi() % 8])
			if rng.randf() < 0.18:
				_vi(a, fx + rng.randf(), fz + rng.randf(), 3)
			continue
		if k == 2:
			if m != 6 and rng.randf() < 0.07:
				_vi(a, fx + rng.randf(), fz + rng.randf(), 0)
			continue
		if k == 5:
			continue
		if k == 3:
			for i in 2:
				if rng.randf() < 0.6:
					_vi(a, fx + rng.randf(), fz + rng.randf(), 3 if rng.randf() < 0.5 else 1)
			continue
		var n := 3 if m != 5 else 2
		for i in n:
			var r := rng.randf()
			var t := 0
			if m == 1:
				t = 2 if r < 0.3 else (1 if r < 0.5 else 0)
			elif m == 4:
				t = 3 if r < 0.5 else 0
			else:
				t = 1 if r < 0.2 else (3 if r < 0.27 else 0)
			if rng.randf() < 0.85:
				_vi(a, fx + rng.randf(), fz + rng.randf(), t)
		if m == 5:
			for i in 3:
				var r2 := rng.randf()
				_vi(a, fx + rng.randf(), fz + rng.randf(), 4 if r2 < 0.45 else (5 if r2 < 0.8 else 6))
		elif rng.randf() < 0.08:
			var r3 := rng.randf()
			_vi(a, fx + rng.randf(), fz + rng.randf(), 4 if r3 < 0.5 else (5 if r3 < 0.8 else 6))
	return a


func _inst(nm: String, p: Vector2, yaw := 0.0, sc := 1.0, y_off := 0.0) -> Node3D:
	var h := tm.height_at(p.x, p.y)
	if is_inf(h):
		return null
	var ps := load("res://props/%s.tscn" % nm) as PackedScene
	var n := ps.instantiate() as Node3D
	n.position = Vector3(p.x, h + y_off, p.y)
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * sc
	props.add_child(n)
	n.owner = scn
	return n


func _edge_trees(count: int, mind := 2.5) -> void:
	var placed: Array[Vector2] = []
	var tries := 0
	var names := ["strom_listnaty", "strom_smrk", "strom_listnaty", "strom_smrk", "strom_smrk"]
	while placed.size() < count and tries < count * 40:
		tries += 1
		var c := Vector2i(rng.randi_range(bx0, bx1 - 1), rng.randi_range(bz0, bz1 - 1))
		if not tm.cells.has(c) or kind.get(c, 0) != 0:
			continue
		var near := false
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				if kind.get(Vector2i(c.x + dx, c.y + dz), 0) != 0 and tm.cells.has(Vector2i(c.x + dx, c.y + dz)):
					near = true
		if not near:
			continue
		var p := Vector2(c.x + rng.randf(), c.y + rng.randf())
		var ok := true
		for q in placed:
			if q.distance_to(p) < mind:
				ok = false
				break
		if ok:
			placed.append(p)
			_inst(names[rng.randi() % 5], p, 0.0, 0.8)


func _rocks(count: int, ks: Array, avoid: Array) -> void:
	var n := 0
	var tries := 0
	while n < count and tries < count * 30:
		tries += 1
		var p := Vector2(rng.randf_range(bx0 + 3, bx1 - 3), rng.randf_range(bz0 + 3, bz1 - 3))
		var c := Vector2i(floori(p.x), floori(p.y))
		if not ks.has(kind.get(c, -1)) or not tm.cells.has(c):
			continue
		var bad := false
		for a in avoid:
			if (a as Rect2).has_point(p):
				bad = true
		if bad:
			continue
		if rng.randf() < 0.15:
			_inst("lp_kamen_velky", p, rng.randf_range(0, 360), rng.randf_range(0.7, 1.1))
		else:
			_inst("lp_kamen_%d" % (1 + rng.randi() % 4), p, rng.randf_range(0, 360), rng.randf_range(0.7, 1.3))
		n += 1


func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.47, 0.32, 0.18)
	m.roughness = 0.9
	return m


func _stone_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/ground/dlazba.png")
	m.albedo_color = Color(0.85, 0.85, 0.88)
	m.uv1_scale = Vector3(2, 2, 1)
	m.roughness = 0.95
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, yaw := 0.0, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = yaw
	parent.add_child(mi)
	mi.owner = scn
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
		sb.owner = scn
		cs.owner = scn
	return mi


func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	mi.owner = scn
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var s := CylinderShape3D.new()
		s.radius = r
		s.height = h
		cs.shape = s
		sb.add_child(cs)
		mi.add_child(sb)
		sb.owner = scn
		cs.owner = scn
	return mi


func _label(parent: Node3D, text: String, pos: Vector3, yaw := 0.0, size := 40) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color(1, 0.95, 0.8)
	l.outline_modulate = Color(0.15, 0.08, 0.02)
	l.position = pos
	l.rotation_degrees.y = yaw
	parent.add_child(l)
	l.owner = scn


func _lantern(p: Vector2) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _h(p.x, p.y), p.y)
	props.add_child(n)
	n.owner = scn
	_cyl(n, Vector3(0, 1.0, 0), 0.06, 2.0, _wood(), false)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.8, 0.4)
	_box(n, Vector3(0, 2.05, 0), Vector3(0.26, 0.32, 0.26), glow)
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.1, 0)
	l.light_color = Color(1.0, 0.72, 0.4)
	l.light_energy = lights_energy
	l.omni_range = 6.0
	n.add_child(l)
	l.owner = scn


func _fence(a: Vector2, b: Vector2) -> void:
	var n := Node3D.new()
	props.add_child(n)
	n.owner = scn
	var len := a.distance_to(b)
	var steps := int(len / 1.6) + 1
	var dir := (b - a).normalized()
	var yaw := rad_to_deg(atan2(-dir.y, dir.x))
	var wood := _wood()
	for i in steps + 1:
		var p := a + dir * (len * i / steps)
		_box(n, Vector3(p.x, _h(p.x, p.y) + 0.45, p.y), Vector3(0.14, 0.9, 0.14), wood)
	for i in steps:
		var p0 := a + dir * (len * i / steps)
		var p1 := a + dir * (len * (i + 1) / steps)
		var mid := (p0 + p1) * 0.5
		var y := _h(mid.x, mid.y)
		_box(n, Vector3(mid.x, y + 0.62, mid.y), Vector3(len / steps, 0.09, 0.07), wood, yaw)
		_box(n, Vector3(mid.x, y + 0.3, mid.y), Vector3(len / steps, 0.09, 0.07), wood, yaw)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(len, 1.0, 0.25)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3((a.x + b.x) * 0.5, _h((a.x + b.x) * 0.5, (a.y + b.y) * 0.5) + 0.5, (a.y + b.y) * 0.5)
	sb.rotation_degrees.y = yaw
	n.add_child(sb)
	sb.owner = scn
	cs.owner = scn


func _well(p: Vector2) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _h(p.x, p.y), p.y)
	props.add_child(n)
	n.owner = scn
	var st := _stone_mat()
	_cyl(n, Vector3(0, 0.5, 0), 1.0, 1.0, st)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.1, 0.25, 0.35)
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cyl(n, Vector3(0, 0.92, 0), 0.8, 0.1, water, false)
	var w := _wood()
	_box(n, Vector3(-0.95, 1.5, 0), Vector3(0.14, 1.5, 0.14), w)
	_box(n, Vector3(0.95, 1.5, 0), Vector3(0.14, 1.5, 0.14), w)
	_box(n, Vector3(0, 2.3, 0), Vector3(2.3, 0.12, 0.2), w)
	var roof := _box(n, Vector3(0, 2.55, 0), Vector3(2.5, 0.1, 1.5), w)
	roof.rotation_degrees.x = 0
	_box(n, Vector3(0, 1.7, 0), Vector3(0.05, 0.05, 0.05), w)


func _signpost(p: Vector2) -> void:
	var n := Node3D.new()
	n.position = Vector3(p.x, _h(p.x, p.y), p.y)
	props.add_child(n)
	n.owner = scn
	var w := _wood()
	_cyl(n, Vector3(0, 1.3, 0), 0.1, 2.6, w)
	var defs := [["◄ Louka u řeky", -1.0, 2.2, 3.0], ["Vesnice ►", 1.0, 1.7, -2.0], ["▲ Tábor", 0.0, 2.7, 0.0]]
	for d in defs:
		var side: float = d[1]
		var bx := _box(n, Vector3(side * 0.75, d[2], 0.0), Vector3(1.5 if side != 0.0 else 1.1, 0.4, 0.09), w, d[3])
		_label(n, d[0], Vector3(side * 0.75, d[2], 0.07), d[3], 34)


## Okolo mapy dodá pás lesa, aby kamera nikdy neukázala prázdno (a vznikl prostor "dolů" i do stran).
func _pad(n: int) -> void:
	var inner := Rect2i(bx0, bz0, bx1 - bx0, bz1 - bz0)
	for x in range(bx0 - n, bx1 + n):
		for z in range(bz0 - n, bz1 + n):
			var c := Vector2i(x, z)
			if not tm.cells.has(c):
				var lvl := 3 + (1 if nz.get_noise_2d(x * 0.45, z * 0.45) > 0.1 else 0)
				tm.cells[c] = Vector2i(lvl, 7 if nzb.get_noise_2d(x, z) > -0.15 else 1)
				kind[c] = 0
	var names := ["strom_listnaty", "strom_smrk", "strom_smrk", "strom_listnaty"]
	var placed: Array[Vector2] = []
	var tries := 0
	var want := int((float(bx1 - bx0 + 2 * n) * float(bz1 - bz0 + 2 * n) - float(bx1 - bx0) * float(bz1 - bz0)) / 12.0)
	while placed.size() < want and tries < want * 30:
		tries += 1
		var p := Vector2(rng.randf_range(bx0 - n + 1, bx1 + n - 1), rng.randf_range(bz0 - n + 1, bz1 + n - 1))
		if p.x > bx0 + 1 and p.x < bx1 - 1 and p.y > bz0 + 1 and p.y < bz1 - 1:
			continue
		var ok := true
		for q in placed:
			if q.distance_to(p) < 3.0:
				ok = false
				break
		if ok:
			placed.append(p)
			_inst(names[rng.randi() % names.size()], p, rng.randf() * 360.0, rng.randf_range(0.85, 1.15))


func _finish(path: String, spawn: Vector3, speaker_npcs: Array = []) -> void:
	if not indoor:
		_pad(10)
	tm.sync_data()
	var veg := VegetationLayer.new()
	veg.name = "Vegetation"
	tm.add_child(veg)
	veg.owner = scn
	veg.types = vtypes
	veg.data = PackedFloat32Array() if indoor else _scatter()
	var sun := DirectionalLight3D.new()
	sun.name = "Slunce"
	sun.rotation_degrees = SUN
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	scn.add_child(sun)
	sun.owner = scn
	for d in speaker_npcs:
		var npc := NPC3D.new()
		npc.name = d[0]
		npc.speaker = d[1]
		npc.lines = d[2]
		if d.size() > 4:
			npc.dialogue_id = d[4].get("dialogue", "")
			if d[4].has("tex"):
				npc.texture = load(d[4]["tex"])
			npc.ppm = d[4].get("ppm", 32.0)
			npc.night_text = d[4].get("night", "")
			npc.routine = d[4].get("routine", [])
		npc.position = Vector3(d[3].x, _h(d[3].x, d[3].y), d[3].y)
		scn.add_child(npc)
		npc.owner = scn
	for e in enemy_cfg:
		var me := MapEnemy.new()
		me.name = e[0]
		me.kinds = PackedStringArray(e[1])
		me.patrol = e[3]
		me.position = Vector3(e[2].x, _h(e[2].x, e[2].y), e[2].y)
		scn.add_child(me)
		me.owner = scn
	var pl := Player3D.new()
	pl.name = "Player"
	pl.position = spawn + Vector3(0, 0.1, 0)
	scn.add_child(pl)
	pl.owner = scn
	var cam := HD2DCamera.new()
	cam.name = "Camera"
	scn.add_child(cam)
	cam.owner = scn
	var ps := PackedScene.new()
	ps.pack(scn)
	ResourceSaver.save(ps, path)
	scn.free()


# ======================= ROZCESTÍ =======================
func _rozcesti() -> void:
	_begin("Rozcesti", 0, 48, 0, 38, 77)
	var J := Vector2(24, 20)
	for x in range(0, 48):
		for z in range(0, 38):
			var c := Vector2i(x, z)
			var cx := x + 0.5
			var cz := z + 0.5
			var nzv := nz.get_noise_2d(x * 0.9, z * 0.9)
			var band := absf(cz - J.y) < 5.0 + 1.2 * nzv
			var corr := absf(cx - J.x) < 5.0 + 1.2 * nzv
			var ell := pow((cx - J.x) / 11.0, 2) + pow((cz - J.y) / 8.5, 2) < 1.0 + 0.2 * nzv
			var lobes := pow((cx - 9.0) / 6.5, 2) + pow((cz - 29.0) / 4.5, 2) < 1.0 or pow((cx - 38.5) / 6.5, 2) + pow((cz - 10.0) / 4.5, 2) < 1.0
			if not (band or corr or ell or lobes):
				_forest(c)
				continue
			var m := 0
			var k := 1
			if nz.get_noise_2d(x, z) > 0.25:
				m = 1
			elif nzb.get_noise_2d(x * 1.3, z * 1.3) > 0.45:
				m = 5
			var onh := absf(cz - J.y) <= 1.7 + 0.3 * nzv
			var onv := absf(cx - J.x) <= 1.7 + 0.3 * nzv
			if onh or onv:
				m = 3 if rng.randf() < 0.12 else 2
				k = 2
			var dj := Vector2(cx, cz).distance_to(J)
			if dj < 3.4:
				m = 6
				k = 2
			elif dj < 4.3 and rng.randf() < 0.5:
				m = 2
				k = 2
			tm.cells[c] = Vector2i(0, m)
			kind[c] = k
	_signpost(J + Vector2(0, -0.2))
	noveg.append(Rect2(J.x - 3.5, J.y - 3.5, 7, 7))
	_rocks(20, [1], [Rect2(J.x - 4.5, J.y - 4.5, 9, 9)])
	_edge_trees(70)
	_lantern(J + Vector2(-3.2, 2.8))
	_lantern(J + Vector2(3.2, 2.8))
	_inst("w_menhir", Vector2(9.0, 8.5), 20.0, 1.0)
	_inst("w_kamenny_kopec", J + Vector2(-6.2, -4.2), 0.0, 1.0)
	_inst("w_hrob", Vector2(41.0, 28.5), 10.0, 1.0)
	_inst("w_krystaly", Vector2(6.5, 31.0), 0.0, 1.0)
	_inst("w_houba", Vector2(41.5, 5.5), 0.0, 1.0)
	_inst("w_ohnisko_miska", J + Vector2(-5.0, 3.8), 0.0, 1.0)
	_inst("w_vuz", J + Vector2(7.5, -3.4), 25.0, 1.0)
	_inst("lp_barel", J + Vector2(4.6, 3.4), 30.0)
	_inst("lp_barel", J + Vector2(5.3, 3.0), 80.0, 0.9)
	_mark("Ze_severu", Vector3(J.x, 0, 3.5))
	_mark("Z_leva", Vector3(4.0, 0, J.y))
	_mark("Z_prava", Vector3(44.0, 0, J.y))
	_exit("Vychod_sever", Vector3(J.x, 0, 0.8), Vector3(8, 2.5, 1), "res://scenes/louka.tscn", "Z_jihu")
	_exit("Vychod_vlevo", Vector3(0.8, 0, J.y), Vector3(1, 2.5, 8), "res://scenes/louka_reka.tscn", "Z_vychodu")
	_exit("Vychod_vpravo", Vector3(47.2, 0, J.y), Vector3(1, 2.5, 8), "res://scenes/vesnice.tscn", "Ze_zapadu")
	_mark("Z_jihu", Vector3(J.x, 0, 34.0))
	_exit("Vychod_jih", Vector3(J.x, 0, 37.2), Vector3(8, 2.5, 1), "res://scenes/hvozd.tscn", "Ze_severu")
	_foe_at("Slizak_r1", ["slime"], Vector2(37.0, 11.0), 3.0)
	_foe_at("Zbojnik_r1", ["bandit", "slime"], Vector2(10.0, 29.0), 3.0)
	_finish("res://scenes/rozcesti.tscn", Vector3(J.x, 0, 3.5))


# ======================= LOUKA U ŘEKY =======================
func _river_c(z: float) -> float:
	return 5.0 + 1.4 * sin(z * 0.11) + 0.8 * sin(z * 0.31 + 1.0)


func _reka() -> void:
	_begin("LoukaUReky", 0, 58, 0, 52, 99)
	for x in range(0, 58):
		for z in range(0, 52):
			var c := Vector2i(x, z)
			var cx := x + 0.5
			var cz := z + 0.5
			var rc := _river_c(cz)
			var d := cx - rc
			if d < -2.9:
				_forest(c, 3)  # zalesněný svah za řekou
				continue
			if absf(d) <= 2.9:
				tm.cells[c] = Vector2i(0, 3)  # koryto
				kind[c] = 5
				continue
			var nzv := nz.get_noise_2d(x * 0.8, z * 0.8)
			var oval := pow((cx - 32.0) / 23.0, 2) + pow((cz - 17.0) / 15.0, 2) < 1.0 + 0.12 * nzv
			var band := cz > 28.0 + 1.5 * nzv and cz < 45.0 + 1.5 * nzv and cx > 16.0
			var neck := cx > 0.0 and cx < 40.0 and cz > 19.0 and cz < 29.0
			if d < 4.6 + 0.5 * nzv and cz > 4.0 and cz < 48.0:
				tm.cells[c] = Vector2i(1, 3 if rng.randf() < 0.55 else 4)
				kind[c] = 3  # břeh
				continue
			if not (oval or band or neck):
				_forest(c, 3)
				continue
			var m := 0
			if nz.get_noise_2d(x, z) > 0.22:
				m = 1
			elif nzb.get_noise_2d(x * 1.3, z * 1.3) > 0.30:
				m = 5
			tm.cells[c] = Vector2i(1, m)
			kind[c] = 1
	# cesta od východu k molu u řeky
	var path := [Vector2(57, 36), Vector2(47, 36.5), Vector2(38, 34), Vector2(31, 28), Vector2(24, 25), Vector2(16, 23.5), Vector2(10.5, 23.5)]
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var steps := int(a.distance_to(b) * 2)
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var cc := Vector2i(floori(p.x) + dx, floori(p.y) + dz)
					if kind.get(cc, -1) == 1 or kind.get(cc, -1) == 3:
						if Vector2(cc.x + 0.5, cc.y + 0.5).distance_to(p) < 1.5:
							tm.cells[cc] = Vector2i(1, 3 if rng.randf() < 0.12 else 2)
							kind[cc] = 2
	# řeka
	var pts: Array = []
	var z := -2.0
	while z <= 54.0:
		pts.append(Vector3(_river_c(z), 0.3, z))
		z += 1.5
	var wr := WaterFx.ribbon(pts, 5.7)
	wr.name = "Reka"
	scn.add_child(wr)
	wr.owner = scn
	# neviditelné stěny nad korytem (nejde se do vody)
	z = 0.0
	while z < 52.0:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(5.2, 3.0, 1.8)
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(_river_c(z + 0.9), 1.3, z + 0.9)
		scn.add_child(sb)
		sb.owner = scn
		cs.owner = scn
		z += 1.8
	# kameny v řece a na břehu
	for zz in [8, 14, 20, 27, 33, 40, 46]:
		_inst("lp_kamen_%d" % (1 + rng.randi() % 4), Vector2(_river_c(zz) + rng.randf_range(-1.2, 1.2), zz), rng.randf_range(0, 360), rng.randf_range(1.0, 1.5), -0.1)
	# molo
	var wood := _wood()
	var pier := Node3D.new()
	pier.name = "Molo"
	props.add_child(pier)
	pier.owner = scn
	var pz := 23.5
	var px := _river_c(pz) + 2.3
	for i in 6:
		_box(pier, Vector3(px - i * 0.55, 0.62, pz), Vector3(0.6, 0.08, 1.5), wood)
	for i in 4:
		_box(pier, Vector3(px - 0.2 - i * 0.9, 0.25, pz - 0.7), Vector3(0.12, 1.0, 0.12), wood)
		_box(pier, Vector3(px - 0.2 - i * 0.9, 0.25, pz + 0.7), Vector3(0.12, 1.0, 0.12), wood)
	noveg.append(Rect2(px - 4, pz - 1, 5, 2))
	_inst("lp_barel", Vector2(px + 1.0, pz + 1.6), 40.0)
	_inst("lp_truhla", Vector2(px + 1.6, pz - 2.2), 100.0)
	_rocks(30, [1, 3], [Rect2(px - 4, pz - 3, 8, 6)])
	for nm in ["w_kamen_mechovy", "w_kamen_stredni", "w_skala", "w_kamen_dvojice", "w_balvan", "w_kamen_stredni", "w_kamen_maly", "w_kamen_maly"]:
		_inst(nm, Vector2(rng.randf_range(14.0, 50.0), rng.randf_range(8.0, 28.0)), rng.randf_range(0, 360), rng.randf_range(0.9, 1.2))
	for zz in [10.0, 17.0, 31.0, 38.0]:
		_inst("w_oblazky", Vector2(_river_c(zz) + 3.6, zz), rng.randf_range(0, 360), 1.0)
		_inst("w_kamen_maly", Vector2(_river_c(zz) + 0.8, zz + 1.5), rng.randf_range(0, 360), 1.0, -0.25)
	_inst("w_plochy_kamen", Vector2(px + 2.5, pz + 3.2), 20.0, 1.0)
	_inst("w_krystaly", Vector2(46.0, 6.0), 0.0, 1.0)
	_inst("w_houba", Vector2(20.5, 5.0), 0.0, 1.0)
	_inst("w_menhir", Vector2(30.0, 12.0), 10.0, 1.0)
	_inst("w_menhir", Vector2(34.0, 13.0), 340.0, 0.85)
	_inst("w_ohniste", Vector2(px + 5.5, pz + 4.5), 0.0, 1.0)
	_inst("w_seno", Vector2(52.0, 31.0), 35.0, 1.0)
	_inst("w_kamenny_kopec", Vector2(40.0, 24.0), 0.0, 1.0)
	_edge_trees(80)
	_mark("Z_vychodu", Vector3(54.0, 0.5, 36.5))
	_exit("Vychod_vychod", Vector3(57.2, 0.5, 36.5), Vector3(1, 2.5, 7), "res://scenes/rozcesti.tscn", "Z_leva")
	_foe_at("Slizak_l1", ["slime", "slime"], Vector2(38.0, 12.0), 3.0)
	_foe_at("Kostlivec_l1", ["skeleton"], Vector2(30.0, 40.0), 3.0)
	_finish("res://scenes/louka_reka.tscn", Vector3(54.0, 0.5, 36.5))


# ======================= VESNICE =======================
func _vesnice() -> void:
	_begin("Vesnice", 0, 62, 0, 54, 123)
	var stair_x0 := 24
	var stair_x1 := 27
	for x in range(0, 62):
		for z in range(0, 54):
			var c := Vector2i(x, z)
			var cx := x + 0.5
			var cz := z + 0.5
			var nzv := nz.get_noise_2d(x * 0.8, z * 0.8)
			var lower := cz >= 25.0 and cz < 49.0 + 1.0 * nzv and cx > 0.5 and cx < 59.0 + 1.0 * nzv
			var upper := cz >= 4.0 + 1.0 * nzv and cz < 25.0 and cx > 5.0 + 1.5 * nzv and cx < 55.0 + 1.5 * nzv
			if upper:
				var m := 0
				if nz.get_noise_2d(x, z) > 0.25:
					m = 1
				elif nzb.get_noise_2d(x * 1.3, z * 1.3) > 0.35:
					m = 5
				tm.cells[c] = Vector2i(4, m)
				kind[c] = 4
			elif lower:
				var m2 := 0
				if nz.get_noise_2d(x, z) > 0.25:
					m2 = 1
				elif nzb.get_noise_2d(x * 1.3, z * 1.3) > 0.4:
					m2 = 5
				tm.cells[c] = Vector2i(0, m2)
				kind[c] = 1
			else:
				_forest(c, 5 if cz < 25.0 else 3)
	# schody: z=25 -> 1, 24 -> 2, 23 -> 3 (pak kopec = 4)
	for x in range(stair_x0, stair_x1 + 1):
		for s in 3:
			var cc := Vector2i(x, 25 - s)
			tm.cells[cc] = Vector2i(1 + s, 6)
			kind[cc] = 2
	# dlažba nahoře před schody + cesty
	var paths := [[Vector2(0.5, 39.0), Vector2(18.0, 39.0)], [Vector2(18.0, 39.0), Vector2(25.5, 31.0)], [Vector2(25.5, 31.0), Vector2(25.5, 26.0)],
		[Vector2(18.0, 39.0), Vector2(46.0, 38.5)], [Vector2(25.5, 22.0), Vector2(25.5, 15.5)], [Vector2(25.5, 15.5), Vector2(12.0, 15.5)], [Vector2(25.5, 15.5), Vector2(45.0, 15.5)]]
	for pp in paths:
		var a: Vector2 = pp[0]
		var b: Vector2 = pp[1]
		var steps := int(a.distance_to(b) * 2)
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var cc := Vector2i(floori(p.x) + dx, floori(p.y) + dz)
					var kk: int = kind.get(cc, -1)
					if (kk == 1 or kk == 4) and tm.cells.has(cc):
						if Vector2(cc.x + 0.5, cc.y + 0.5).distance_to(p) < 1.35:
							var lv: Vector2i = tm.cells[cc]
							tm.cells[cc] = Vector2i(lv.x, 6 if kk == 4 else (3 if rng.randf() < 0.1 else 2))
							kind[cc] = 2
	# náměstí s kašnou dole
	var plaza := Vector2(33.0, 34.0)
	for x in range(int(plaza.x) - 5, int(plaza.x) + 6):
		for z in range(int(plaza.y) - 5, int(plaza.y) + 6):
			var cc := Vector2i(x, z)
			if kind.get(cc, -1) in [1, 2] and Vector2(x + 0.5, z + 0.5).distance_to(plaza) < 4.2 + 0.4 * nzb.get_noise_2d(x * 3.0, z * 3.0):
				tm.cells[cc] = Vector2i(0, 6)
				kind[cc] = 2
	# domy
	var hs := [["lp_domek", Vector2(13.0, 12.0), 0.0, 1.7], ["lp_obchod_2", Vector2(44.0, 12.5), 0.0, 1.7], ["lp_obchod_1", Vector2(53.0, 38.0), -90.0, 2.0]]
	for h in hs:
		var hn := _inst(h[0], h[1], h[2], h[3])
		noveg.append(Rect2(h[1].x - 7.0, h[1].y - 7.0, 14.0, 14.0))
		if h[0] == "lp_obchod_2":
			var bb := _aabb_of(hn, hn.transform, true)
			var dx := bb.get_center().x
			var fz := bb.end.z
			_exit("Vchod_obchod", Vector3(dx, _h(dx, fz + 0.6), fz + 0.7), Vector3(2.6, 2.5, 1.4), "res://scenes/obchod.tscn", "Vchod")
			_mark("Z_obchodu", Vector3(dx, _h(dx, fz + 2.4), fz + 2.4))
			_label(hn.get_parent(), "OBCHOD", Vector3(dx, _h(dx, fz) + 3.0, fz + 0.2), 0.0, 44)
	noveg.append(Rect2(plaza.x - 4.5, plaza.y - 4.5, 9, 9))
	noveg.append(Rect2(stair_x0 - 1, 21.0, 6, 6))
	_inst("w_studna", plaza, 0.0, 1.0)
	# kovárna (Well) na dolní úrovni nad cestou, vchod k jihu
	_inst("w_kovarna", Vector2(12.5, 33.0), 0.0, 1.0)
	noveg.append(Rect2(6.0, 28.0, 14, 9))
	_inst("w_stojan_zbroje", Vector2(18.2, 34.8), 200.0, 1.0)
	_inst("w_ohnisko_miska", Vector2(7.2, 35.8), 0.0, 1.0)
	_inst("w_kotlik", Vector2(18.8, 31.8), 120.0, 1.0)
	# trh u náměstí
	_inst("w_trh", Vector2(40.0, 41.0), 180.0, 1.0)
	_inst("w_bedna_mala", Vector2(35.2, 42.8), 20.0, 1.0)
	_inst("w_sud", Vector2(44.6, 43.0), 0.0, 1.0)
	_inst("w_vuz", Vector2(31.0, 44.0), 160.0, 1.0)
	_inst("w_seno", Vector2(27.0, 44.5), 10.0, 1.0)
	_inst("w_vlajka", Vector2(29.5, 29.0), 0.0, 1.0)
	_inst("w_vlajka", Vector2(36.5, 29.0), 0.0, 1.0)
	# políčko se strašákem
	_inst("w_strasak", Vector2(9.0, 46.0), 20.0, 1.0)
	_inst("w_seno", Vector2(13.5, 46.0), 80.0, 1.0)
	_inst("w_plot", Vector2(6.0, 43.0), 0.0, 1.0)
	_inst("w_plot", Vector2(10.5, 43.0), 0.0, 1.0)
	_inst("w_plot", Vector2(15.0, 43.0), 0.0, 1.0)
	# kopec: socha, pult, rozcestník, hroby
	_inst("w_socha", Vector2(25.5, 9.0), 0.0, 1.0)
	_inst("w_pult", Vector2(19.0, 17.5), 160.0, 1.0)
	_inst("w_rozcestnik", Vector2(22.5, 19.5), 10.0, 1.0)
	_inst("w_hrob", Vector2(52.0, 20.5), 0.0, 1.0)
	_inst("w_hrob", Vector2(54.0, 21.5), 15.0, 1.0)
	_inst("w_truhla", Vector2(11.5, 14.8), 195.0, 1.0)
	_inst("w_sud", Vector2(15.8, 8.8), 40.0, 1.0)
	for p in [Vector2(29.0, 37.5), Vector2(37.0, 37.5), Vector2(29.0, 30.5), Vector2(37.0, 30.5), Vector2(22.5, 30.0), Vector2(28.5, 23.5), Vector2(22.5, 21.5), Vector2(28.5, 21.5), Vector2(49.0, 35.0), Vector2(49.0, 41.5), Vector2(9.5, 16.5), Vector2(16.5, 16.5), Vector2(41.0, 16.5), Vector2(47.5, 16.5)]:
		_inst("w_lampa", p, 0.0, 1.0)
	# ploty
	_fence(Vector2(6.5, 17.0), Vector2(6.5, 7.5))
	_fence(Vector2(6.5, 7.5), Vector2(19.5, 7.5))
	_fence(Vector2(50.5, 17.0), Vector2(50.5, 7.5))
	_fence(Vector2(37.5, 7.5), Vector2(50.5, 7.5))
	_fence(Vector2(40.0, 44.0), Vector2(51.0, 44.0))
	_fence(Vector2(40.0, 33.0), Vector2(40.0, 34.5))
	_fence(Vector2(2.0, 36.0), Vector2(14.0, 36.0))
	_fence(Vector2(2.0, 42.0), Vector2(14.0, 42.0))
	# bedny, sudy, truhly, kameny
	for p in [Vector2(51.0, 33.0), Vector2(51.8, 33.7), Vector2(42.5, 17.5), Vector2(15.5, 15.0), Vector2(10.0, 15.5)]:
		_inst("lp_barel", p, rng.randf_range(0, 360), rng.randf_range(0.9, 1.1))
	_inst("lp_truhla", Vector2(47.0, 41.0), 200.0)
	_inst("lp_truhla", Vector2(19.5, 14.0), 160.0)
	_rocks(26, [1, 4], [Rect2(3.0, 25.0, 20.0, 14.0)])
	_edge_trees(110, 2.3)
	# značky a východ
	_mark("Ze_zapadu", Vector3(3.5, 0, 39.0))
	_mark("Start", Vector3(3.5, 0, 39.0))
	_exit("Vychod_zapad", Vector3(0.8, 0, 39.0), Vector3(1, 2.5, 7), "res://scenes/rozcesti.tscn", "Z_prava")
	var npcs := [
		["Vesnican1", "Vesničan", "Vítej ve vesnici!|Nahoře na kopci bydlí truhlář a kovář.|Pozor na vlky v lese.", Vector2(30.5, 36.0)],
		["Vesnican2", "Stará Anna", "Kašna je tu starší než celá vesnice.|Voda z ní nikdy nevyschla.", Vector2(35.5, 31.5)],
		["Kovar", "Kovář", "Hmpf.", Vector2(12.2, 34.8), {"dialogue": "kovar", "tex": "res://npc/kovar.png", "ppm": 112.0}],
		["Hostinsky", "Hostinský Bohouš", "Hostinec U Zlatého sudu.", Vector2(20.5, 36.5), {"dialogue": "hostinsky"}],
		["Strazny", "Strážný", "Kdo chce na kopec, musí po schodech.|Dávej na sebe pozor, cizinče.", Vector2(25.5, 28.0)]]
	_finish("res://scenes/vesnice.tscn", Vector3(3.5, 0, 39.0), npcs)


# ======================= OBCHOD (interiér) =======================
# ======================= NOVÉ MAPY: HVOZD, JEZERO, JESKYNĚ =======================
func _seg_dist(p: Vector2, pts: Array) -> float:
	var best := 999.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func _omni(pos: Vector3, col: Color, energy: float, rng_: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_
	scn.add_child(l)
	l.owner = scn


func _foe_at(nm: String, kinds_: Array, p: Vector2, patrol_ := 3.0) -> void:
	enemy_cfg.append([nm, kinds_, p, patrol_])


func _hvozd() -> void:
	_begin("Hvozd", 0, 52, 0, 46, 211)
	var main_path := [Vector2(26, 0), Vector2(26, 9), Vector2(23, 17), Vector2(25, 25), Vector2(31, 29), Vector2(37, 31)]
	var west := [Vector2(23, 17), Vector2(16, 25), Vector2(11, 33), Vector2(9, 38)]
	var east := [Vector2(26, 9), Vector2(34, 12), Vector2(43, 17), Vector2(52, 22)]
	var camp := Vector2(38, 31)
	var cave_plaza := Vector2(9, 38)
	for x in range(0, 52):
		for z in range(0, 46):
			var c := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var nzv := nz.get_noise_2d(x * 0.8, z * 0.8)
			var dp := minf(_seg_dist(p, main_path), minf(_seg_dist(p, west), _seg_dist(p, east)))
			var in_camp := p.distance_to(camp) < 7.5 + 1.0 * nzv
			var in_cave := p.distance_to(cave_plaza) < 4.2 + 0.6 * nzv
			if dp < 2.2 + 0.5 * nzv or in_camp or in_cave:
				var onp := dp < 1.3 or p.distance_to(camp) < 5.0 or in_cave
				tm.cells[c] = Vector2i(0, 2 if onp else 1)
				kind[c] = 2 if onp else 1
			elif dp < 4.5 + nzv and nzb.get_noise_2d(x, z) > 0.0:
				tm.cells[c] = Vector2i(0, 4 if nz.get_noise_2d(x * 1.5, z) > 0 else 1)
				kind[c] = 1
			else:
				_forest(c, 3)
	noveg.append(Rect2(camp.x - 6.5, camp.y - 6.5, 13, 13))
	noveg.append(Rect2(cave_plaza.x - 4, cave_plaza.y - 4, 8, 8))
	_edge_trees(110, 2.2)
	_rocks(10, [1], [Rect2(camp.x - 8, camp.y - 8, 16, 16)])
	# tábor zbojníků
	_inst("lp_stan", camp + Vector2(-3.6, -2.4), 30.0)
	_inst("lp_stan", camp + Vector2(3.4, -3.0), 330.0)
	_inst("lp_stan", camp + Vector2(4.2, 2.8), 250.0)
	_inst("w_ohniste", camp + Vector2(0.0, 0.2), 0.0)
	_inst("w_kotlik", camp + Vector2(-1.4, 1.6), 20.0)
	_inst("w_bedna_velka", camp + Vector2(-5.0, 1.2), 70.0)
	_inst("w_bedna_mala", camp + Vector2(-4.4, 2.0), 10.0)
	_inst("w_sud", camp + Vector2(2.2, -5.2), 0.0)
	_inst("lp_barel", camp + Vector2(3.0, -5.0), 40.0)
	_inst("w_truhla", camp + Vector2(5.8, -0.4), 270.0)
	_inst("w_vlajka", camp + Vector2(-0.5, -4.4), 0.0)
	_inst("w_strasak", camp + Vector2(-6.0, -3.5), 20.0)
	# vchod do jeskyně: skalní masiv
	_inst("w_kamenny_kopec", cave_plaza + Vector2(0.0, 5.2), 0.0, 1.6)
	_inst("w_skala", cave_plaza + Vector2(-3.3, 3.8), 40.0)
	_inst("w_skala", cave_plaza + Vector2(3.3, 3.8), 300.0)
	_inst("w_krystaly", cave_plaza + Vector2(-2.6, 1.0), 0.0)
	_inst("w_ohnisko_miska", cave_plaza + Vector2(2.6, 0.2), 0.0)
	_inst("w_hrob", Vector2(17.0, 21.0), 20.0)
	_inst("w_houba", Vector2(30.0, 4.0))
	_inst("w_menhir", Vector2(43.0, 6.0), 15.0)
	_inst("w_rozcestnik", Vector2(24.2, 16.2), 40.0)
	_mark("Ze_severu", Vector3(26.0, 0, 3.5))
	_mark("Z_jeskyne", Vector3(cave_plaza.x, 0, cave_plaza.y + 1.5))
	_mark("Ze_zapadu", Vector3(48.0, 0, 21.5))
	_exit("Vychod_sever", Vector3(26.0, 0, 0.8), Vector3(7, 2.5, 1), "res://scenes/rozcesti.tscn", "Z_jihu")
	_exit("Vchod_jeskyne", Vector3(cave_plaza.x, 0, cave_plaza.y + 3.6), Vector3(4.0, 2.5, 1.4), "res://scenes/jeskyne.tscn", "Vchod")
	_exit("Vychod_vychod", Vector3(51.2, 0, 22.0), Vector3(1, 2.5, 7), "res://scenes/jezero.tscn", "Z_zapadu")
	_foe_at("Zbojnici_1", ["bandit", "bandit"], camp + Vector2(-1.0, -1.0), 3.0)
	_foe_at("Zbojnici_2", ["bandit", "slime", "bandit"], camp + Vector2(2.5, 3.0), 2.5)
	_foe_at("Slizak_1", ["slime"], Vector2(25.0, 20.0), 3.0)
	_foe_at("Slizak_2", ["slime", "slime"], Vector2(38.0, 15.0), 3.0)
	_label(props, "JESKYNĚ", Vector3(cave_plaza.x, _h(cave_plaza.x, cave_plaza.y + 3.2) + 3.2, cave_plaza.y + 3.2), 0.0, 44)
	_finish("res://scenes/hvozd.tscn", Vector3(26.0, 0, 3.5), [
		["Hlidka", "Zběhlý hlídač", "Pst! Tábor zbojníků je na jihovýchodě. Jestli jdeš tam, nevolej na ně.|V noci spí... aspoň někteří.", Vector2(25.0, 6.0), {"dialogue": "hlidka"}]])


func _jezero() -> void:
	_begin("Jezero", 0, 50, 0, 40, 307)
	var lake := Vector2(33, 21)
	for x in range(0, 50):
		for z in range(0, 40):
			var c := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var nzv := nz.get_noise_2d(x * 0.7, z * 0.7)
			var dl := pow((p.x - lake.x) / 11.0, 2) + pow((p.y - lake.y) / 8.0, 2)
			var land := pow((p.x - 20.0) / 24.0, 2) + pow((p.y - 20.0) / 17.0, 2) < 1.0 + 0.12 * nzv
			var corr := (p.x < 22.0 and absf(p.y - 21.5) < 4.0 + nzv) or _seg_dist(p, [Vector2(20, 21.5), Vector2(26, 7), Vector2(49, 5.5)]) < 2.4 + 0.5 * nzv
			if dl < 1.0 + 0.1 * nzv:
				tm.cells[c] = Vector2i(0, 3)
				kind[c] = 5
			elif dl < 1.45 + 0.12 * nzv and (land or corr):
				tm.cells[c] = Vector2i(0, 3 if rng.randf() < 0.5 else 4)
				kind[c] = 3
			elif land or corr:
				var m := 0
				if nz.get_noise_2d(x, z) > 0.25:
					m = 1
				elif nzb.get_noise_2d(x * 1.3, z * 1.3) > 0.35:
					m = 5
				var onp := (absf(p.y - 21.5) < 1.5 + 0.3 * nzv and p.x < 24.0) or _seg_dist(p, [Vector2(20, 21.5), Vector2(26, 7), Vector2(49, 5.5)]) < 1.1
				tm.cells[c] = Vector2i(0, 2 if onp else m)
				kind[c] = 2 if onp else 1
			else:
				_forest(c, 3)
	var pts: Array = []
	var a := 0.0
	while a <= TAU + 0.3:
		pts.append(Vector3(lake.x + cos(a) * 8.5, 0.3, lake.y + sin(a) * 5.6))
		a += 0.45
	var wr := WaterFx.ribbon(pts, 9.0)
	wr.name = "Jezero"
	scn.add_child(wr)
	wr.owner = scn
	var wr2 := WaterFx.ribbon([Vector3(lake.x - 8, 0.3, lake.y), Vector3(lake.x, 0.3, lake.y), Vector3(lake.x + 8, 0.3, lake.y)], 11.5)
	scn.add_child(wr2)
	wr2.owner = scn
	# neviditelná zeď kolem vody
	var n := 20
	for i in n:
		var ang := TAU * i / n
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(5.4, 3.0, 3.2)
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(lake.x + cos(ang) * 10.6, 1.3, lake.y + sin(ang) * 7.4)
		sb.rotation.y = -ang
		scn.add_child(sb)
		sb.owner = scn
		cs.owner = scn
	noveg.append(Rect2(lake.x - 12, lake.y - 9, 24, 18))
	_edge_trees(70, 2.4)
	_rocks(16, [1], [Rect2(lake.x - 12, lake.y - 9, 24, 18)])
	# molo a rybářská chýše
	var wood := _wood()
	var pier := Node3D.new()
	pier.name = "Molo"
	props.add_child(pier)
	pier.owner = scn
	var pz := 21.0
	var px := lake.x - 12.2
	for i in 9:
		_box(pier, Vector3(px + i * 0.6, 0.62, pz), Vector3(0.62, 0.08, 1.5), wood)
	_inst("lp_domek", Vector2(14.0, 15.5), 160.0)
	_inst("w_sud", Vector2(17.6, 16.5), 0.0)
	_inst("w_ohniste", Vector2(18.5, 24.5), 0.0).add_to_group("ohniste", true)
	_inst("w_seno", Vector2(11.0, 26.5), 35.0)
	_inst("w_plot", Vector2(12.0, 19.5), 90.0)
	_inst("lp_barel", Vector2(16.0, 26.0), 30.0)
	_inst("w_oblazky", Vector2(24.5, 13.5), 0.0)
	_inst("w_krystaly", Vector2(44.0, 6.0), 0.0)
	_inst("w_kamen_mechovy", Vector2(40.0, 31.0), 20.0)
	_mark("Z_zapadu", Vector3(4.0, 0, 21.5))
	_mark("Z_hrbitova", Vector3(46.0, 0, 5.5))
	_exit("Vychod_hrbitov", Vector3(49.2, 0, 5.5), Vector3(1, 2.5, 5), "res://scenes/hrbitov.tscn", "Ze_zapadu")
	_exit("Vychod_zapad", Vector3(0.8, 0, 21.5), Vector3(1, 2.5, 7), "res://scenes/hvozd.tscn", "Ze_zapadu")
	_foe_at("Slizak_j1", ["slime", "slime"], Vector2(28.0, 31.0), 3.0)
	_foe_at("Kostlivec_j1", ["skeleton"], Vector2(41.0, 20.0), 2.5)
	_finish("res://scenes/jezero.tscn", Vector3(4.0, 0, 21.5), [
		["Rybar", "Rybář Tomáš", "Ryby nekoušou. Možná je to tím, že u jeskyně straší.|Nemáš náhodou červy?", Vector2(15.5, 18.3), {"dialogue": "rybar", "routine": [{"t0": 0.28, "t1": 0.80, "off": Vector3(0, 0, 0)}, {"t0": 0.80, "t1": 0.28, "hide": true}], "night": "Chrrr... (Rybář spí.)"}]])


func _jeskyne() -> void:
	indoor = true
	sun_energy = 0.12
	_begin("Jeskyne", 0, 44, 0, 36, 409)
	var rooms := [[Vector2(14, 29), 4.0], [Vector2(14, 17), 6.0], [Vector2(31, 14), 7.0], [Vector2(35, 27), 4.5]]
	var corridors := [[Vector2(14, 34), Vector2(14, 23)], [Vector2(14, 17), Vector2(31, 14)], [Vector2(31, 14), Vector2(35, 27)]]
	for x in range(0, 44):
		for z in range(0, 36):
			var c := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var nzv := nz.get_noise_2d(x * 0.8, z * 0.8)
			var open := false
			for r in rooms:
				if p.distance_to(r[0]) < float(r[1]) + 0.8 * nzv:
					open = true
			for cr in corridors:
				if _seg_dist(p, [cr[0], cr[1]]) < 1.9 + 0.4 * nzv:
					open = true
			if open:
				tm.cells[c] = Vector2i(0, 3 if nzb.get_noise_2d(x, z) > -0.1 else 2)
				kind[c] = 2
			else:
				tm.cells[c] = Vector2i(9 + (1 if nzb.get_noise_2d(x, z) > 0.3 else 0), 3)
				kind[c] = 0
	# krystaly svítí
	var cr_spots := [Vector2(10.5, 15.5), Vector2(19.0, 19.5), Vector2(27.0, 10.0), Vector2(36.5, 17.0), Vector2(12.0, 30.5), Vector2(38.0, 29.5)]
	for p in cr_spots:
		_inst("w_krystaly", p, rng.randf_range(0, 360), 1.2)
		_omni(Vector3(p.x, _h(p.x, p.y) + 1.4, p.y), Color(0.45, 0.8, 1.0), 2.6, 9.0)
	_omni(Vector3(14, 1.8, 33), Color(1.0, 0.8, 0.5), 2.0, 8.0)
	for nm in ["w_kamen_stredni", "w_kamen_maly", "w_balvan", "w_kamen_dvojice", "w_oblazky"]:
		for i in 3:
			var q := Vector2(rng.randf_range(8, 38), rng.randf_range(10, 31))
			var c2 := Vector2i(floori(q.x), floori(q.y))
			if tm.cells.has(c2) and (tm.cells[c2] as Vector2i).x == 0:
				_inst(nm, q, rng.randf_range(0, 360), rng.randf_range(0.8, 1.2))
	_inst("w_hrob", Vector2(33.0, 9.5), 0.0)
	_chest(Vector2(36.0, 30.0), 200.0, 1, [["ruda", 2], ["gold", 80]])
	_inst("w_bedna_otevrena", Vector2(33.5, 29.0), 20.0)
	_inst("w_socha", Vector2(31.0, 17.5), 180.0)
	_mark("Vchod", Vector3(14.0, 0, 31.5))
	_exit("Vychod_jeskyne", Vector3(14.0, 0, 35.2), Vector3(5, 2.5, 1.0), "res://scenes/hvozd.tscn", "Z_jeskyne")
	_foe_at("Kostlivci_1", ["skeleton", "skeleton"], Vector2(14, 17), 3.0)
	_foe_at("Kostlivci_2", ["skeleton", "slime", "skeleton"], Vector2(31, 14), 3.5)
	_foe_at("Strazce", ["skeleton", "skeleton", "bandit"], Vector2(35, 26), 2.0)
	_finish("res://scenes/jeskyne.tscn", Vector3(14.0, 0, 31.5), [])
	indoor = false
	sun_energy = 0.95


func _obchod() -> void:
	_begin("Obchod", 0, 16, 2, 12, 31)
	indoor = true
	sun_energy = 0.5
	for x in range(0, 16):
		for z in range(2, 12):
			tm.cells[Vector2i(x, z)] = Vector2i(0, 6 if (x + z) % 2 == 0 else 2)
			kind[Vector2i(x, z)] = 2
	var wood := _wood()
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.62, 0.46, 0.3)
	wall.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.35, 0.22, 0.12)
	var parent := props
	_box(parent, Vector3(8, 1.9, 1.75), Vector3(16.6, 3.8, 0.5), wall, 0.0, true)
	_box(parent, Vector3(-0.25, 1.9, 7.0), Vector3(0.5, 3.8, 10.4), wall, 0.0, true)
	_box(parent, Vector3(16.25, 1.9, 7.0), Vector3(0.5, 3.8, 10.4), wall, 0.0, true)
	# trám a okno na zadní stěně
	_box(parent, Vector3(8, 3.6, 1.95), Vector3(16.6, 0.3, 0.3), dark)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 1.0)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(parent, Vector3(13.2, 2.1, 1.98), Vector3(1.6, 1.3, 0.1), glass)
	_box(parent, Vector3(13.2, 2.1, 1.93), Vector3(1.8, 1.5, 0.08), dark)
	# pult
	_box(parent, Vector3(8, 0.55, 5.6), Vector3(6.0, 1.1, 1.3), dark, 0.0, true)
	_box(parent, Vector3(8, 1.12, 5.6), Vector3(6.3, 0.1, 1.5), wood)
	for i in 5:
		var gx := 6.2 + i * 0.9
		var col := StandardMaterial3D.new()
		col.albedo_color = [Color(0.8, 0.2, 0.25), Color(0.25, 0.5, 0.85), Color(0.3, 0.75, 0.35), Color(0.9, 0.75, 0.2), Color(0.7, 0.3, 0.8)][i]
		_cyl(parent, Vector3(gx, 1.35, 5.45), 0.12, 0.38, col, false)
	# police se zbozim
	for sx: float in [3.0, 8.0, 13.2]:
		for lv in 3:
			_box(parent, Vector3(sx if sx != 13.2 else 10.8, 0.9 + lv * 0.9, 2.2), Vector3(3.2, 0.1, 0.6), wood)
		for lv in 3:
			for k in 4:
				var c2 := StandardMaterial3D.new()
				c2.albedo_color = Color.from_hsv(rng.randf(), 0.55, 0.85)
				var px: float = (sx if sx != 13.2 else 10.8) - 1.2 + k * 0.8
				_box(parent, Vector3(px, 1.15 + lv * 0.9, 2.25), Vector3(0.35, 0.4, 0.3), c2)
	_inst("w_sud", Vector2(1.6, 4.2), 0.0, 1.0)
	_inst("w_sud", Vector2(2.4, 3.5), 40.0, 1.0)
	_inst("w_bedna_velka", Vector2(14.3, 4.0), 20.0, 1.0)
	_inst("w_pytle", Vector2(14.6, 5.6), 60.0, 1.0)
	_inst("w_stojan_zbroje", Vector2(2.2, 8.4), 150.0, 1.0)
	_inst("w_truhla", Vector2(14.2, 9.0), 200.0, 1.0)
	_inst("w_sud", Vector2(1.7, 10.2), 0.0, 1.0)
	# koberec
	var rug := StandardMaterial3D.new()
	rug.albedo_color = Color(0.6, 0.15, 0.18)
	_box(parent, Vector3(8, 0.03, 8.4), Vector3(4.0, 0.05, 3.0), rug)
	for lp in [Vector2(4.0, 3.6), Vector2(12.0, 3.6), Vector2(8.0, 8.8)]:
		var lt := OmniLight3D.new()
		lt.position = Vector3(lp.x, 2.6, lp.y)
		lt.light_color = Color(1.0, 0.76, 0.45)
		lt.light_energy = 1.4
		lt.omni_range = 9.0
		parent.add_child(lt)
		lt.owner = scn
	_label(parent, "OBCHOD", Vector3(8, 3.1, 2.05), 0.0, 52)
	_mark("Vchod", Vector3(8.0, 0.0, 10.0))
	_exit("Vychod_obchod", Vector3(8.0, 0.0, 11.75), Vector3(5.0, 2.5, 1.0), "res://scenes/vesnice.tscn", "Z_obchodu")
	var npcs := [["Prodavacka", "Prodavačka", "Dobrý den!", Vector2(8.0, 4.4), {"dialogue": "prodavacka", "tex": "res://npc/prodavacka.png", "ppm": 125.0}]]
	_finish("res://scenes/obchod.tscn", Vector3(8.0, 0.0, 10.0), npcs)


func _chest(p: Vector2, yaw: float, lock: int, loot: Array) -> void:
	var c := Chest3D.new()
	c.name = "Truhla_%d_%d" % [int(p.x), int(p.y)]
	c.lock_level = lock
	c.loot = loot
	c.position = Vector3(p.x, _h(p.x, p.y), p.y)
	c.rotation_degrees.y = yaw
	scn.add_child(c)
	c.owner = scn
	var ps := load("res://props/w_truhla.tscn") as PackedScene
	var v := ps.instantiate() as Node3D
	c.add_child(v)
	v.owner = scn


func _web(pos: Vector3, yaw: float, sz: float) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for i in 9:
		var a := PI * 0.5 * float(i) / 8.0
		for t in 64:
			var x := int(cos(a) * t)
			var y := int(sin(a) * t)
			if x < 64 and y < 64:
				img.set_pixel(x, y, Color(0.9, 0.92, 0.95, 0.55))
	for r in [14, 26, 38, 50]:
		for i in 400:
			var a2 := PI * 0.5 * float(i) / 400.0
			var rr: float = float(r) * (0.88 + 0.12 * absf(sin(a2 * 8.0)))
			var x2 := int(cos(a2) * rr)
			var y2 := int(sin(a2) * rr)
			if x2 < 64 and y2 < 64:
				img.set_pixel(x2, y2, Color(0.9, 0.92, 0.95, 0.4))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(sz, sz)
	q.mesh = qm
	q.material_override = m
	q.position = pos
	q.rotation_degrees = Vector3(0, yaw, 0)
	props.add_child(q)
	q.owner = scn


func _shaft(pos: Vector3, h: float, r: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.7
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 16
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.55, 0.65, 0.9, 0.09)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos + Vector3(0, h * 0.5, 0)
	scn.add_child(mi)
	mi.owner = scn
	var sp := SpotLight3D.new()
	sp.position = pos + Vector3(0, h, 0)
	sp.rotation_degrees = Vector3(-90, 0, 0)
	sp.light_color = Color(0.7, 0.8, 1.0)
	sp.light_energy = 5.0
	sp.spot_range = h + 2.0
	sp.spot_angle = 16.0
	scn.add_child(sp)
	sp.owner = scn


func _brazier(p: Vector2) -> void:
	_inst("w_ohnisko_miska", p, 0.0, 1.0)
	_omni(Vector3(p.x, _h(p.x, p.y) + 1.5, p.y), Color(1.0, 0.62, 0.28), 3.2, 9.5)


func _pillar(p: Vector2, h := 4.0) -> void:
	var st := _stone_mat()
	st.albedo_color = Color(0.55, 0.55, 0.6)
	_cyl(props, Vector3(p.x, _h(p.x, p.y) + h * 0.5, p.y), 0.55, h, st)
	_box(props, Vector3(p.x, _h(p.x, p.y) + 0.2, p.y), Vector3(1.4, 0.4, 1.4), st)


# ======================= HŘBITOV =======================
func _hrbitov() -> void:
	sun_energy = 0.4
	_begin("Hrbitov", 0, 42, 0, 34, 511)
	for x in range(0, 42):
		for z in range(0, 34):
			var c := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var nzv := nz.get_noise_2d(x * 0.7, z * 0.7)
			var yard := p.x > 2.0 and p.x < 40.0 and p.y > 3.0 and p.y < 31.0
			var path := _seg_dist(p, [Vector2(0, 27), Vector2(10, 27), Vector2(21, 22), Vector2(21, 8)]) < 1.5 + 0.3 * nzv
			if yard or path:
				var m := 1
				if path:
					m = 3
				elif nzb.get_noise_2d(x * 1.3, z * 1.3) > 0.4:
					m = 2
				tm.cells[c] = Vector2i(0, m)
				kind[c] = 2 if path else 1
			else:
				_forest(c, 3)
	_edge_trees(60, 2.4)
	var st := _stone_mat()
	st.albedo_color = Color(0.5, 0.5, 0.55)
	# mauzoleum
	var mz := Node3D.new()
	mz.name = "Mauzoleum"
	props.add_child(mz)
	mz.owner = scn
	_box(mz, Vector3(21, 2.0, 4.0), Vector3(10, 4.0, 5.5), st, 0.0, true)
	_box(mz, Vector3(21, 4.4, 4.0), Vector3(11, 0.8, 6.5), st)
	_box(mz, Vector3(21, 5.4, 4.0), Vector3(8, 1.2, 5.5), st)
	_box(mz, Vector3(21, 1.4, 6.85), Vector3(2.4, 2.8, 0.3), _dark_mat())
	for dx in [-2.2, 2.2]:
		_cyl(mz, Vector3(21 + dx, 2.0, 7.3), 0.4, 4.0, st)
	_box(mz, Vector3(21, 0.15, 7.6), Vector3(5, 0.3, 1.2), st)
	_omni(Vector3(19.0, 2.3, 8.0), Color(0.5, 0.75, 1.0), 2.2, 8.0)
	_omni(Vector3(23.0, 2.3, 8.0), Color(0.5, 0.75, 1.0), 2.2, 8.0)
	# hroby v řadách
	for row in 3:
		for i in 6:
			var gx := 6.0 + i * 3.0 + (14.0 if i > 2 else 0.0) - (0.0)
			var gz := 13.0 + row * 4.5
			if absf(gx - 21.0) < 3.0 or _seg_dist(Vector2(gx, gz), [Vector2(10, 27), Vector2(21, 22), Vector2(21, 8)]) < 2.0:
				continue
			_inst("w_hrob", Vector2(gx, gz), rng.randf_range(-8, 8) + 180.0)
	_inst("w_socha", Vector2(14.0, 21.0), 20.0)
	_inst("w_socha", Vector2(28.0, 21.0), -20.0)
	_inst("w_krystaly", Vector2(36.5, 8.0), 0.0, 0.8)
	_inst("w_kamen_mechovy", Vector2(6.0, 8.0), 30.0)
	_inst("w_rozcestnik", Vector2(5.0, 25.0), 90.0)
	for lp in [Vector2(10, 25.2), Vector2(18.5, 20.0), Vector2(24, 20.0), Vector2(19, 11)]:
		_inst("w_lampa", lp, 0.0)
		_omni(Vector3(lp.x, 2.0, lp.y), Color(0.75, 0.88, 1.0), 1.4, 7.0)
	for fx in range(3, 40, 2):
		_inst("w_plot", Vector2(fx, 3.2), 0.0)
	_mark("Ze_zapadu", Vector3(3.0, 0, 27.0))
	_mark("Z_hrobky", Vector3(21.0, 0, 9.0))
	_exit("Vychod_jezero", Vector3(0.7, 0, 27.0), Vector3(1, 2.5, 5), "res://scenes/jezero.tscn", "Z_hrbitova")
	_exit("Vchod_hrobka", Vector3(21.0, 0, 6.9), Vector3(2.4, 2.5, 0.8), "res://scenes/hrobka.tscn", "Vchod")
	_foe_at("Kostlivec_h1", ["skeleton", "skeleton"], Vector2(12, 17), 3.0)
	_foe_at("Kostlivec_h2", ["skeleton", "bandit"], Vector2(31, 18), 3.0)
	_foe_at("Duch_h1", ["ghost", "skeleton"], Vector2(33, 10), 2.0)
	_foe_at("Kostlivec_h3", ["skeleton", "skeleton", "skeleton"], Vector2(21, 14), 2.0)
	_finish("res://scenes/hrbitov.tscn", Vector3(3.0, 0, 27.0), [
		["Knez", "Farář Alois", "Pokoj s tebou.", Vector2(8.0, 25.0), {"dialogue": "knez"}]])
	sun_energy = 0.95


func _dark_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.03)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ======================= HROBKA =======================
func _in_r(p: Vector2, r: Rect2) -> bool:
	return r.has_point(p)


func _hrobka() -> void:
	indoor = true
	sun_energy = 0.08
	_begin("Hrobka", 0, 46, 0, 46, 613)
	var hall := Rect2(18, 36, 10, 8)        # vstupní síň
	var cor1 := Rect2(21.5, 28, 3, 8.5)     # chodba
	var cross := Rect2(14, 20, 18, 8.5)     # křižovatka s pilíři
	var west := Rect2(3, 19, 9, 11)         # západní krypta
	var east := Rect2(34, 19, 9, 11)        # východní krypta
	var linkw := Rect2(11.5, 23, 3, 3)
	var linke := Rect2(31.5, 23, 3, 3)
	var cor2 := Rect2(21.5, 13.5, 3, 7)
	var boss := Rect2(11, 2.5, 24, 11.5)    # síň krále
	var rooms := [hall, cor1, cross, west, east, linkw, linke, cor2, boss]
	for x in range(0, 46):
		for z in range(0, 46):
			var c := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var open := false
			for r in rooms:
				if _in_r(p, r):
					open = true
			if open:
				var lv := 0
				if _in_r(p, boss):
					if p.y < 6.0:
						lv = 3
					elif p.y < 7.5:
						lv = 2
					elif p.y < 9.0:
						lv = 1
				var m := 6
				if nzb.get_noise_2d(x * 1.1, z * 1.1) > 0.3:
					m = 3
				tm.cells[c] = Vector2i(lv, m)
				kind[c] = 2
			else:
				tm.cells[c] = Vector2i(9 + (1 if nzb.get_noise_2d(x, z) > 0.3 else 0), 6)
				kind[c] = 0
	# pilíře a pochodně
	for p in [Vector2(16, 22), Vector2(30, 22), Vector2(16, 26.5), Vector2(30, 26.5), Vector2(14, 5), Vector2(14, 11), Vector2(32, 5), Vector2(32, 11), Vector2(19, 8), Vector2(27, 8), Vector2(19, 12), Vector2(27, 12)]:
		_pillar(p)
	for b in [Vector2(19.5, 37.5), Vector2(26.5, 37.5), Vector2(19, 21.5), Vector2(27, 21.5), Vector2(19, 27), Vector2(27, 27), Vector2(5, 20.5), Vector2(10, 20.5), Vector2(37, 20.5), Vector2(41, 20.5), Vector2(17, 4.5), Vector2(29, 4.5), Vector2(15, 13.0), Vector2(31, 13.0), Vector2(22, 15)]:
		_brazier(b)
	# vstupní síň: tábor s ohništěm (vaření)
	_inst("w_ohniste", Vector2(23, 40), 0.0).add_to_group("ohniste", true)
	_omni(Vector3(23, 1.4, 40), Color(1.0, 0.6, 0.25), 3.0, 8.0)
	_inst("w_bedna_velka", Vector2(19.5, 42.2), 10.0)
	_inst("w_bedna_mala", Vector2(20.8, 42.4), 40.0)
	_inst("w_sud", Vector2(26.8, 42.0), 0.0)
	_inst("lp_barel", Vector2(26.0, 42.5), 70.0)
	# západní krypta: sklad
	_chest(Vector2(4.5, 28.0), 90.0, 1, [["ruda", 3], ["gold", 120], ["lektvar", 2]])
	_inst("w_bedna_otevrena", Vector2(6.5, 28.6), 20.0)
	_inst("w_bedna_mala", Vector2(8.0, 28.4), 60.0)
	_inst("w_sud", Vector2(10.5, 28.2), 0.0)
	_inst("w_hrob", Vector2(7.0, 23.5), 90.0)
	_inst("w_hrob", Vector2(7.0, 26.0), 90.0)
	# východní krypta: sarkofágy a lahve
	_inst("w_hrob", Vector2(38.0, 22.5), 0.0)
	_inst("w_hrob", Vector2(38.0, 26.5), 0.0)
	_inst("w_pytle", Vector2(41.0, 28.0), 20.0)
	_inst("lp_barel", Vector2(35.0, 28.5), 0.0)
	_inst("w_kotlik", Vector2(41.0, 21.5), 10.0)
	_chest(Vector2(35.0, 20.5), 180.0, 2, [["kost", 4], ["gold", 200], ["zelezny_mec", 1]])
	_inst("w_socha", Vector2(23, 22.0), 0.0)
	# trůn krále
	_inst("w_hrob", Vector2(23, 3.4), 0.0, 1.4)
	_inst("w_socha", Vector2(14.5, 8.0), 90.0)
	_inst("w_socha", Vector2(31.5, 8.0), -90.0)
	_inst("w_krystaly", Vector2(12.5, 13.0), 0.0, 0.8)
	_inst("w_krystaly", Vector2(33.5, 13.0), 0.0, 0.8)
	# pavučiny v rozích
	for w in [Vector3(14.6, 3.6, 20.6), Vector3(31.4, 3.6, 20.6), Vector3(11.6, 3.6, 19.6), Vector3(34.4, 3.6, 19.6), Vector3(11.6, 3.6, 3.0), Vector3(34.4, 3.6, 3.0), Vector3(18.6, 3.6, 36.6), Vector3(27.4, 3.6, 36.6)]:
		_web(w, 45.0 if w.x < 23 else -45.0, 3.0)
	# světelný sloup v křižovatce
	_shaft(Vector3(23, 0, 24.5), 9.0, 2.0)
	_shaft(Vector3(8, 0, 25), 8.0, 1.5)
	_mark("Vchod", Vector3(23.0, 0, 41.0))
	_exit("Vychod_hrobka", Vector3(23.0, 0, 44.2), Vector3(5, 2.5, 1.0), "res://scenes/hrbitov.tscn", "Z_hrobky")
	_foe_at("Hrobka_1", ["skeleton", "skeleton"], Vector2(23, 31), 2.0)
	_foe_at("Hrobka_2", ["skeleton", "skeleton", "bandit"], Vector2(23, 25), 3.0)
	_foe_at("Hrobka_5", ["ghost", "ghost"], Vector2(23, 17), 2.0)
	_foe_at("Hrobka_6", ["knight", "skeleton"], Vector2(23, 11), 1.5)
	_foe_at("Hrobka_3", ["skeleton", "slime", "skeleton"], Vector2(7.5, 25), 2.5)
	_foe_at("Hrobka_4", ["skeleton", "bandit", "skeleton"], Vector2(38.5, 25), 2.5)
	_foe_at("Kral", ["king"], Vector2(23, 5.0), 0.4)
	_finish("res://scenes/hrobka.tscn", Vector3(23.0, 0, 41.0), [])
	indoor = false
	sun_energy = 0.95
