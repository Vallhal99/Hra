@tool
class_name TerrainMat
extends Resource
## Materiál terénu. Přetáhni PNG (32x32) do slotů v Inspectoru.

@export var mat_name := "Materiál":
	set(v):
		mat_name = v
		emit_changed()
@export var top_texture: Texture2D:
	set(v):
		top_texture = v
		emit_changed()
@export var side_texture: Texture2D:
	set(v):
		side_texture = v
		emit_changed()
@export var color := Color.WHITE:
	set(v):
		color = v
		emit_changed()
