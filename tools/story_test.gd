extends SceneTree
var f := 0
func _process(_d) -> bool:
	f += 1
	if f == 3:
		var r := root
		var Q = r.get_node("Quests")
		var D = r.get_node("DialogueRunner")
		# projdi hlavní řetěz bez dialogových oken
		var P = r.get_node("Party")
		Q.start("neklid")
		for i in 2: Q.event("kill:Přízrak")
		print("neklid ready ", Q.ready_to_complete("neklid"))
		Q.complete("neklid")
		Q.start("zapecetit")
		var inv = r.get_node("Inventory")
		inv.add("ruda", 3); inv.add("kost", 2)
		print("zapec ready ", Q.ready_to_complete("zapecetit"))
		Q.complete("zapecetit")
		P.recruit("brum")
		print("brum ", P.members.has("brum"), " hrot ", inv.count("pecetni_hrot"))
		Q.start("kral"); Q.event("kill:Kostěný král")
		print("kral ready ", Q.ready_to_complete("kral"))
		D.start("knez")
	if f == 6:
		var D2 = root.get_node("DialogueRunner")
		print("dlg active ", D2.active)
		D2._goto("f_end")
		D2._goto("f_stay")
	if f == 10:
		print("ending ", root.has_node("EndingScreen"), " flag ", root.get_node("Quests").flags.get("konec_zustat"))
		quit()
	return false
