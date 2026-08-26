extends SceneTree

# Does the RUN actually consume the roll? manifest_test proves the roll is
# right; this boots the real main.tscn behind a dealt manifest and measures
# what changed inside it: the spawn filter, the horde multiplier, the gold
# multiplier. See tools/rift_run_test.sh.

const EXPECTED := ["seed_search", "spawn_filter", "horde_mult", "gold_mult"]

var _f := 0
var _ok := true
var _done := {}
var _m: Node = null
var _rm: GDScript = null
var _seed: int = -1

func _fail(msg: String) -> void:
	print("[RIFTRUN] FAIL: %s" % msg)
	_ok = false

func _mark(name: String) -> void:
	_done[name] = true

func _process(_d: float) -> bool:
	_f += 1
	if _f < 2:
		return false
	if _f == 2:
		_rm = load("res://scripts/run_manifest.gd")
		# A seed whose deal exercises everything at once: salvage_deck primary
		# (the thin roster) AND both wired modifiers. Searched, not hardcoded,
		# so a weight retune moves the seed instead of silently gutting the
		# test. dense+lean is the most likely pair (weight 2 and 2), salvage a
		# 1-in-4 primary; ~1 in 30 seeds qualifies.
		for s in range(1, 20000):
			var probe = _rm.roll_default(s)
			if probe.region_id != "salvage_deck":
				continue
			if not ("dense_horde" in probe.modifier_ids and "lean_purse" in probe.modifier_ids):
				continue
			_seed = s
			break
		if _seed < 0:
			_fail("no seed in 20000 deals salvage_deck + dense_horde + lean_purse")
			print("[RIFTRUN] RESULT: FAIL")
			quit(1)
			return true
		print("[RIFTRUN] seed %d deals salvage_deck + dense_horde + lean_purse" % _seed)
		_mark("seed_search")

		var meta = root.get_node_or_null("MetaProgression")
		_rm.deal(meta, _seed)
		if meta != null:
			meta.autostart_run = true
		_m = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		root.add_child(_m)
		return false
	if _f < 6:
		return false

	# --- spawn filter: 300 draws late enough that every pool row is live ----
	# The salvage roster is husk + banshee + wraith. elapsed is set so the
	# richest pool applies; every draw must still come back from the roster.
	_m.elapsed = 1200.0
	var allowed: Dictionary = _m._rift_allowed_scenes
	if allowed.size() != 3:
		_fail("allowed scenes: %d, want 3 (husk, banshee, wraith)" % allowed.size())
	var seen := {}
	var strays := 0
	for i in range(300):
		var scene: PackedScene = _m._pick_enemy_scene()
		var path := str(scene.resource_path)
		seen[path] = true
		if not allowed.has(path):
			strays += 1
	if strays > 0:
		_fail("%d of 300 draws left the roster: %s" % [strays, str(seen.keys())])
	else:
		print("[RIFTRUN] spawn filter: 300 draws, %d distinct scenes, zero strays" % seen.size())
		_mark("spawn_filter")

	# --- horde: the Dense modifier must scale the count multiplier by 1.35 ---
	# Measured as a ratio at fixed time, so every other factor cancels.
	var with_mod: float = _m._get_horde_count_multiplier(600.0)
	var saved: float = _m._rift_horde_mult
	_m._rift_horde_mult = 1.0
	var without: float = _m._get_horde_count_multiplier(600.0)
	_m._rift_horde_mult = saved
	if without <= 0.0:
		_fail("baseline horde multiplier is %f -- cannot form a ratio" % without)
	else:
		var ratio: float = with_mod / without
		if absf(ratio - 1.35) > 0.0001:
			_fail("horde ratio %f, want 1.35" % ratio)
		else:
			print("[RIFTRUN] horde: x%.2f with Dense rolled (%.3f -> %.3f)" % [ratio, without, with_mod])
			_mark("horde_mult")

	# --- gold: the Lean modifier must cut gains, and spends never ------------
	# Expected is computed with the SAME arithmetic add_resources uses --
	# including RESOURCE_GAIN_MULT, which already scales all gains to 0.85x,
	# and the same float product (0.85 * 0.7 rounds DOWN to 59, not to 60,
	# because the product is 0.59499... in binary). The first cut of this
	# check assumed a 1.0 baseline and failed; that was the harness modelling
	# the code instead of reading it.
	var want_gain: int = max(1, int(round(100.0 * _m.RESOURCE_GAIN_MULT * _m._rift_gold_mult)))
	var want_base: int = max(1, int(round(100.0 * _m.RESOURCE_GAIN_MULT)))
	if want_gain == want_base:
		_fail("Lean changes nothing at +100 -- the check cannot distinguish the modifier")
	var before: int = _m.resources
	_m.add_resources(100)
	var gained: int = _m.resources - before
	if gained != want_gain:
		_fail("add_resources(100) with Lean gained %d, want %d (baseline %d)" % [
			gained, want_gain, want_base])
	else:
		before = _m.resources
		_m.add_resources(-50)
		var spent: int = _m.resources - before
		if spent != -50:
			_fail("add_resources(-50) moved %d -- a spend must never be discounted" % spent)
		else:
			print("[RIFTRUN] gold: +100 lands as +%d (baseline +%d), -50 stays -50" % [
				want_gain, want_base])
			_mark("gold_mult")

	for name in EXPECTED:
		if not _done.has(name):
			_fail("check '%s' never completed -- it errored out partway" % name)
	print("[RIFTRUN] checks completed: %d of %d" % [_done.size(), EXPECTED.size()])
	print("[RIFTRUN] RESULT: %s" % ("PASS" if _ok else "FAIL"))
	_rm.current = null
	quit(0 if _ok else 1)
	return true
