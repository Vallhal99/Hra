extends RefCounted
## Obchod: Shop.open(tree, shop_id). Nákup i prodej za zlato.

static func open(tree: SceneTree, id: String) -> void:
	var sh: Dictionary = GameData.shops.get(id, {})
	if sh.is_empty():
		return
	var cl := CanvasLayer.new()
	cl.layer = 93
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(cl)
	tree.paused = true
	_build(tree, cl, sh)


static func _build(tree: SceneTree, cl: CanvasLayer, sh: Dictionary) -> void:
	for c in cl.get_children():
		c.queue_free()
	var inv := tree.root.get_node("Inventory")
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.2, 0.96)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.offset_left = -400
	pc.offset_right = 400
	pc.offset_top = -250
	pc.offset_bottom = 250
	cl.add_child(pc)
	var vb := VBoxContainer.new()
	pc.add_child(vb)
	var t := Label.new()
	t.text = "%s     Tvoje zlato: %d" % [sh.get("name", "Obchod"), inv.gold]
	t.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	vb.add_child(t)
	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	var cols := [["KOUPIT", true], ["PRODAT", false]]
	for col in cols:
		var sc := ScrollContainer.new()
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.custom_minimum_size = Vector2(380, 380)
		hb.add_child(sc)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(v)
		var h := Label.new()
		h.text = col[0]
		v.add_child(h)
		var ids: Array = sh.get("stock", []) if col[1] else inv.bag.keys()
		for id in ids:
			var it: Dictionary = inv.ITEMS.get(id, {})
			if it.is_empty():
				continue
			var price := int(round(float(it.get("price", 0)) * (float(sh.get("buy_mult", 1.0)) if col[1] else float(sh.get("sell_mult", 0.5)))))
			var b := Button.new()
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "%s%s  –  %d zl." % [it.name, "" if col[1] else " ×%d" % inv.bag[id], price]
			b.tooltip_text = it.get("desc", "")
			if it.get("icon", "") != "":
				b.icon = load(it.icon)
				b.expand_icon = true
			b.disabled = (col[1] and inv.gold < price) or (not col[1] and (id == "paklic" and false))
			b.pressed.connect(func():
				if col[1]:
					inv.gold -= price
					inv.add(id)
				else:
					inv.gold += price
					inv.remove(id)
					for s in inv.equip:
						if inv.equip[s] == id and inv.count(id) == 0:
							inv.equip[s] = null
				_build(tree, cl, sh))
			v.add_child(b)
	var close := Button.new()
	close.text = "Zavřít"
	close.pressed.connect(func():
		cl.queue_free()
		tree.paused = false)
	vb.add_child(close)
	close.grab_focus.call_deferred()
