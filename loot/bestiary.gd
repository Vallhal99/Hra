extends Node
## Autoload "Bestiary": co hráč o nepřátelích zjistil.

const INFO := {
	"Slizák": {"desc": "Rosolovitá tvář lesů a luk. Neškodný, dokud se jich nenasbírá víc.", "where": "Louka, Rozcestí, Hvozd"},
	"Kostlivec": {"desc": "Pozůstatek dávné bitvy. Světlo ho trápí, tma ho nechává chladným.", "where": "Louka u řeky, Jezero, Jeskyně, Hrobka"},
	"Zbojník": {"desc": "Lupič s lukem. Útočí i zezadu, takže ho nenechte být.", "where": "Hvozd, Rozcestí"},
	"Kostěný král": {"desc": "Vládce hrobky. Ten, kdo zná jeho slabiny, má šanci.", "where": "Hrobka"},
}
var seen: Dictionary = {}   ## jméno -> {kills, hp, weak: [], resist: {}, drops: []}


func record_seen(u) -> void:
	if not seen.has(u.unit_name):
		seen[u.unit_name] = {"kills": 0, "hp": u.max_hp, "weak": [], "resist": {}, "drops": []}


func record_kill(u) -> void:
	record_seen(u)
	var e: Dictionary = seen[u.unit_name]
	e.kills = int(e.kills) + 1
	e.hp = u.max_hp
	for k in u.weak_known:
		if not e.weak.has(k):
			e.weak.append(k)
	for k in u.resist:
		e.resist[k] = u.resist[k]
	for d in u.drops:
		if not e.drops.has(d[0]):
			e.drops.append(d[0])


func get_state() -> Dictionary:
	return seen.duplicate(true)


func set_state(d: Dictionary) -> void:
	seen = d
