class_name WaterFx
extends RefCounted
## Řeka: pás vody podél křivky se shaderem (proudění, vlnky, třpyt, pěna u břehů).

const SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(0.07, 0.30, 0.42);
uniform vec3 shallow : source_color = vec3(0.30, 0.72, 0.74);
uniform float speed = 0.45;
uniform float alpha = 0.86;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 uv, float t) {
	vec2 p = vec2(uv.x * 5.0, uv.y * 2.2 - t);
	float a = vn(p * 1.6 + vec2(0.0, t * 0.3));
	float b = vn(p * 3.4 - vec2(t * 0.2, t * 0.9));
	return a * 0.6 + b * 0.4;
}
void vertex() {
	VERTEX.y += sin(UV.y * 6.0 - TIME * 1.6 + UV.x * 5.0) * 0.012;
}
void fragment() {
	float t = TIME * speed;
	float w = waves(UV, t);
	float e = min(UV.x, 1.0 - UV.x);
	float depth = smoothstep(0.0, 0.45, e);
	vec3 col = mix(shallow, deep, depth * 0.85 + (w - 0.5) * 0.35);
	// proudové pruhy
	float streak = smoothstep(0.62, 0.9, vn(vec2(UV.x * 9.0, UV.y * 1.4 - t * 1.6)));
	col += streak * 0.10;
	// pěna u břehů
	float foam = smoothstep(0.17, 0.03, e + (w - 0.5) * 0.16);
	foam *= 0.55 + 0.45 * vn(vec2(UV.x * 14.0, UV.y * 6.0 - t * 2.0));
	col = mix(col, vec3(0.92, 0.97, 1.0), clamp(foam, 0.0, 1.0));
	// třpyt
	float sp = pow(vn(vec2(UV.x * 26.0, UV.y * 9.0 - t * 2.4)), 14.0) * 1.6;
	ALBEDO = col;
	EMISSION = vec3(sp) * vec3(1.0, 0.96, 0.85) * 0.8;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	METALLIC = 0.0;
	ALPHA = clamp(alpha + foam * 0.14, 0.0, 1.0);
	NORMAL = normalize(NORMAL + vec3((w - 0.5) * 0.35, 0.0, (vn(UV * vec2(8.0, 4.0) + t) - 0.5) * 0.25));
}
"""


static func material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## pts = střed řeky (Vector3, y = hladina), width = šířka
static func ribbon(pts: Array, width: float) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var dist := 0.0
	for i in pts.size():
		var p: Vector3 = pts[i]
		var prev: Vector3 = pts[maxi(i - 1, 0)]
		var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		if i > 0:
			dist += Vector2(p.x - prev.x, p.z - prev.z).length()
		var d := Vector3(nxt.x - prev.x, 0, nxt.z - prev.z).normalized()
		var side := Vector3(-d.z, 0, d.x) * width * 0.5
		verts.push_back(p - side)
		verts.push_back(p + side)
		uvs.push_back(Vector2(0.0, dist / 4.0))
		uvs.push_back(Vector2(1.0, dist / 4.0))
		if i > 0:
			var b := (i - 1) * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	for i in verts.size():
		normals.push_back(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
