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
	"weighting", "modifier_bounds", "tables",
	"formula", "composition", "roster", "sample"
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
	print("[MANIFEST] tables: %d races, %d biomes, %d enemies, %d bosses, %d modifiers" % [
		(tables.get("races", []) as Array).size(),
		(tables.get("biomes", []) as Array).size(),
		(tables.get("enemies", []) as Array).size(),
		(tables.get("bosses", []) as Array).size(),
		(tables.get("modifiers", []) as Array).size()])

	_check_arithmetic(RM)
	_check_determinism(RM, tables)
	_check_varies(RM, tables)
	_check_axis_independence(RM, tables)
	_check_weighting(RM)
	_check_modifier_bounds(RM, tables)
	_check_tables_are_true(DB, SDB)
	_check_formula(RM, DB)
	_check_composition(RM, DB, tables)
	_check_roster(RM, DB)
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
	var wired_count := 0
	for b in tables.get("biomes", []):
		if bool((b as Dictionary).get("wired", false)):
			wired_count += 1
	var expect := {
		"race": races.size(),
		"body": (first_race.get("bodies", []) as Array).size(),
		"arrival": (first_race.get("arrivals", []) as Array).size(),
		"region": wired_count,
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
				or a.arrival_id != b.arrival_id or a.region_id != b.region_id \
				or a.accent_ids != b.accent_ids or a.boss_id != b.boss_id:
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
		"biomes": [{"id": "r", "weight": 1, "wired": true}],
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

	# A WIRED biome's terrain must be a key ground.gd actually knows -- wired is
	# a promise that the primary can be built. Unwired biomes need no terrain.
	var ground: GDScript = load("res://scripts/ground.gd")
	var terrain: Dictionary = ground.get_script_constant_map().get("LEVEL_TERRAIN", {})
	if terrain.is_empty():
		_fail("read zero terrain keys off ground.gd -- this check is not measuring anything")
	for biome in DB.biomes():
		var bd := biome as Dictionary
		if bool(bd.get("wired", false)) and not terrain.has(str(bd.get("terrain", ""))):
			_fail("wired biome %s wants terrain '%s'; ground.gd knows %s" % [
				str(bd.get("id", "?")), str(bd.get("terrain", "")), str(terrain.keys())])

	# Enemy scenes and boss scripts must exist -- the roster filter matches on
	# these paths, and a path that resolves to nothing silently filters forever.
	for e in DB.enemies():
		var path := str((e as Dictionary).get("scene", ""))
		if not ResourceLoader.exists(path):
			_fail("enemy %s scene missing: %s" % [str((e as Dictionary).get("id", "?")), path])
	for boss in DB.bosses():
		var spath := str((boss as Dictionary).get("script", ""))
		if not ResourceLoader.exists(spath):
			_fail("boss %s script missing: %s" % [str((boss as Dictionary).get("id", "?")), spath])

	# Every climate range must be well-formed: all four axes, lo <= hi, 0..3.
	var tagged: Array = DB.biomes() + DB.enemies() + DB.bosses()
	for entry in tagged:
		var ed := entry as Dictionary
		var axes: Dictionary = ed.get("axes", {})
		for axis in RM_AXES:
			var r: Array = axes.get(axis, [])
			if r.size() != 2 or int(r[0]) > int(r[1]) or int(r[0]) < 0 or int(r[1]) > 3:
				_fail("%s has a malformed %s range: %s" % [str(ed.get("id", "?")), axis, str(r)])

	print("[MANIFEST] tables: %d characters, %d terrain keys, %d enemies, %d bosses all resolve" % [
		known.size(), terrain.size(), DB.enemies().size(), DB.bosses().size()])
	_mark("tables")


const RM_AXES := ["heat", "light", "wet", "depth"]


# The user-facing truths of the climate space, locked as assertions against the
# REAL table. If a retune of the axes breaks one of these, the design broke,
# whatever the numbers say: lava never mixes with forest or ocean, caves mix
# with almost everything because underground is insulated, the radiant plains
# accept forest but not lava, and the salvage deck is a sealed hull that mixes
# with nothing organic.
func _check_formula(RM: GDScript, DB: GDScript) -> void:
	var truths := [
		["lava_fields", "forest", false],
		["lava_fields", "ocean", false],
		["lava_fields", "caves", true],
		["forest", "ocean", true],
		["forest", "caves", true],
		["graveyard", "caves", true],
		["graveyard", "forest", true],
		["luminous_plains", "forest", true],
		["luminous_plains", "lava_fields", false],
		["salvage_deck", "forest", false],
		["salvage_deck", "lava_fields", false]
	]
	for t in truths:
		var a: Dictionary = DB.get_biome(t[0])
		var b: Dictionary = DB.get_biome(t[1])
		if a.is_empty() or b.is_empty():
			_fail("formula truth references a missing biome: %s x %s" % [t[0], t[1]])
			continue
		var got: bool = RM.climate_compatible(a.get("axes", {}), b.get("axes", {}))
		if got != bool(t[2]):
			_fail("formula: %s x %s should be %s, the axes say %s" % [t[0], t[1], t[2], got])
	print("[MANIFEST] formula: %d compatibility truths hold" % truths.size())
	_mark("formula")


# Composition: the primary always carries real art, accents are always legal
# guests, and the boss is always an intruder where the table makes one possible.
func _check_composition(RM: GDScript, DB: GDScript, tables: Dictionary) -> void:
	# Both wired primaries must HAVE intruders, or boss-as-intruder is
	# unfalsifiable and the fallback path runs silently forever.
	for primary_id in ["graveyard", "salvage_deck"]:
		var primary: Dictionary = DB.get_biome(primary_id)
		var intruders := 0
		for boss in DB.bosses():
			if not RM.climate_compatible((boss as Dictionary).get("axes", {}), primary.get("axes", {})):
				intruders += 1
		if intruders == 0:
			_fail("no boss is an intruder vs %s -- the inversion means nothing there" % primary_id)

	var bad := 0
	for s in range(0, 400):
		var m = RM.roll(s, tables)
		var primary: Dictionary = DB.get_biome(m.region_id)
		if not bool(primary.get("wired", false)):
			_fail("seed %d rolled unwired primary '%s'" % [s, m.region_id]); bad += 1; break
		if m.accent_ids.size() > 2:
			_fail("seed %d rolled %d accents" % [s, m.accent_ids.size()]); bad += 1; break
		for aid in m.accent_ids:
			if aid == m.region_id:
				_fail("seed %d rolled its primary as an accent" % s); bad += 1
			var accent: Dictionary = DB.get_biome(aid)
			if not RM.climate_compatible(accent.get("axes", {}), primary.get("axes", {})):
				_fail("seed %d: accent %s is not compatible with primary %s" % [s, aid, m.region_id]); bad += 1
		var boss: Dictionary = DB.get_boss(m.boss_id)
		if boss.is_empty():
			_fail("seed %d rolled no boss" % s); bad += 1
		elif RM.climate_compatible(boss.get("axes", {}), primary.get("axes", {})):
			_fail("seed %d: boss %s is NATIVE to %s -- the intruder rule failed" % [
				s, m.boss_id, m.region_id]); bad += 1
		if bad > 0:
			break
	if bad == 0:
		print("[MANIFEST] composition: 400 seeds -- primaries wired, accents legal, bosses intrude")
	_mark("composition")


# The roster is what the formula says it is, and the two shipped worlds get
# exactly the game they should: the graveyard keeps every enemy the game spawns
# today (the pivot must not thin the current game), and the salvage deck keeps
# only the mass and the ghosts -- a dead ship haunted, which is the first time
# the world composition changes what walks in it.
func _check_roster(RM: GDScript, DB: GDScript) -> void:
	var m = RM.new()
	m.region_id = "graveyard"
	var grave := {}
	for e in m.enemy_roster():
		grave[str((e as Dictionary).get("id", ""))] = true
	if grave.size() != DB.enemies().size():
		var missing := []
		for e in DB.enemies():
			if not grave.has(str((e as Dictionary).get("id", ""))):
				missing.append(str((e as Dictionary).get("id", "")))
		_fail("graveyard roster lost %s -- the pivot thinned the current game" % str(missing))

	m.region_id = "salvage_deck"
	var deck := {}
	for e in m.enemy_roster():
		deck[str((e as Dictionary).get("id", ""))] = true
	var want := {"husk": true, "banshee": true, "wraith": true}
	if deck != want:
		_fail("salvage deck roster is %s, want exactly husk+banshee+wraith" % str(deck.keys()))

	# Modifier effects: wired modifiers multiply, unwired ones are inert, and
	# an effect nobody rolled is 1.0.
	m.modifier_ids = ["lean_purse", "dense_horde", "long_dusk"] as Array[String]
	var gold: float = m.modifier_effect("gold_mult")
	var horde: float = m.modifier_effect("horde_mult")
	var nothing: float = m.modifier_effect("does_not_exist")
	if absf(gold - 0.7) > 0.0001:
		_fail("gold_mult with lean_purse rolled: %f, want 0.7" % gold)
	if absf(horde - 1.35) > 0.0001:
		_fail("horde_mult with dense_horde rolled: %f, want 1.35" % horde)
	if absf(nothing - 1.0) > 0.0001:
		_fail("an effect nobody defines returned %f, want 1.0" % nothing)

	print("[MANIFEST] roster: graveyard keeps all %d, salvage deck is husk+ghosts, effects multiply" % grave.size())
	_mark("roster")


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
