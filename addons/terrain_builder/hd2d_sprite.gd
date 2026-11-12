class_name HD2DSprite
extends RefCounted
## Pomocné funkce pro sprity ve stylu HD-2D (billboard, Nearest, 1 px = 1/32 m).


static func make(tex: Texture2D, hframes := 1, vframes := 1) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.hframes = hframes
	s.vframes = vframes
	s.pixel_size = 1.0 / 32.0
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.position.y = tex.get_height() / float(vframes) * 0.5 / 32.0
	return s


static func placeholder(body: Color) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(20, 22, 24, 38), body)
	img.fill_rect(Rect2i(22, 6, 20, 18), Color(0.95, 0.8, 0.65))
	img.fill_rect(Rect2i(36, 12, 3, 3), Color.BLACK)
	return ImageTexture.create_from_image(img)


static func blob_shadow() -> MeshInstance3D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.rotation_degrees.x = -90
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
