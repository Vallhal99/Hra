@tool
class_name NPC3D
extends Node3D
## NPC: stoupni si k němu a stiskni E / Enter / mezerník. Věty odděluj znakem |

@export var speaker := "NPC"
@export_multiline var lines := "Ahoj, cestovateli!|Hezký den, že?"
@export var dialogue_id := ""  ## id dialogu z gamedata.json (má přednost před textem výše)
@export var texture: Texture2D
@export var hframes := 1
@export var vframes := 1
@export var ppm := 32.0 ## pixelu na metr sprite
@export var night_text := ""  ## co řekne v noci (prázdné = chová se normálně)
var routine: Array = []       ## [{t0, t1, off: Vector3} | {t0, t1, hide: true}] podle denní doby (Atmo.tod)
var _home := Vector3.ZERO
var _body: StaticBody3D


func _ready() -> void:
	var spr := HD2DSprite.make(texture if texture else HD2DSprite.placeholder(Color(0.3, 0.5, 0.8)), hframes, vframes)
	spr.pixel_size = 1.0 / ppm
	spr.position.y = spr.texture.get_height() / float(vframes) * 0.5 / ppm
	if ppm > 60.0:
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(spr)
	add_child(HD2DSprite.blob_shadow())
	if Engine.is_editor_hint():
		return
	add_to_group("interactable")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 0.9
	cs.shape = cap
	cs.position.y = 0.45
	body.add_child(cs)
	add_child(body)
	_body = body
	_home = position


func _in_range(t: float, a: float, b: float) -> bool:
	return (t >= a and t < b) if a <= b else (t >= a or t < b)


func _process(dt: float) -> void:
	if Engine.is_editor_hint() or routine.is_empty():
		return
	var at := get_node_or_null("/root/Atmo")
	if at == null:
		return
	var tod: float = at.tod
	for e in routine:
		if _in_range(tod, float(e.t0), float(e.t1)):
			if e.get("hide", false):
				if visible:
					visible = false
					remove_from_group("interactable")
					_body.process_mode = Node.PROCESS_MODE_DISABLED
			else:
				if not visible:
					visible = true
					add_to_group("interactable")
					_body.process_mode = Node.PROCESS_MODE_INHERIT
				var tgt: Vector3 = _home + (e.off as Vector3)
				var mv := tgt - position
				mv.y = 0.0
				if mv.length() > 0.08:
					position += mv.normalized() * minf(1.6 * dt, mv.length())
					var q := PhysicsRayQueryParameters3D.create(position + Vector3(0, 3, 0), position + Vector3(0, -5, 0))
					var r := get_world_3d().direct_space_state.intersect_ray(q)
					if r:
						position.y = r.position.y
			break


func interact(_who: Node) -> void:
	var at := get_node_or_null("/root/Atmo")
	if night_text != "" and at and at.is_night():
		var dn := get_node_or_null("/root/Dialogue")
		if dn:
			dn.say(PackedStringArray([night_text]), speaker)
		return
	if dialogue_id != "":
		var dr := get_node_or_null("/root/DialogueRunner")
		if dr:
			dr.start(dialogue_id, speaker)
			return
	var d := get_node_or_null("/root/Dialogue")
	if d == null:
		return
	var arr := PackedStringArray()
	for l in lines.replace("\n", "|").split("|"):
		if l.strip_edges() != "":
			arr.append(l.strip_edges())
	d.say(arr, speaker)
