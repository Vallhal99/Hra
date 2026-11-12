@tool
class_name TerrainMap
extends Node3D
## Terén z čtvercových bloků a ramp. 1 dlaždice = 1 m = 32 px textury.
## Buňka: Vector2i(level, material + slope * 256). slope: 0 žádná, 1 klesá doprava (+X), 2 doleva, 3 k hráči (+Z), 4 dál (-Z).

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MAX_LEVEL := 60
const MAT_DIR := "res://library/materials"

@export var level_height := 0.5:
	set(v):
		level_height = v
		rebuild()
@export var materials: Array[TerrainMat] = []:
	set(v):
		materials = v
		rebuild()
@export_storage var data := PackedInt32Array(): set = set_data

var cells := {}
var _syncing := false


func _ready() -> void:
	if materials.is_empty():
		var lib: Array[TerrainMat] = []
		for r in Lib.list(MAT_DIR):
			if r is TerrainMat:
				lib.append(r)
		materials = lib if not lib.is_empty() else _defaults()
	rebuild()


func _defaults() -> Array[TerrainMat]:
	var out: Array[TerrainMat] = []
	var defs := [["Tráva", Color(0.42, 0.62, 0.3)], ["Hlína", Color(0.55, 0.4, 0.27)],
		["Kámen", Color(0.55, 0.55, 0.58)], ["Písek", Color(0.84, 0.77, 0.55)]]
	for d in defs:
		var m := TerrainMat.new()
		m.mat_name = d[0]
		m.color = d[1]
		out.append(m)
	return out


# ---------- data ----------
func set_data(v: PackedInt32Array) -> void:
	data = v
	if _syncing:
		return
	cells.clear()
	for i in range(0, v.size() - 3, 4):
		cells[Vector2i(v[i], v[i + 1])] = Vector2i(v[i + 2], v[i + 3])
	rebuild()


func pack() -> PackedInt32Array:
	var a := PackedInt32Array()
	for c in cells:
		var v: Vector2i = cells[c]
		a.append(c.x)
		a.append(c.y)
		a.append(v.x)
		a.append(v.y)
	return a


func sync_data() -> void:
	_syncing = true
	data = pack()
	_syncing = false


func height_at(x: float, z: float) -> float:
	var c := Vector2i(floori(x), floori(z))
	if not cells.has(c):
		return -INF
	var v: Vector2i = cells[c]
	var h := v.x * level_height
	var s := v.y >> 8
	if s == 0:
		return h
	var fx := x - c.x
	var fz := z - c.y
	var t := 0.0
	match s:
		1: t = fx
		2: t = 1.0 - fx
		3: t = fz
		4: t = 1.0 - fz
	return h - level_height * t


# ---------- editace ----------
func raise(c: Vector2i, delta: int, mat: int) -> void:
	if not cells.has(c):
		if delta > 0:
			cells[c] = Vector2i(0, mat)
		return
	var v: Vector2i = cells[c]
	var l := v.x + delta
	if l < 0:
		cells.erase(c)
	else:
		cells[c] = Vector2i(mini(l, MAX_LEVEL), v.y)


func set_level(c: Vector2i, level: int, mat: int) -> void:
	var v := Vector2i(clampi(level, 0, MAX_LEVEL), mat)
	if cells.has(c):
		v.y = (cells[c] as Vector2i).y
	cells[c] = v


func set_slope(c: Vector2i, dir: int, level: int, mat: int) -> void:
	if cells.has(c):
		var v: Vector2i = cells[c]
		cells[c] = Vector2i(v.x, (v.y & 255) | (dir << 8))
	else:
		cells[c] = Vector2i(clampi(level, 0, MAX_LEVEL), mat | (dir << 8))


func paint(c: Vector2i, mat: int) -> void:
	if cells.has(c):
		var v: Vector2i = cells[c]
		cells[c] = Vector2i(v.x, (v.y & ~255) | mat)


func erase(c: Vector2i) -> void:
	cells.erase(c)


func fill_rect(a: Vector2i, b: Vector2i, level: int, mat: int, remove: bool) -> void:
	for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
		for z in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			if remove:
				erase(Vector2i(x, z))
			else:
				set_level(Vector2i(x, z), level, mat)


func mountain(center: Vector2i, base: int, height: int, rough: bool, mat: int) -> void:
	var half := (base - 1) >> 1
	var step := maxi(1, roundi(float(height) / float(half + 1)))
	for dx in range(-half, half + 1):
		for dz in range(-half, half + 1):
			var ring := half - maxi(absi(dx), absi(dz))
			var lvl := (ring + 1) * step
			if rough and ring > 0 and randf() < 0.35:
				lvl += randi_range(-1, 1)
			set_level(center + Vector2i(dx, dz), maxi(lvl, 0), mat)


# ---------- mesh ----------
func _corners(v: Vector2i) -> Array:
	var b := v.x * level_height
	var r := [b, b, b, b]
	match v.y >> 8:
		1:
			r[1] -= level_height
			r[2] -= level_height
		2:
			r[0] -= level_height
			r[3] -= level_height
		3:
			r[2] -= level_height
			r[3] -= level_height
		4:
			r[0] -= level_height
			r[1] -= level_height
	return r


# rohy: 0 (x0,z0)  1 (x1,z0)  2 (x1,z1)  3 (x0,z1); vrací [moje A, moje B, sousedova A, sousedova B]
func _edge(d: Vector2i) -> Array:
	if d.x == 1:
		return [1, 2, 0, 3]
	if d.x == -1:
		return [0, 3, 1, 2]
	if d.y == 1:
		return [3, 2, 0, 1]
	return [0, 1, 3, 2]


func rebuild() -> void:
	if not is_inside_tree():
		return
	var mats := {}
	for i in materials.size():
		var tm := materials[i]
		if tm == null:
			continue
		if not tm.changed.is_connected(_on_mat_changed):
			tm.changed.connect(_on_mat_changed)
		var side_tex := tm.side_texture if tm.side_texture else tm.top_texture
		mats[i * 2 + 1] = _make_mat(side_tex, tm.color.darkened(0.2))
	if not cells.is_empty():
		mats[-1] = _top_material()
	var tools := {}
	for c in cells:
		var v: Vector2i = cells[c]
		var m := clampi(v.y & 255, 0, maxi(materials.size() - 1, 0))
		var ch := _corners(v)
		var x0 := float(c.x)
		var z0 := float(c.y)
		var p := [Vector3(x0, ch[0], z0), Vector3(x0 + 1, ch[1], z0), Vector3(x0 + 1, ch[2], z0 + 1), Vector3(x0, ch[3], z0 + 1)]
		var n := ((p[3] - p[0]) as Vector3).cross(p[1] - p[0]).normalized()
		_quad(_st(tools, -1), p,
			[Vector2(x0, z0), Vector2(x0 + 1, z0), Vector2(x0 + 1, z0 + 1), Vector2(x0, z0 + 1)], n)
		for d in DIRS:
			var nbr: Vector2i = c + d
			var e := _edge(d)
			var ha: float = ch[e[0]]
			var hb: float = ch[e[1]]
			var na := -level_height
			var nb := -level_height
			if cells.has(nbr):
				var nc := _corners(cells[nbr])
				na = nc[e[2]]
				nb = nc[e[3]]
			if na >= ha - 0.0001 and nb >= hb - 0.0001:
				continue
			var la := minf(na, ha)
			var lb := minf(nb, hb)
			var q0: Vector3 = p[e[0]]
			var q1: Vector3 = p[e[1]]
			_quad(_st(tools, m * 2 + 1),
				[Vector3(q0.x, la, q0.z), Vector3(q1.x, lb, q1.z), Vector3(q1.x, hb, q1.z), Vector3(q0.x, ha, q0.z)],
				[Vector2(q0.x + q0.z, -la), Vector2(q1.x + q1.z, -lb), Vector2(q1.x + q1.z, -hb), Vector2(q0.x + q0.z, -ha)],
				Vector3(d.x, 0, d.y))
	var mesh := ArrayMesh.new()
	var keys := tools.keys()
	keys.sort()
	for k in keys:
		(tools[k] as SurfaceTool).commit(mesh)
		if mats.has(k):
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[k])
	var mi := _node("_Mesh", MeshInstance3D.new()) as MeshInstance3D
	mi.mesh = mesh
	var body := _node("_Body", StaticBody3D.new()) as StaticBody3D
	var cs := _node("_Shape", CollisionShape3D.new(), body) as CollisionShape3D
	cs.shape = mesh.create_trimesh_shape() if mesh.get_surface_count() > 0 else null


func _on_mat_changed() -> void:
	call_deferred("rebuild")


func _node(n: String, fresh: Node, parent: Node = null) -> Node:
	var p := parent if parent else self
	var ex := p.get_node_or_null(n)
	if ex:
		fresh.free()
		return ex
	fresh.name = n
	p.add_child(fresh)
	return fresh


func _make_mat(tex: Texture2D, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = col
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	return m


func _st(tools: Dictionary, key: int) -> SurfaceTool:
	if not tools.has(key):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = s
	return tools[key]


func _quad(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	var o := [0, 1, 2, 0, 2, 3]
	var cr: Vector3 = ((p[1] - p[0]) as Vector3).cross(p[2] - p[0]) + ((p[2] - p[0]) as Vector3).cross(p[3] - p[0])
	if cr.dot(n) > 0:
		o = [0, 2, 1, 0, 3, 2]
	for i in o:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])


# ---------- vršek terénu: splat shader s organickými přechody ----------
const TOP_SHADER := """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2DArray tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D splat0 : filter_nearest, repeat_disable;
uniform sampler2D splat1 : filter_nearest, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec2 origin;
uniform vec2 area;
uniform float blend_depth = 0.14;
uniform float macro_strength = 0.12;
uniform float warp = 0.55;
uniform float rim_dark = 0.22;
uniform float rim_width = 0.09;
uniform float cloud_shadow = 0.10;
varying vec3 lpos;
void vertex() { lpos = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	// organicky zvlnena hranice: souradnice se deformuji sumem
	vec2 wxz = lpos.xz;
	vec2 wv = vec2(texture(noise_tex, wxz * 0.23).r, texture(noise_tex, wxz * 0.23 + vec2(0.37, 0.71)).r) - 0.5;
	vec2 wv2 = vec2(texture(noise_tex, wxz * 0.9 + vec2(0.13, 0.29)).r, texture(noise_tex, wxz * 0.9 + vec2(0.61, 0.17)).r) - 0.5;
	vec2 p = (wxz - origin) + wv * 2.0 * warp + wv2 * 0.5 * warp - vec2(0.5);
	// hladka (quintic) interpolace mezi bunkami misto kosoctvercu bilinearu
	vec2 fi = floor(p);
	vec2 f = p - fi;
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	ivec2 sz = ivec2(area);
	ivec2 i0 = clamp(ivec2(fi), ivec2(0), sz - ivec2(1));
	ivec2 i1 = clamp(ivec2(fi) + ivec2(1), ivec2(0), sz - ivec2(1));
	vec4 a = mix(mix(texelFetch(splat0, ivec2(i0.x, i0.y), 0), texelFetch(splat0, ivec2(i1.x, i0.y), 0), f.x),
		mix(texelFetch(splat0, ivec2(i0.x, i1.y), 0), texelFetch(splat0, ivec2(i1.x, i1.y), 0), f.x), f.y);
	vec4 b = mix(mix(texelFetch(splat1, ivec2(i0.x, i0.y), 0), texelFetch(splat1, ivec2(i1.x, i0.y), 0), f.x),
		mix(texelFetch(splat1, ivec2(i0.x, i1.y), 0), texelFetch(splat1, ivec2(i1.x, i1.y), 0), f.x), f.y);
	float w[8] = float[8](a.r, a.g, a.b, a.a, b.r, b.g, b.b, b.a);
	float sum = a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a;
	float n = texture(noise_tex, lpos.xz * 0.5).r;
	vec3 c[8];
	float v[8];
	float mx = -10.0;
	float mx2 = -10.0;
	for (int i = 0; i < 8; i++) {
		w[i] /= max(sum, 0.0001);
		if (w[i] > 0.01) {
			c[i] = textureLod(tex, vec3(lpos.xz, float(i)), 0.0).rgb;
			float l = dot(c[i], vec3(0.3, 0.59, 0.11));
			v[i] = w[i] + (l - 0.5) * 0.35 + (n - 0.5) * 0.25;
		} else {
			c[i] = vec3(0.0);
			v[i] = -10.0;
		}
		if (v[i] > mx) { mx2 = mx; mx = v[i]; } else if (v[i] > mx2) { mx2 = v[i]; }
	}
	vec3 col = vec3(0.0);
	float tot = 0.0;
	float dw = 0.0;
	float gw = 0.0;
	for (int i = 0; i < 8; i++) {
		float k = max(v[i] - (mx - blend_depth), 0.0);
		col += c[i] * k;
		tot += k;
		if (i == 2 || i == 3) { dw += k; }
		if (i == 0 || i == 1 || i == 5 || i == 7) { gw += k; }
	}
	col /= max(tot, 0.0001);
	dw /= max(tot, 0.0001);
	gw /= max(tot, 0.0001);
	// ---- detaily na zemi: oblazky, pukliny, stebla trav, kvitky ----
	vec2 q = lpos.xz;
	vec2 pg = q * 2.2;
	vec2 pid = floor(pg);
	vec2 pf = fract(pg);
	float ph1 = hash(pid);
	vec2 pc = vec2(hash(pid + vec2(3.1, 1.7)), hash(pid + vec2(7.3, 2.9))) * 0.5 + 0.25;
	float prad = 0.06 + 0.07 * fract(ph1 * 7.3);
	float on = step(0.72, ph1);
	float peb = on * (1.0 - smoothstep(prad - 0.03, prad, length((pf - pc) * vec2(1.0, 1.25))));
	float pshd = on * (1.0 - smoothstep(prad - 0.03, prad + 0.06, length((pf - pc - vec2(0.1, 0.13)) * vec2(1.0, 1.25))));
	col = mix(col, col * 0.72, dw * pshd * (1.0 - peb));
	col = mix(col, mix(col, vec3(dot(col, vec3(0.33))) * 1.15, 0.5) * (0.95 + 0.25 * fract(ph1 * 13.1)), dw * peb);
	float crk = abs(texture(noise_tex, q * 0.42).r - 0.5);
	col *= 1.0 - dw * 0.3 * (1.0 - smoothstep(0.0, 0.02, crk));
	float bl = texture(noise_tex, vec2(q.x * 5.0, q.y * 1.1)).r;
	col *= 1.0 + gw * (smoothstep(0.42, 0.72, bl) - 0.4) * 0.24;
	vec2 fg = q * 1.6;
	vec2 fid = floor(fg);
	vec2 ff = fract(fg);
	vec2 fc2 = vec2(hash(fid + vec2(1.3, 4.1)), hash(fid + vec2(5.9, 2.2))) * 0.6 + 0.2;
	float fl = step(0.82, hash(fid + vec2(9.1, 0.3))) * (1.0 - smoothstep(0.07, 0.1, length(ff - fc2)));
	vec3 fcol = mix(vec3(0.95, 0.95, 0.88), vec3(1.0, 0.82, 0.22), step(0.5, hash(fid + vec2(2.2, 8.8))));
	col = mix(col, fcol, gw * gw * fl * 0.9);
	// tmavsi lem na styku materialu = jemny kontaktni stin (malovany vzhled)
	float rim = (mx2 > -5.0) ? 1.0 - smoothstep(0.0, rim_width + blend_depth, mx - mx2) : 0.0;
	col *= 1.0 - rim_dark * rim * rim;
	// makro variace ve dvou meritkach (barevne skvrny, aby plocha nebyla plocha)
	float macro = texture(noise_tex, lpos.xz * 0.06).r;
	float macro2 = texture(noise_tex, lpos.xz * 0.19 + vec2(0.5, 0.2)).r;
	col *= 1.0 - macro_strength + macro * macro_strength * 2.0;
	col *= 0.94 + macro2 * 0.12;
	col = mix(col, col * vec3(1.06, 1.0, 0.9), smoothstep(0.5, 0.75, macro2) * 0.5);
	// pomale plouci stiny mraku
	float cl = texture(noise_tex, lpos.xz * 0.028 + vec2(TIME * 0.006, TIME * 0.003)).r;
	col *= 1.0 - cloud_shadow * smoothstep(0.52, 0.66, cl);
	ALBEDO = col;
	ROUGHNESS = 1.0;
}
"""

static var _noise: ImageTexture
static var _shader: Shader
var _tex_key := ""
var _tex_array: Texture2DArray


static func _noise_tex() -> ImageTexture:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.035
		n.seed = 11
		_noise = ImageTexture.create_from_image(n.get_seamless_image(128, 128, false, false, 0.1, true))
	return _noise


func _layer_images() -> Array[Image]:
	var sz := 16
	for tm in materials:
		if tm and tm.top_texture:
			sz = maxi(sz, mini(tm.top_texture.get_width(), 128))
	var out: Array[Image] = []
	for i in 8:
		var tm: TerrainMat = materials[i] if i < materials.size() else null
		var img: Image = null
		if tm and tm.top_texture:
			img = tm.top_texture.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != sz or img.get_height() != sz:
				img.resize(sz, sz, Image.INTERPOLATE_NEAREST)
			if tm.color != Color.WHITE:
				for x in sz:
					for y in sz:
						img.set_pixel(x, y, img.get_pixel(x, y) * tm.color)
		else:
			img = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
			img.fill(tm.color if tm else Color(0.4, 0.4, 0.4))
		out.append(img)
	return out


func _top_material() -> ShaderMaterial:
	var mn := Vector2i(1 << 30, 1 << 30)
	var mx := Vector2i(-(1 << 30), -(1 << 30))
	for c in cells:
		mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
		mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
	var size := mx - mn + Vector2i.ONE
	var s0 := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var s1 := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	s0.fill(Color(0, 0, 0, 0))
	s1.fill(Color(0, 0, 0, 0))
	var top_mat := maxi(mini(materials.size(), 8) - 1, 0)
	for c in cells:
		var m := mini((cells[c] as Vector2i).y & 255, top_mat)
		var col := Color(0, 0, 0, 0)
		col[m % 4] = 1.0
		(s0 if m < 4 else s1).set_pixelv(c - mn, col)
	var key := ""
	for tm in materials:
		key += "%d:%d:%s;" % [tm.get_instance_id() if tm else 0, tm.top_texture.get_instance_id() if (tm and tm.top_texture) else 0, tm.color.to_html() if tm else ""]
	if key != _tex_key or _tex_array == null:
		_tex_key = key
		_tex_array = Texture2DArray.new()
		_tex_array.create_from_images(_layer_images())
	if _shader == null:
		_shader = Shader.new()
		_shader.code = TOP_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = _shader
	sm.set_shader_parameter("tex", _tex_array)
	sm.set_shader_parameter("splat0", ImageTexture.create_from_image(s0))
	sm.set_shader_parameter("splat1", ImageTexture.create_from_image(s1))
	sm.set_shader_parameter("noise_tex", _noise_tex())
	sm.set_shader_parameter("origin", Vector2(mn))
	sm.set_shader_parameter("area", Vector2(size))
	return sm
