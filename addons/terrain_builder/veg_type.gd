@tool
class_name VegType
extends Resource
## Druh vegetace. ppm = pixelů na metr (32 = pixel-art, 200+ = detailní kresba). hframes/frame = výřez ze spritesheetu.

@export var veg_name := "Tráva":
	set(v):
		veg_name = v
		emit_changed()
@export var texture: Texture2D:
	set(v):
		texture = v
		emit_changed()
@export var scale_min := 0.8:
	set(v):
		scale_min = v
		emit_changed()
@export var scale_max := 1.2:
	set(v):
		scale_max = v
		emit_changed()
@export var ppm := 32.0:
	set(v):
		ppm = maxf(v, 1.0)
		emit_changed()
@export var nearest := true:
	set(v):
		nearest = v
		emit_changed()
@export var hframes := 1:
	set(v):
		hframes = maxi(v, 1)
		emit_changed()
@export var frame := 0:
	set(v):
		frame = v
		emit_changed()
@export var tint := Color.WHITE:
	set(v):
		tint = v
		emit_changed()
