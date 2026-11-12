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
	out.append(make("Hrdina", true, 120, 30, 26, 9, 12, Color(0.25, 0.45, 0.9), [
		{"name": "Silný úder", "cost": 8, "power": 1.9},
		{"name": "Vír ostří", "cost": 14, "power": 1.1, "all": true}]))
	out.append(make("Léčitelka", true, 90, 40, 15, 6, 9, Color(0.9, 0.85, 0.95), [
		{"name": "Léčení", "cost": 10, "heal": 45},
		{"name": "Světelný šíp", "cost": 8, "power": 1.6}]))
	return out


static func default_enemies() -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	out.append(make("Slizák", false, 70, 0, 16, 4, 8, Color(0.3, 0.8, 0.35)))
	out.append(make("Vlk", false, 85, 0, 20, 6, 14, Color(0.55, 0.5, 0.5)))
	out.append(make("Slizák", false, 70, 0, 16, 4, 7, Color(0.3, 0.8, 0.35)))
	return out
