class_name FlameFx
extends Node3D
## Animovaný oheň: svítivé částice (plamen), jiskry a kouř. Nahrazuje statické modely plamenů.

@export var size := 1.0


func _ready() -> void:
	add_child(_flame(28, 0.95, 0.62 * size, Color(1.0, 0.85, 0.35), 0.9 * size, 0.55 * size, true))
	add_child(_flame(14, 0.7, 0.36 * size, Color(1.0, 0.95, 0.7), 1.2 * size, 0.3 * size, true))
	add_child(_sparks())
	add_child(_smoke())


static func _tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


static func _mat(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _tex()
	m.vertex_color_use_as_albedo = true
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	return m


func _flame(n: int, life: float, rad: float, col: Color, vel: float, quad: float, add: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = rad * 0.45
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = vel * 0.6
	pm.initial_velocity_max = vel
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 0.2
	pm.damping_max = 0.6
	pm.scale_min = 0.7
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	g.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), Color(col.r, col.g * 0.9, col.b * 0.5, 0.85), Color(1.0, 0.4, 0.08, 0.55), Color(0.5, 0.1, 0.02, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.5
	pm.turbulence_noise_scale = 2.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(quad, quad)
	q.material = _mat(add)
	p.draw_pass_1 = q
	return p


func _sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.6
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15 * size
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.8 * size
	pm.initial_velocity_max = 2.0 * size
	pm.gravity = Vector3(0, 0.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0), Color(1.0, 0.3, 0.05, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06) * size
	q.material = _mat(true)
	p.draw_pass_1 = q
	return p


func _smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 8
	p.lifetime = 2.6
	p.local_coords = false
	p.position = Vector3(0, 0.5 * size, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.35
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0, 0.1, 0)
	pm.scale_min = 1.0
	pm.scale_max = 1.8
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(0.2, 0.2, 0.22, 0.0), Color(0.25, 0.25, 0.28, 0.16), Color(0.3, 0.3, 0.33, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7) * size
	q.material = _mat(false)
	p.draw_pass_1 = q
	return p
