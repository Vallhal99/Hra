class_name Rules
extends RefCounted
## Pravidla soubojů: prvky, statusy, typy zbraní, dovednosti povolání, limity, vliv prostředí.

const PHYS := ["sword", "dagger", "spear", "axe", "bow", "staff", "fist"]
const MAGIC := ["fire", "ice", "lightning", "wind", "light", "dark"]
const KIND_NAMES := {"sword": "Meč", "dagger": "Dýka", "spear": "Kopí", "axe": "Sekera", "bow": "Luk", "staff": "Hůl", "fist": "Pěst",
	"fire": "Oheň", "ice": "Led", "lightning": "Blesk", "wind": "Vítr", "light": "Světlo", "dark": "Tma"}

## typ zbraně: reach = front (jen přední řada), pierce (cíl + jeden za ním), any (kdokoli), adjacent (cíl + soused)
const WEAPON_TYPES := {
	"sword": {"reach": "front", "melee": true, "desc": "Přední řada."},
	"dagger": {"reach": "front", "melee": true, "crit": 0.25, "desc": "Přední řada, vysoká šance na kritický zásah."},
	"axe": {"reach": "front", "melee": true, "shield_break": 2, "desc": "Přední řada, láme štíty dvakrát rychleji."},
	"spear": {"reach": "pierce", "melee": true, "desc": "Zasáhne cíl i nepřítele za ním."},
	"bow": {"reach": "any", "melee": false, "desc": "Dosáhne na celé pole."},
	"staff": {"reach": "adjacent", "melee": false, "desc": "Zasáhne dva sousední cíle."},
	"fist": {"reach": "front", "melee": true, "desc": "Přední řada."},
}
const WEAPON_ITEMS := {"zelezny_mec": "sword", "ozdobny_mec": "sword", "dyka": "dagger", "sekera": "axe", "kopi": "spear", "luk": "bow", "hul": "staff"}

const STATUS := {
	"poison": {"name": "Jed", "ico": "☠", "col": Color(0.5, 0.9, 0.3), "dot": 0.07},
	"burn": {"name": "Popálení", "ico": "♨", "col": Color(1.0, 0.5, 0.2), "dot": 0.08},
	"bleed": {"name": "Krvácení", "ico": "✚", "col": Color(0.9, 0.2, 0.25), "dot": 0.05},
	"regen": {"name": "Obnova", "ico": "♥", "col": Color(0.4, 1.0, 0.6), "hot": 0.07},
	"sleep": {"name": "Spánek", "ico": "Z", "col": Color(0.6, 0.7, 1.0), "skip": true},
	"stun": {"name": "Omráčení", "ico": "✱", "col": Color(1.0, 0.9, 0.3), "skip": true},
	"blind": {"name": "Slepota", "ico": "◐", "col": Color(0.7, 0.7, 0.7), "miss": 0.5},
	"slow": {"name": "Zpomalení", "ico": "▼", "col": Color(0.5, 0.6, 0.9), "spd": 0.6},
	"haste": {"name": "Zrychlení", "ico": "▲", "col": Color(1.0, 0.9, 0.4), "spd": 1.5},
	"atkup": {"name": "Síla", "ico": "⚔", "col": Color(1.0, 0.6, 0.3), "atk": 1.3},
	"defup": {"name": "Ochrana", "ico": "⛨", "col": Color(0.5, 0.8, 1.0), "taken": 0.7},
	"defdown": {"name": "Rozbité krytí", "ico": "⛉", "col": Color(0.8, 0.4, 0.4), "taken": 1.35},
}

## Dovednosti: lvl = od jaké úrovně; target: enemy | all | ally | allies | self
const SKILLS := {
	"valecnik": [
		{"name": "Silný úder", "cost": 8, "power": 1.9, "kind": "sword", "lvl": 1, "desc": "Těžký úder."},
		{"name": "Rozbít brnění", "cost": 10, "power": 1.0, "kind": "axe", "st": ["defdown", 3, 1.0], "lvl": 3, "desc": "Nepřítel bere víc zranění (3 kola)."},
		{"name": "Bojový pokřik", "cost": 12, "power": 0, "target": "allies", "st": ["atkup", 3, 1.0], "lvl": 5, "desc": "Družina je silnější."},
		{"name": "Vír ostří", "cost": 16, "power": 1.1, "all": true, "kind": "wind", "lvl": 8, "desc": "Zasáhne všechny."}],
	"lucistnik": [
		{"name": "Přesný šíp", "cost": 8, "power": 1.8, "kind": "bow", "lvl": 1, "desc": "Silná střela na celé pole."},
		{"name": "Ohnivý šíp", "cost": 10, "power": 1.4, "kind": "fire", "st": ["burn", 3, 0.6], "lvl": 3, "desc": "Může zapálit."},
		{"name": "Déšť šípů", "cost": 16, "power": 1.0, "all": true, "kind": "bow", "lvl": 6, "desc": "Zasáhne všechny."},
		{"name": "Oslepující šíp", "cost": 10, "power": 0.8, "kind": "light", "st": ["blind", 3, 0.9], "lvl": 8, "desc": "Oslepí cíl."}],
	"mag": [
		{"name": "Ohnivá koule", "cost": 8, "power": 1.8, "kind": "fire", "st": ["burn", 2, 0.35], "lvl": 1, "desc": "Oheň na jeden cíl."},
		{"name": "Ledový úlomek", "cost": 8, "power": 1.6, "kind": "ice", "st": ["slow", 2, 0.5], "lvl": 2, "desc": "Může zpomalit."},
		{"name": "Blesk", "cost": 14, "power": 1.3, "all": true, "kind": "lightning", "lvl": 5, "desc": "Zasáhne všechny."},
		{"name": "Temný pohlcení", "cost": 12, "power": 1.5, "kind": "dark", "st": ["sleep", 2, 0.4], "lvl": 8, "desc": "Může uspat."}],
	"zlodej": [
		{"name": "Zákeřný bod", "cost": 6, "power": 1.7, "kind": "dagger", "st": ["bleed", 3, 0.5], "lvl": 1, "desc": "Může způsobit krvácení."},
		{"name": "Jedová čepel", "cost": 9, "power": 1.2, "kind": "dagger", "st": ["poison", 3, 0.8], "lvl": 3, "desc": "Otráví cíl."},
		{"name": "Pytel písku", "cost": 8, "power": 0.4, "kind": "dagger", "st": ["blind", 3, 0.9], "lvl": 5, "desc": "Oslepí cíl."},
		{"name": "Tanec nožů", "cost": 15, "power": 1.0, "all": true, "kind": "dagger", "lvl": 8, "desc": "Zasáhne všechny."}],
	"klerik": [
		{"name": "Léčení", "cost": 10, "heal": 45, "target": "ally", "lvl": 1, "desc": "Vyléčí spojence."},
		{"name": "Světelný šíp", "cost": 8, "power": 1.6, "kind": "light", "lvl": 2, "desc": "Světlo na jeden cíl."},
		{"name": "Požehnání", "cost": 12, "power": 0, "target": "allies", "st": ["defup", 3, 1.0], "lvl": 4, "desc": "Družina bere méně zranění."},
		{"name": "Obnova", "cost": 14, "power": 0, "target": "allies", "st": ["regen", 4, 1.0], "lvl": 6, "desc": "Družina se postupně léčí."}],
	"paladin": [
		{"name": "Svatý úder", "cost": 9, "power": 1.7, "kind": "light", "lvl": 1, "desc": "Světelný úder zbraní."},
		{"name": "Štít víry", "cost": 10, "power": 0, "target": "self", "st": ["defup", 3, 1.0], "lvl": 3, "desc": "Menší zranění po 3 kola."},
		{"name": "Léčivé dotek", "cost": 12, "heal": 35, "target": "ally", "lvl": 5, "desc": "Vyléčí spojence."},
		{"name": "Soud", "cost": 16, "power": 1.4, "all": true, "kind": "light", "lvl": 8, "desc": "Zasáhne všechny."}],
}
const LIMITS := {
	"valecnik": {"name": "Ocelová bouře", "power": 3.2, "kind": "sword", "all": true},
	"lucistnik": {"name": "Hvězdný déšť", "power": 2.8, "kind": "bow", "all": true},
	"mag": {"name": "Meteor", "power": 3.6, "kind": "fire", "all": true, "st": ["burn", 3, 1.0]},
	"zlodej": {"name": "Tisíc ran", "power": 3.0, "kind": "dagger", "all": true, "st": ["bleed", 3, 1.0]},
	"klerik": {"name": "Boží světlo", "power": 2.0, "kind": "light", "all": true, "heal_all": 80},
	"paladin": {"name": "Svatý hněv", "power": 3.2, "kind": "light", "all": true},
}


static func weapon_type_of(item_id: String) -> String:
	if item_id == "":
		return "fist"
	return WEAPON_ITEMS.get(item_id, "sword")


static func skills_for(class_id: String, sub_id: String, level: int) -> Array:
	var out: Array = []
	for s in SKILLS.get(class_id, []):
		if int(s.lvl) <= level:
			out.append(s)
	if sub_id != "" and sub_id != class_id:
		var n := 0
		for s in SKILLS.get(sub_id, []):
			if int(s.lvl) <= level and n < 2:
				out.append(s)
				n += 1
	return out


static func _atmo() -> Node:
	var l := Engine.get_main_loop() as SceneTree
	return l.root.get_node_or_null("Atmo") if l else null


## Násobič poškození podle počasí a denní doby.
static func env_mult(kind: String) -> float:
	var a := _atmo()
	if a == null:
		return 1.0
	var m := 1.0
	if a.is_wet():
		if kind == "fire":
			m *= 0.6
		elif kind == "lightning":
			m *= 1.3
	elif a.sun_factor() > 0.65:
		if kind == "fire" or kind == "light":
			m *= 1.15
		elif kind == "dark":
			m *= 0.85
	if a.is_night():
		if kind == "dark":
			m *= 1.25
		elif kind == "light":
			m *= 0.85
	return m


## Šance, že zásah mine (noc a déšť zhoršují přesnost střelby a hrdinů).
static func env_miss(kind: String, hero_side: bool) -> float:
	var a := _atmo()
	if a == null:
		return 0.0
	var p := 0.0
	if a.is_night() and hero_side and PHYS.has(kind):
		p += 0.12
	if a.is_wet() and kind == "bow":
		p += 0.2
	return p


static func env_text() -> String:
	var a := _atmo()
	if a == null:
		return ""
	var parts: Array[String] = []
	if a.is_wet():
		parts.append("Déšť: oheň −40 %, blesk +30 %, luk mine častěji")
	if a.is_night():
		parts.append("Noc: tma +25 %, světlo −15 %, hrdinové častěji míjejí")
	elif a.sun_factor() > 0.65 and not a.is_wet():
		parts.append("Jasný den: oheň a světlo +15 %, tma −15 %")
	return "\n".join(parts)
