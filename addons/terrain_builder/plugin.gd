@tool
extends EditorPlugin

const AUTOLOADS := {
	"SceneManager": "res://addons/terrain_builder/scene_manager.gd",
	"Dialogue": "res://addons/terrain_builder/dialogue_box.gd",
}
const PROPS_DIR := "res://props"
const MODES := ["Zvednout / snížit", "Nastavit výšku", "Obdélník (výška)", "Hora", "Schody (rampa)", "Malovat materiál", "Guma"]
const MODE_HINTS := [
	"LMB: zvednout o úroveň (prázdno = nová plocha)\nShift+LMB: snížit\nTáhni = maluj víc políček",
	"LMB: nastaví políčka na hodnotu „Výška“\nTáhni = maluj",
	"Táhni obdélník a pusť: vyplní ho výškou „Výška“\nShift = obdélník smaže",
	"LMB: vytvoří stupňovitou horu\nŠtětec = šířka (liché číslo), Výška = vrchol",
	"LMB: udělá z políčka rampu/schody\nR = otočit směr, Shift+LMB = zrušit rampu",
	"LMB: přemaluje vybraný materiál (výška se nemění)",
	"LMB: maže políčka",
]
const SLOPE_ORDER := [1, 3, 2, 4]
const SLOPE_NAMES := {1: "vpravo", 2: "vlevo", 3: "dolů (k hráči)", 4: "nahoru (dál)"}

var map: TerrainMap
var dock: VBoxContainer
var boxes: Array[Control] = []
var tool_btns: Array[Button] = []
var hint_lbl: Label
var new_dlg: ConfirmationDialog
var new_name: LineEdit
var file_dialog: EditorFileDialog
# terén
var mode_opt: OptionButton
var brush_spin: SpinBox
var level_spin: SpinBox
var rough_chk: CheckBox
var slope_lbl: Label
var mat_list: ItemList
var mat_name_edit: LineEdit
# objekty
var filter_edit: LineEdit
var prop_list: ItemList
var snap_opt: OptionButton
var rot_spin: SpinBox
var rand_chk: CheckBox
var scale_spin: SpinBox
var col_chk: CheckBox
var all_props: Array[String] = []
var thumbs := {}
# vegetace
var veg_opt: OptionButton
var radius_spin: SpinBox
var density_spin: SpinBox
# značky
var mark_opt: OptionButton
var mark_name: LineEdit
var exit_box: VBoxContainer
var npc_box: VBoxContainer
var scene_edit: LineEdit
var spawn_edit: LineEdit
var width_spin: SpinBox
var npc_text: LineEdit
var npc_tex: LineEdit

var cursor: MeshInstance3D
var ghost: Node3D
var ghost_path := ""

var cur_tool := 0
var mode := 0
var brush := 1
var level := 0
var mat := 0
var slope_i := 0
var prop_path := ""
var veg_radius := 2.0
var veg_density := 6.0

var painting := false
var stroke := {}
var stroke_mode := 0
var stroke_lower := false
var old_data := PackedInt32Array()
var rect_start := Vector2i.ZERO
var last_cell := Vector2i.ZERO
var veg_layer: VegetationLayer
var old_veg := PackedFloat32Array()
var last_pos := Vector3.ZERO


# ================= životní cyklus =================
func _enter_tree() -> void:
	for k in AUTOLOADS:
		if not ProjectSettings.has_setting("autoload/" + k):
			add_autoload_singleton(k, AUTOLOADS[k])
	_ensure_library()
	_build_dialogs()
	_build_dock()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, dock)
	dock.visible = false
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_scan_props)
	_scan_props()


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs and fs.filesystem_changed.is_connected(_scan_props):
		fs.filesystem_changed.disconnect(_scan_props)
	_free_cursor()
	_free_ghost()
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, dock)
	dock.queue_free()
	new_dlg.queue_free()
	if file_dialog:
		file_dialog.queue_free()


func _disable_plugin() -> void:
	for k in AUTOLOADS:
		remove_autoload_singleton(k)


func _handles(o: Object) -> bool:
	return o is TerrainMap


func _edit(o: Object) -> void:
	_free_cursor()
	_free_ghost()
	map = o as TerrainMap
	if map:
		_refresh_all()


func _make_visible(v: bool) -> void:
	dock.visible = v
	if not v:
		_free_cursor()
		_free_ghost()


func _ensure_library() -> void:
	if Lib.list(TerrainMap.MAT_DIR).is_empty():
		for d in [["Tráva", Color(0.42, 0.62, 0.3)], ["Hlína", Color(0.55, 0.4, 0.27)],
				["Kámen", Color(0.55, 0.55, 0.58)], ["Písek", Color(0.84, 0.77, 0.55)]]:
			var m := TerrainMat.new()
			m.mat_name = d[0]
			m.color = d[1]
			Lib.save_new(TerrainMap.MAT_DIR, m)
	if Lib.list(VegetationLayer.VEG_DIR).is_empty():
		for n in ["Tráva", "Květiny", "Keř"]:
			var t := VegType.new()
			t.veg_name = n
			Lib.save_new(VegetationLayer.VEG_DIR, t)


# ================= UI =================
func _build_dialogs() -> void:
	new_dlg = ConfirmationDialog.new()
	new_dlg.title = "Nová lokace"
	new_dlg.ok_button_text = "Vytvořit"
	var vb := VBoxContainer.new()
	var l := Label.new()
	l.text = "Jméno lokace (např. vesnice):"
	vb.add_child(l)
	new_name = LineEdit.new()
	new_name.custom_minimum_size = Vector2(260, 0)
	vb.add_child(new_name)
	new_dlg.add_child(vb)
	new_dlg.confirmed.connect(func(): _new_location(new_name.text))
	EditorInterface.get_base_control().add_child(new_dlg)


func _build_dock() -> void:
	dock = VBoxContainer.new()
	dock.custom_minimum_size = Vector2(250, 0)
	var top := HBoxContainer.new()
	top.add_child(_btn("Hrát", func(): EditorInterface.play_current_scene()))
	top.add_child(_btn("Uložit", func(): EditorInterface.save_scene()))
	top.add_child(_btn("+ Lokace", func(): new_dlg.popup_centered()))
	dock.add_child(top)
	var tb := HBoxContainer.new()
	var grp := ButtonGroup.new()
	var names := ["Terén", "Objekty", "Tráva", "Značky"]
	for i in 4:
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = grp
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(_on_tool_toggled.bind(i))
		tb.add_child(b)
		tool_btns.append(b)
	dock.add_child(tb)

	# --- terén ---
	var t := VBoxContainer.new()
	mode_opt = OptionButton.new()
	for s in MODES:
		mode_opt.add_item(s)
	mode_opt.item_selected.connect(_on_mode)
	t.add_child(_row("Nástroj", mode_opt))
	brush_spin = _spin(1, 25, 1, 1, func(v): brush = int(v))
	t.add_child(_row("Štětec", brush_spin))
	level_spin = _spin(0, 60, 1, 0, func(v): level = int(v))
	t.add_child(_row("Výška", level_spin))
	rough_chk = CheckBox.new()
	rough_chk.text = "Nerovná hora"
	t.add_child(rough_chk)
	var sr := HBoxContainer.new()
	slope_lbl = Label.new()
	slope_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr.add_child(slope_lbl)
	sr.add_child(_btn("Otočit (R)", _rotate_slope))
	t.add_child(sr)
	t.add_child(_title("Materiály"))
	mat_list = ItemList.new()
	mat_list.custom_minimum_size = Vector2(0, 120)
	mat_list.fixed_icon_size = Vector2i(24, 24)
	mat_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mat_list.item_selected.connect(_on_mat_selected)
	t.add_child(mat_list)
	mat_name_edit = LineEdit.new()
	mat_name_edit.placeholder_text = "Jméno materiálu (Enter)"
	mat_name_edit.text_submitted.connect(_on_mat_renamed)
	t.add_child(mat_name_edit)
	var mr := HBoxContainer.new()
	mr.add_child(_btn("+ Nový", _new_mat))
	mr.add_child(_btn("Vršek…", _mat_tex.bind(false)))
	mr.add_child(_btn("Stěna…", _mat_tex.bind(true)))
	t.add_child(mr)
	t.add_child(_btn("Načíst materiály z knihovny", _load_mat_lib))
	dock.add_child(t)
	boxes.append(t)

	# --- objekty ---
	var p := VBoxContainer.new()
	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = "Hledat objekt…"
	filter_edit.text_changed.connect(func(_s): _fill_props())
	p.add_child(filter_edit)
	prop_list = ItemList.new()
	prop_list.custom_minimum_size = Vector2(0, 230)
	prop_list.select_mode = ItemList.SELECT_MULTI
	prop_list.icon_mode = ItemList.ICON_MODE_TOP
	prop_list.fixed_icon_size = Vector2i(56, 56)
	prop_list.max_columns = 0
	prop_list.same_column_width = true
	prop_list.max_text_lines = 2
	prop_list.multi_selected.connect(func(_i, _s): _roll_prop())
	p.add_child(prop_list)
	snap_opt = OptionButton.new()
	for s in ["Volně", "0,5 m", "1 m (střed dlaždice)"]:
		snap_opt.add_item(s)
	snap_opt.select(1)
	p.add_child(_row("Přichyt", snap_opt))
	rot_spin = _spin(0, 360, 45, 0, func(_v): pass)
	p.add_child(_row("Rotace", rot_spin))
	rand_chk = CheckBox.new()
	rand_chk.text = "Náhodná rotace"
	p.add_child(rand_chk)
	scale_spin = _spin(0, 50, 5, 0, func(_v): pass)
	p.add_child(_row("Velikost ±%", scale_spin))
	col_chk = CheckBox.new()
	col_chk.text = "Auto kolize (kvádr)"
	col_chk.button_pressed = true
	p.add_child(col_chk)
	p.add_child(_btn("Obnovit seznam", _scan_props))
	dock.add_child(p)
	boxes.append(p)

	# --- vegetace ---
	var v := VBoxContainer.new()
	veg_opt = OptionButton.new()
	v.add_child(_row("Druh", veg_opt))
	radius_spin = _spin(0.5, 10, 0.5, 2, func(x): veg_radius = x)
	v.add_child(_row("Poloměr", radius_spin))
	v.add_child(_row("Hustota", _spin(1, 40, 1, 6, func(x): veg_density = x)))
	var vr := HBoxContainer.new()
	vr.add_child(_btn("+ Druh", _new_veg))
	vr.add_child(_btn("Textura…", _veg_tex))
	v.add_child(vr)
	v.add_child(_btn("Načíst druhy z knihovny", _load_veg_lib))
	dock.add_child(v)
	boxes.append(v)

	# --- značky ---
	var m := VBoxContainer.new()
	mark_opt = OptionButton.new()
	for s in ["Východ do jiné scény", "Spawn (místo příchodu)", "NPC"]:
		mark_opt.add_item(s)
	mark_opt.item_selected.connect(func(_i): _update_mark_ui())
	m.add_child(mark_opt)
	mark_name = LineEdit.new()
	mark_name.text = "Start"
	mark_name.placeholder_text = "Jméno"
	m.add_child(_row("Jméno", mark_name))
	exit_box = VBoxContainer.new()
	scene_edit = LineEdit.new()
	scene_edit.placeholder_text = "res://scenes/les.tscn"
	var sr2 := HBoxContainer.new()
	scene_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr2.add_child(scene_edit)
	sr2.add_child(_btn("…", _browse.bind(PackedStringArray(["*.tscn"]), _on_scene_picked)))
	exit_box.add_child(_row("Cíl", sr2))
	spawn_edit = LineEdit.new()
	spawn_edit.text = "Start"
	exit_box.add_child(_row("Spawn v cíli", spawn_edit))
	width_spin = _spin(1, 16, 1, 3, func(_v): pass)
	exit_box.add_child(_row("Šířka (m)", width_spin))
	m.add_child(exit_box)
	npc_box = VBoxContainer.new()
	npc_text = LineEdit.new()
	npc_text.text = "Ahoj, cestovateli!|Hezký den, že?"
	npc_box.add_child(_row("Text", npc_text))
	npc_tex = LineEdit.new()
	npc_tex.placeholder_text = "textura postavy (64x64)"
	var tr := HBoxContainer.new()
	npc_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(npc_tex)
	tr.add_child(_btn("…", _browse.bind(PackedStringArray(["*.png,*.webp"]), _on_npc_tex_picked)))
	npc_box.add_child(_row("Sprite", tr))
	m.add_child(npc_box)
	dock.add_child(m)
	boxes.append(m)

	hint_lbl = Label.new()
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	dock.add_child(hint_lbl)
	tool_btns[0].button_pressed = true
	_update_mark_ui()
	_on_tool(0)


func _on_mode(i: int) -> void:
	mode = i
	_update_hint()


func _on_tool_toggled(on: bool, i: int) -> void:
	if on:
		_on_tool(i)


func _on_tool(i: int) -> void:
	cur_tool = i
	for k in boxes.size():
		boxes[k].visible = (k == i)
	_free_ghost()
	_update_hint()


func _update_hint() -> void:
	slope_lbl.text = "Rampa klesá: " + SLOPE_NAMES[SLOPE_ORDER[slope_i]]
	match cur_tool:
		0:
			hint_lbl.text = MODE_HINTS[mode] + "\nCtrl+LMB: přemalovat materiál\n[ ] = velikost štětce"
		1:
			hint_lbl.text = "LMB: položit · Shift+LMB: smazat nejbližší\nR / Shift+R: otočit · Vyber víc objektů (Ctrl+klik) = náhodný výběr\nSoubory .glb dej do res://props/"
		2:
			hint_lbl.text = "LMB: malovat · Shift+LMB: mazat\n[ ] = velikost štětce"
		3:
			hint_lbl.text = "LMB: položit značku · Shift+LMB: smazat\nVýchod: vyber cílovou scénu a spawn v ní. R otočí východ.\nNPC: věty odděluj znakem |"


func _update_mark_ui() -> void:
	exit_box.visible = mark_opt.selected == 0
	npc_box.visible = mark_opt.selected == 2
	if mark_opt.selected == 2 and mark_name.text == "Start":
		mark_name.text = "Vesničan"
	elif mark_opt.selected != 2 and mark_name.text == "Vesničan":
		mark_name.text = "Start"


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	return l


func _spin(mn: float, mx: float, step: float, val: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.value_changed.connect(cb)
	return s


func _row(text: String, c: Control) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var lb := Label.new()
	lb.text = text
	lb.custom_minimum_size = Vector2(78, 0)
	hb.add_child(lb)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(c)
	return hb


# ================= dialog souboru =================
func _browse(filters: PackedStringArray, cb: Callable) -> void:
	if file_dialog == null:
		file_dialog = EditorFileDialog.new()
		file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		EditorInterface.get_base_control().add_child(file_dialog)
	file_dialog.clear_filters()
	for f in filters:
		file_dialog.add_filter(f)
	for c in file_dialog.file_selected.get_connections():
		file_dialog.file_selected.disconnect(c["callable"])
	file_dialog.file_selected.connect(cb, CONNECT_ONE_SHOT)
	file_dialog.popup_centered_ratio(0.6)


func _on_scene_picked(path: String) -> void:
	scene_edit.text = path


func _on_npc_tex_picked(path: String) -> void:
	npc_tex.text = path


func _save_res(r: Resource) -> void:
	if r and r.resource_path != "" and not r.resource_path.contains("::"):
		ResourceSaver.save(r, r.resource_path)


func _set_prop_undo(obj: Object, prop: String, val: Variant, label: String) -> void:
	var ur := get_undo_redo()
	ur.create_action(label, UndoRedo.MERGE_DISABLE, map)
	ur.add_do_property(obj, prop, val)
	ur.add_undo_property(obj, prop, obj.get(prop))
	ur.commit_action()


# ================= materiály =================
func _refresh_all() -> void:
	_refresh_mats()
	_refresh_veg()
	_scan_props()
	_update_hint()


func _mat_icon(m: TerrainMat) -> Texture2D:
	if m and m.top_texture:
		return m.top_texture
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(m.color if m else Color.GRAY)
	return ImageTexture.create_from_image(img)


func _refresh_mats() -> void:
	mat_list.clear()
	if map == null:
		return
	for i in map.materials.size():
		var m := map.materials[i]
		mat_list.add_item(m.mat_name if m else str(i), _mat_icon(m))
	mat = clampi(mat, 0, maxi(map.materials.size() - 1, 0))
	if mat_list.item_count > 0:
		mat_list.select(mat)
		mat_name_edit.text = map.materials[mat].mat_name if map.materials[mat] else ""


func _on_mat_selected(i: int) -> void:
	mat = i
	if map and i < map.materials.size() and map.materials[i]:
		mat_name_edit.text = map.materials[i].mat_name


func _on_mat_renamed(txt: String) -> void:
	if map == null or mat >= map.materials.size():
		return
	var m := map.materials[mat]
	_set_prop_undo(m, "mat_name", txt, "Jméno materiálu")
	_save_res(m)
	_refresh_mats()


func _new_mat() -> void:
	if map == null:
		return
	var m := TerrainMat.new()
	m.mat_name = "Materiál %d" % (map.materials.size() + 1)
	m.color = Color.from_hsv(randf(), 0.4, 0.75)
	Lib.save_new(TerrainMap.MAT_DIR, m)
	var old: Array[TerrainMat] = []
	old.assign(map.materials)
	var arr: Array[TerrainMat] = []
	arr.assign(map.materials)
	arr.append(m)
	var ur := get_undo_redo()
	ur.create_action("Nový materiál", UndoRedo.MERGE_DISABLE, map)
	ur.add_do_property(map, "materials", arr)
	ur.add_undo_property(map, "materials", old)
	ur.commit_action()
	mat = arr.size() - 1
	_refresh_mats()


func _mat_tex(side: bool) -> void:
	if map == null or map.materials.is_empty():
		return
	_browse(PackedStringArray(["*.png,*.webp,*.jpg"]), _on_mat_tex_picked.bind(side))


func _on_mat_tex_picked(path: String, side: bool) -> void:
	var tex := load(path) as Texture2D
	if tex == null or map == null or mat >= map.materials.size():
		return
	var m := map.materials[mat]
	var ur := get_undo_redo()
	ur.create_action("Textura materiálu", UndoRedo.MERGE_DISABLE, map)
	var prop := "side_texture" if side else "top_texture"
	ur.add_do_property(m, prop, tex)
	ur.add_undo_property(m, prop, m.get(prop))
	if not side:
		ur.add_do_property(m, "color", Color.WHITE)
		ur.add_undo_property(m, "color", m.color)
	ur.commit_action()
	_save_res(m)
	_refresh_mats()


func _load_mat_lib() -> void:
	if map == null:
		return
	var arr: Array[TerrainMat] = []
	for r in Lib.list(TerrainMap.MAT_DIR):
		if r is TerrainMat:
			arr.append(r)
	if arr.is_empty():
		return
	var old: Array[TerrainMat] = []
	old.assign(map.materials)
	var ur := get_undo_redo()
	ur.create_action("Materiály z knihovny", UndoRedo.MERGE_DISABLE, map)
	ur.add_do_property(map, "materials", arr)
	ur.add_undo_property(map, "materials", old)
	ur.commit_action()
	_refresh_mats()


# ================= vegetace (druhy) =================
func _veg_layer() -> VegetationLayer:
	return _layer("Vegetation", VegetationLayer) as VegetationLayer


func _refresh_veg() -> void:
	var keep := maxi(veg_opt.selected, 0)
	veg_opt.clear()
	var names: Array = ["Tráva", "Květiny", "Keř"]
	if map:
		var l := map.get_node_or_null("Vegetation") as VegetationLayer
		if l and not l.types.is_empty():
			names = l.types.map(func(x): return x.veg_name if x else "?")
	for n in names:
		veg_opt.add_item(n)
	veg_opt.select(clampi(keep, 0, veg_opt.item_count - 1))


func _new_veg() -> void:
	if map == null:
		return
	var l := _veg_layer()
	var t := VegType.new()
	t.veg_name = "Druh %d" % (l.types.size() + 1)
	Lib.save_new(VegetationLayer.VEG_DIR, t)
	var old: Array[VegType] = []
	old.assign(l.types)
	var arr: Array[VegType] = []
	arr.assign(l.types)
	arr.append(t)
	var ur := get_undo_redo()
	ur.create_action("Nový druh vegetace", UndoRedo.MERGE_DISABLE, map)
	ur.add_do_property(l, "types", arr)
	ur.add_undo_property(l, "types", old)
	ur.commit_action()
	_refresh_veg()
	veg_opt.select(arr.size() - 1)


func _veg_tex() -> void:
	if map == null:
		return
	_browse(PackedStringArray(["*.png,*.webp"]), _on_veg_tex_picked)


func _on_veg_tex_picked(path: String) -> void:
	var tex := load(path) as Texture2D
	var l := _veg_layer()
	var i := maxi(veg_opt.selected, 0)
	if tex == null or i >= l.types.size():
		return
	var t := l.types[i]
	_set_prop_undo(t, "texture", tex, "Textura vegetace")
	_save_res(t)
	l.rebuild()


func _load_veg_lib() -> void:
	if map == null:
		return
	var l := _veg_layer()
	var arr: Array[VegType] = []
	for r in Lib.list(VegetationLayer.VEG_DIR):
		if r is VegType:
			arr.append(r)
	if not arr.is_empty():
		l.types = arr
	_refresh_veg()


# ================= objekty (paleta) =================
func _scan_props() -> void:
	if prop_list == null:
		return
	DirAccess.make_dir_recursive_absolute(PROPS_DIR)
	all_props.clear()
	_scan_dir(PROPS_DIR)
	_fill_props()


func _scan_dir(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for dn in d.get_directories():
		_scan_dir(p.path_join(dn))
	for f in d.get_files():
		if f.get_extension().to_lower() in ["glb", "gltf", "tscn", "scn"]:
			all_props.append(p.path_join(f))


func _tk(p: String) -> String:
	return "%s@%d" % [p, FileAccess.get_modified_time(p)]


func _fill_props() -> void:
	var keep: Array[String] = []
	for i in prop_list.get_selected_items():
		keep.append(prop_list.get_item_metadata(i))
	prop_list.clear()
	var f := filter_edit.text.strip_edges()
	var rp := EditorInterface.get_resource_previewer()
	for p in all_props:
		var nm := p.get_file().get_basename()
		if f != "" and not nm.containsn(f):
			continue
		var i := prop_list.add_item(nm, thumbs.get(_tk(p), null))
		prop_list.set_item_metadata(i, p)
		if p in keep:
			prop_list.select(i, false)
		if not thumbs.has(_tk(p)):
			rp.queue_resource_preview(p, self, "_on_preview", p)
	_roll_prop()


func _on_preview(path: String, preview: Texture2D, _thumb: Texture2D, _ud: Variant) -> void:
	if preview == null:
		return
	thumbs[_tk(path)] = preview
	for i in prop_list.item_count:
		if prop_list.get_item_metadata(i) == path:
			prop_list.set_item_icon(i, preview)


func _roll_prop() -> void:
	var sel := prop_list.get_selected_items()
	if sel.is_empty():
		prop_path = ""
		return
	prop_path = prop_list.get_item_metadata(sel[randi() % sel.size()])


# ================= vstup =================
func _rotate_slope() -> void:
	slope_i = (slope_i + 1) % SLOPE_ORDER.size()
	_update_hint()


func _forward_3d_gui_input(cam: Camera3D, ev: InputEvent) -> int:
	if map == null or not is_instance_valid(map):
		return AFTER_GUI_INPUT_PASS
	if ev is InputEventKey:
		return _on_key(ev)
	if ev is InputEventMouseMotion:
		var hit := _pick(cam, ev.position)
		_update_cursor(hit)
		if cur_tool == 1:
			_update_ghost(hit)
		if hit.ok:
			last_cell = hit.cell
		if painting and hit.ok:
			if cur_tool == 2:
				if Vector2(hit.pos.x - last_pos.x, hit.pos.z - last_pos.z).length() > veg_radius * 0.35:
					_apply_veg(hit.pos)
			elif cur_tool == 0 and stroke_mode != 2 and stroke_mode != 3:
				_apply(hit.cell)
		return AFTER_GUI_INPUT_STOP if painting else AFTER_GUI_INPUT_PASS
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and not ev.alt_pressed:
			var hit := _pick(cam, ev.position)
			if not hit.ok:
				return AFTER_GUI_INPUT_PASS
			match cur_tool:
				1:
					_prop_click(hit, ev.shift_pressed)
					return AFTER_GUI_INPUT_STOP
				3:
					_mark_click(hit, ev.shift_pressed)
					return AFTER_GUI_INPUT_STOP
			painting = true
			stroke_lower = ev.shift_pressed
			last_pos = hit.pos
			if cur_tool == 2:
				veg_layer = _veg_layer()
				old_veg = veg_layer.data.duplicate()
				_apply_veg(hit.pos)
			else:
				stroke.clear()
				old_data = map.pack()
				stroke_mode = 5 if ev.ctrl_pressed else _terrain_mode()
				rect_start = hit.cell
				last_cell = hit.cell
				if stroke_mode == 3:
					map.mountain(hit.cell, brush, level, rough_chk.button_pressed, mat)
					map.rebuild()
				elif stroke_mode != 2:
					_apply(hit.cell)
			return AFTER_GUI_INPUT_STOP
		if not ev.pressed and painting:
			painting = false
			if cur_tool == 2:
				_commit_veg()
			else:
				if stroke_mode == 2:
					map.fill_rect(rect_start, last_cell, level, mat, stroke_lower)
					map.rebuild()
				_commit()
			return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


# mapování nabídky na interní režimy: 0 zvednout, 1 výška, 2 obdélník, 3 hora, 4 rampa, 5 malovat, 6 guma
func _terrain_mode() -> int:
	return mode


func _on_key(ev: InputEventKey) -> int:
	if not ev.pressed or ev.echo or ev.ctrl_pressed or ev.alt_pressed:
		return AFTER_GUI_INPUT_PASS
	match ev.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			tool_btns[ev.keycode - KEY_1].button_pressed = true
			return AFTER_GUI_INPUT_STOP
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var s := -1 if ev.keycode == KEY_BRACKETLEFT else 1
			if cur_tool == 2:
				radius_spin.value += 0.5 * s
			else:
				brush_spin.value += s
			return AFTER_GUI_INPUT_STOP
		KEY_R:
			if cur_tool == 1 or cur_tool == 3:
				rot_spin.value = fposmod(rot_spin.value + (-45.0 if ev.shift_pressed else 45.0), 360.0)
				return AFTER_GUI_INPUT_STOP
			if cur_tool == 0 and mode == 4:
				_rotate_slope()
				return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _pick(cam: Camera3D, pos: Vector2) -> Dictionary:
	var inv := map.global_transform.affine_inverse()
	var o: Vector3 = inv * cam.project_ray_origin(pos)
	var d: Vector3 = (inv.basis * cam.project_ray_normal(pos)).normalized()
	var t := 0.0
	while t < 300.0:
		var p := o + d * t
		var h := map.height_at(p.x, p.z)
		if not is_inf(h):
			if p.y <= h:
				return {"ok": true, "cell": Vector2i(floori(p.x), floori(p.z)), "y": h, "pos": Vector3(p.x, h, p.z)}
		elif p.y <= 0.0:
			# paprsek dopadl na rovinu y = 0 nad prázdným místem -> nová dlaždice přesně pod kurzorem
			if absf(d.y) > 0.0001 and o.y > 0.0:
				p = o + d * (-o.y / d.y)
			return {"ok": true, "cell": Vector2i(floori(p.x), floori(p.z)), "y": 0.0, "pos": Vector3(p.x, 0.0, p.z)}
		t += 0.1
	return {"ok": false}


# ================= terén =================
func _apply(center: Vector2i) -> void:
	var s := (brush - 1) >> 1
	for i in brush:
		for j in brush:
			var c := center + Vector2i(i - s, j - s)
			if stroke.has(c):
				continue
			stroke[c] = true
			match stroke_mode:
				0: map.raise(c, -1 if stroke_lower else 1, mat)
				1: map.set_level(c, level, mat)
				4: map.set_slope(c, 0 if stroke_lower else SLOPE_ORDER[slope_i], level, mat)
				5: map.paint(c, mat)
				6: map.erase(c)
	map.rebuild()


func _commit() -> void:
	var nd := map.pack()
	if nd == old_data:
		return
	var ur := get_undo_redo()
	ur.create_action("Úprava terénu", UndoRedo.MERGE_DISABLE, map)
	ur.add_do_property(map, "data", nd)
	ur.add_undo_property(map, "data", old_data)
	ur.commit_action()


# ================= vegetace (malování) =================
func _apply_veg(pos: Vector3) -> void:
	last_pos = pos
	if stroke_lower:
		veg_layer.erase_in(pos, veg_radius)
	else:
		veg_layer.scatter(pos, veg_radius, veg_density, maxi(veg_opt.selected, 0))


func _commit_veg() -> void:
	var nd := veg_layer.data.duplicate()
	if nd == old_veg:
		return
	var ur := get_undo_redo()
	ur.create_action("Vegetace", UndoRedo.MERGE_DISABLE, map)
	ur.add_do_property(veg_layer, "data", nd)
	ur.add_undo_property(veg_layer, "data", old_veg)
	ur.commit_action()


# ================= vrstvy, objekty, značky =================
func _layer(n: String, script: Variant) -> Node3D:
	var l := map.get_node_or_null(n) as Node3D
	if l == null:
		l = script.new() if script is GDScript else Node3D.new()
		l.name = n
		map.add_child(l)
		l.owner = EditorInterface.get_edited_scene_root()
	return l


func _snap(p: Vector3) -> Vector3:
	var s: float = [0.0, 0.5, 1.0][snap_opt.selected]
	if s > 0.0:
		p.x = floorf(p.x / s) * s + s * 0.5
		p.z = floorf(p.z / s) * s + s * 0.5
	return p


func _add_node(layer: Node, n: Node, label: String) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var ur := get_undo_redo()
	ur.create_action(label, UndoRedo.MERGE_DISABLE, map)
	ur.add_do_method(layer, "add_child", n, true)
	ur.add_do_method(n, "set_owner", root)
	ur.add_do_reference(n)
	ur.add_undo_method(layer, "remove_child", n)
	ur.commit_action()


func _remove_nearest(layer_name: String, pos: Vector3, radius: float) -> void:
	var layer := map.get_node_or_null(layer_name)
	if layer == null:
		return
	var best: Node3D = null
	var bd := radius
	for c in layer.get_children():
		if c is Node3D:
			var d := Vector2(c.position.x - pos.x, c.position.z - pos.z).length()
			if d < bd:
				bd = d
				best = c
	if best == null:
		return
	var root := EditorInterface.get_edited_scene_root()
	var ur := get_undo_redo()
	ur.create_action("Smazat", UndoRedo.MERGE_DISABLE, map)
	ur.add_do_method(layer, "remove_child", best)
	ur.add_undo_method(layer, "add_child", best, true)
	ur.add_undo_method(best, "set_owner", root)
	ur.add_undo_reference(best)
	ur.commit_action()


func _prop_click(hit: Dictionary, remove: bool) -> void:
	if remove:
		_remove_nearest("Props", hit.pos, 1.2)
		return
	if prop_path == "":
		return
	var ps := load(prop_path) as PackedScene
	if ps == null:
		return
	var n := ps.instantiate() as Node3D
	if n == null:
		return
	n.position = _snap(hit.pos)
	n.rotation_degrees.y = (randf() * 360.0) if rand_chk.button_pressed else rot_spin.value
	if scale_spin.value > 0.0:
		n.scale = Vector3.ONE * (1.0 + randf_range(-scale_spin.value, scale_spin.value) / 100.0)
	if col_chk.button_pressed:
		n.set_meta("auto_col", true)
	_add_node(_layer("Props", PropLayer), n, "Přidat objekt")
	_roll_prop()


func _mark_click(hit: Dictionary, remove: bool) -> void:
	if remove:
		_remove_nearest("Marks", hit.pos, 1.6)
		return
	var pos := Vector3(floorf(hit.pos.x) + 0.5, hit.y, floorf(hit.pos.z) + 0.5)
	var nm := mark_name.text.strip_edges().validate_node_name()
	var n: Node3D
	match mark_opt.selected:
		0:
			var e := SceneExit.new()
			e.target_scene = scene_edit.text.strip_edges()
			e.target_spawn = spawn_edit.text.strip_edges()
			e.size = Vector3(width_spin.value, 2.5, 1.0)
			e.rotation_degrees.y = rot_spin.value
			n = e
			nm = "Vychod_" + e.target_scene.get_file().get_basename()
		1:
			n = Marker3D.new()
		2:
			var c := NPC3D.new()
			c.speaker = mark_name.text.strip_edges()
			c.lines = npc_text.text
			if npc_tex.text != "":
				c.texture = load(npc_tex.text) as Texture2D
			n = c
			nm = "NPC_" + nm
	n.name = nm if nm != "" else "Znacka"
	n.position = pos
	_add_node(_layer("Marks", null), n, "Přidat značku")


func _update_ghost(hit: Dictionary) -> void:
	if prop_path == "" or not hit.ok:
		if ghost and is_instance_valid(ghost):
			ghost.visible = false
		return
	if ghost == null or not is_instance_valid(ghost) or ghost_path != prop_path:
		_free_ghost()
		var ps := load(prop_path) as PackedScene
		if ps == null:
			return
		ghost = ps.instantiate() as Node3D
		if ghost == null:
			return
		ghost.name = "_Ghost"
		map.add_child(ghost)
		ghost_path = prop_path
	ghost.visible = true
	ghost.position = _snap(hit.pos)
	ghost.rotation_degrees.y = rot_spin.value


func _free_ghost() -> void:
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	ghost_path = ""


# ================= kurzor =================
func _update_cursor(hit: Dictionary) -> void:
	if cursor == null or not is_instance_valid(cursor):
		cursor = MeshInstance3D.new()
		cursor.name = "_Cursor"
		cursor.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.4)
		cursor.material_override = m
		map.add_child(cursor)
	cursor.visible = hit.ok
	if not hit.ok:
		return
	var bm := cursor.mesh as BoxMesh
	if cur_tool == 0:
		if painting and stroke_mode == 2:
			var a := Vector2i(mini(rect_start.x, hit.cell.x), mini(rect_start.y, hit.cell.y))
			var b := Vector2i(maxi(rect_start.x, hit.cell.x), maxi(rect_start.y, hit.cell.y))
			var sz := b - a + Vector2i.ONE
			bm.size = Vector3(sz.x, 0.1, sz.y)
			cursor.position = Vector3(a.x + sz.x / 2.0, hit.y + 0.05, a.y + sz.y / 2.0)
		else:
			var s := (brush - 1) >> 1
			var mn: Vector2i = hit.cell - Vector2i(s, s)
			bm.size = Vector3(brush, 0.1, brush)
			cursor.position = Vector3(mn.x + brush / 2.0, hit.y + 0.05, mn.y + brush / 2.0)
	elif cur_tool == 1:
		bm.size = Vector3(0.4, 0.1, 0.4)
		var sp := _snap(hit.pos)
		cursor.position = Vector3(sp.x, hit.y + 0.05, sp.z)
	elif cur_tool == 3:
		bm.size = Vector3(1, 0.1, 1)
		cursor.position = Vector3(floorf(hit.pos.x) + 0.5, hit.y + 0.05, floorf(hit.pos.z) + 0.5)
	else:
		bm.size = Vector3(veg_radius * 2.0, 0.1, veg_radius * 2.0)
		cursor.position = Vector3(hit.pos.x, hit.y + 0.05, hit.pos.z)


func _free_cursor() -> void:
	if cursor and is_instance_valid(cursor):
		cursor.queue_free()
	cursor = null


# ================= nová lokace =================
func _new_location(raw: String) -> void:
	var nm := raw.strip_edges().validate_filename()
	if nm == "":
		return
	DirAccess.make_dir_recursive_absolute("res://scenes")
	var path := "res://scenes/%s.tscn" % nm
	if FileAccess.file_exists(path):
		EditorInterface.open_scene_from_path(path)
		return
	_ensure_library()
	var root := Node3D.new()
	root.name = nm.validate_node_name()
	var tm := TerrainMap.new()
	tm.name = "TerrainMap"
	var lib: Array[TerrainMat] = []
	for r in Lib.list(TerrainMap.MAT_DIR):
		if r is TerrainMat:
			lib.append(r)
	tm.materials = lib
	for x in range(-4, 4):
		for z in range(-4, 4):
			tm.cells[Vector2i(x, z)] = Vector2i(0, 0)
	tm.sync_data()
	root.add_child(tm)
	tm.owner = root
	var sp := Marker3D.new()
	sp.name = "Start"
	root.add_child(sp)
	sp.owner = root
	sp.position = Vector3(0.5, 0.0, 0.5)
	var pl := Player3D.new()
	pl.name = "Player"
	root.add_child(pl)
	pl.owner = root
	pl.position = Vector3(0.5, 0.1, 0.5)
	var cam := HD2DCamera.new()
	cam.name = "Camera"
	root.add_child(cam)
	cam.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, path)
	root.free()
	EditorInterface.open_scene_from_path(path)
