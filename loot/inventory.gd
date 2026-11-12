extends Node
## Autoload "Inventory": předměty, zlato, výbava a okno inventáře (klávesa I).
## ID předmětů a sloty odpovídají exportu z Dílny postav (items.json).

signal changed

const SLOTS := ["helma", "telo", "rukavice", "kalhoty", "boty", "zbran"]
const SLOT_NAMES := {"helma": "Helma", "telo": "Brnění", "rukavice": "Rukavice", "kalhoty": "Kalhoty", "boty": "Boty", "zbran": "Zbraň"}
const ITEMS := {
	"ozdobny_mec": {"name": "Ozdobný meč", "slot": "zbran", "atk": 9, "def": 0, "hp": 0, "price": 400, "icon": "res://items/ozdobny_mec.png", "desc": "Dlouhý meč s ozdobnou záštitou."},
	"zelezny_mec": {"name": "Železný meč", "slot": "zbran", "atk": 6, "def": 0, "hp": 0, "price": 120, "icon": "res://items/zelezny_mec.png", "desc": "Obyčejný spolehlivý meč."},
	"helma": {"name": "Rytířská přilba", "slot": "helma", "atk": 0, "def": 3, "hp": 10, "price": 150, "icon": "res://items/helma.png", "desc": "Uzavřená ocelová přilba."},
	"telo": {"name": "Plátový krunýř", "slot": "telo", "atk": 0, "def": 8, "hp": 25, "price": 420, "icon": "res://items/telo.png", "desc": "Ocelový hrudní plát s ramenicemi."},
	"boty": {"name": "Plátové holínky", "slot": "boty", "atk": 0, "def": 3, "hp": 5, "price": 160, "icon": "res://items/boty.png", "desc": "Vysoké ocelové boty."},
	"kalhoty": {"name": "Kalhoty s chrániči", "slot": "kalhoty", "atk": 0, "def": 4, "hp": 10, "price": 180, "icon": "res://items/kalhoty.png", "desc": "Tuhé kalhoty s chrániči kolen."},
	"rukavice": {"name": "Ocelové rukavice", "slot": "rukavice", "atk": 1, "def": 3, "hp": 0, "price": 140, "icon": "res://items/rukavice.png", "desc": "Těžké rukavice z oceli."},
	"paklic": {"name": "Paklíč", "slot": "", "atk": 0, "def": 0, "hp": 0, "price": 15, "icon": "", "desc": "Na páčení zámků."},
}

var bag: Dictionary = {"paklic": 5}
var equip: Dictionary = {}
var gold := 25
var _ui: CanvasLayer
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = CanvasLayer.new()
	_ui.layer = 80
	_ui.visible = false
	add_child(_ui)


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


func stats() -> Dictionary:
	var s := {"atk": 5, "def": 2, "hp": 40}
	for k in equip:
		if equip[k] != null:
			var it: Dictionary = ITEMS[equip[k]]
			for q in s:
				s[q] += int(it.get(q, 0))
	return s


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
	_root = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.95)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	_root.add_theme_stylebox_override("panel", sb)
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(720, 420)
	_root.offset_left = -360
	_root.offset_right = 360
	_root.offset_top = -210
	_root.offset_bottom = 210
	_ui.add_child(_root)
	var vb := VBoxContainer.new()
	_root.add_child(vb)
	var t := Label.new()
	var st := stats()
	t.text = "INVENTÁŘ     Zlato: %d     Útok %d · Obrana %d · Život %d     (I / Esc = zavřít)" % [gold, st.atk, st.def, st.hp]
	t.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vb.add_child(t)
	var eq := HBoxContainer.new()
	vb.add_child(eq)
	for s in SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 84)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var id = equip.get(s)
		b.text = SLOT_NAMES[s] if id == null else ITEMS[id].name
		if id != null and ITEMS[id].icon != "":
			b.icon = load(ITEMS[id].icon)
		b.pressed.connect(func(): equip[s] = null; changed.emit(); _build())
		eq.add_child(b)
	vb.add_child(HSeparator.new())
	var g := GridContainer.new()
	g.columns = 6
	vb.add_child(g)
	for id in bag:
		var it: Dictionary = ITEMS.get(id, {})
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 96)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var on: bool = it.get("slot", "") != "" and equip.get(it.slot) == id
		b.text = "%s%s%s" % [it.get("name", id), " ×%d" % bag[id] if bag[id] > 1 else "", "  ✔" if on else ""]
		b.tooltip_text = "%s\nÚtok %d · Obrana %d · Život %d" % [it.get("desc", ""), it.get("atk", 0), it.get("def", 0), it.get("hp", 0)]
		if it.get("icon", "") != "":
			b.icon = load(it.icon)
		b.pressed.connect(func(): toggle_equip(id); _build())
		g.add_child(b)
	var h := Label.new()
	h.text = "Klikni na předmět = obléct / sundat. Vzhled postavy se napojí po zapojení hrdiny z Dílny postav."
	h.add_theme_color_override("font_color", Color(0.7, 0.8, 1))
	vb.add_child(h)
