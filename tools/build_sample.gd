extends SceneTree
## Generátor ukázkové mapy "Louka". Spuštění: godot --headless --path . -s res://tools/build_sample.gd

const T := "res://textures/"
const SUN := Vector3(-48, -38, 0)
const CAM_PITCH := 35.0
const X0 := -18
const X1 := 60
const Z0 := -22
const Z1 := 40
const CLEAR := Vector2(17.5, 12.5)

var rng := RandomNumberGenerator.new()
var nz := FastNoiseLite.new()
var nz2 := FastNoiseLite.new()
var nzb := FastNoiseLite.new()
var lit := {}
var mats: Array[TerrainMat] = []
var vtypes: Array[VegType] = []
var kind := {}  # Vector2i -> 0 les, 1 louka, 2 palouček, 3 cesta
var tm: TerrainMap


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	rng.seed = 1337
	nz.seed = 5
	nz.frequency = 0.11
	nz2.seed = 9
	nz2.frequency = 0.2
	nzb.seed = 21
	nzb.frequency = 0.25
	lit = JSON.parse_string(FileAccess.get_file_as_string("res://tools/lit.json"))
	_make_library()
	_make_props()
	_make_map()
	print("HOTOVO")
	quit()


# ---------------- knihovna ----------------
func _clear(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d:
		for f in d.get_files():
			d.remove(f)


func _make_library() -> void:
	_clear(TerrainMap.MAT_DIR)
	_clear(VegetationLayer.VEG_DIR)
	var defs := [
		["Tráva", "ground/trava", "cliff/hlina_utes"], ["Tráva tmavá", "ground/trava_tmava", "cliff/hlina_utes"],
		["Hlína (cesta)", "ground/hlina", "cliff/hlina_utes"], ["Štěrk", "ground/sterk", "cliff/hlina_utes"],
		["Listí", "ground/listi", "cliff/hlina_utes"], ["Květinová louka", "ground/kvetiny", "cliff/hlina_utes"],
		["Dlažba", "ground/dlazba", "cliff/kamen_utes"], ["Les", "ground/les", "cliff/hlina_utes"]]
	for d in defs:
		var m := TerrainMat.new()
		m.mat_name = d[0]
		m.top_texture = load(T + d[1] + ".png")
		m.side_texture = load(T + d[2] + ".png")
		if d[0] == "Tráva" or d[0] == "Tráva tmavá" or d[0] == "Květinová louka":
			m.color = Color(0.86, 0.9, 0.84)
		if d[0] == "Les":
			m.color = Color(0.55, 0.66, 0.55)
		if d[0] == "Štěrk":
			m.color = Color(0.6, 0.56, 0.5)
		Lib.save_new(TerrainMap.MAT_DIR, m)
		mats.append(m)
	var sun_ang := _sun_angle()
	var veg := [
		["Tráva (chomáč)", "veg/trava_chomac", 330.0, false, 1, 0, 0.7, 1.1],
		["Tráva (klasy)", "veg/trava_klasy", 300.0, false, 1, 0, 0.7, 1.1],
		["Zlatá tráva", "veg/trava_zlata", 300.0, false, 1, 0, 0.7, 1.1],
		["Kapradí", "veg/kapradi", 230.0, false, 1, 0, 0.8, 1.2],
		["Kopretiny", "veg/kopretiny", 280.0, false, 1, 0, 0.8, 1.2],
		["Levandule", "veg/levandule", 280.0, false, 1, 0, 0.8, 1.2],
		["Slunečnice", "veg/slunecnice", 190.0, false, 1, 0, 0.8, 1.2],
		["Strom (pixel)", "trees/strom_pixel", 78.0, true, 1, 0, 0.85, 1.2],
		["Smrk", "trees/strom_smrk_sheet", 70.0, false, 12, _best_frame("strom_smrk", sun_ang), 0.85, 1.2],
		["Listnatý strom", "trees/strom_listnaty_sheet", 78.0, false, 12, _best_frame("strom_listnaty", sun_ang), 0.85, 1.2]]
	for v in veg:
		var t := VegType.new()
		t.veg_name = v[0]
		t.texture = load(T + v[1] + ".png")
		t.ppm = v[2]
		t.nearest = v[3]
		t.hframes = v[4]
		t.frame = v[5]
		t.scale_min = v[6]
		t.scale_max = v[7]
		if v[1].begins_with("veg/trava") or v[1] == "veg/kapradi":
			t.tint = Color(0.86, 0.92, 0.66)
		Lib.save_new(VegetationLayer.VEG_DIR, t)
		vtypes.append(t)


func _sun_angle() -> float:
	var l := Basis.from_euler(Vector3(deg_to_rad(SUN.x), deg_to_rad(SUN.y), 0)).z
	var cb := Basis.from_euler(Vector3(deg_to_rad(-CAM_PITCH), 0, 0))
	return rad_to_deg(atan2(l.dot(cb.y), l.dot(cb.x)))


func _best_frame(key: String, ang: float) -> int:
	var best := 0
	var bd := 1000.0
	var a: Array = lit[key]["angles"]
	for i in a.size():
		var d := absf(wrapf(float(a[i]) - ang, -180.0, 180.0))
		if d < bd:
			bd = d
			best = i
	return best


# ---------------- objekty (props) ----------------
func _owner_all(n: Node, o: Node) -> void:
	for c in n.get_children():
		c.owner = o
		_owner_all(c, o)


func _save_prop(root: Node3D, nm: String) -> void:
	_owner_all(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://props/%s.tscn" % nm)
	root.free()


func _sprite(tex: Texture2D, ppm: float, nearest: bool, shaded: bool) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "Sprite"
	s.texture = tex
	s.pixel_size = 1.0 / ppm
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if nearest else BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if nearest else SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.shaded = shaded
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position.y = tex.get_height() / ppm * 0.5
	return s


func _body(root: Node3D, shape: Shape3D, y: float) -> void:
	var b := StaticBody3D.new()
	b.name = "Kolize"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = y
	b.add_child(cs)
	root.add_child(b)


func _make_props() -> void:
	_clear("res://props")
	for def in [["strom_listnaty", "trees/strom_listnaty_sheet", 78.0, 0.35], ["strom_smrk", "trees/strom_smrk_sheet", 70.0, 0.35]]:
		var root := Node3D.new()
		root.name = def[0]
		var key: String = def[0]
		var sp := LitSprite3D.new()
		var base := _sprite(load(T + def[1] + ".png"), def[2], false, false)
		sp.name = "Sprite"
		sp.texture = base.texture
		sp.hframes = 12
		sp.pixel_size = base.pixel_size
		sp.billboard = base.billboard
		sp.texture_filter = base.texture_filter
		sp.alpha_cut = base.alpha_cut
		sp.shaded = false
		sp.double_sided = true
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position.y = base.position.y
		sp.frame_angles = PackedFloat32Array(lit[key]["angles"])
		sp.frame = _best_frame(key, _sun_angle())
		base.free()
		root.add_child(sp)
		var sh := HD2DSprite.blob_shadow()
		sh.scale = Vector3(2.6, 2.6, 2.6)
		root.add_child(sh)
		var cyl := CylinderShape3D.new()
		cyl.radius = def[3]
		cyl.height = 2.0
		_body(root, cyl, 1.0)
		_save_prop(root, key)
	var r := Node3D.new()
	r.name = "strom_pixel"
	r.add_child(_sprite(load(T + "trees/strom_pixel.png"), 78.0, true, true))
	var sh2 := HD2DSprite.blob_shadow()
	sh2.scale = Vector3(2.8, 2.8, 2.8)
	r.add_child(sh2)
	var cyl2 := CylinderShape3D.new()
	cyl2.radius = 0.35
	cyl2.height = 2.0
	_body(r, cyl2, 1.0)
	_save_prop(r, "strom_pixel")
	_make_models()


# ---------------- 3D modely (lowpoly) ----------------
# název props : [glb, měřítko, tvar kolize ("box"/"cyl"/""), velikost]
const MODELS := {
	"lp_stan": ["Tent", 1.7, "box", Vector3(3.3, 2.6, 4.6)],
	"lp_barel": ["Barrel", 1.25, "cyl", Vector3(0.5, 1.1, 0)],
	"lp_truhla": ["Chest", 1.3, "box", Vector3(1.3, 0.9, 0.85)],
	"lp_kamen_velky": ["Rock_Big", 1.5, "box", Vector3(2.9, 1.5, 2.3)],
	"lp_kamen_1": ["Rock_S1", 1.8, "cyl", Vector3(0.45, 0.6, 0)],
	"lp_kamen_2": ["Rock_S2", 1.8, "cyl", Vector3(0.5, 0.35, 0)],
	"lp_kamen_3": ["Rock_S3", 1.8, "cyl", Vector3(0.45, 0.7, 0)],
	"lp_kamen_4": ["Rock_S4", 1.8, "cyl", Vector3(0.5, 0.5, 0)],
	"lp_domek": ["House_Cabin", 1.0, "box", Vector3(5.2, 3.5, 4.0)],
	"lp_obchod_1": ["House_Shop1", 1.0, "box", Vector3(5.6, 4.0, 5.0)],
	"lp_obchod_2": ["House_Shop2", 1.0, "box", Vector3(4.8, 4.5, 4.5)],
	"lp_dub": ["Tree_Oak", 1.4, "cyl", Vector3(0.45, 2.0, 0)],
	"lp_borovice": ["Tree_Pine", 1.4, "cyl", Vector3(0.4, 2.0, 0)]}
var _tex_cache := {}


func _make_models() -> void:
	DirAccess.make_dir_recursive_absolute("res://textures/models")
	for key in MODELS:
		var def: Array = MODELS[key]
		var ps := load("res://models/%s.glb" % def[0]) as PackedScene
		if ps == null:
			push_warning("Chybí model " + def[0])
			continue
		var root := Node3D.new()
		root.name = key
		var m := ps.instantiate() as Node3D
		m.name = "Model"
		m.scale = Vector3.ONE * float(def[1])
		root.add_child(m)
		_fix_mats(m, key)
		if def[2] == "box":
			var bs := BoxShape3D.new()
			bs.size = def[3]
			_body(root, bs, def[3].y * 0.5)
		elif def[2] == "cyl":
			var cs := CylinderShape3D.new()
			cs.radius = def[3].x
			cs.height = def[3].y
			_body(root, cs, def[3].y * 0.5)
		_save_prop(root, key)


func _fix_mats(n: Node, key: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			var nm := src.duplicate() as StandardMaterial3D
			var low := String(src.resource_name).to_lower()
			nm.roughness = 0.92
			nm.metallic = 0.25 if low.contains("metal") else 0.0
			nm.metallic_specular = 0.25
			nm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			nm.cull_mode = BaseMaterial3D.CULL_DISABLED if (low.contains("leaves") or low.contains("canvas")) else BaseMaterial3D.CULL_BACK
			if nm.albedo_texture:
				nm.albedo_texture = _enhance(nm.albedo_texture, key + "_" + str(i) + "_" + low)
			mi.set_surface_override_material(i, nm)
	for c in n.get_children():
		_fix_mats(c, key)


# zvýší kontrast a sytost, přidá jemné zrno a uloží jako vlastní texturu
func _enhance(tex: Texture2D, id: String) -> Texture2D:
	var path := "res://textures/models/%s.res" % id.validate_filename()
	if _tex_cache.has(path):
		return _tex_cache[path]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.adjust_bcs(0.82 if id.begins_with("lp_kamen") else 0.9, 1.12, 1.15)
	var gn := FastNoiseLite.new()
	gn.seed = id.hash()
	gn.frequency = 0.35
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var k := 1.0 + gn.get_noise_2d(x, y) * 0.12
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	ResourceSaver.save(out, path)
	var loaded := load(path) as Texture2D
	_tex_cache[path] = loaded if loaded else out
	return _tex_cache[path]



# ---------------- mapa ----------------
func _path_x(z: float) -> float:
	return 17.5 + 1.4 * sin((z - 14.0) * 0.28)


func _in_meadow(x: int, z: int) -> bool:
	var xl := -5.0 + 1.6 * nz.get_noise_1d(z * 9.0)
	var xr := 45.0 + 1.6 * nz.get_noise_1d(z * 9.0 + 500.0)
	var zt := -9.0 + 1.6 * nz.get_noise_1d(x * 9.0 + 900.0)
	if z >= 32:
		return z <= Z1 - 2 and absf(x + 0.5 - _path_x(z)) <= 3.6
	return x >= xl and x < xr and z >= zt


func _make_map() -> void:
	tm = TerrainMap.new()
	tm.name = "TerrainMap"
	tm.materials = mats
	var meadow := {}
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			if _in_meadow(x, z):
				meadow[Vector2i(x, z)] = true
	# materiály a úrovně
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			var c := Vector2i(x, z)
			var cx := x + 0.5
			var cz := z + 0.5
			if not meadow.has(c):
				var lvl := 3 + (1 if nz.get_noise_2d(x * 0.45, z * 0.45) > 0.1 else 0)
				var m := 7 if nzb.get_noise_2d(x, z) > -0.15 else 1
				tm.cells[c] = Vector2i(lvl, m)
				kind[c] = 0
				continue
			var k := 1
			var m := 0
			if nz.get_noise_2d(x, z) > 0.22:
				m = 1
			elif nz2.get_noise_2d(x * 1.3, z * 1.3) > 0.42 and z < 31:
				m = 5
			# blízkost lesa -> listí
			var near := false
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					if not meadow.has(Vector2i(x + dx, z + dz)) and z < 32:
						near = true
			if near and rng.randf() < 0.55:
				m = 4
			# cesta
			var px := _path_x(cz)
			if cz >= 12.0 and absf(cx - px) <= 1.6:
				m = 3 if rng.randf() < 0.12 else 2
				k = 3
			elif cz >= 12.0 and absf(cx - px) <= 2.2 and rng.randf() < 0.35:
				m = 2
			# palouček
			var dist := Vector2(cx, cz).distance_to(CLEAR)
			var rad := 4.0 + 0.8 * nzb.get_noise_2d(x * 3.0, z * 3.0)
			if dist <= rad:
				m = 3 if dist <= rad - 1.7 else 2
				k = 2
			elif dist <= rad + 1.0 and rng.randf() < 0.4:
				m = 2
			tm.cells[c] = Vector2i(0, m)
			kind[c] = k
	# vyvýšená plošina A + rampa
	for x in range(7, 12):
		for z in range(20, 24):
			tm.cells[Vector2i(x, z)] = Vector2i(2, 0)
	for z in [21, 22]:
		tm.cells[Vector2i(12, z)] = Vector2i(2, 0)
		tm.set_slope(Vector2i(12, z), 1, 2, 0)
		tm.cells[Vector2i(13, z)] = Vector2i(1, 0)
		tm.set_slope(Vector2i(13, z), 1, 1, 0)
	# plošina B + rampa
	for x in range(25, 29):
		for z in range(15, 19):
			tm.cells[Vector2i(x, z)] = Vector2i(1, 0)
	for z in [16, 17]:
		tm.cells[Vector2i(24, z)] = Vector2i(1, 0)
		tm.set_slope(Vector2i(24, z), 2, 1, 0)
	tm.sync_data()
	# vrstvy
	var root := Node3D.new()
	root.name = "Louka"
	root.add_child(tm)
	tm.owner = root
	var veg := VegetationLayer.new()
	veg.name = "Vegetation"
	tm.add_child(veg)
	veg.owner = root
	veg.types = vtypes
	veg.data = _scatter_veg()
	var props := PropLayer.new()
	props.name = "Props"
	tm.add_child(props)
	props.owner = root
	_place_props(props, root)
	var marks := Node3D.new()
	marks.name = "Marks"
	tm.add_child(marks)
	marks.owner = root
	_mark(marks, root, "Start", Vector3(_path_x(28.5), 0, 28.5))
	_mark(marks, root, "Z_jihu", Vector3(_path_x(30.0), 0, 30.0))
	_mark(marks, root, "Cervena_znacka", Vector3(14.3, 0, 9.0))
	var ex := SceneExit.new()
	ex.name = "Vychod_jih"
	ex.size = Vector3(7, 2.5, 1)
	ex.position = Vector3(_path_x(37.5), 0, 37.5)
	marks.add_child(ex)
	ex.owner = root
	# slunce, hráč, kamera
	var sun := DirectionalLight3D.new()
	sun.name = "Slunce"
	sun.rotation_degrees = SUN
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)
	sun.owner = root
	var pl := Player3D.new()
	pl.name = "Player"
	pl.position = Vector3(_path_x(28.5), 0.1, 28.5)
	root.add_child(pl)
	pl.owner = root
	var cam := HD2DCamera.new()
	cam.name = "Camera"
	root.add_child(cam)
	cam.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://scenes/louka.tscn")
	root.free()


func _mark(parent: Node, root: Node, nm: String, pos: Vector3) -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	parent.add_child(m)
	m.owner = root


func _vi(arr: PackedFloat32Array, x: float, z: float, t: int) -> void:
	var h := tm.height_at(x, z)
	if is_inf(h):
		return
	var v := vtypes[t]
	arr.push_back(x)
	arr.push_back(h)
	arr.push_back(z)
	arr.push_back(rng.randf_range(v.scale_min, v.scale_max))
	arr.push_back(float(t))


func _scatter_veg() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for c in tm.cells:
		var v: Vector2i = tm.cells[c]
		var k: int = kind.get(c, 0)
		var m := v.y & 255
		var fx := float(c.x)
		var fz := float(c.y)
		if (v.y >> 8) != 0:
			continue
		if k == 0:
			# les: stromy, hustěji u okraje louky
			var ed := 9
			for dx in range(-4, 5):
				for dz in range(-4, 5):
					if kind.get(Vector2i(c.x + dx, c.y + dz), 0) != 0:
						ed = mini(ed, maxi(absi(dx), absi(dz)))
			var p := 0.62 if ed <= 3 else 0.3
			if c.y >= 30 and absf(c.x + 0.5 - _path_x(c.y + 0.5)) < 5.5:
				p = 0.05
			if rng.randf() < p:
				var t: int = [8, 9, 9, 8, 9, 8, 9, 9][rng.randi() % 8]
				_vi(a, fx + rng.randf(), fz + rng.randf(), t)
			if rng.randf() < 0.18:
				_vi(a, fx + rng.randf(), fz + rng.randf(), 3)
			continue
		if k == 2:
			if rng.randf() < 0.1:
				_vi(a, fx + rng.randf(), fz + rng.randf(), 0)
			continue
		if k == 3:
			if rng.randf() < 0.07:
				_vi(a, fx + rng.randf(), fz + rng.randf(), 0)
			continue
		# louka
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
		elif rng.randf() < 0.07:
			var r3 := rng.randf()
			_vi(a, fx + rng.randf(), fz + rng.randf(), 4 if r3 < 0.5 else (5 if r3 < 0.8 else 6))
	return a


func _place_props(layer: Node3D, root: Node3D) -> void:
	var trees := ["strom_listnaty", "strom_smrk", "strom_listnaty", "strom_smrk", "strom_smrk"]
	var clusters := [[9, 8, 3.2], [9.5, 15, 2.8], [8, 22, 3.0], [11.5, 26, 2.5], [27, 7.5, 3.0], [28, 14, 3.0],
		[27, 22, 3.2], [25, 27, 2.5], [19.5, 5.8, 1.6], [13.5, 6.0, 1.6], [24.5, 5.5, 1.5],
		[-1, 12, 3.0], [-2, 24, 2.8], [40, 10, 3.0], [41, 22, 2.8], [37, 29, 2.2], [5, -3, 3.0], [17, -5, 2.6], [31, -3, 3.0], [24, -7, 2.0]]
	var placed: Array[Vector2] = []
	for cl in clusters:
		var n := int(cl[2] * 1.7)
		var tries := 0
		var got := 0
		while got < n and tries < 200:
			tries += 1
			var a := rng.randf() * TAU
			var r: float = cl[2] * sqrt(rng.randf())
			var p := Vector2(cl[0] + cos(a) * r, cl[1] + sin(a) * r)
			if absf(p.x - _path_x(p.y)) < 3.2 and p.y > 10.0:
				continue
			if p.distance_to(CLEAR) < 6.4:
				continue
			if not kind.has(Vector2i(floori(p.x), floori(p.y))) or kind[Vector2i(floori(p.x), floori(p.y))] != 1:
				continue
			var ok := true
			for q in placed:
				if q.distance_to(p) < 2.4:
					ok = false
					break
			if not ok:
				continue
			placed.append(p)
			got += 1
			_inst(layer, root, trees[rng.randi() % 5], p)

	_place_models(layer, root)


func _place_models(layer: Node3D, root: Node3D) -> void:
	# tábor na paloučku: stan, sudy, truhla
	_inst3(layer, root, "lp_stan", CLEAR + Vector2(-0.8, -1.6), -12.0, 1.0)
	_inst3(layer, root, "lp_barel", CLEAR + Vector2(2.2, -1.2), 20.0, 1.0)
	_inst3(layer, root, "lp_barel", CLEAR + Vector2(3.0, -0.4), 70.0, 0.9)
	var ch := _inst3(layer, root, "lp_truhla", CLEAR + Vector2(-3.4, -0.6), 25.0, 1.0)
	_make_chest(ch, 1, [["zelezny_mec", 1], ["helma", 1], ["paklic", 2], ["gold", 60]])
	var ch2 := _inst3(layer, root, "lp_truhla", Vector2(26.6, 16.6), 200.0, 1.0)
	_make_chest(ch2, 3, [["telo", 1], ["kalhoty", 1], ["boty", 1], ["rukavice", 1], ["ozdobny_mec", 1], ["gold", 250]])
	# velké kameny
	for s in [Vector2(21.8, 8.6), Vector2(10.0, 28.6), Vector2(30.6, 24.2), Vector2(-1.8, 2.0), Vector2(40.5, 13.5), Vector2(8.0, -3.5), Vector2(28.0, -2.5), Vector2(3.0, 16.5)]:
		_inst3(layer, root, "lp_kamen_velky", s, rng.randf_range(0, 360), rng.randf_range(0.85, 1.2))
	# drobné kameny roztroušené po louce (mimo cestu a paloučky)
	var n := 0
	var tries := 0
	while n < 46 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(X0 + 12, X1 - 14), rng.randf_range(Z0 + 14, Z1 - 4))
		var c := Vector2i(floori(p.x), floori(p.y))
		if kind.get(c, 0) != 1:
			continue
		if p.y > 10.0 and absf(p.x - _path_x(p.y)) < 3.0:
			continue
		if p.distance_to(CLEAR) < 5.2:
			continue
		var nm := "lp_kamen_%d" % (1 + rng.randi() % 4)
		_inst3(layer, root, nm, p, rng.randf_range(0, 360), rng.randf_range(0.7, 1.3))
		n += 1



func _make_chest(n: Node3D, level: int, loot: Array) -> void:
	if n == null:
		return
	n.set_script(load("res://loot/chest.gd"))
	n.set("lock_level", level)
	n.set("loot", loot)


func _inst3(layer: Node3D, root: Node3D, nm: String, p: Vector2, yaw: float, sc: float) -> Node3D:
	var h := tm.height_at(p.x, p.y)
	if is_inf(h):
		return null
	var ps := load("res://props/%s.tscn" % nm) as PackedScene
	var n := ps.instantiate() as Node3D
	n.position = Vector3(p.x, h, p.y)
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * sc
	layer.add_child(n)
	n.owner = root
	return n


func _inst(layer: Node3D, root: Node3D, nm: String, p: Vector2) -> void:
	var h := tm.height_at(p.x, p.y)
	if is_inf(h):
		return
	var ps := load("res://props/%s.tscn" % nm) as PackedScene
	var n := ps.instantiate() as Node3D
	n.position = Vector3(p.x, h, p.y)
	var sc := rng.randf_range(0.9, 1.15)
	n.scale = Vector3(sc, sc, sc)
	layer.add_child(n)
	n.owner = root
