extends Node
## Autoload "Inventory": předměty, zlato, výbava a okno inventáře (klávesa I).
## ID předmětů a sloty odpovídají exportu z Dílny postav (items.json).

signal changed

const SLOTS := ["helma", "telo", "rukavice", "kalhoty", "boty", "zbran"]
const SLOT_NAMES := {"helma": "Helma", "telo": "Brnění", "rukavice": "Rukavice", "kalhoty": "Kalhoty", "boty": "Boty", "zbran": "Zbraň"}
var ITEMS: Dictionary = {}

var bag: Dictionary = {"paklic": 3}
var equip: Dictionary = {}
var gold := 25
var wlevel: Dictionary = {}  ## id zbraně -> stupeň vylepšení 0..5
var dura: Dictionary = {}   ## slot -> odolnost 0..100 (chybí = 100)
var _ui: CanvasLayer
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ITEMS = get_node("/root/GameData").items
	_ui = CanvasLayer.new()
	_ui.layer = 80
	_ui.visible = false
	add_child(_ui)


func consumables() -> Array:
	var out: Array = []
	for id in ITEMS:
		if count(id) > 0 and not ITEMS[id].get("use", {}).is_empty():
			out.append(id)
	return out


func dura_of(slot: String) -> float:
	return float(dura.get(slot, 100.0))


## 0 v pořádku, 1 poškozeno, 2 kriticky, 3 zničeno (kus odpadl, bonusy zmizely)
func dura_level(slot: String) -> int:
	if equip.get(slot) == null:
		return 0
	var d := dura_of(slot)
	if d <= 0.0:
		return 3
	if d < 30.0:
		return 2
	if d < 60.0:
		return 1
	return 0


func hurt_gear(ratio: float) -> String:
	## ratio = zasažené HP / max HP. Vrátí zprávu o nově poškozeném kusu ("" = nic).
	var worn: Array = []
	for s in SLOTS:
		if s != "zbran" and equip.get(s) != null and dura_of(s) > 0.0:
			worn.append(s)
	if worn.is_empty():
		return ""
	var slot: String = worn[randi() % worn.size()]
	var before := dura_level(slot)
	dura[slot] = maxf(0.0, dura_of(slot) - (4.0 + ratio * 70.0))
	var after := dura_level(slot)
	changed.emit()
	if after != before:
		var nm: String = ITEMS.get(equip[slot], {}).get("name", SLOT_NAMES[slot])
		return ["", "%s praskl(a)!" % nm, "%s se rozpadá!" % nm, "%s odpadl(a)!" % nm][after]
	return ""


func wear_weapon(amount: float) -> void:
	if equip.get("zbran") != null:
		dura["zbran"] = maxf(0.0, dura_of("zbran") - amount)


func repair_cost() -> int:
	var c := 0
	for s in SLOTS:
		if equip.get(s) != null:
			c += int(round((100.0 - dura_of(s)) * 0.6))
	return c


func repair_all() -> bool:
	var c := repair_cost()
	if c <= 0 or gold < c:
		return false
	gold -= c
	dura.clear()
	changed.emit()
	return true


func count(id: String) -> int:
	return int(bag.get(id, 0))


func add(id: String, n := 1) -> void:
	if id == "gold" or id == "zlato":
		gold += n
	else:
		bag[id] = count(id) + n
	changed.emit()


func remove(id: String, n := 1) -> void:
	bag[id] = maxi(count(id) - n, 0)
	if bag[id] == 0:
		bag.erase(id)
	changed.emit()


func toggle_equip(id: String) -> void:
	var it: Dictionary = ITEMS.get(id, {})
	var slot: String = it.get("slot", "")
	if slot == "":
		return
	equip[slot] = null if equip.get(slot) == id else id
	changed.emit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_I or ev.keycode == KEY_TAB):
		_toggle()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and _ui.visible:
		_toggle()


func _toggle() -> void:
	var d := get_node_or_null("/root/Dialogue")
	if not _ui.visible and d and d.active:
		return
	_ui.visible = not _ui.visible
	get_tree().paused = _ui.visible
	if _ui.visible:
		_build()


func _build() -> void:
	if _root:
		_root.queue_free()
	var ui := InventoryUI.new()
	_root = ui
	_ui.add_child(ui)
	ui.build(self)
