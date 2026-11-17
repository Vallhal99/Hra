class_name BattleUnit
extends Resource
## Jedna bojující postava (hrdina nebo nepřítel). Textury doplníš později do `texture`.

@export var unit_name := "Hrdina"
@export var is_hero := true
@export var max_hp := 100
@export var max_sp := 30
@export var atk := 20
@export var defense := 8
@export var spd := 10
@export var texture: Texture2D
@export var hframes := 1
@export var hero_anim := false ## hrdina z Dílny: animace podle stavu
var anim_name := "Idle"
var anim_loop := true
var anim_t := 0.0
var anims := {}   ## animace nepratel: jmeno -> {tex, frames, fps}
var proc := false ## jednosnimkovy nepritel: proceduralni dychani
var phase := 0.0
var shield := 0
var shield_max := 0
var weak: Array = []       ## slabiny (sword, spear, dagger, axe, bow, staff, fire, ice, lightning, wind, light, dark)
var weak_known: Array = []
var broken := false
var broken_turns := 0
var bp := 1
var row := 0 ## 0 = přední řada, 1 = zadní
var status: Dictionary = {}   ## id -> zbývající kola
var resist: Dictionary = {}   ## prvek -> násobič (0.5 odolný, 1.5 citlivý, 0 imunní)
var wtype := "fist"           ## typ zbraně (viz Rules.WEAPON_TYPES)
var class_id := ""
var ranged := false           ## nepřítel útočí na kohokoli
var boss := false
var tint := Color.WHITE
var xp_value := 0
var gold_value := 0
var drops: Array = []         ## [[id, šance]]
var member_id := ""           ## "" = hlavní hrdina, jinak id parťáka
@export var ppm := 32.0 ## pixelů na metr (hrdina z Dílny má 133)
## Kam se postava na obrázku dívá. Hrdina stojí vpravo a musí se dívat doleva, nepřítel naopak (obrázek se sám překlopí).
@export var faces_right := true
@export var color := Color(0.3, 0.5, 0.9) ## barva zástupné figurky, než bude hotová grafika
## Dovednosti: {"name": String, "cost": int, "power": float, "all": bool, "heal": int}
@export var skills: Array = []

var hp := 0
var sp := 0
var defending := false
var node: Node3D
var sprite: Sprite3D
var label: Label3D


func reset() -> void:
	hp = max_hp
	sp = max_sp
	defending = false
	shield = shield_max
	broken = false
	broken_turns = 0
	weak_known = []
	bp = 1
	status = {}


func has_st(id: String) -> bool:
	return status.has(id)


func add_st(id: String, turns: int) -> void:
	status[id] = maxi(int(status.get(id, 0)), turns)


func eff_spd() -> float:
	var v := float(spd)
	for k in status:
		v *= float(Rules.STATUS[k].get("spd", 1.0))
	return v


func eff_atk() -> float:
	var v := float(atk)
	for k in status:
		v *= float(Rules.STATUS[k].get("atk", 1.0))
	return v


func taken_mult() -> float:
	var v := 1.0
	for k in status:
		v *= float(Rules.STATUS[k].get("taken", 1.0))
	return v


func alive() -> bool:
	return hp > 0


static func make(n: String, hero: bool, hp_: int, sp_: int, atk_: int, def_: int, spd_: int, col: Color, sk: Array = []) -> BattleUnit:
	var u := BattleUnit.new()
	u.unit_name = n
	u.is_hero = hero
	u.max_hp = hp_
	u.max_sp = sp_
	u.atk = atk_
	u.defense = def_
	u.spd = spd_
	u.color = col
	u.skills = sk
	u.reset()
	return u


static func default_party() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var H = root.get_node_or_null("Hero")
	var inv = root.get_node_or_null("/root/Inventory")
	if H != null and H.class_id != "":
		var u := make(H.cls().name, true, H.max_hp(), H.max_sp(), H.atk() + 6, H.defense() + 3, H.spd() + 4, Color(0.25, 0.45, 0.9))
		u.class_id = H.class_id
		u.skills = Rules.skills_for(H.class_id, H.sub, H.level)
		out.append(u)
	else:
		var u := make("Hrdina", true, 120, 30, 26, 9, 12, Color(0.25, 0.45, 0.9))
		u.class_id = "valecnik"
		u.skills = Rules.skills_for("valecnik", "", 8)
		out.append(u)
	var hs: Dictionary = load("res://hero/hero_sprite.gd").sheet("Idle", "W", inv.equip)
	if not hs.is_empty():
		out[0].texture = hs.tex
		out[0].hframes = hs.frames
		out[0].ppm = 115.0
		out[0].faces_right = false
		out[0].hero_anim = true
	out[0].wtype = Rules.weapon_type_of(str(inv.equip.get("zbran", "")) if inv.equip.get("zbran") != null else "")
	var P = root.get_node_or_null("Party")
	if P != null:
		for id in P.order:
			out.append(P.make_unit(id))
	else:
		out.append(make("Léčitelka", true, 90, 40, 15, 6, 9, Color(0.9, 0.85, 0.95), Rules.SKILLS["klerik"]))
	return out


static func make_kind(k: String) -> BattleUnit:
	match k:
		"king":
			return _king()
		"ghost":
			var g: BattleUnit = _foe("Přízrak", 60, 24, 3, 13, Color(0.6, 0.75, 1.0), 3, ["light", "fire", "staff"])
			g.ranged = true
			g.resist = {"dark": 0.0, "dagger": 0.5, "sword": 0.6, "axe": 0.6, "spear": 0.6}
			g.drops = [["kost", 0.5], ["koreni", 0.3]]
			g.texture = load("res://enemies/kostlivec.png")
			g.ppm = 100.0
			g.proc = true
			_rt(g, "kostlivec", "E")
			g.tint = Color(0.55, 0.75, 1.3, 0.62)
			g.xp_value = 38
			return g
		"knight":
			var kn: BattleUnit = _skeleton(5, ["light", "lightning", "axe"])
			kn.unit_name = "Hrobní rytíř"
			kn.max_hp = 150
			kn.atk = 27
			kn.defense = 12
			kn.spd = 8
			kn.reset()
			kn.tint = Color(1.25, 0.65, 0.6)
			kn.ppm = 88.0
			kn.xp_value = 55
			kn.drops = [["ruda", 0.7], ["kost", 0.5], ["lektvar", 0.3]]
			return kn
		"wolf":
			var w: BattleUnit = _foe("Vlk", 62, 19, 3, 16, Color(0.5, 0.5, 0.55), 2, ["fire", "light", "ice"])
			w.resist = {"dark": 0.5}
			w.drops = [["bylina", 0.4], ["koreni", 0.3]]
			w.texture = load("res://enemies/slime_Idle.png")
			w.ppm = 105.0
			_rt(w, "vlk", "E")
			w.xp_value = 30
			return w
		"flame":
			var fl: BattleUnit = _foe("Plamínek", 55, 21, 2, 12, Color(1.0, 0.5, 0.2), 3, ["ice", "wind"])
			fl.resist = {"fire": 0.0, "ice": 1.6}
			fl.drops = [["ruda", 0.3], ["lektvar", 0.2]]
			fl.texture = load("res://enemies/slime_Idle.png")
			fl.ppm = 105.0
			_rt(fl, "plamen", "E")
			fl.xp_value = 34
			return fl
		"skeleton":
			return _skeleton(4, ["light", "axe", "fire", "staff"])
		"bandit":
			return _bandit(3, ["ice", "bow", "dagger"])
	return _slime(3, ["fire", "sword", "wind"])


static func default_enemies() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	out.append(_slime(3, ["fire", "sword", "wind"]))
	out.append(_skeleton(4, ["light", "axe", "fire", "staff"]))
	out.append(_bandit(3, ["ice", "bow", "dagger"]))
	return out


static func _foe(n: String, hp_: int, atk_: int, def_: int, spd_: int, col: Color, sh: int, weak_: Array) -> BattleUnit:
	var u := make(n, false, hp_, 0, atk_, def_, spd_, col)
	u.shield_max = sh
	u.weak = weak_
	u.xp_value = 20 + atk_
	u.gold_value = 8 + hp_ / 10
	u.reset()
	return u


static func _slime(sh: int, weak_: Array) -> BattleUnit:
	var u := _foe("Slizák", 70, 16, 4, 8, Color(0.3, 0.8, 0.35), sh, weak_)
	u.resist = {"ice": 0.6, "dark": 0.8}
	u.drops = [["lektvar", 0.3], ["zele", 0.5], ["houba", 0.3]]
	var fps := {"Idle": 6.0, "Attack": 12.0, "Hurt": 9.0, "Death": 7.0}
	for k in fps:
		var t := load("res://enemies/slime_%s.png" % k) as Texture2D
		u.anims[k] = {"tex": t, "frames": int(round(t.get_width() / 130.0)), "fps": fps[k]}
	u.texture = u.anims["Idle"]["tex"]
	u.hframes = u.anims["Idle"]["frames"]
	u.ppm = 58.0
	return u


static func _skeleton(sh: int, weak_: Array) -> BattleUnit:
	var u := _foe("Kostlivec", 85, 20, 6, 10, Color(0.85, 0.85, 0.8), sh, weak_)
	u.resist = {"dark": 0.0, "dagger": 0.7, "bow": 0.6}
	u.drops = [["paklic", 0.2], ["kost", 0.6], ["ruda", 0.2]]
	u.texture = load("res://enemies/kostlivec.png")
	u.ppm = 105.0
	u.proc = true
	_rt(u, "kostlivec", "E")
	u.ppm = 100.0
	return u


const RT_MAP := {"Idle": ["Idle", "Breath"], "Attack": ["Slash", "Bite", "Castspell"], "Hurt": ["Block"], "Death": ["Death"]}


## animace z npc/anim (packer): jeden smer ("E" = nepritel kouka doprava, "W" = druzina)
static func _rt(u: BattleUnit, ch: String, d: String) -> void:
	var meta: Dictionary = AnimActor.meta(ch)
	if meta.is_empty():
		return
	var found := {}
	for k in RT_MAP:
		for src in RT_MAP[k]:
			var png := "res://npc/anim/%s_%s_%s.png" % [ch, src, d]
			if meta.has(src) and ResourceLoader.exists(png):
				found[k] = {"tex": load(png), "frames": int(meta[src].frames), "fps": float(meta[src].fps)}
				break
	if not found.has("Idle"):
		return
	u.anims = found
	u.texture = found["Idle"]["tex"]
	u.hframes = found["Idle"]["frames"]
	u.proc = false


static func _king() -> BattleUnit:
	var u := _foe("Kostěný král", 560, 30, 10, 9, Color(0.8, 0.75, 0.6), 8, ["light", "fire", "axe", "lightning", "staff"])
	u.boss = true
	u.resist = {"dark": 0.0, "dagger": 0.6, "bow": 0.5, "ice": 0.7}
	u.xp_value = 420
	u.gold_value = 500
	u.drops = [["ruda", 1.0], ["kost", 1.0], ["lektvar", 1.0]]
	u.texture = load("res://enemies/kostlivec.png")
	u.ppm = 58.0
	u.proc = true
	_rt(u, "kostlivec", "E")
	return u


static func _bandit(sh: int, weak_: Array) -> BattleUnit:
	var u := _foe("Zbojník", 75, 22, 5, 14, Color(0.5, 0.2, 0.25), sh, weak_)
	u.ranged = true
	u.drops = [["lektvar", 0.3], ["ruda", 0.35], ["maso", 0.4], ["koreni", 0.2]]
	u.texture = load("res://enemies/zbojnik.png")
	u.ppm = 105.0
	u.proc = true
	return u
