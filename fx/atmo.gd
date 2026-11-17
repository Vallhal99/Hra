extends Node
## Atmosféra: denní doba, počasí (déšť, padající listí), světlušky, prach, sluneční paprsky.
## Autoload "Atmo". Částice se vznášejí kolem místa, kam se dívá kamera (funguje i v souboji).

signal weather_changed(w: String)

const DAY_LENGTH := 900.0  ## sekund reálného času na jeden herní den
const INDOOR := ["obchod", "jeskyne", "hrobka", "chram", "hostinec"]
const FOREST := ["rozcesti", "louka", "louka_reka"]

var tod := 0.40            ## 0 = půlnoc, 0.25 = svítání, 0.5 = poledne, 0.75 = soumrak
var weather := "clear"     ## clear | rain | leaves
var locked_weather := ""   ## pro testy / scénář
var rain_level := 0.0
var enabled := true

var _rig: Node3D
var _rain: GPUParticles3D
var _leaves: GPUParticles3D
var _flies: GPUParticles3D
var _dust: GPUParticles3D
var _shafts: Array[MeshInstance3D] = []
var _shaft_mat: ShaderMaterial
var _scene_path := ""
var _indoor := false
var _cave := false
var _crypt := false
var _lights: Array = []
var _acc := 0.0
var _wtimer := 120.0
var _flicker_t := 0.0
var _sun_e := 1.0
var _night := 0.0
var _sun: DirectionalLight3D


static func _lerpc(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


func is_night() -> bool:
	return _night > 0.6


func is_wet() -> bool:
	return rain_level > 0.5


func sun_factor() -> float:
	return clampf(_sun_e * 0.5 + 0.5, 0.0, 1.0)


func get_state() -> Dictionary:
	return {"tod": tod, "weather": weather, "day": day}


func set_state(d: Dictionary) -> void:
	tod = float(d.get("tod", tod))
	day = int(d.get("day", 1))
	weather = str(d.get("weather", weather))


func set_weather(w: String) -> void:
	locked_weather = w
	if weather != w:
		weather = w
		weather_changed.emit(w)


var day := 1
var _clock: Label
var _clock_panel: PanelContainer


func clock_text() -> String:
	var mins := int(tod * 1440.0)
	return "%02d:%02d" % [mins / 60, mins % 60]


func _build_clock() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 40
	add_child(cl)
	_clock_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.72)
	sb.border_color = Color(0.85, 0.68, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	_clock_panel.add_theme_stylebox_override("panel", sb)
	_clock_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_panel.position = Vector2(-150, 10)
	_clock_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 20)
	_clock.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_clock_panel.add_child(_clock)
	cl.add_child(_clock_panel)
	_clock_panel.visible = false


func _update_clock() -> void:
	var show_it := get_tree().get_first_node_in_group("player") != null
	var bm := get_node_or_null("/root/BattleManager")
	if bm and bm.active:
		show_it = false
	_clock_panel.visible = show_it
	if show_it:
		var sym := "☀" if (tod > 0.25 and tod < 0.75) else "☾"
		_clock.text = "%s  %s  ·  Den %d" % [sym, clock_text(), day]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_rig()
	_build_clock()


# ---------------------------------------------------------------- částice
func _mk_particles(amount: int, life: float, box: Vector3, mesh: Mesh, pos_y: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position.y = pos_y
	p.draw_pass_1 = mesh
	p.emitting = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = box
	p.process_material = m
	_rig.add_child(p)
	return p


func _unshaded(col: Color, additive := false, vcol := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = vcol
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _fade_ramp(peak: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, peak), Color(1, 1, 1, peak), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.name = "AtmoRig"
	add_child(_rig)
	# --- déšť: tenké čárky padající šikmo
	var rm := BoxMesh.new()
	rm.size = Vector3(0.012, 0.55, 0.012)
	rm.material = _unshaded(Color(0.75, 0.85, 1.0, 0.45))
	_rain = _mk_particles(1800, 0.8, Vector3(16, 0.2, 16), rm, 17.0)
	var pm := _rain.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0.18, -1, 0.05)
	pm.spread = 2.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3(0, -6, 0)
	pm.particle_flag_align_y = true
	# --- listí
	var lm := QuadMesh.new()
	lm.size = Vector2(0.2, 0.14)
	lm.material = _unshaded(Color.WHITE, false, true)
	(lm.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_leaves = _mk_particles(70, 9.0, Vector3(18, 0.5, 18), lm, 11.0)
	pm = _leaves.process_material as ParticleProcessMaterial
	pm.direction = Vector3(1, -0.2, 0.2)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0.5, -0.9, 0.15)
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -140.0
	pm.angular_velocity_max = 140.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 3.0
	var cg := Gradient.new()
	cg.offsets = PackedFloat32Array([0.0, 0.4, 0.75, 1.0])
	cg.colors = PackedColorArray([Color(0.85, 0.45, 0.12), Color(0.9, 0.7, 0.2), Color(0.55, 0.62, 0.2), Color(0.7, 0.3, 0.1)])
	var cgt := GradientTexture1D.new()
	cgt.gradient = cg
	pm.color_initial_ramp = cgt
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	# --- světlušky
	var fm := QuadMesh.new()
	fm.size = Vector2(0.11, 0.11)
	var fmat := _unshaded(Color(0.85, 1.0, 0.45, 1.0), true, true)
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.albedo_texture = _soft_dot()
	fm.material = fmat
	_flies = _mk_particles(46, 6.0, Vector3(13, 1.2, 13), fm, 1.6)
	pm = _flies.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 1.6
	pm.color_ramp = _fade_ramp(1.0)
	# --- prach ve slunci
	var dm := QuadMesh.new()
	dm.size = Vector2(0.045, 0.045)
	var dmat := _unshaded(Color(1.0, 0.95, 0.8, 0.5), false, true)
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dmat.albedo_texture = _soft_dot()
	dm.material = dmat
	_dust = _mk_particles(90, 8.0, Vector3(12, 2.5, 12), dm, 2.5)
	pm = _dust.process_material as ParticleProcessMaterial
	pm.direction = Vector3(1, 0.1, 0.3)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.35
	pm.gravity = Vector3(0, -0.02, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.color_ramp = _fade_ramp(0.55)
	# --- sluneční paprsky (falešné, funguje i v compat rendereru)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.7);
uniform float strength = 0.0;
uniform float lean = 2.5;
uniform float seed = 0.0;
uniform bool compat = false;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX.x += (1.0 - UV.y) * lean;
}
void fragment() {
	float xx = (clamp(UV.x, 0.0, 1.0) - 0.5) * 2.0;
	float across = exp(-xx * xx * 3.2) * smoothstep(1.0, 0.45, abs(xx));
	float along = smoothstep(0.0, 0.3, UV.y) * pow(max(1.0 - UV.y, 0.0), 1.3);
	along *= smoothstep(5.0, 15.0, length(VERTEX));
	float fl = 0.75 + 0.25 * sin(TIME * 0.6 + seed * 6.0) + 0.1 * sin(TIME * 1.7 + seed);
	float dz = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, compat ? dz * 2.0 - 1.0 : dz);
	vec4 vw = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vw.xyz /= vw.w;
	float soft = clamp((-vw.z + VERTEX.z) / 2.5, 0.0, 1.0);
	float a = clamp(across * along * fl * strength * soft, 0.0, 1.0);
	ALBEDO = tint * a;
	ALPHA = 1.0;
}
"""
	_shaft_mat = ShaderMaterial.new()
	_shaft_mat.shader = sh
	_shaft_mat.set_shader_parameter("compat", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var q := QuadMesh.new()
		q.size = Vector2(rng.randf_range(1.6, 3.4), rng.randf_range(11.0, 16.0))
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var mm := _shaft_mat.duplicate() as ShaderMaterial
		mm.set_shader_parameter("seed", rng.randf() * 10.0)
		mi.material_override = mm
		mi.position = Vector3(rng.randf_range(-11, 11), q.size.y * 0.5 - 0.5, rng.randf_range(-9, 5))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_shafts.append(mi)


func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


# ---------------------------------------------------------------- průběh
func _process(dt: float) -> void:
	if not enabled:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_rig.visible = false
		return
	_scan_scene()
	# denní doba
	var tod0 := tod
	tod = fposmod(tod + dt / DAY_LENGTH, 1.0)
	if tod < tod0:
		day += 1
	_update_clock()
	if _cave:
		tod = 0.5
	# počasí se mění samo
	if locked_weather == "" and not _indoor:
		_wtimer -= dt
		if _wtimer <= 0.0:
			_wtimer = randf_range(120.0, 300.0)
			var r := randf()
			var nw := "clear" if r < 0.55 else ("rain" if r < 0.8 else "leaves")
			if nw != weather:
				weather = nw
				weather_changed.emit(nw)
	var target_rain := 1.0 if (weather == "rain" and not _indoor) else 0.0
	rain_level = move_toward(rain_level, target_rain, dt * 0.25)
	# kam se částice vznášejí
	var fwd := -cam.global_transform.basis.z
	var focus := cam.global_position
	if fwd.y < -0.05:
		focus = cam.global_position + fwd * (cam.global_position.y / -fwd.y)
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		focus = pl.global_position
	_rig.global_position = Vector3(focus.x, focus.y, focus.z)
	_rig.visible = not _indoor or _cave
	_acc += dt
	_flicker_t += dt
	if _acc >= 0.25:
		_acc = 0.0
		_apply(cam)
	if _flicker_t > 0.07:
		_flicker_t = 0.0
		_flicker()


func _scan_scene() -> void:
	var sc := get_tree().current_scene
	if sc == null or not sc.is_inside_tree():
		return
	var path := sc.scene_file_path
	if path == _scene_path:
		return
	_scene_path = path
	var nm := path.get_file().get_basename()
	_indoor = false
	var ref := nm
	if nm == "battle":
		var bmn := get_node_or_null("/root/BattleManager")
		ref = str(bmn.return_scene).get_file().get_basename() if bmn else nm
	_cave = ref.begins_with("jeskyne") or ref.begins_with("hrobka")
	_crypt = ref.begins_with("hrobka")
	for k in INDOOR:
		if nm.begins_with(k):
			_indoor = true
	_lights.clear()
	for l in sc.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D:
			continue
		if not l.has_meta("base_e"):
			l.set_meta("base_e", (l as Light3D).light_energy)
		_lights.append(l)
	_sun = null
	_attach_flames(sc)
	var b := Rect2(-12, -10, 24, 20)
	for tmn in sc.find_children("*", "TerrainMap", true, false):
		var tmm := tmn as TerrainMap
		if tmm != null and not tmm.cells.is_empty():
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for c: Vector2i in tmm.cells:
				mn = mn.min(Vector2(c))
				mx = mx.max(Vector2(c) + Vector2.ONE)
			b = Rect2(mn, mx - mn).grow(-3.0)
			break
	var rr := RandomNumberGenerator.new()
	rr.seed = 77
	for s in _shafts:
		s.visible = FOREST.has(nm)
		var hh: float = (s.mesh as QuadMesh).size.y
		s.global_position = Vector3(rr.randf_range(b.position.x, b.end.x), hh * 0.5 - 0.5, rr.randf_range(b.position.y, b.end.y))


func _attach_flames(sc: Node) -> void:
	if sc == null or not sc.is_inside_tree():
		return
	for m in sc.find_children("*Flame*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var par := mi.get_parent()
		if par == null or not par.is_inside_tree() or not mi.is_inside_tree():
			continue
		if par.has_meta("flamed"):
			mi.visible = false
			continue
		par.set_meta("flamed", true)
		mi.visible = false
		var fx := FlameFx.new()
		fx.top_level = true
		var sz := 1.0
		var nm := String(par.name)
		if nm.begins_with("Cauldron"):
			sz = 0.7
		fx.size = sz
		par.add_child(fx)
		fx.global_position = mi.global_position - Vector3(0, 0.25 * sz, 0)
	for m in sc.find_children("*Flame*", "MeshInstance3D", true, false):
		if (m as Node).is_inside_tree():
			(m as MeshInstance3D).visible = false


func _apply(cam: Camera3D) -> void:
	var e := sin((tod - 0.25) * TAU)
	_sun_e = e
	var day := smoothstep(-0.12, 0.32, e)
	_night = 1.0 - day
	var warm := clampf(1.0 - absf(e) / 0.42, 0.0, 1.0)
	var rl := rain_level
	var env := cam.environment
	if not is_instance_valid(_sun) and get_tree().current_scene:
		var suns := get_tree().current_scene.find_children("*", "DirectionalLight3D", true, false)
		_sun = suns[0] if not suns.is_empty() else null
	var sun: DirectionalLight3D = _sun
	if _indoor and not _cave:
		_set_flies(false, 0.0)
		_rain.emitting = false
		_leaves.emitting = false
		_dust.emitting = false
		return
	if _cave:
		if env:
			env.ambient_light_color = Color(0.62, 0.5, 0.42) if _crypt else Color(0.25, 0.32, 0.5)
			env.ambient_light_energy = 0.75 if _crypt else 0.55
			env.background_color = Color(0.03, 0.02, 0.02) if _crypt else Color(0.02, 0.03, 0.06)
			env.fog_light_color = Color(0.2, 0.14, 0.11) if _crypt else Color(0.12, 0.16, 0.26)
			env.fog_density = 0.02
		if sun:
			sun.light_energy = 0.12
			sun.light_color = Color(0.5, 0.6, 1.0)
		_rain.emitting = false
		_leaves.emitting = false
		_dust.emitting = true
		(_dust.draw_pass_1.material as StandardMaterial3D).albedo_color = Color(1.0, 0.8, 0.55, 0.5) if _crypt else Color(0.5, 0.85, 1.0, 0.5)
		_set_flies(not _crypt, 1.0)
		for s in _shafts:
			s.visible = false
		_update_lights(1.0)
		return
	# --- slunce
	if sun:
		var moon := Color(0.5, 0.62, 1.0)
		var dayc := _lerpc(Color(1.0, 0.96, 0.88), Color(1.0, 0.58, 0.3), warm)
		sun.light_color = _lerpc(moon, dayc, day)
		sun.light_energy = lerpf(0.38, 0.78, day) * (1.0 - 0.55 * rl)
		var elev := lerpf(8.0, 62.0, maxf(e, 0.0))
		sun.rotation_degrees = Vector3(-lerpf(45.0, elev, day), -30.0 + tod * 70.0, 0.0)
	if env:
		var amb_day := _lerpc(Color(0.62, 0.72, 0.95), Color(0.85, 0.6, 0.62), warm * 0.7)
		env.ambient_light_color = _lerpc(Color(0.2, 0.26, 0.5), amb_day, day).lerp(Color(0.5, 0.55, 0.62), rl * 0.5)
		env.ambient_light_energy = lerpf(0.85, 0.36, day) * (1.0 - 0.25 * rl)
		var bg_day := _lerpc(Color(0.55, 0.72, 0.9), Color(0.95, 0.6, 0.42), warm * 0.8)
		var bg := _lerpc(Color(0.03, 0.05, 0.14), bg_day, day).lerp(Color(0.45, 0.5, 0.56), rl * 0.7)
		env.background_color = bg
		env.fog_light_color = bg.lerp(Color(0.72, 0.82, 0.95), 0.4 * day)
		env.fog_density = 0.003 + 0.007 * rl + 0.002 * _night
		env.tonemap_exposure = lerpf(1.0, 0.82, day)
	# --- částice
	var clear_day := day * (1.0 - rl)
	_rain.emitting = rl > 0.03
	_rain.amount_ratio = clampf(rl, 0.05, 1.0)
	_leaves.emitting = weather == "leaves" and rl < 0.2
	_dust.emitting = clear_day > 0.4
	(_dust.draw_pass_1.material as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.8, 0.5)
	_set_flies(_night > 0.45 and rl < 0.3, 1.0)
	_shaft_mat.set_shader_parameter("strength", 0.0)
	var str_ := smoothstep(0.18, 0.5, e) * (1.0 - rl) * (0.06 + 0.05 * warm) * (0.3 if _scene_path.contains("battle") or _scene_path == "" else 1.0)
	var nm := _scene_path.get_file().get_basename()
	for s in _shafts:
		var mm := s.material_override as ShaderMaterial
		mm.set_shader_parameter("strength", str_ if FOREST.has(nm) else 0.0)
		mm.set_shader_parameter("tint", Vector3(1.0, 0.93 - 0.2 * warm, 0.7 - 0.25 * warm))
	_update_lights(_night)


func _set_flies(on: bool, _s: float) -> void:
	_flies.emitting = on


func _update_lights(night: float) -> void:
	for l in _lights:
		if not is_instance_valid(l):
			continue
		var be: float = l.get_meta("base_e", 1.0)
		(l as Light3D).light_energy = be * lerpf(0.5, 1.5, night)


func _flicker() -> void:
	for l in _lights:
		if not is_instance_valid(l):
			continue
		var n: String = String((l as Node).name).to_lower() + (String(l.get_parent().name).to_lower() if l.get_parent() else "")
		if n.contains("ohni") or n.contains("ohen") or n.contains("kov") or n.contains("brazier") or n.contains("fire") or n.contains("mis"):
			var be: float = l.get_meta("base_e", 1.0)
			(l as Light3D).light_energy = be * lerpf(0.5, 1.5, _night) * randf_range(0.82, 1.15)
