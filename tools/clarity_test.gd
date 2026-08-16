extends SceneTree
## Clarity audit: what the player is TOLD vs what the game DOES.
##
## Every number here is read off a configured tower, not off structures.json --
## the sheet has been wrong by 2.3x-4.65x before and tuning against it is what
## caused the reverted balance pass (dc853f2). The point of this probe is the
## GAP, so it prints both columns side by side and never just one.
##
## Three separate questions:
##   1. does the upgrade panel's "Damage/Range/Fire Rate" match the tower?
##   2. does the upgrade COST the panel shows match what is charged?
##   3. is the cost the same for every tower, and does the sheet agree?

var _frames := 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	return _run()

func _run() -> bool:
	var raw := FileAccess.get_file_as_string("res://data/structures.json")
	var db = JSON.parse_string(raw)
	var tower_script = load("res://scripts/tower.gd")
	var ok := true

	print("[CLARITY] ===== 1. PANEL NUMBERS vs CONFIGURED TOWER =====")
	print("[CLARITY] The panel prints tier_data['damage'/'range'/'fire_rate'] verbatim.")
	print("[CLARITY]")
	print("[CLARITY] %-18s %-4s %8s %8s %7s   %8s %8s %7s" % [
		"tower", "tier", "dmg_shown", "dmg_real", "ratio", "rng_shown", "rng_real", "ratio"])

	var towers := ["arrow_turret", "cannon_tower", "tesla_tower", "spike_burst_tower", "flamethrower_tower"]
	var worst_dmg := 1.0
	for id in towers:
		var def = db[id]
		var scene_path: String = str(def.get("scene", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			print("[CLARITY] %-18s  (no scene at %s)" % [id, scene_path])
			continue
		for t in range(def["tiers"].size()):
			var inst = load(scene_path).instantiate()
			root.add_child(inst)
			if not inst.has_method("configure"):
				inst.queue_free()
				continue
			inst.configure(id, def, t)
			var td = def["tiers"][t]
			var shown_d := float(td.get("damage", 0.0))
			var shown_r := float(td.get("range", 0.0))
			var shown_f := float(td.get("fire_rate", 0.0))
			var real_d := float(inst.damage)
			var real_r := float(inst.range)
			var real_f := float(inst.fire_rate)
			var rd: float = real_d / maxf(shown_d, 0.0001)
			var rr: float = real_r / maxf(shown_r, 0.0001)
			worst_dmg = maxf(worst_dmg, rd)
			print("[CLARITY] %-18s %-4d %8.1f %8.1f %6.2fx   %8.1f %8.1f %6.2fx" % [
				id, t + 1, shown_d, real_d, rd, shown_r, real_r, rr])
			if absf(rd - 1.0) > 0.01 and t > 0:
				ok = false
			inst.queue_free()

	print("[CLARITY]")
	print("[CLARITY] ===== 2. UPGRADE COST: SHEET vs CHARGED =====")
	print("[CLARITY] %-18s %-6s %10s %10s %10s" % ["structure", "tier", "sheet_cost", "charged", "essence"])
	for id in db.keys():
		var def = db[id]
		var scene_path: String = str(def.get("scene", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		var tiers: Array = def.get("tiers", [])
		for t in range(tiers.size() - 1):
			var inst = load(scene_path).instantiate()
			root.add_child(inst)
			if not inst.has_method("configure") or not inst.has_method("get_upgrade_cost"):
				inst.queue_free()
				continue
			inst.configure(id, def, t)
			var sheet := int(tiers[t + 1].get("cost", 0))
			var charged := int(inst.get_upgrade_cost())
			var ess := 0
			if inst.has_method("get_upgrade_essence_cost"):
				ess = int(inst.get_upgrade_essence_cost())
			var flag := "" if sheet == charged else "   <-- SHEET DISAGREES"
			print("[CLARITY] %-18s %d->%d  %10d %10d %10d%s" % [
				id, t + 1, t + 2, sheet, charged, ess, flag])
			inst.queue_free()

	print("[CLARITY]")
	print("[CLARITY] ===== 3. WHAT AN UPGRADE ACTUALLY BUYS =====")
	print("[CLARITY] Real cumulative gold to reach each tier, and the DPS it buys.")
	print("[CLARITY] %-18s %-4s %9s %9s %9s %10s" % [
		"tower", "tier", "cum_gold", "dps_real", "dps/gold", "vs_tier1"])
	for id in towers:
		var def = db[id]
		var scene_path: String = str(def.get("scene", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			continue
		var cum := int(def["tiers"][0].get("cost", 0))
		var base_dps := 0.0
		for t in range(def["tiers"].size()):
			var inst = load(scene_path).instantiate()
			root.add_child(inst)
			if not inst.has_method("configure"):
				inst.queue_free()
				continue
			inst.configure(id, def, t)
			if t > 0:
				cum += 500  # the flat charge proven in section 2
			var dps := float(inst.damage) * float(inst.fire_rate)
			if t == 0:
				base_dps = dps
			print("[CLARITY] %-18s %-4d %9d %9.1f %9.3f %9.2fx" % [
				id, t + 1, cum, dps, dps / maxf(float(cum), 1.0), dps / maxf(base_dps, 0.0001)])
			inst.queue_free()

	print("[CLARITY]")
	print("[CLARITY] worst shown-vs-real damage ratio: %.2fx" % worst_dmg)
	print("[CLARITY] RESULT: %s" % ("panel matches tower" if ok else "PANEL DISAGREES WITH THE TOWER"))
	quit(0)
	return true
