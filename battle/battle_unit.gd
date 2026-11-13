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
var shield := 0
var shield_max := 0
var weak: Array = []       ## slabiny (sword, spear, dagger, axe, bow, staff, fire, ice, lightning, wind, light, dark)
var weak_known: Array = []
var broken := false
var broken_turns := 0
var bp := 1
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
	var H = Engine.get_main_loop().root.get_node_or_null("Hero")
	if H != null and H.class_id != "":
		out.append(make(H.cls().name, true, H.max_hp(), H.max_sp(), H.atk() + 6, H.defense() + 3, H.spd() + 4, Color(0.25, 0.45, 0.9), [
			{"name": "Silný úder", "cost": 8, "power": 1.9, "kind": "sword"},
			{"name": "Vír ostří", "cost": 14, "power": 1.1, "all": true, "kind": "wind"}]))
		var hs: Dictionary = load("res://hero/hero_sprite.gd").sheet("Idle", "W", H.get_node("/root/Inventory").equip)
		if not hs.is_empty():
			out[0].texture = hs.tex
			out[0].hframes = hs.frames
			out[0].ppm = 115.0
			out[0].faces_right = false
			out[0].hero_anim = true
	else:
		out.append(make("Hrdina", true, 120, 30, 26, 9, 12, Color(0.25, 0.45, 0.9), [
		{"name": "Silný úder", "cost": 8, "power": 1.9, "kind": "sword"},
		{"name": "Vír ostří", "cost": 14, "power": 1.1, "all": true, "kind": "wind"}]))
	out.append(make("Léčitelka", true, 90, 40, 15, 6, 9, Color(0.9, 0.85, 0.95), [
		{"name": "Léčení", "cost": 10, "heal": 45},
		{"name": "Světelný šíp", "cost": 8, "power": 1.6, "kind": "light"}]))
	return out


static func default_enemies() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	out.append(_foe("Slizák", 70, 16, 4, 8, Color(0.3, 0.8, 0.35), 3, ["fire", "sword", "wind"]))
	out.append(_foe("Vlk", 85, 20, 6, 14, Color(0.55, 0.5, 0.5), 4, ["axe", "lightning", "bow", "light"]))
	out.append(_foe("Slizák", 70, 16, 4, 7, Color(0.3, 0.8, 0.35), 3, ["ice", "staff", "dagger"]))
	return out


static func _foe(n: String, hp_: int, atk_: int, def_: int, spd_: int, col: Color, sh: int, weak_: Array) -> BattleUnit:
	var u := make(n, false, hp_, 0, atk_, def_, spd_, col)
	u.shield_max = sh
	u.weak = weak_
	u.reset()
	return u
