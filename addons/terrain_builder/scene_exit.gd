@tool
class_name SceneExit
extends Area3D
## Východ do další scény. Dej ho na okraj mapy, vyber cílovou scénu a jméno Marker3D ve cílové scéně.

@export_file("*.tscn") var target_scene := ""
@export var target_spawn := "Start"
@export var size := Vector3(2, 2, 1):
	set(v):
		size = v
		_update()

var _shape: CollisionShape3D
var _vis: MeshInstance3D


func _ready() -> void:
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	if Engine.is_editor_hint():
		_vis = MeshInstance3D.new()
		_vis.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 0.6, 0.1, 0.35)
		_vis.material_override = m
		add_child(_vis)
	else:
		body_entered.connect(_on_body)
		var sm := get_node_or_null("/root/SceneManager")
		if sm:
			sm.preload_scene(target_scene)
	_update()


func _update() -> void:
	if _shape == null:
		return
	(_shape.shape as BoxShape3D).size = size
	_shape.position.y = size.y / 2.0
	if _vis:
		(_vis.mesh as BoxMesh).size = size
		_vis.position.y = size.y / 2.0


func _on_body(body: Node3D) -> void:
	if body.is_in_group("player"):
		var sm := get_node_or_null("/root/SceneManager")
		if sm:
			sm.go(target_scene, target_spawn)
