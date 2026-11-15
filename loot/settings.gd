extends Node
## Autoload "Settings": kvalita grafiky, zvuk, celá obrazovka. Ukládá do user://settings.cfg.

const QUALITY_NAMES := ["Nízká", "Střední", "Vysoká"]
var quality := 2
var fullscreen := false
var vsync := true
var volume := 0.8
var res_scale := 1.0
var weather_fx := true
var _last_cam: Camera3D
var _acc := 0.0
const FILE := "user://settings.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cf := ConfigFile.new()
	if cf.load(FILE) == OK:
		quality = int(cf.get_value("g", "quality", 2))
		fullscreen = bool(cf.get_value("g", "fullscreen", false))
		vsync = bool(cf.get_value("g", "vsync", true))
		volume = float(cf.get_value("a", "volume", 0.8))
		res_scale = float(cf.get_value("g", "res_scale", 1.0))
		weather_fx = bool(cf.get_value("g", "weather", true))
	apply_global()


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "quality", quality)
	cf.set_value("g", "fullscreen", fullscreen)
	cf.set_value("g", "vsync", vsync)
	cf.set_value("g", "res_scale", res_scale)
	cf.set_value("g", "weather", weather_fx)
	cf.set_value("a", "volume", volume)
	cf.save(FILE)


func apply_global() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	get_viewport().scaling_3d_scale = clampf(res_scale, 0.5, 1.0)
	var at := get_node_or_null("/root/Atmo")
	if at:
		at.enabled = weather_fx
		if at._rig:
			at._rig.visible = weather_fx
	_last_cam = null


func _process(dt: float) -> void:
	_acc += dt
	if _acc < 1.0:
		return
	_acc = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam != _last_cam and cam != null:
		_last_cam = cam
		apply_camera(cam)


func apply_camera(cam: Camera3D) -> void:
	var env := cam.environment
	if env:
		env.glow_enabled = quality >= 1
		env.ssao_enabled = quality >= 2
		env.ssil_enabled = quality >= 2
		env.volumetric_fog_enabled = quality >= 2
	if cam.attributes is CameraAttributesPractical:
		var a := cam.attributes as CameraAttributesPractical
		a.dof_blur_far_enabled = quality >= 1
		a.dof_blur_near_enabled = quality >= 1
	for l in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		(l as DirectionalLight3D).shadow_enabled = quality >= 1


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_C and not get_tree().paused:
		if get_tree().get_first_node_in_group("player") != null and not get_tree().root.has_node("PartyMenu"):
			PartyMenu.open(get_tree(), 0)
			get_viewport().set_input_as_handled()
