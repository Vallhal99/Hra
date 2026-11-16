extends SceneTree
var f := 0
func _process(_d) -> bool:
	f += 1
	if f == 3:
		var inv = root.get_node("Inventory")
		for id in ["zelezny_mec","helma","telo","lektvar","lektvar_many","ruda","kost","maso","bylina","gulas","pecetni_hrot","klic_mauzolea","past","paklic","ryba","houba","koreni","zele","ryb_polevka"]:
			inv.add(id, 3 if id in ["lektvar","ruda"] else 1)
		inv.equip["helma"] = "helma"
		inv.equip["zbran"] = "zelezny_mec"
		inv.dura["helma"] = 55.0
		inv.gold = 480
		root.get_node("Hero").class_id = "valecnik"
		root.get_node("Hero").points = 2
		inv._toggle(); inv._root._show("zelezny_mec", false)
	if f == 8:
		root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
		quit()
	return false
