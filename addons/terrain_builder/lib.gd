class_name Lib
extends RefCounted
## Sdílená knihovna zdrojů (materiály terénu, druhy vegetace) uložená jako .tres soubory.


static func list(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var files: Array = []
	for f in d.get_files():
		var g := f.trim_suffix(".remap")
		if g.ends_with(".tres") or g.ends_with(".res"):
			files.append(g)
	files.sort()
	for f in files:
		var r := load(dir.path_join(f))
		if r:
			out.append(r)
	return out


static func save_new(dir: String, res: Resource) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var i := list(dir).size()
	var path := dir.path_join("item_%03d.tres" % i)
	while FileAccess.file_exists(path):
		i += 1
		path = dir.path_join("item_%03d.tres" % i)
	ResourceSaver.save(res, path)
	res.take_over_path(path)
