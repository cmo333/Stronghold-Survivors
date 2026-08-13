extends SceneTree
# An ally in a horde must be fighting, and must never be swinging at a corpse.
#
# WHAT THIS GUARDS, AND WHY IT IS NOT COVERED ELSEWHERE:
#
#   ally.gd caches its target and only searches for a new one every
#   RETARGET_INTERVAL. That is worth 23x fewer distance checks a frame, and it
#   introduces exactly one way to be wrong: holding a target that has stopped
#   being worth attacking. An enemy plays out its death animation before it
#   frees itself, so is_instance_valid() stays TRUE while it is dying.
#
#   The subtle half -- and the reason this file exists -- is that revalidating
#   the held target is not enough on its own. Dropping a dying target and then
#   re-picking from a candidate list that still contains it selects the same
#   corpse again, because it is still the nearest thing. The guard reads as
#   working while changing nothing. A probe caught that in the first draft of
#   the change; the filter has to be applied in the SEARCH as well.
#
# Negative control, confirmed: reverting _find_target's filter to a bare
# is_instance_valid() check -- leaving the revalidation intact -- makes the
# stale-target case report FAIL. A fixture not shown to fail on the broken code
# has not been shown to test anything.
#
# Also asserts every ally standing in a horde actually holds a target, because
# a version that got cheap by not acquiring targets at all would otherwise look
# like a win.
#
# load(), not preload(): a SceneTree script's _initialize() runs before the
# autoloads are attached, and ally.gd/enemy.gd reference them at compile time,
# so preloading here caches the scene with NO SCRIPT and the probe measures
# nothing at all.

const ALLIES := 16
const ENEMIES := 440
const FRAMES := 120

var _world: Node2D = null
var _allies: Array = []
var _frames := 0
var _built := false
var _phys_frames := 0
var _stub: GameStub = null
var _enemies: Array = []

class GameStub extends Node:
	# Transcribed from main.gd (ENEMY_GRID_CELL, _grid_cell, _rebuild_enemy_grid,
	# get_enemies_near) so the grid half of the measurement is against the real
	# bucketing. Set `caches_live = false` to measure the group-scan fallback.
	const ENEMY_GRID_CELL := 160.0
	var player: Node2D = null
	var caches_live: bool = true
	var cached_enemies: Array = []
	var _enemy_grid: Dictionary = {}

	func _grid_cell(pos: Vector2) -> Vector2i:
		return Vector2i(int(floor(pos.x / ENEMY_GRID_CELL)), int(floor(pos.y / ENEMY_GRID_CELL)))

	func rebuild(enemies: Array) -> void:
		cached_enemies = enemies
		_enemy_grid.clear()
		for e in cached_enemies:
			if e == null or not is_instance_valid(e):
				continue
			var c := _grid_cell(e.global_position)
			if not _enemy_grid.has(c):
				_enemy_grid[c] = []
			_enemy_grid[c].append(e)

	func get_cached_enemies() -> Array:
		return cached_enemies if caches_live else []

	func get_enemies_near(pos: Vector2, radius: float) -> Array:
		if _enemy_grid.is_empty():
			return cached_enemies
		var out: Array = []
		var span := int(ceil(radius / ENEMY_GRID_CELL))
		var base := _grid_cell(pos)
		for dy in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var c := base + Vector2i(dx, dy)
				var bucket = _enemy_grid.get(c)
				if bucket != null:
					out.append_array(bucket)
		return out

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_build()
		return false
	if not _built:
		return false
	if _frames < 6 + FRAMES:
		return false
	_report()
	return true

func _physics_process(_delta: float) -> bool:
	if _built and _frames >= 6:
		_phys_frames += 1
	return false

func _build() -> void:
	_world = Node2D.new()
	root.add_child(_world)

	var stub := GameStub.new()
	stub.caches_live = OS.get_environment("ALLY_PROBE_CACHES") != "0"
	root.add_child(stub)
	_stub = stub

	var player := Node2D.new()
	player.global_position = Vector2.ZERO
	_world.add_child(player)
	stub.player = player

	# Horde spread over a field the allies sit inside, so a realistic fraction
	# of it falls inside aggro_range rather than all or none of it.
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	for i in range(ENEMIES):
		var e = enemy_scene.instantiate()
		if e.get_script() == null:
			print("[ALLY-PROBE] FAIL: enemy instantiated with no script")
			quit(1)
			return
		var a := TAU * float(i) / float(ENEMIES)
		var r := 120.0 + 640.0 * float(i % 37) / 37.0
		e.global_position = Vector2(cos(a), sin(a)) * r
		e.max_health = 1.0e9
		e.health = 1.0e9
		e.speed = 0.0
		_world.add_child(e)
		e.set_physics_process(false)
		_enemies.append(e)

	var ally_scene: PackedScene = load("res://scenes/allies/ally_unit.tscn")
	for i in range(ALLIES):
		var al = ally_scene.instantiate()
		if al.get_script() == null:
			print("[ALLY-PROBE] FAIL: ally instantiated with no script")
			quit(1)
			return
		var a := TAU * float(i) / float(ALLIES)
		al.global_position = Vector2(cos(a), sin(a)) * 140.0
		_world.add_child(al)
		al.setup(stub, {})
		_allies.append(al)
	stub.rebuild(_enemies)
	_built = true

func _report() -> void:
	var pf: int = max(1, _phys_frames)
	# How many allies actually hold a target -- a "cheap" version that stopped
	# acquiring targets would also post a low count, so this has to be reported
	# alongside it or the number means nothing.
	print("[ALLY-PROBE] allies=%d enemies=%d physics_frames=%d" % [ALLIES, ENEMIES, pf])
	var engaged := 0
	for al in _allies:
		if is_instance_valid(al) and al._target != null:
			engaged += 1
	print("[ALLY-PROBE] allies holding a target: %d/%d" % [engaged, ALLIES])
	if engaged < ALLIES:
		print("[ALLY-PROBE] FAIL: an ally standing in a horde is not fighting")
		quit(1)
		return
	print("[ALLY-PROBE] caches_live=%s" % str(_stub.caches_live))
	_check_stale_target()

# The trap this change could have walked into: a re-pick timer with no per-frame
# revalidation leaves an ally attacking a corpse for up to RETARGET_INTERVAL.
func _check_stale_target() -> void:
	var subject = null
	for al in _allies:
		if is_instance_valid(al) and al._target != null:
			subject = al
			break
	if subject == null:
		print("[ALLY-PROBE] stale-target check: INCONCLUSIVE, no ally held a target")
		quit(1)
		return
	var victim = subject._target
	# Mark it dying WITHOUT freeing it, which is the window the naive version
	# gets wrong: still a valid instance, still in range, worth nothing.
	victim._is_dying = true
	var kept: bool = subject._target_still_valid()
	var reacquired = subject._acquire_target(0.0)
	var ok: bool = (not kept) and reacquired != victim
	print("[ALLY-PROBE] stale-target check: dying target still considered valid=%s, re-picked to a different enemy=%s -> %s" % [
		str(kept), str(reacquired != victim), "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)
