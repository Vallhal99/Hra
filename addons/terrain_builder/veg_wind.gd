class_name VegWind
extends RefCounted
## Materiál s větrem pro billboardy (tráva, stromy). Houpe horní částí obrázku, spodek zůstává na místě.

const CODE := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float hf = 1.0;
uniform float frame_idx = 0.0;
uniform float amp = 0.1;
uniform float speed = 1.6;
uniform float wind_dir = 0.6;
uniform bool billboard = true;
void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 0.45 + wp.z * 0.3 - TIME * 0.35;
	float gust = sin(TIME * speed + ph * 2.0) + 0.5 * sin(TIME * speed * 2.3 + ph * 3.1) + 0.6 * sin(TIME * 0.5 + ph * 0.5);
	float top = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.6);
	VERTEX.x += (gust * 0.55 + wind_dir) * amp * top;
	UV = UV * vec2(1.0 / hf, 1.0) + vec2(frame_idx / hf, 0.0);
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * tint.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
}
"""
static var _shader: Shader


static func material(tex: Texture2D, tint: Color, hframes: int, frame: int, amp: float, billboard := true, speed := 1.6) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("hf", float(maxi(hframes, 1)))
	m.set_shader_parameter("frame_idx", float(frame))
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("billboard", billboard)
	return m
