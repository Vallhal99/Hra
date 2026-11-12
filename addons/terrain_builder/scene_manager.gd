extends Node
## Autoload "SceneManager": rychlé přechody mezi malými scénami (načítání na pozadí + fade).

signal transition_finished
var busy := false
var fade_time := 0.25
var _rect: ColorRect


func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_rect)


func preload_scene(path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)


func go(path: String, spawn: String = "") -> void:
	if busy or not ResourceLoader.exists(path):
		return
	busy = true
	await _fade(1.0)
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var ps: PackedScene
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		ps = ResourceLoader.load_threaded_get(path)
	else:
		ps = load(path)
	if ps == null:
		await _fade(0.0)
		busy = false
		return
	get_tree().change_scene_to_packed(ps)
	await get_tree().process_frame
	await get_tree().process_frame
	_place_player(spawn)
	await get_tree().process_frame
	await _fade(0.0)
	busy = false
	transition_finished.emit()


func _place_player(spawn: String) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if p and scene and spawn != "":
		var sp := scene.find_child(spawn, true, false) as Node3D
		if sp:
			p.global_position = sp.global_position
			if p is CharacterBody3D:
				(p as CharacterBody3D).velocity = Vector3.ZERO
	get_tree().call_group("camera_follow", "snap")


func _fade(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", a, fade_time)
	await tw.finished
