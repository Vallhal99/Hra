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


func interact(_who: Node) -> void:
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
