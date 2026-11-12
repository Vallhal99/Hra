@tool
class_name HD2DCamera
extends Camera3D
## Kamera ve stylu Octopath: nízké FOV, náklon, tilt-shift (DOF), glow, SSAO, vinětace.

@export var target: Node3D
@export var distance := 40.0
@export_range(10, 70) var pitch := 35.0
@export var yaw := 0.0
@export var height_offset := 1.0
@export var smoothing := 8.0
@export var limit_to_map := true  ## kamera se zastaví u okraje terénu, takže nikdy neukáže prázdno
@export_group("Efekty (jen za běhu hry)")
@export var builtin_fx := true
@export var tilt_shift := true
@export_range(0.0, 0.5) var blur_amount := 0.1
@export_range(0.0, 1.0) var vignette := 0.35
@export var glow := true
@export var ssao := true
@export var fog := true
@export var volumetric := true  ## sluneční paprsky (jen Forward+)
@export var grade := true  ## barevný grading + bloom + zrno (postprocess shader)
@export_range(0.0, 1.0) var tilt_strength := 0.6  ## síla tilt-shift rozostření nahoře/dole

var _snap := true
var _bounds := Rect2()
var _has_bounds := false
var _bounds_tried := false


func _init() -> void:
	fov = 24.0


func _ready() -> void:
	add_to_group("camera_follow")
	if Engine.is_editor_hint():
		return
	make_current()
	if builtin_fx:
		_setup_fx()


func snap() -> void:
	_snap = true


func _process(dt: float) -> void:
	var t := target
	if t == null and not Engine.is_editor_hint():
		t = get_tree().get_first_node_in_group("player") as Node3D
	if t == null:
		return
	var focus := t.global_position + Vector3(0, height_offset, 0)
	if limit_to_map and not Engine.is_editor_hint():
		focus = _clamp_focus(focus)
	var off := Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))) * distance
	var goal := focus + off.rotated(Vector3.UP, deg_to_rad(yaw))
	if _snap or Engine.is_editor_hint():
		global_position = goal
		_snap = false
	else:
		global_position = global_position.lerp(goal, 1.0 - exp(-smoothing * dt))
	rotation_degrees = Vector3(-pitch, yaw, 0)


func _find_bounds() -> void:
	_bounds_tried = true
	for n in get_tree().root.find_children("*", "TerrainMap", true, false):
		var tm := n as TerrainMap
		if tm == null or tm.cells.is_empty():
			continue
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for c: Vector2i in tm.cells:
			mn.x = minf(mn.x, c.x)
			mn.y = minf(mn.y, c.y)
			mx.x = maxf(mx.x, c.x + 1)
			mx.y = maxf(mx.y, c.y + 1)
		_bounds = Rect2(mn, mx - mn).grow(-0.25)
		_has_bounds = true
		return


func _clamp_focus(focus: Vector3) -> Vector3:
	if not _bounds_tried:
		_find_bounds()
	if not _has_bounds:
		return focus
	# kam dopadnou rohy obrazovky na zem (rovina y = ground), relativně k bodu zaměření
	var vs := get_viewport().get_visible_rect().size
	var asp := vs.x / maxf(vs.y, 1.0)
	var th := tan(deg_to_rad(fov) * 0.5)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0))
	var off := Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))).rotated(Vector3.UP, deg_to_rad(yaw)) * distance
	var cam_y := focus.y + off.y
	var ground := focus.y - height_offset
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var d := basis * Vector3(sx * th * asp, sy * th, -1.0)
			if d.y >= -0.01:
				continue
			var k := (ground - cam_y) / d.y
			var h := Vector2(off.x + d.x * k, off.z + d.z * k)
			lo = lo.min(h)
			hi = hi.max(h)
	var fx := _fit(focus.x, _bounds.position.x - lo.x, _bounds.end.x - hi.x, _bounds.get_center().x)
	var fz := _fit(focus.z, _bounds.position.y - lo.y, _bounds.end.y - hi.y, _bounds.get_center().y)
	return Vector3(fx, focus.y, fz)


func _fit(v: float, lo: float, hi: float, mid: float) -> float:
	if lo > hi:
		return mid
	return clampf(v, lo, hi)


const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float tilt = 0.6;
uniform float focus_y = 0.52;
uniform float focus_w = 0.18;
uniform float vignette = 0.35;
uniform float grain = 0.025;
uniform float aberration = 0.0016;
uniform float bloom = 0.35;
uniform float grading = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float d = abs(uv.y - focus_y);
	float k = smoothstep(focus_w, 0.55, d) * tilt;
	vec2 dir = uv - 0.5;
	float ab = aberration * (0.4 + length(dir) * 2.0);
	float lod = k * 2.2;
	float r = 0.004 * k;
	vec3 col = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * 1.0472;
		vec2 o = vec2(cos(a), sin(a)) * r;
		col += vec3(textureLod(scr, uv + o + dir * ab, lod).r, textureLod(scr, uv + o, lod).g, textureLod(scr, uv + o - dir * ab, lod).b);
	}
	col /= 6.0;
	// jemny bloom ze svetlych casti
	vec3 bl = textureLod(scr, uv, 3.5).rgb * 0.5 + textureLod(scr, uv, 5.0).rgb * 0.5;
	col += max(bl - vec3(0.65), vec3(0.0)) * bloom;
	// grading: chladne stiny, tepla svetla, sytejsi barvy
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 cool = vec3(0.90, 0.97, 1.10);
	vec3 warm = vec3(1.05, 1.0, 0.9);
	vec3 graded = col * mix(cool, warm, smoothstep(0.15, 0.75, lum));
	graded = mix(vec3(lum), graded, 1.06 + k * 0.22);
	graded = (graded - 0.5) * 1.12 + 0.5;
	col = mix(col, graded, grading);
	col *= 1.0 - vignette * smoothstep(0.35, 0.95, length(dir) * 1.25);
	col += (hash(uv / SCREEN_PIXEL_SIZE + fract(TIME)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
"""


func _is_compat() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


func _setup_fx() -> void:
	var compat := _is_compat()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.72, 0.9)
	# modre stiny + tepla slunce = typicky HD-2D kontrast
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.95)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = glow
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = ssao and not compat
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	if fog:
		env.fog_enabled = true
		env.fog_light_color = Color(0.72, 0.82, 0.95)
		env.fog_density = 0.003
		env.fog_sun_scatter = 0.25
		env.fog_sky_affect = 1.0
		if not compat:
			env.fog_aerial_perspective = 0.3
	if volumetric and not compat:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color(1.0, 0.95, 0.85)
		env.volumetric_fog_anisotropy = 0.65
		env.volumetric_fog_length = 70.0
		env.volumetric_fog_ambient_inject = 0.3
	environment = env
	var at := CameraAttributesPractical.new()
	if tilt_shift and not compat:
		at.dof_blur_amount = blur_amount
		at.dof_blur_far_enabled = true
		at.dof_blur_far_distance = distance + 6.0
		at.dof_blur_far_transition = 14.0
		at.dof_blur_near_enabled = true
		at.dof_blur_near_distance = maxf(distance - 5.0, 1.0)
		at.dof_blur_near_transition = 6.0
	attributes = at
	var sc: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	var suns := sc.find_children("*", "DirectionalLight3D", true, false)
	if suns.is_empty():
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, -30, 0)
		sun.light_color = Color(1.0, 0.95, 0.85)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 70.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.light_volumetric_fog_energy = 1.5
		get_parent().add_child.call_deferred(sun)
	else:
		for s in suns:
			(s as DirectionalLight3D).light_volumetric_fog_energy = 1.5
			(s as DirectionalLight3D).shadow_blur = 1.4
	if grade or vignette > 0.0:
		var cl := CanvasLayer.new()
		cl.layer = 10
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sh := Shader.new()
		sh.code = POST_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("vignette", vignette)
		sm.set_shader_parameter("grading", 1.0 if grade else 0.0)
		sm.set_shader_parameter("bloom", 0.25 if grade else 0.0)
		sm.set_shader_parameter("grain", 0.025 if grade else 0.0)
		sm.set_shader_parameter("tilt", tilt_strength if (tilt_shift and grade) else 0.0)
		r.material = sm
		cl.add_child(r)
		add_child(cl)
