extends Node
## Autoload "GameData": načte data/gamedata.json (export z Dílny postav).

var data: Dictionary = {}
var items: Dictionary = {}
var classes: Array = []
var dialogues: Dictionary = {}
var quests: Dictionary = {}
var shops: Dictionary = {}
var stat_names: Dictionary = {}
var prog: Dictionary = {"max_level": 30, "xp_base": 40, "xp_exp": 1.5, "points_per_level": 3}


func _ready() -> void:
	var f := FileAccess.open("res://data/gamedata.json", FileAccess.READ)
	if f == null:
		push_warning("Chybí res://data/gamedata.json")
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_warning("gamedata.json je poškozený")
		return
	data = d
	stat_names = d.get("stat_names", {})
	prog.merge(d.get("progression", {}), true)
	classes = d.get("classes", [])
	for it in d.get("items", []):
		var o: Dictionary = it.duplicate()
		var ic: String = o.get("icon", "")
		o["icon"] = ("res://" + ic) if ic != "" and ResourceLoader.exists("res://" + ic) else ""
		items[o.id] = o
	for dl in d.get("dialogues", []):
		var nodes := {}
		for n in dl.get("nodes", []):
			nodes[n.id] = n
		dl["_nodes"] = nodes
		dialogues[dl.id] = dl
	for q in d.get("quests", []):
		quests[q.id] = q
	for s in d.get("shops", []):
		shops[s.id] = s


func class_by_id(id: String) -> Dictionary:
	for c in classes:
		if c.id == id:
			return c
	return {}
