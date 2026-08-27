extends Node

# Host-only AI driver for an FFA bot player. One controller is attached per bot in
# `main._setup_players()`. Each frame (on the host) it writes a desired direction
# into the bot player's `bot_move_vector`; the player script reads that instead of
# hardware input (see player._get_move_vector). The host already owns all bot
# damage/economy/scoring, so the bot's collected resources flow into the normal
# pickup -> add_resources(owner_id) path and onto the scoreboard.
#
# Behaviour priority (cheap, no pathfinding):
#   1) Steer toward the nearest visible pickup (collecting drives the win metric).
#   2) Otherwise close on the nearest enemy so the auto-fire can farm drops.
#   3) Otherwise wander toward an undepleted resource zone, repicking periodically.
# Light separation keeps bots from stacking on the same target.

var _game: Node = null
var _bot: CharacterBody2D = null

const PICKUP_SCAN_RADIUS := 520.0      # only chase loot we could plausibly reach
const ENGAGE_RANGE := 460.0            # roughly the player's attack_range
const WANDER_REPICK_MIN := 2.5
const WANDER_REPICK_MAX := 5.0
const ARRIVE_EPSILON := 48.0

var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _think_accum: float = 0.0
var _think_interval: float = 0.12      # re-evaluate targets ~8x/sec, not every frame
var _cached_dir: Vector2 = Vector2.ZERO

# --- Building AI ---------------------------------------------------------
# Bots spend some of their collected resources on towers near their position so
# they defend themselves like a real player would. Host-authoritative: the tower
# is added to the scene tree (auto-replicated) tagged with the bot's owner_id.
const BOT_TOWER_IDS := ["arrow_turret", "cannon_tower", "tesla_tower"]
const BOT_BUILD_INTERVAL := 4.0        # attempt to build at most this often
const BOT_BUILD_RESERVE := 25          # keep some resources for emergencies
const BOT_BUILD_MIN_DIST := 120.0      # don't drop towers on top of itself
const BOT_BUILD_MAX_DIST := 260.0
const BOT_BUILD_PLACE_ATTEMPTS := 6    # random candidate spots per build tick
var _build_accum: float = 0.0

func setup(game: Node, bot_player: CharacterBody2D) -> void:
	_game = game
	_bot = bot_player

func _physics_process(delta: float) -> void:
	# Host-authoritative only. Clients never run bot AI (bots are host-owned).
	if _game == null or not is_instance_valid(_bot):
		return
	if _game.has_method("is_host") and not _game.is_host():
		return
	if _game.has_method("is_ffa") and not _game.is_ffa():
		return
	if "inert" in _bot and _bot.inert:
		_bot.bot_move_vector = Vector2.ZERO
		return

	_think_accum += delta
	if _think_accum >= _think_interval:
		_think_accum = 0.0
		_cached_dir = _decide_direction(delta)
	_bot.bot_move_vector = _cached_dir

	_build_accum += delta
	if _build_accum >= BOT_BUILD_INTERVAL:
		_build_accum = 0.0
		_try_build()

# Pick the most expensive tower the bot can comfortably afford (keeping a reserve)
# and try to place it at a clear spot a short distance from the bot.
func _try_build() -> void:
	if _game == null or not is_instance_valid(_bot):
		return
	if not ("build_manager" in _game) or _game.build_manager == null:
		return
	if not _game.build_manager.has_method("bot_place_tower"):
		return
	var owner_id: int = int(_bot.peer_id)
	var tower_id := _choose_tower(owner_id)
	if tower_id == "":
		return
	var origin: Vector2 = _bot.global_position
	for _i in range(BOT_BUILD_PLACE_ATTEMPTS):
		var angle := randf() * TAU
		var dist := randf_range(BOT_BUILD_MIN_DIST, BOT_BUILD_MAX_DIST)
		var candidate := origin + Vector2.RIGHT.rotated(angle) * dist
		if _game.build_manager.bot_place_tower(owner_id, candidate, tower_id):
			return

# Pick a random tower from BOT_TOWER_IDS that the bot can afford while keeping a
# small reserve, so each bot builds a varied mix. Returns "" if it can't afford any.
func _choose_tower(owner_id: int) -> String:
	if not (_game.has_method("can_afford")):
		return ""
	var affordable: Array = []
	for tid in BOT_TOWER_IDS:
		var def = StructureDB.get_def(tid)
		if def.is_empty():
			continue
		var tier_data = StructureDB.get_tier(def, 0)
		var cost := int(tier_data.get("cost", 0))
		if _game.can_afford(cost + BOT_BUILD_RESERVE, owner_id):
			affordable.append(tid)
	if affordable.is_empty():
		return ""
	return affordable[randi() % affordable.size()]

func _decide_direction(delta: float) -> Vector2:
	var origin: Vector2 = _bot.global_position

	# 1) Nearest pickup within scan radius.
	var pickup := _nearest_in_group("pickups", origin, PICKUP_SCAN_RADIUS)
	if pickup != null:
		return _steer_to(origin, pickup.global_position)

	# 2) Nearest enemy: close to engage range so auto-fire can farm drops.
	var enemy := _nearest_in_group("enemies", origin, INF)
	if enemy != null:
		var to_enemy: Vector2 = enemy.global_position - origin
		if to_enemy.length() > ENGAGE_RANGE:
			return _steer_to(origin, enemy.global_position)
		# In range already: drift slightly so we don't freeze on top of it.
		return _orbit(origin, enemy.global_position)

	# 3) Wander toward an undepleted resource zone, repicking periodically.
	_wander_timer -= delta
	if _wander_timer <= 0.0 or origin.distance_to(_wander_target) <= ARRIVE_EPSILON:
		_pick_wander_target(origin)
	return _steer_to(origin, _wander_target)

func _steer_to(origin: Vector2, target: Vector2) -> Vector2:
	var dir: Vector2 = target - origin
	if dir.length() < 0.001:
		return Vector2.ZERO
	return (dir.normalized() + _separation(origin) * 0.4).normalized()

func _orbit(origin: Vector2, target: Vector2) -> Vector2:
	var radial: Vector2 = (origin - target)
	if radial.length() < 0.001:
		radial = Vector2.RIGHT
	# Tangent to keep mobile while staying in attack range.
	return radial.normalized().rotated(PI * 0.5)

# Soft push away from other (alive) players so bots don't pile on one target.
func _separation(origin: Vector2) -> Vector2:
	var push := Vector2.ZERO
	if _game == null or not ("players" in _game):
		return push
	for pid in _game.players.keys():
		var other = _game.players[pid]
		if other == null or other == _bot or not is_instance_valid(other):
			continue
		var d: float = origin.distance_to(other.global_position)
		if d > 0.001 and d < 96.0:
			push += (origin - other.global_position) / d
	return push

func _pick_wander_target(origin: Vector2) -> void:
	_wander_timer = randf_range(WANDER_REPICK_MIN, WANDER_REPICK_MAX)
	# Prefer an undepleted resource zone; fall back to a nearby random point.
	if "resource_zones" in _game:
		var best: Node2D = null
		var best_d := INF
		for z in _game.resource_zones:
			if z == null or not is_instance_valid(z):
				continue
			if z.has_method("get_multiplier") and z.get_multiplier() <= 1.0:
				continue   # depleted zone, skip
			var d: float = origin.distance_squared_to(z.global_position)
			if d < best_d:
				best_d = d
				best = z
		if best != null:
			_wander_target = best.global_position + Vector2(randf_range(-120, 120), randf_range(-120, 120))
			return
	_wander_target = origin + Vector2(randf_range(-400, 400), randf_range(-400, 400))

func _nearest_in_group(group: String, origin: Vector2, max_radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var max_sq: float = INF
	if max_radius != INF:
		max_sq = max_radius * max_radius
	for n in get_tree().get_nodes_in_group(group):
		if n == null or not is_instance_valid(n) or not (n is Node2D):
			continue
		var d: float = origin.distance_squared_to((n as Node2D).global_position)
		if d < best_d and d <= max_sq:
			best_d = d
			best = n
	return best
