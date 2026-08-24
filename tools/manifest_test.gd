extends SceneTree

# Does the run manifest actually roll a run, and does the same seed give the same
# run? See tools/manifest_test.sh for what each section is guarding against.
#
# WHY THIS FILE COUNTS ITS OWN CHECKS: the first run of this harness printed
# "RESULT: PASS" while every single check had aborted on a runtime error. A
# GDScript error unwinds only the function it happened in -- control returns to
# the caller and the next check runs -- so nothing ever touched the fail flag and
# a harness that measured nothing reported success. That is the same "green
# because silent" failure that shipped two broken wrappers before it (see
# docs/HANDOFF_2026-08-16.md). So every check registers itself on completion and
# the summary fails unless all of them are accounted for. A harness has to prove
# it ran before it is allowed to say PASS.

const EXPECTED := [
	"arithmetic", "determinism", "varies", "independence",
	"weighting", "modifier_bounds", "tables", "sample"
]

var _f := 0
var _ok := true
var _done := {}

func _fail(msg: String) -> void:
	print("[MANIFEST] FAIL: %s" % msg)
	_ok = false

func _mark(name: String) -> void:
	_done[name] = true


func _process(_d: float) -> bool:
	_f += 1
	if _f < 2:
		return false

	# load() at frame 2, not preload(). preload() in a SceneTree script compiles
	# before autoloads attach, and this codebase has already been bitten by it.
	var RM: GDScript = load("res://scripts/run_manifest.gd")
	var DB: GDScript = load("res://scripts/rift_db.gd")
	var SDB: GDScript = load("res://scripts/structure_db.gd")

	if RM == null or DB == null or SDB == null:
		_fail("a script failed to load; see the parse errors above")
		print("[MANIFEST] RESULT: FAIL")
		quit(1)
		return true

	var tables: Dictionary = DB.tables()
	print("[MANIFEST] tables: %d races, %d regions, %d modifiers" % [
		(tables.get("races", []) as Array).size(),
		(tables.get("regions", []) as Array).size(),
		(tables.get("modifiers", []) as Array).size()])

	_check_arithmetic(RM)
	_check_determinism(RM, tables)
	_check_varies(RM, tables)
	_check_axis_independence(RM, tables)
	_check_weighting(RM)
	_check_modifier_bounds(RM, tables)
	_check_tables_are_true(DB, SDB)
	_show_sample(RM)

	for name in EXPECTED:
		if not _done.has(name):
			_fail("check '%s' never completed -- it errored out partway" % name)

	print("[MANIFEST] checks completed: %d of %d" % [_done.size(), EXPECTED.size()])
	print("[MANIFEST] RESULT: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
	return true


# The seed must mean the same thing on every machine. Masked 31-bit operands mean
# no product can reach int64, so nothing wraps -- assert that rather than trust
# it, including at the extremes where a sloppy mixer goes negative.
func _check_arithmetic(RM: GDScript) -> void:
	var limit: int = 1 << 62
	var seeds: Array = [0, 1, -1, 2147483647, -2147483648, 9223372036854775807, 20260808]
	for s in seeds:
		for axis in ["race", "body", "arrival", "region", "modifiers"]:
			var v: int = RM.axis_seed(s, axis)
			if v < 0:
				_fail("axis_seed(%d, %s) went negative: %d" % [s, axis, v])
			elif v >= limit:
				_fail("axis_seed(%d, %s) exceeded 2^62: %d" % [s, axis, v])
	# Different axes must not collide, or the axes are not independent at all.
	var seen := {}
	for axis in ["race", "body", "arrival", "region", "modifiers"]:
		var v: int = RM.axis_seed(12345, axis)
		if seen.has(v):
			_fail("axes %s and %s derive the same seed" % [seen[v], axis])
		seen[v] = axis
	print("[MANIFEST] arithmetic: in range and axis-distinct across %d seeds" % seeds.size())
	_mark("arithmetic")


func _check_determinism(RM: GDScript, tables: Dictionary) -> void:
	var mismatches := 0
	for s in range(0, 400):
		var a = RM.roll(s, tables)
		var b = RM.roll(s, tables)
		if a.to_dict() != b.to_dict():
			if mismatches == 0:
				_fail("seed %d rolled two different runs: %s vs %s" % [s, a.describe(), b.describe()])
			mismatches += 1
	if mismatches > 0:
		_fail("%d of 400 seeds were not deterministic" % mismatches)
	print("[MANIFEST] determinism: 400 seeds, each rolled twice, %d mismatches" % mismatches)
	_mark("determinism")


# THE NEGATIVE CONTROL. A manifest that returned the same run for every seed would
# sail through the determinism check above. This is what makes that check mean
# something: every axis whose table offers a real choice must actually vary.
func _check_varies(RM: GDScript, tables: Dictionary) -> void:
	var seen := {"race": {}, "body": {}, "arrival": {}, "region": {}, "modifiers": {}}
	for s in range(0, 400):
		var m = RM.roll(s, tables)
		seen["race"][m.race_id] = true
		seen["body"][m.body_id] = true
		seen["arrival"][m.arrival_id] = true
		seen["region"][m.region_id] = true
		seen["modifiers"][", ".join(m.modifier_ids)] = true

	var races: Array = tables.get("races", [])
	var first_race: Dictionary = {} if races.is_empty() else races[0]
	var expect := {
		"race": races.size(),
		"body": (first_race.get("bodies", []) as Array).size(),
		"arrival": (first_race.get("arrivals", []) as Array).size(),
		"region": (tables.get("regions", []) as Array).size(),
		"modifiers": (tables.get("modifiers", []) as Array).size()
	}
	for axis in ["race", "body", "arrival", "region", "modifiers"]:
		var distinct: int = (seen[axis] as Dictionary).size()
		var available: int = int(expect.get(axis, 0))
		print("[MANIFEST] varies: %-10s %d distinct over 400 seeds (table offers %d)" % [
			axis, distinct, available])
		if available > 1 and distinct < 2:
			_fail("%s never varied -- the roll is not reaching this axis" % axis)
	_mark("varies")


# The property that keeps every recorded seed meaningful. Adding an entry to one
# table must not re-deal the other axes. If the axes shared a sequential stream
# this check fails, which is exactly why it is here.
func _check_axis_independence(RM: GDScript, tables: Dictionary) -> void:
	var grown: Dictionary = tables.duplicate(true)
	var mods: Array = grown.get("modifiers", [])
	mods.append({"id": "synthetic_extra", "weight": 1})
	grown["modifiers"] = mods

	var drifted := 0
	for s in range(0, 300):
		var a = RM.roll(s, tables)
		var b = RM.roll(s, grown)
		if a.race_id != b.race_id or a.body_id != b.body_id \
				or a.arrival_id != b.arrival_id or a.region_id != b.region_id:
			if drifted == 0:
				_fail("growing the modifier table re-dealt seed %d: %s -> %s" % [
					s, a.describe(), b.describe()])
			drifted += 1
	if drifted > 0:
		_fail("%d of 300 seeds drifted when an unrelated table grew" % drifted)
	print("[MANIFEST] independence: +1 modifier left race/body/arrival/region untouched (%d/300 drifted)" % drifted)
	_mark("independence")


# Weights must be honoured, not just present. A _pick that ignored weight and
# chose uniformly would pass every other check in this file.
func _check_weighting(RM: GDScript) -> void:
	var synthetic := {
		"races": [
			{"id": "heavy", "weight": 3, "bodies": ["x"], "arrivals": [{"id": "a", "weight": 1}]},
			{"id": "light", "weight": 1, "bodies": ["x"], "arrivals": [{"id": "a", "weight": 1}]}
		],
		"regions": [{"id": "r", "weight": 1}],
		"modifiers": [{"id": "m", "weight": 1}]
	}
	var heavy := 0
	var total := 4000
	for s in range(0, total):
		if RM.roll(s, synthetic).race_id == "heavy":
			heavy += 1
	var share := float(heavy) / float(total)
	print("[MANIFEST] weighting: 3:1 table gave %.1f%% heavy over %d seeds (want 75%%)" % [
		share * 100.0, total])
	if absf(share - 0.75) > 0.04:
		_fail("weighted pick is off: %.3f, wanted 0.75 +/- 0.04" % share)
	_mark("weighting")


func _check_modifier_bounds(RM: GDScript, tables: Dictionary) -> void:
	var lo: int = RM.MODIFIERS_MIN
	var hi: int = RM.MODIFIERS_MAX
	var bad := 0
	var dupes := 0
	for s in range(0, 400):
		var ids: Array = RM.roll(s, tables).modifier_ids
		if ids.size() < lo or ids.size() > hi:
			if bad == 0:
				_fail("seed %d rolled %d modifiers, bounds are %d..%d" % [s, ids.size(), lo, hi])
			bad += 1
		var uniq := {}
		for i in ids:
			if uniq.has(i):
				if dupes == 0:
					_fail("seed %d rolled duplicate modifier %s" % [s, i])
				dupes += 1
			uniq[i] = true
	print("[MANIFEST] modifiers: 400 seeds within %d..%d (%d out of bounds, %d duplicated)" % [
		lo, hi, bad, dupes])
	_mark("modifier_bounds")


# "A data table is not the truth" -- a trap this codebase has already sprung.
# Every id rift.json hands out must resolve in the system that consumes it, or
# the manifest will one day roll a run that cannot be built.
func _check_tables_are_true(DB: GDScript, SDB: GDScript) -> void:
	# Towers must exist in structures.json.
	for race in DB.races():
		var rid: String = str((race as Dictionary).get("id", "?"))
		var offered: Array = (race as Dictionary).get("towers", [])
		for tid in offered:
			if (SDB.get_def(str(tid)) as Dictionary).is_empty():
				_fail("race %s offers tower '%s', absent from structures.json" % [rid, tid])
		# Planned towers are design, not content. They must NOT be offered.
		for p in (race as Dictionary).get("planned", []):
			var pid: String = str((p as Dictionary).get("id", ""))
			if pid in offered:
				_fail("race %s offers '%s', which is still only planned" % [rid, pid])

	# Bodies must exist in main.gd's real characters table -- read off the script
	# rather than restated here, so a rename in main.gd surfaces as a failure
	# instead of agreeing with a copy that has drifted.
	var main_script: GDScript = load("res://scripts/main.gd")
	var probe = main_script.new()
	var known := {}
	for c in probe.characters:
		known[str((c as Dictionary).get("id", ""))] = true
	probe.free()
	if known.is_empty():
		_fail("read zero characters off main.gd -- this check is not measuring anything")
	for race in DB.races():
		for bid in (race as Dictionary).get("bodies", []):
			if not known.has(str(bid)):
				_fail("race %s lists body '%s', absent from main.gd characters" % [
					str((race as Dictionary).get("id", "?")), bid])

	# Region terrain must be a key ground.gd actually knows.
	var ground: GDScript = load("res://scripts/ground.gd")
	var terrain: Dictionary = ground.get_script_constant_map().get("LEVEL_TERRAIN", {})
	if terrain.is_empty():
		_fail("read zero terrain keys off ground.gd -- this check is not measuring anything")
	for region in DB.regions():
		var t: String = str((region as Dictionary).get("terrain", ""))
		if not terrain.has(t):
			_fail("region %s wants terrain '%s'; ground.gd knows %s" % [
				str((region as Dictionary).get("id", "?")), t, str(terrain.keys())])

	print("[MANIFEST] tables: %d characters and %d terrain keys read; towers resolve in StructureDB" % [
		known.size(), terrain.size()])
	_mark("tables")


func _show_sample(RM: GDScript) -> void:
	print("[MANIFEST] sample rolls:")
	for s in [1, 2, 3, 20260816, 99999]:
		print("[MANIFEST]   %s" % RM.roll_default(s).describe())
	# A typed seed must survive the round trip a player expects.
	var typed: int = RM.seed_from_text("4242")
	if typed != 4242:
		_fail("seed_from_text('4242') gave %d, not 4242" % typed)
	var worded: int = RM.seed_from_text("brimstone")
	if worded != RM.seed_from_text("brimstone"):
		_fail("seed_from_text is not stable for a worded seed")
	print("[MANIFEST]   typed '4242' -> %d, 'brimstone' -> %d" % [typed, worded])
	_mark("sample")
