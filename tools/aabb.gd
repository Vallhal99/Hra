extends SceneTree
func _aabb(n: Node, t: Transform3D, acc: Array) -> void:
	var tt := t
	if n is Node3D: tt = t * (n as Node3D).transform
	if n is MeshInstance3D:
		var a := tt * (n as MeshInstance3D).get_aabb()
		acc.append(a)
	for c in n.get_children(): _aabb(c, tt, acc)
func _initialize() -> void:
	var d := DirAccess.open("res://models/well")
	for f in d.get_files():
		if f.ends_with(".glb"):
			var n := (load("res://models/well/" + f) as PackedScene).instantiate()
			var acc := []
			for c in n.get_children(): _aabb(c, Transform3D.IDENTITY, acc)
			var a: AABB = acc[0]
			for x in acc: a = a.merge(x)
			print(f, " pos ", a.position.snapped(Vector3(0.01,0.01,0.01)), " size ", a.size.snapped(Vector3(0.01,0.01,0.01)))
	quit()
