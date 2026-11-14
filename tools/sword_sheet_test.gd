extends SceneTree
func _initialize() -> void:
	var dirs := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
	var eq := {"helma": "x", "telo": "x", "rukavice": "x", "kalhoty": "x", "boty": "x", "zbran": "zelezny_mec"}
	var out := Image.create(160 * 8, 520, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.35, 0.43, 0.35))
	for i in 8:
		for r in 2:
			var s := HeroSprite3D.sheet(["Idle", "Walk"][r], dirs[i], eq)
			if s.is_empty(): print("missing ", dirs[i]); continue
			var im: Image = s.tex.get_image()
			im.decompress() if im.is_compressed() else null
			var fr := 2 if r == 1 else 0
			out.blend_rect(im, Rect2i(fr * s.w, 0, s.w, s.h), Vector2i(i * 160, r * 260))
	out.save_png(OS.get_cmdline_user_args()[0])
	quit()
