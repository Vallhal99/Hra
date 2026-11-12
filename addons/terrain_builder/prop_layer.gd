@tool
class_name PropLayer
extends Node3D
## Kontejner objektů (domy, sudy...). Nastaví Nearest filtr na texturách z Blenderu.


func _ready() -> void:
	child_entered_tree.connect(func(n): _pixelize.call_deferred(n))
	_pixelize(self)
	if not Engine.is_editor_hint():
		for c in get_children():
			_auto_col(c)


func _auto_col(n: Node) -> void:
	if not (n is Node3D and n.has_meta("auto_col")):
		return
	var box := AABB()
	var first := true
	var inv := (n as Node3D).global_transform.affine_inverse()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var a: AABB = inv * m.global_transform * m.get_aabb()
		box = a if first else box.merge(a)
		first = false
	if first:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = box.size
	cs.shape = shp
	cs.position = box.get_center()
	body.add_child(cs)
	n.add_child(body)


func _pixelize(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m := (n as MeshInstance3D).get_active_material(i)
			if m is BaseMaterial3D:
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for c in n.get_children():
		_pixelize(c)
