extends SceneTree
var _f := 0
func _process(_d: float) -> bool:
	_f += 1
	if _f < 2:
		return false
	var db = root.get_node_or_null("StructureDB")
	var defs = load("res://scripts/structure_db.gd")
	var raw = FileAccess.get_file_as_string("res://data/structures.json")
	var d = JSON.parse_string(raw)
	var sh = d["shrine"]
	print("[STARGATE] tiers: %d" % sh["tiers"].size())
	var ok := true
	if sh["tiers"].size() != 3:
		print("[STARGATE] FAIL: expected 3 tiers"); ok = false
	var t3 = sh["tiers"][2]
	var t2 = sh["tiers"][1]
	print("[STARGATE] T3 cost %d gold + %d essence" % [int(t3["cost"]), int(t3["essence_cost"])])
	if int(t3["cost"]) != 1500 or int(t3["essence_cost"]) != 100:
		print("[STARGATE] FAIL: wrong price"); ok = false
	for k in ["demon_health", "demon_damage", "demon_attack_rate", "caster_aoe_radius", "caster_aoe_damage"]:
		var a := float(t2[k]); var b := float(t3[k])
		print("[STARGATE] %-20s T2 %8.1f -> T3 %8.1f  (x%.2f)" % [k, a, b, b / a])
		if b <= a:
			print("[STARGATE] FAIL: %s did not increase" % k); ok = false
	if not bool(t3.get("greater", false)):
		print("[STARGATE] FAIL: T3 is not flagged greater"); ok = false
	# Every T3 demon must be an overlord, or "greater" is a coin flip.
	print("[STARGATE] caster_chance T3 = %.2f (want 1.0: every demon is greater)" % float(t3["caster_chance"]))
	if absf(float(t3["caster_chance"]) - 1.0) > 0.001:
		print("[STARGATE] FAIL: caster_chance must be 1.0 at T3"); ok = false
	# And the building must actually charge the essence.
	var b2 = load("res://scripts/shrine_building.gd").new()
	b2.definition = sh
	b2.tier = 1
	print("[STARGATE] get_upgrade_cost()=%d get_upgrade_essence_cost()=%d at tier 2" % [
		b2.get_upgrade_cost(), b2.get_upgrade_essence_cost()])
	if b2.get_upgrade_cost() != 1500 or b2.get_upgrade_essence_cost() != 100:
		print("[STARGATE] FAIL: the building does not charge the T3 price"); ok = false
	b2.tier = 2
	if b2.get_upgrade_essence_cost() != 0:
		print("[STARGATE] FAIL: a maxed stargate still asks for essence"); ok = false
	b2.free()
	print("[STARGATE] RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
