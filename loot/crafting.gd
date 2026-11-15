class_name Crafting
extends RefCounted
## Vaření (u ohniště) a vylepšování zbraní (u kováře).

const RECIPES := [
	{"id": "gulas", "ing": {"maso": 1, "koreni": 1, "bylina": 1}},
	{"id": "ryb_polevka", "ing": {"ryba": 2, "koreni": 1}},
	{"id": "houbova_panev", "ing": {"houba": 2, "koreni": 1}},
	{"id": "bylinny_caj", "ing": {"bylina": 2}},
	{"id": "zele_dezert", "ing": {"zele": 2, "koreni": 1}},
]
const MAX_UPGRADE := 5


static func _inv() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Inventory")


static func can_cook(r: Dictionary) -> bool:
	for k in r.ing:
		if _inv().count(k) < int(r.ing[k]):
			return false
	return true


static func cook(r: Dictionary) -> bool:
	if not can_cook(r):
		return false
	for k in r.ing:
		_inv().remove(k, int(r.ing[k]))
	_inv().add(r.id, 1)
	return true


static func near_fire(pl: Node3D) -> bool:
	if pl == null:
		return false
	for n in pl.get_tree().get_nodes_in_group("ohniste"):
		if (n as Node3D).global_position.distance_to(pl.global_position) < 4.5:
			return true
	return false


## Cena dalšího stupně vylepšení aktuální zbraně ({} = nejde).
static func upgrade_info() -> Dictionary:
	var inv := _inv()
	var id = inv.equip.get("zbran")
	if id == null:
		return {}
	var lv: int = int(inv.wlevel.get(id, 0))
	if lv >= MAX_UPGRADE:
		return {"id": id, "level": lv, "max": true}
	var n := lv + 1
	var cost := {"gold": 80 * n, "ruda": n}
	if n >= 3:
		cost["kost"] = n - 1
	var ok: bool = inv.gold >= int(cost.gold)
	for k in cost:
		if k != "gold" and inv.count(k) < int(cost[k]):
			ok = false
	return {"id": id, "level": lv, "cost": cost, "ok": ok}


static func upgrade() -> bool:
	var info := upgrade_info()
	if info.is_empty() or info.get("max", false) or not info.ok:
		return false
	var inv := _inv()
	for k in info.cost:
		if k == "gold":
			inv.gold -= int(info.cost[k])
		else:
			inv.remove(k, int(info.cost[k]))
	inv.wlevel[info.id] = int(info.level) + 1
	inv.changed.emit()
	return true
