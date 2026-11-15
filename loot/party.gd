extends Node
## Autoload "Party": parťáci, kteří se přidají k hrdinovi (max. 3 + hrdina = 4 v boji).

signal changed
signal joined(id: String)

const MAX_ACTIVE := 3
## base = hp, sp, atk, def, spd; grow = přírůstek za úroveň
const DEFS := {
	"lia": {"name": "Lia", "title": "Prodavačka a léčitelka", "cls": "klerik", "wtype": "staff", "tex": "res://npc/prodavacka.png", "ppm": 125.0,
		"base": [80, 40, 12, 6, 9], "grow": [9, 5, 1.2, 0.6, 0.3], "join_level": 1,
		"bio": "Prodává lektvary a ví, jak jimi zachránit kůži. Mírná, ale s ostrým jazykem."},
	"brum": {"name": "Brum", "title": "Kovář", "cls": "valecnik", "wtype": "axe", "tex": "res://npc/kovar.png", "ppm": 112.0,
		"base": [150, 12, 22, 14, 6], "grow": [16, 2, 2.2, 1.4, 0.2], "join_level": 99,
		"bio": "Mlčenlivý obr, který raději bije kladivem do kovadliny než do lidí. Pokud musí, tak i do lidí."},
	"rys": {"name": "Rys", "title": "Bývalý zbojník", "cls": "zlodej", "wtype": "dagger", "tex": "res://enemies/zbojnik.png", "ppm": 105.0,
		"base": [95, 20, 18, 7, 16], "grow": [10, 3, 1.8, 0.7, 0.6], "join_level": 5,
		"bio": "Zběhl od zbojníků, protože mu nechtěli dělit kořist. Cynik se zlatým srdcem (dobře schovaným)."},
}

var members: Dictionary = {}   ## id -> {level, xp, sub}
var order: Array = []          ## pořadí aktivních parťáků


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	recruit("lia", true)
	var h := get_node_or_null("/root/Hero")
	if h:
		h.leveled.connect(_on_hero_level)


func _on_hero_level(lv: int) -> void:
	for id in DEFS:
		if not members.has(id) and lv >= int(DEFS[id].join_level):
			recruit(id)
	for id in members:
		_level_to(id, maxi(int(members[id].level), lv - 1))


func recruit(id: String, silent := false) -> void:
	if members.has(id) or not DEFS.has(id):
		return
	var h := get_node_or_null("/root/Hero")
	members[id] = {"level": maxi(1, (h.level - 1) if h else 1), "xp": 0, "sub": ""}
	if order.size() < MAX_ACTIVE:
		order.append(id)
	changed.emit()
	if not silent:
		joined.emit(id)
		var d := get_node_or_null("/root/Dialogue")
		if d and d.has_method("say"):
			d.say(PackedStringArray(["Přidávám se k vám!"]), DEFS[id].name)


func _level_to(id: String, lv: int) -> void:
	members[id].level = lv


func add_xp(n: int) -> void:
	for id in members:
		var m: Dictionary = members[id]
		m.xp = int(m.xp) + n
		var need := int(round(float(GameData.prog.xp_base) * pow(float(m.level), float(GameData.prog.xp_exp))))
		while m.xp >= need and int(m.level) < int(GameData.prog.max_level):
			m.xp -= need
			m.level += 1
			need = int(round(float(GameData.prog.xp_base) * pow(float(m.level), float(GameData.prog.xp_exp))))


func stats(id: String) -> Dictionary:
	var d: Dictionary = DEFS[id]
	var lv := int(members[id].level) - 1
	var b: Array = d.base
	var g: Array = d.grow
	return {"hp": int(b[0] + g[0] * lv), "sp": int(b[1] + g[1] * lv), "atk": int(b[2] + g[2] * lv), "def": int(b[3] + g[3] * lv), "spd": int(b[4] + g[4] * lv)}


func make_unit(id: String) -> BattleUnit:
	var d: Dictionary = DEFS[id]
	var st := stats(id)
	var u := BattleUnit.make(d.name, true, st.hp, st.sp, st.atk, st.def, st.spd, Color(0.8, 0.8, 0.9))
	u.class_id = d.cls
	u.wtype = d.wtype
	u.member_id = id
	u.skills = Rules.skills_for(d.cls, str(members[id].sub), int(members[id].level))
	u.texture = load(d.tex)
	u.ppm = d.ppm
	u.faces_right = true
	return u


func get_state() -> Dictionary:
	return {"members": members.duplicate(true), "order": order.duplicate()}


func set_state(d: Dictionary) -> void:
	members = d.get("members", members)
	order = d.get("order", order)
	changed.emit()
