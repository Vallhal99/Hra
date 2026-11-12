@tool
class_name LitSprite3D
extends Sprite3D
## Předsvícený sprite: 12 snímků = světlo obíhá kolem stromu. Vybírá snímek podle směru slunce vůči kameře.

@export var follow_sun := true
@export var wind := true
@export var wind_amp := 0.22
@export var frame_angles := PackedFloat32Array([-22, 41, 88, 110, 138, 170, -165, -147, -138, -119, -81, -57])

var _sun: DirectionalLight3D
var _t := 0.0


func _ready() -> void:
	hframes = maxi(hframes, 12)
	if wind and texture and not Engine.is_editor_hint():
		billboard = BaseMaterial3D.BILLBOARD_DISABLED
		material_override = VegWind.material(texture, Color.WHITE, 1, 0, wind_amp)
	_update()


func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 0.4
		_update()


func _update() -> void:
	if not follow_sun or frame_angles.is_empty() or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _sun == null or not is_instance_valid(_sun):
		var root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
		if root == null:
			return
		var found := root.find_children("*", "DirectionalLight3D", true, false)
		if found.is_empty():
			return
		_sun = found[0]
	var l := _sun.global_transform.basis.z # směr ke slunci
	var ang := rad_to_deg(atan2(l.dot(cam.global_transform.basis.y), l.dot(cam.global_transform.basis.x)))
	var best := 0
	var bd := 1000.0
	for i in frame_angles.size():
		var d := absf(wrapf(frame_angles[i] - ang, -180.0, 180.0))
		if d < bd:
			bd = d
			best = i
	frame = best
