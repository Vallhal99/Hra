@tool
class_name VegetationLayer
extends Node3D
## Tráva a vegetace: tisíce billboardů v MultiMesh. Rodič musí být TerrainMap.

const MAX_INSTANCES := 30000
const PX := 1.0 / 32.0
const VEG_DIR := "res://library/vegetation"

@export var types: Array[VegType] = []:
	set(v):
		types = v
		for t in types:
			if t and not t.changed.is_connected(_on_type_changed):
				t.changed.connect(_on_type_changed)
		rebuild()
@export_storage var data := PackedFloat32Array(): set = set_data # x,y,z,scale,type


func _ready() -> void:
	if types.is_empty():
		var out: Array[VegType] = []
		for r in Lib.list(VEG_DIR):
			if r is VegType:
				out.append(r)
		if out.is_empty():
			for n in ["Tráva", "Květiny", "Keř"]:
				var t := VegType.new()
				t.veg_name = n
				out.append(t)
		types = out
	rebuild()


func _on_type_changed() -> void:
	call_deferred("rebuild")


func set_data(v: PackedFloat32Array) -> void:
	data = v
	rebuild()


func scatter(c: Vector3, radius: float, density: float, type: int) -> void:
	var terrain := get_parent() as TerrainMap
	if terrain == null:
		return
	var n := maxi(1, roundi(density * PI * radius * radius * 0.35))
	var smin := 0.8
	var smax := 1.2
	if type < types.size() and types[type]:
		smin = types[type].scale_min
		smax = types[type].scale_max
	var nd := data.duplicate()
	for i in n:
		if nd.size() >= MAX_INSTANCES * 5:
			break
		var a := randf() * TAU
		var r := radius * sqrt(randf())
		var x := c.x + cos(a) * r
		var z := c.z + sin(a) * r
		var h := terrain.height_at(x, z)
		if is_inf(h):
			continue
		nd.push_back(x)
		nd.push_back(h)
		nd.push_back(z)
		nd.push_back(randf_range(smin, smax))
		nd.push_back(float(type))
	data = nd


func erase_in(c: Vector3, radius: float) -> void:
	var nd := PackedFloat32Array()
	for i in range(0, data.size() - 4, 5):
		if Vector2(data[i] - c.x, data[i + 2] - c.z).length() > radius:
			for k in 5:
				nd.push_back(data[i + k])
	data = nd


func rebuild() -> void:
	if not is_inside_tree():
		return
	for ch in get_children():
		if ch.name.begins_with("_V"):
			remove_child(ch)
			ch.free()
	var bufs := {}
	var counts := {}
	for i in range(0, data.size() - 4, 5):
		var t := int(data[i + 4])
		var s := data[i + 3]
		if not bufs.has(t):
			bufs[t] = PackedFloat32Array()
			counts[t] = 0
		var b: PackedFloat32Array = bufs[t]
		b.append_array(PackedFloat32Array([s, 0, 0, data[i], 0, s, 0, data[i + 1], 0, 0, s, data[i + 2]]))
		bufs[t] = b
		counts[t] += 1
	for t in bufs:
		var tp: VegType = types[t] if t < types.size() else null
		var tex: Texture2D = tp.texture if (tp and tp.texture) else _placeholder(t)
		var hf := tp.hframes if tp else 1
		var ppm := tp.ppm if tp else 32.0
		var w := tex.get_width() / float(hf) / ppm
		var hh := tex.get_height() / ppm
		var q := QuadMesh.new()
		q.size = Vector2(w, hh)
		q.center_offset = Vector3(0, hh / 2.0, 0)
		var hgt := hh
		var wind_amp := (hgt * 0.09 if hgt < 2.0 else hgt * 0.02)
		if tp and (tp.veg_name.to_lower().contains("kamen") or tp.veg_name.to_lower().contains("kámen")):
			wind_amp = 0.0
		var m := VegWind.material(tex, tp.tint if tp else Color.WHITE, hf, tp.frame if tp else 0, wind_amp)
		q.material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = counts[t]
		mm.mesh = q
		mm.buffer = bufs[t]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "_V%d" % t
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _placeholder(kind: int) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var g := Color(0.35, 0.7, 0.28)
	var dk := Color(0.22, 0.5, 0.2)
	if kind == 2:
		for y in range(4, 16):
			for x in range(1, 15):
				if Vector2(x - 7.5, y - 10).length() < 6.5:
					img.set_pixel(x, y, g if (x + y) % 5 else dk)
	else:
		for x in [3, 6, 8, 11, 13]:
			var h: int = 6 + (x * 5) % 6
			for y in range(16 - h, 16):
				img.set_pixel(x, y, dk if y > 12 else g)
			if kind == 1 and x in [3, 8, 13]:
				img.set_pixel(x, 16 - h - 1, Color(1, 0.9, 0.3))
	return ImageTexture.create_from_image(img)
