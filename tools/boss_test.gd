extends SceneTree
# Engine-side measurement of the two boss claims: how much health a boss really
# ends up with, and whether it really paths around a wall.
#
# Both questions had been answered on paper before. Both paper answers were
# wrong, and in the same way: the thing being measured never happened.
#
#   health  - boss_base.setup() runs BEFORE _ready(), and every subclass assigns
#             max_health inside its own _ready(). Anything that reads the number
#             at setup() time reads a value that is about to be thrown away. The
#             only honest reading is taken after add_child() has run _ready().
#
#   path    - the previous pathing fixture was not sealed. The colossus "crossed"
#             it after 18px of lateral travel, which is not routing, it is a boss
#             walking through a wall that was never a wall. So this fixture
#             proves itself before it reports anything: see _assert_wall_sealed.
#
# Usage (see tools/boss_test.sh, which supplies --fixed-fps):
#   godot --headless --path . --script tools/boss_test.gd -- --mode=health
#   godot --headless --path . --script tools/boss_test.gd -- --mode=path

const MAIN_SCENE := "res://scenes/main.tscn"
# load(), never preload(): a --script run compiles this file before the project's
# autoloads are registered, and preloading anything that reaches enemy.gd fails
# the whole script with "Identifier not found: AudioManager".
const ENEMY_SCENE_PATH := "res://scenes/enemy.tscn"

# main.gd's ExtractionPhase, restated so this file does not have to reach through
# an untyped node for an enum.
const PHASE_SCOUT := 0
const PHASE_SIEGE := 1

const BOSSES := [
	["colossus", "res://scripts/boss_bone_colossus.gd"],
	["plague", "res://scripts/boss_plague_bringer.gd"],
	["siegebreaker", "res://scripts/boss_siegebreaker.gd"],
	["lich", "res://scripts/boss_lich.gd"],
]

# --- Pathing fixture geometry -------------------------------------------------
#
# Everything is on the 32px build grid and centred on the world origin, because
# the flow field's BFS discards any cell whose distance FROM THE ORIGIN exceeds
# play_radius -- not its distance from the player. A fixture built far off-origin
# silently loses its cells and reports "no route" for a reason that has nothing
# to do with the boss.
const PLAYER_POS := Vector2.ZERO
const WALL_X := 320.0            # multiple of 32: tiles abut with no seam
const WALL_HALF_SPAN := 384.0    # tiles at y = -384..384, so the wall covers +-400
const WALL_STEP := 32.0          # == wall footprint_radius * 2, so tiles tile
const BOSS_START := Vector2(640.0, 0.0)
const AGENT_RADIUS := 7.0        # enemy.tscn CollisionShape2D, and FLOW_AGENT_RADIUS
const WALL_HALF_THICK := 16.0    # wall footprint_radius

# 60s of simulated time at 60Hz. The longest legitimate route here is roughly
# 1100px and the slowest boss moves at 45px/s, so ~25s; the rest is headroom.
const SIM_FRAMES := 3600
const REACH_DIST := 200.0        # the plague bringer parks at 150 and the lich at 120

var _frames := 0
var _game: Node = null
var _walls: Array = []
var _failures: Array = []

func _process(_delta: float) -> bool:
	_frames += 1
	# A SceneTree script's _initialize() runs before the autoloads are attached,
	# so nothing that touches /root/AudioManager can happen there.
	if _frames < 3:
		return false
	if _frames == 3:
		_go()
	return false

func _mode() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			return a.substr(7)
	return ""

func _trace() -> bool:
	return OS.get_cmdline_user_args().has("--trace")

func _say(text: String) -> void:
	print("[BOSS-TEST] %s" % text)

func _fail(text: String) -> void:
	_failures.append(text)
	print("[BOSS-TEST] FAIL: %s" % text)

func _go() -> void:
	var mode := _mode()
	if mode != "health" and mode != "path":
		_say("FAIL: pass --mode=health|path")
		quit(1)
		return
	_run(mode)

func _run(mode: String) -> void:
	if not await _boot():
		quit(1)
		return
	if mode == "health":
		await _run_health()
	else:
		await _run_path()
	if _failures.is_empty():
		_say("RESULT: PASS")
		quit(0)
	else:
		_say("RESULT: FAIL (%d)" % _failures.size())
		quit(1)

# --- Boot ---------------------------------------------------------------------

func _boot() -> bool:
	var packed: PackedScene = load(MAIN_SCENE)
	if packed == null:
		_fail("could not load %s" % MAIN_SCENE)
		return false
	_game = packed.instantiate()
	root.add_child(_game)
	for _i in range(5):
		await process_frame
	if _game.player == null or not is_instance_valid(_game.player):
		_fail("no player in the scene")
		return false
	if _game.enemies_root == null or _game.buildings_root == null:
		_fail("missing World/Enemies or World/Buildings")
		return false
	if not _game.game_started:
		_fail("run never started (game_started=false)")
		return false
	# The horde must not exist. Every spawner in main.gd is gated on this flag,
	# and max_enemies_cap_base is the one that matters -- _update_dynamic_caps
	# recomputes the derived cap every frame from it.
	_game._dps_test_active = true
	_game.max_enemies_cap_base = 0
	# _process returns above _update_flow_field until start_timer >= spawn_delay,
	# so with the stock 10s delay the field is never built and every boss below
	# would fall back to a straight line for reasons that are the harness's fault.
	_game.spawn_delay = 0.0
	# The SCOUT timer auto-drops an extractor at the player when it expires, which
	# would move the flow-field goal and switch every enemy to objective targeting
	# partway through a run.
	_game._extraction_auto_placed = true
	# The player must not shoot. Two bosses summon adds; the player kills them, the
	# kills level the player up, the level-up opens the tech draft, and the draft
	# sets Engine.time_scale to 0 -- at which point the boss stops receiving
	# _physics_process entirely and freezes mid-route. The first version of this
	# harness reported "the lich does not reach the objective" for exactly that
	# reason, with the lich sitting motionless 48 of its 60 seconds. `inert` is the
	# same switch main.gd's own DPS harness uses.
	_game.player.inert = true
	_game.player.global_position = PLAYER_POS
	_clear_enemies()
	for _i in range(5):
		await physics_frame
	return true

func _clear_enemies() -> int:
	var n := 0
	if _game.enemies_root == null:
		return 0
	for child in _game.enemies_root.get_children():
		_game.enemies_root.remove_child(child)
		child.queue_free()
		n += 1
	return n

func _spawn_boss(script_path: String, difficulty: float) -> Node:
	"""Exactly what main.gd:_spawn_boss does, minus the placement and net registry."""
	var scene: PackedScene = load(ENEMY_SCENE_PATH)
	var boss = scene.instantiate()
	var boss_script = load(script_path)
	if boss_script == null:
		return null
	boss.set_script(boss_script)
	boss.setup(_game, difficulty)
	_game.enemies_root.add_child(boss)
	return boss

# --- Mode: health -------------------------------------------------------------

func _run_health() -> void:
	# Every number below is read off a boss that has actually run _ready(), not
	# computed from the constants. That distinction is the entire point: the bug
	# this calibrates was invisible to arithmetic because setup()'s result was
	# being discarded by code that runs later.
	_say("mode=health  (elapsed pinned to 0.0; the only variables are difficulty and milestone)")
	_say("horde health mult at the reference: %.4f" % _horde_mult_at(0.0, -1.0))
	var diffs := [1.0, 1.5, 2.0, 3.0]
	var stages := [["none", -1.0], ["50%", 0.50], ["75%", 0.75], ["90%", 0.90]]
	_say("%-14s %-6s %-6s %10s %10s %8s" % ["boss", "diff", "mile", "base", "health", "xbase"])
	for entry in BOSSES:
		var boss_name: String = entry[0]
		for d in diffs:
			for stage in stages:
				var progress: float = stage[1]
				var r := await _measure_health(entry[1], float(d), progress)
				if r.is_empty():
					_fail("%s: could not instantiate" % boss_name)
					continue
				_say("%-14s %-6.2f %-6s %10.0f %10.0f %8.3f" % [
					boss_name, d, str(stage[0]), r["base"], r["health"], r["ratio"]])
				# The calibration point. Anything else is allowed to be bigger.
				if is_equal_approx(float(d), 1.0) and progress < 0.0:
					if abs(float(r["ratio"]) - 3.0) > 0.01:
						_fail("%s at the reference (difficulty 1.0, run start, no milestone) is x%.4f, not x3" % [boss_name, r["ratio"]])
	# await, not a bare call: _report_run_ramp spawns real bosses now, so it is a
	# coroutine. Calling it without await returns at its first suspend and the
	# table silently prints its header and nothing else.
	await _report_run_ramp()

func _set_stage(progress: float) -> void:
	if progress < 0.0:
		_game.extraction_phase = PHASE_SCOUT
		_game.extraction_progress = 0.0
	else:
		_game.extraction_phase = PHASE_SIEGE
		_game.extraction_progress = progress

func _horde_mult_at(elapsed: float, progress: float) -> float:
	_game.elapsed = elapsed
	_set_stage(progress)
	return float(_game.get_enemy_health_mult())

func _measure_health(script_path: String, difficulty: float, progress: float, at_elapsed: float = 0.0) -> Dictionary:
	_game.elapsed = at_elapsed
	_set_stage(progress)
	# The authored base, read off a boss that ran _ready() with every multiplier
	# neutralised, so the ratio below divides by the real number rather than one
	# copied out of the subclass.
	var base := _authored_base(script_path)
	var boss := _spawn_boss(script_path, difficulty)
	if boss == null:
		return {}
	var health := float(boss.max_health)
	_game.enemies_root.remove_child(boss)
	boss.queue_free()
	await physics_frame
	if base <= 0.0:
		return {}
	return {"base": base, "health": health, "ratio": health / base}

func _authored_base(script_path: String) -> float:
	"""max_health as the subclass authored it, with every multiplier forced to 1."""
	var scene: PackedScene = load(ENEMY_SCENE_PATH)
	var boss = scene.instantiate()
	boss.set_script(load(script_path))
	boss._game = _game
	boss._scale_health_mult = 1.0
	boss._scale_damage_mult = 1.0
	boss._scale_speed_mult = 1.0
	_game.enemies_root.add_child(boss)
	var base := float(boss.max_health)
	_game.enemies_root.remove_child(boss)
	boss.queue_free()
	return base

func _report_run_ramp() -> void:
	"""Not asked for, but it is the number that decides whether the calibration
	above matters: get_enemy_health_mult() carries main.gd's run-length ramp
	(+0.25 of ENEMY_HEALTH_BASE_MULT per 30s), and bosses are scheduled by run
	time, so the ramp compounds with authored health that already grows per boss."""
	_say("run-length ramp: horde health mult and spawn difficulty at each scheduled boss")
	var sched := [[300.0, 0], [600.0, 1], [900.0, 2], [1200.0, 3]]
	for row in sched:
		var t: float = row[0]
		var entry: Array = BOSSES[int(row[1])]
		var horde := _horde_mult_at(t, 0.0)
		var diff := float(_game._get_spawn_settings(t).get("difficulty", 1.0))
		# Spawned for real at that run time and read off the instance. An earlier
		# version of this block recomputed the formula inline
		# (base * horde * (1 + (diff-1)*0.45) * 2.5) and so reported the same
		# numbers after the scaling changed underneath it -- a model of the code
		# rather than a measurement of it, which is the exact failure this file
		# exists to avoid.
		var r := await _measure_health(str(entry[1]), diff, 0.0, t)
		if r.is_empty():
			_fail("%s: could not instantiate at t=%.0fs" % [str(entry[0]), t])
			continue
		_say("  t=%6.0fs %-13s horde x%5.2f  difficulty %5.2f  -> health %10.0f (x%.1f base)" % [
			t, str(entry[0]), horde, diff, float(r["health"]), float(r["ratio"])])
	_game.elapsed = 0.0
	_set_stage(-1.0)

# --- Mode: path ---------------------------------------------------------------

func _run_path() -> void:
	_say("mode=path")
	# "reached" is min distance <= REACH_DIST. That can only be satisfied on the
	# far side of the wall: the nearest a body can get while still blocked is the
	# wall's face at WALL_X + WALL_HALF_THICK + AGENT_RADIUS, and that must be
	# further from the goal than REACH_DIST or "reached" would be free.
	var face := WALL_X + WALL_HALF_THICK + AGENT_RADIUS
	if face <= REACH_DIST:
		_fail("fixture: the wall face (%.0fpx) is inside REACH_DIST (%.0fpx) -- 'reached' would be meaningless" % [face, REACH_DIST])
		return
	_build_wall()
	_game.mark_flow_field_dirty()
	# FLOW_REBUILD_INTERVAL is 0.35s and the rebuild is gated on a timer, so a
	# judgement made on the next frame is a judgement about the old field.
	for _i in range(45):
		await physics_frame
	if not await _assert_wall_sealed():
		_fail("fixture is not sealed; no routing result below would mean anything")
		return
	_say("%-14s %8s %8s %9s %9s %8s %9s %7s" % [
		"boss", "reached", "min_d", "lateral", "path_len", "max_step", "cross_y", "flow%"])
	for entry in BOSSES:
		# The lich is the one boss that can leave the fixture without walking, so
		# its first run is reported but not asserted against; the assertion lands
		# on the teleport-suppressed run below. max_step is what tells the two
		# apart: a walker moves ~1px per physics frame, a teleport moves hundreds.
		var is_lich: bool = str(entry[0]) == "lich"
		await _run_one_path(str(entry[0]), str(entry[1]), false, not is_lich)
	await _run_one_path("lich(no-tp)", "res://scripts/boss_lich.gd", true, true)
	await _report_target_is_ignored()

func _report_target_is_ignored() -> void:
	"""A consequence of routing through the flow field, worth stating with a
	number rather than left implicit.

	enemy.gd:_get_move_direction takes a target_pos but overwrites it with
	main.gd's flow direction whenever the field has an answer, and that field's
	BFS goal is the player (or the extractor), never the caller's target. So a
	boss that picked something else -- the siegebreaker prioritises resource
	generators in _find_siege_target -- is steered to the player regardless."""
	_clear_enemies()
	var boss := _spawn_boss("res://scripts/boss_siegebreaker.gd", 1.0)
	if boss == null:
		return
	boss.global_position = BOSS_START
	for _i in range(5):
		_game.pending_picks = 0
		await physics_frame
	# A target 400px BEHIND the boss, directly away from the player.
	var decoy: Vector2 = BOSS_START + Vector2(400.0, 0.0)
	var boss_pos: Vector2 = boss.global_position
	var to_decoy: Vector2 = (decoy - boss_pos).normalized()
	var chosen: Vector2 = boss._get_move_direction(decoy, 1.0 / 60.0)
	var flow: Vector2 = _game.get_flow_direction(boss_pos)
	_say("target-vs-flow: asked for %s, flow says %s, _get_move_direction returned %s (dot with the ask: %+.2f)" % [
		str(to_decoy.round()), str(flow.round()), str(chosen.round()), chosen.dot(to_decoy)])
	_game.enemies_root.remove_child(boss)
	boss.queue_free()
	await physics_frame

func _build_wall() -> void:
	var def: Dictionary = StructureDB.get_def("wall")
	if def.is_empty():
		_fail("no 'wall' structure definition")
		return
	var scene: PackedScene = load(str(def.get("scene", "")))
	if scene == null:
		_fail("wall scene missing")
		return
	var y := -WALL_HALF_SPAN
	while y <= WALL_HALF_SPAN + 0.01:
		var w: Node2D = scene.instantiate()
		w.global_position = Vector2(WALL_X, y)
		_game.buildings_root.add_child(w)
		# configure() is what builds the collider and sets its layer. A wall that
		# skipped it is a sprite: the flow field still sees it (it is in the
		# "buildings" group from _ready) but nothing physically stops a body. That
		# asymmetry is exactly how a fixture reports a clean pass in a broken build.
		w.configure("wall", def, 0)
		# The siegebreaker mortars walls and the colossus slams them. A fixture that
		# demolishes itself mid-run is a different fixture by the end of it.
		w.max_health = 1.0e9
		w.health = w.max_health
		_walls.append(w)
		y += WALL_STEP
	_say("wall: %d tiles at x=%.0f, y=%.0f..%.0f, step %.0f" % [
		_walls.size(), WALL_X, -WALL_HALF_SPAN, WALL_HALF_SPAN, WALL_STEP])

func _assert_wall_sealed() -> bool:
	var ok := true

	# 1. Geometry. Contiguity is a property of the colliders, not of the loop that
	#    placed them: a ring of towers at angular steps snaps onto the 32px grid
	#    and leaves holes, which is how the last fixture came apart.
	var ys: Array = []
	for w in _walls:
		if not is_instance_valid(w):
			ok = false
			_fail("seal/geometry: a wall tile did not survive construction")
			continue
		var shape_node: CollisionShape2D = w.get_node_or_null("Collider/CollisionShape2D")
		var body: StaticBody2D = w.get_node_or_null("Collider")
		if shape_node == null or body == null or not (shape_node.shape is RectangleShape2D):
			ok = false
			_fail("seal/geometry: tile at y=%.0f has no rectangle collider" % w.global_position.y)
			continue
		var size: Vector2 = (shape_node.shape as RectangleShape2D).size
		if abs(size.x - WALL_STEP) > 0.01 or abs(size.y - WALL_STEP) > 0.01:
			ok = false
			_fail("seal/geometry: tile at y=%.0f is %s, not %.0fx%.0f" % [w.global_position.y, str(size), WALL_STEP, WALL_STEP])
		if int(body.collision_layer) != GameLayers.BUILDING:
			ok = false
			_fail("seal/geometry: tile at y=%.0f is on layer %d, not BUILDING" % [w.global_position.y, body.collision_layer])
		if not bool(w.blocks_path):
			ok = false
			_fail("seal/geometry: tile at y=%.0f does not block_path" % w.global_position.y)
		ys.append(w.global_position.y)
	ys.sort()
	for i in range(1, ys.size()):
		if abs(float(ys[i]) - float(ys[i - 1]) - WALL_STEP) > 0.01:
			ok = false
			_fail("seal/geometry: %.0fpx seam between y=%.0f and y=%.0f" % [float(ys[i]) - float(ys[i - 1]), ys[i - 1], ys[i]])

	# 2. Physics. Walk an agent-sized circle down the wall line: every position
	#    inside the span must be inside a building. A 32px hole passes a ray cast
	#    down the middle and admits a 7px enemy, so the ray is not the test.
	var world: World2D = _game.get_world_2d()
	var space := world.direct_space_state
	var probe := CircleShape2D.new()
	probe.radius = AGENT_RADIUS
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = probe
	q.collision_mask = GameLayers.BUILDING
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var holes := 0
	var y := -WALL_HALF_SPAN
	while y <= WALL_HALF_SPAN + 0.01:
		q.transform = Transform2D(0.0, Vector2(WALL_X, y))
		if space.intersect_shape(q, 1).is_empty():
			holes += 1
		y += 1.0
	if holes > 0:
		ok = false
		_fail("seal/physics: %d of %d 1px samples down the wall line hit nothing" % [holes, int(WALL_HALF_SPAN * 2.0) + 1])

	# 3. The pathfinder's own opinion. Building placement, the obstacle grid and
	#    the flow field are three different things; a wall the BFS cannot see is
	#    not a wall, however solid it is to a collider.
	var unblocked := 0
	var samples := 0
	y = -WALL_HALF_SPAN
	while y <= WALL_HALF_SPAN + 0.01:
		samples += 1
		if _game.is_flow_reachable(Vector2(WALL_X, y)):
			unblocked += 1
		y += WALL_STEP * 0.5
	if unblocked > 0:
		ok = false
		_fail("seal/flow: %d of %d wall-line samples are still flow-reachable" % [unblocked, samples])

	# 4. The control. A body with the enemy's collision profile, walking the
	#    straight line the old fixture claimed to have blocked. If this crosses,
	#    nothing else on this page is evidence.
	var control := await _run_control_walker()
	if control["crossed"]:
		ok = false
		_fail("seal/control: a straight-line walker crossed the wall (min_x=%.1f)" % control["min_x"])
	else:
		_say("seal/control: straight-line walker stopped at x=%.1f (wall face is %.1f), lateral=%.1f" % [
			control["min_x"], WALL_X + WALL_HALF_THICK + AGENT_RADIUS, control["lateral"]])
	_say("seal: geometry ok, %d/%d physics samples solid, %d/%d flow samples blocked" % [
		int(WALL_HALF_SPAN * 2.0) + 1 - holes, int(WALL_HALF_SPAN * 2.0) + 1, samples - unblocked, samples])
	return ok

func _run_control_walker() -> Dictionary:
	var walker := CharacterBody2D.new()
	walker.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	walker.collision_layer = GameLayers.ENEMY
	walker.collision_mask = GameLayers.BUILDING
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = AGENT_RADIUS
	cs.shape = circle
	walker.add_child(cs)
	_game.enemies_root.add_child(walker)
	walker.global_position = BOSS_START
	var min_x := BOSS_START.x
	var lateral := 0.0
	for _i in range(SIM_FRAMES):
		var dir := (PLAYER_POS - walker.global_position)
		if dir.length() < 4.0:
			break
		walker.velocity = dir.normalized() * 55.0
		walker.move_and_slide()
		min_x = min(min_x, walker.global_position.x)
		lateral = max(lateral, abs(walker.global_position.y))
		await physics_frame
	var result := {
		"min_x": min_x,
		"lateral": lateral,
		"crossed": min_x < WALL_X - WALL_HALF_THICK,
	}
	_game.enemies_root.remove_child(walker)
	walker.queue_free()
	await physics_frame
	return result

func _run_one_path(label: String, script_path: String, suppress_teleport: bool, assert_walk: bool) -> void:
	_clear_enemies()
	var wall_before := _wall_census()
	_game.player.global_position = PLAYER_POS
	_game.mark_flow_field_dirty()
	for _i in range(30):
		await physics_frame
	var boss := _spawn_boss(script_path, 1.0)
	if boss == null:
		_fail("%s: could not instantiate" % label)
		return
	boss.global_position = BOSS_START

	var min_dist := BOSS_START.distance_to(PLAYER_POS)
	var lateral := 0.0
	var path_len := 0.0
	var prev := BOSS_START
	var cross_y := INF          # |y| at the moment it first got past the wall's far face
	var max_step := 0.0         # largest single-frame displacement: a teleport tell
	var flow_frames := 0
	var frames_run := 0
	var stalled := 0
	var reached := false
	for _i in range(SIM_FRAMES):
		if not is_instance_valid(boss):
			break
		frames_run += 1
		if suppress_teleport:
			boss._teleport_timer = 1.0e9
		# The player is the flow-field goal. Pinning it removes a variable, and
		# keeps a boss from killing the goal it is being measured against.
		_game.player.global_position = PLAYER_POS
		_game.player.health = _game.player.max_health
		# Belt and braces alongside player.inert: a banked level-up opens the tech
		# draft, which sets Engine.time_scale to 0 and stops physics dead.
		_game.pending_picks = 0
		if Engine.time_scale <= 0.0:
			stalled += 1
		await physics_frame
		if not is_instance_valid(boss):
			break
		var p: Vector2 = boss.global_position
		var step := prev.distance_to(p)
		path_len += step
		max_step = max(max_step, step)
		prev = p
		lateral = max(lateral, abs(p.y))
		min_dist = min(min_dist, p.distance_to(PLAYER_POS))
		if _game.get_flow_direction(p) != Vector2.ZERO:
			flow_frames += 1
		if cross_y == INF and p.x < WALL_X - WALL_HALF_THICK:
			cross_y = abs(p.y)
		if _trace() and frames_run % 60 == 0:
			_say("  trace %-12s t=%5.1fs pos=(%7.1f,%7.1f) flow=%s vel=%s spd=%.1f slow=%.2f stun=%.2f state=%s" % [
				label, float(frames_run) / 60.0, p.x, p.y, str(_game.get_flow_direction(p)),
				str(boss.velocity.round()), float(boss.speed), float(boss._slow_multiplier),
				float(boss._stun_timer), _boss_state(boss)])
		if min_dist <= REACH_DIST:
			reached = true
			break

	# How much of the run the flow field actually had an opinion at the boss's
	# position. A low number means the boss was steering on the fallback probe,
	# not on the pathfinder, and a "pass" would be luck.
	var flow_pct := 100.0 * float(flow_frames) / float(max(1, frames_run))
	_say("%-14s %8s %8.1f %9.1f %9.1f %8.1f %9s %6.0f%%" % [
		label,
		"yes" if reached else "NO",
		min_dist,
		lateral,
		path_len,
		max_step,
		("-" if cross_y == INF else "%.0f" % cross_y),
		flow_pct])

	# A frozen clock is not a slow boss. Say so rather than reporting "did not
	# reach" for a run that was never simulated.
	if stalled > 0:
		_fail("%s: Engine.time_scale was 0 for %d of %d frames -- a modal opened mid-run" % [label, stalled, frames_run])
	# A single frame that covers more than a wall thickness is either a teleport or
	# a body punched through the collider. Either way the route it implies is not
	# a walked one, so it is called out rather than folded into path_len.
	if max_step > WALL_HALF_THICK * 2.0:
		_say("  %s: max single-frame step %.0fpx -- this boss did not walk the whole way" % [label, max_step])
	if assert_walk:
		# Routing means it got past the wall AROUND the end, not through the span.
		if cross_y != INF and cross_y <= WALL_HALF_SPAN + WALL_HALF_THICK:
			_fail("%s: reached the far side at |y|=%.0f, inside the wall span -- it went THROUGH" % [label, cross_y])
		if cross_y == INF:
			_fail("%s: never reached the far side of the wall" % label)
		if max_step > WALL_HALF_THICK * 2.0:
			_fail("%s: covered %.0fpx in one frame -- that is not walking" % [label, max_step])
		if not reached:
			_fail("%s: did not reach the objective in %.0fs (closest %.0fpx)" % [label, float(SIM_FRAMES) / 60.0, min_dist])

	var wall_after := _wall_census()
	if wall_after != wall_before:
		_fail("%s: wall changed during the run (%d tiles before, %d after)" % [label, wall_before, wall_after])
	if is_instance_valid(boss):
		_game.enemies_root.remove_child(boss)
		boss.queue_free()
	_clear_enemies()
	await physics_frame

func _boss_state(boss: Node) -> String:
	var bits: Array = []
	for key in ["_is_teleporting", "_is_winding_up_slam", "_summon_timer", "_nova_timer", "_teleport_timer"]:
		if key in boss:
			bits.append("%s=%s" % [key, str(boss.get(key))])
	if "_active_skeletons" in boss:
		bits.append("skels=%d" % boss._active_skeletons.size())
	bits.append("tree=%s dying=%s active=%s over=%s paused=%s php=%.0f" % [
		str(boss.is_inside_tree()), str(boss._is_dying), str(boss.is_boss_active),
		str(_game.game_over), str(paused), float(_game.player.health)])
	return " ".join(bits)

func _wall_census() -> int:
	var n := 0
	for w in _walls:
		if is_instance_valid(w) and float(w.health) > 0.0:
			n += 1
	return n
