@tool
class_name NPC3D
extends Node3D
## NPC: stoupni si k němu a stiskni E / Enter / mezerník. Věty odděluj znakem |

@export var speaker := "NPC"
@export_multiline var lines := "Ahoj, cestovateli!|Hezký den, že?"
@export var texture: Texture2D
@export var hframes := 1
@export var vframes := 1


func _ready() -> void:
	add_child(HD2DSprite.make(texture if texture else HD2DSprite.placeholder(Color(0.3, 0.5, 0.8)), hframes, vframes))
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
	var d := get_node_or_null("/root/Dialogue")
	if d == null:
		return
	var arr := PackedStringArray()
	for l in lines.replace("\n", "|").split("|"):
		if l.strip_edges() != "":
			arr.append(l.strip_edges())
	d.say(arr, speaker)
