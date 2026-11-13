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
	print("HOTOVO")
	quit()


# ---------------- společné ----------------
func _begin(nm: String, x0: int, x1: int, z0: int, z1: int, seed_: int) -> void:
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
			_inst(names[rng.randi() % 5], p)


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


func _finish(path: String, spawn: Vector3, speaker_npcs: Array = []) -> void:
	tm.sync_data()
	var veg := VegetationLayer.new()
	veg.name = "Vegetation"
	tm.add_child(veg)
	veg.owner = scn
	veg.types = vtypes
	veg.data = _scatter()
	var sun := DirectionalLight3D.new()
	sun.name = "Slunce"
	sun.rotation_degrees = SUN
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	scn.add_child(sun)
	sun.owner = scn
	for d in speaker_npcs:
		var npc := NPC3D.new()
		npc.name = d[0]
		npc.speaker = d[1]
		npc.lines = d[2]
		npc.position = Vector3(d[3].x, _h(d[3].x, d[3].y), d[3].y)
		scn.add_child(npc)
		npc.owner = scn
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
			var corr := absf(cx - J.x) < 5.0 + 1.2 * nzv and cz < J.y
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
			var onv := absf(cx - J.x) <= 1.7 + 0.3 * nzv and cz < J.y
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
		_inst(h[0], h[1], h[2], h[3])
		noveg.append(Rect2(h[1].x - 7.0, h[1].y - 7.0, 14.0, 14.0))
	noveg.append(Rect2(plaza.x - 4.5, plaza.y - 4.5, 9, 9))
	noveg.append(Rect2(stair_x0 - 1, 21.0, 6, 6))
	_inst("w_studna", plaza, 0.0, 1.0)
	# kovárna (Well) na dolní úrovni nad cestou, vchod k jihu
	_inst("w_kovarna", Vector2(12.5, 33.0), 0.0, 1.0)
	noveg.append(Rect2(6.0, 28.0, 14, 9))
	_inst("w_stojan_zbroje", Vector2(18.2, 34.8), 200.0, 1.0)
	_inst("w_ohnisko_miska", Vector2(7.2, 35.8), 0.0, 1.0)
	_inst("w_kotlik", Vector2(18.8, 31.8), 120.0, 1.0)
	_inst("w_bedna_velka", Vector2(6.8, 31.0), 30.0, 1.0)
	_inst("w_pytle", Vector2(20.2, 33.2), 80.0, 1.0)
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
	_rocks(26, [1, 4], [Rect2(0, 0, 0, 0)])
	_edge_trees(110, 2.3)
	# značky a východ
	_mark("Ze_zapadu", Vector3(3.5, 0, 39.0))
	_mark("Start", Vector3(3.5, 0, 39.0))
	_exit("Vychod_zapad", Vector3(0.8, 0, 39.0), Vector3(1, 2.5, 7), "res://scenes/rozcesti.tscn", "Z_prava")
	var npcs := [
		["Vesnican1", "Vesničan", "Vítej ve vesnici!|Nahoře na kopci bydlí truhlář a kovář.|Pozor na vlky v lese.", Vector2(30.5, 36.0)],
		["Vesnican2", "Stará Anna", "Kašna je tu starší než celá vesnice.|Voda z ní nikdy nevyschla.", Vector2(35.5, 31.5)],
		["Strazny", "Strážný", "Kdo chce na kopec, musí po schodech.|Dávej na sebe pozor, cizinče.", Vector2(25.5, 28.0)]]
	_finish("res://scenes/vesnice.tscn", Vector3(3.5, 0, 39.0), npcs)
