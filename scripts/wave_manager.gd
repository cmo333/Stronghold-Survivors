extends Node

const BAT_SWARM_TIME = 120.0
const PLANT_WALL_TIME = 240.0
const ANNOUNCE_LEAD_TIME = 12.0
const BAT_SWARM_INTERVAL = 180.0
const PLANT_WALL_INTERVAL = 240.0

# Raised from 60 now that the budget bug below is fixed - the swarm used to
# overshoot wildly, so the nominal count was never what actually landed. This
# keeps the wall-of-bats moment while capping the real body count.
const BAT_SWARM_COUNT = 72
# Bats enter over a few frames instead of all at once. Instantiating the whole
# swarm in one frame cost ~55ms - a visible stutter. They fly in from off-screen
# and take seconds to converge, so spreading the spawn is invisible in play.
const BAT_SWARM_SPAWN_PER_FRAME = 6
const BAT_SWARM_SPEED_MULT = 1.7
const BAT_SWARM_HEALTH_MULT = 0.5
const BAT_SWARM_DAMAGE_MULT = 0.65
const BAT_SWARM_EDGE_JITTER = 24.0

const PLANT_WALL_SPEED_MULT = 0.6
const PLANT_WALL_HEALTH_MULT = 2.6
const PLANT_WALL_DAMAGE_MULT = 1.2
const PLANT_WALL_SPACING = 80.0
const PLANT_WALL_MIN_COUNT = 18
const PLANT_WALL_MAX_COUNT = 28
const PLANT_WALL_EDGE_OFFSET = 60.0

const BAT_SCENE = preload("res://scenes/enemies/banshee.tscn")
const PLANT_SCENE = preload("res://scenes/enemies/plague_abomination.tscn")

var game: Node2D = null
var ui: CanvasLayer = null
var enemies_root: Node2D = null
var player: Node2D = null
var game_time: float = 0.0
var _next_bat_swarm_time = BAT_SWARM_TIME
var _next_plant_wall_time = PLANT_WALL_TIME
var _bat_swarm_count = 0
var _plant_wall_count = 0
var _pending_bats: Array[Vector2] = []

func setup(game_ref: Node2D, ui_ref: CanvasLayer) -> void:
	game = game_ref
	ui = ui_ref
	if game != null:
		enemies_root = game.enemies_root
		player = game.player

func update(_delta: float, time_sec: float) -> void:
	game_time = time_sec
	_drain_pending_bats()
	_check_events()
	_update_announcement()

func _queue_bats(positions: Array[Vector2]) -> void:
	_pending_bats.append_array(positions)

func _drain_pending_bats() -> void:
	if _pending_bats.is_empty():
		return
	var n = mini(BAT_SWARM_SPAWN_PER_FRAME, _pending_bats.size())
	for i in range(n):
		_spawn_bat(_pending_bats[i])
	_pending_bats = _pending_bats.slice(n)

# Centers each timed wave event targets. Solo: the single player. FFA: every
# living player, so a bat swarm / plague wall descends on EACH person at once
# (the host owns this sim; clients receive the spawned enemies via replication).
func _event_target_centers() -> Array:
	var centers: Array = []
	if game != null and game.has_method("is_ffa") and game.is_ffa():
		# Prefer the game's roster so all participants (incl. remotes/bots) count.
		if "players" in game:
			for pid in game.players.keys():
				var p = game.players[pid]
				if p == null or not is_instance_valid(p):
					continue
				if "inert" in p and p.inert:
					continue
				centers.append(p.global_position)
		if centers.is_empty() and player != null and is_instance_valid(player):
			centers.append(player.global_position)
	else:
		if player != null and is_instance_valid(player):
			centers.append(player.global_position)
	return centers

func _check_events() -> void:
	if game == null or enemies_root == null:
		return
	# Only the simulation authority (solo, or the FFA host) spawns wave enemies;
	# clients receive them via replication. Without this guard a client would
	# double-spawn unregistered bats/plants. The timer state still advances on the
	# authority so the announcement countdown (run by everyone) stays in sync.
	if game.has_method("is_sim_authority") and not game.is_sim_authority():
		return
	# Keep a valid local player reference for solo; FFA pulls centers per-event.
	if player == null or not is_instance_valid(player):
		if game != null and "player" in game:
			player = game.player
	if game_time >= _next_bat_swarm_time:
		_spawn_bat_swarm()
		_bat_swarm_count += 1
		_next_bat_swarm_time = game_time + BAT_SWARM_INTERVAL
	if game_time >= _next_plant_wall_time:
		_spawn_plant_wall()
		_plant_wall_count += 1
		_next_plant_wall_time = game_time + PLANT_WALL_INTERVAL

func _update_announcement() -> void:
	if ui == null or not ui.has_method("show_wave_announcement"):
		return
	var next_time = INF
	next_time = min(_next_bat_swarm_time, _next_plant_wall_time)
	if next_time == INF:
		ui.show_wave_announcement("", 0.0, false)
		return
	var time_left = next_time - game_time
	if time_left <= ANNOUNCE_LEAD_TIME and time_left > 0.0:
		ui.show_wave_announcement("WAVE INCOMING", time_left, true)
	else:
		ui.show_wave_announcement("", 0.0, false)

func _spawn_bat_swarm() -> void:
	var centers := _event_target_centers()
	if centers.is_empty():
		return
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("BAT SWARM!", Color(0.7, 0.3, 1.0), 44, 2.4)
	# Each player gets their OWN swarm so the wave goes for everyone (FFA). The
	# per-player count keeps individual pressure constant instead of splitting one
	# swarm across the map.
	var per_center = int(round(BAT_SWARM_COUNT * _get_event_scalar()))
	var edge_distance = _get_edge_distance()
	var spread = edge_distance
	for center in centers:
		# min(), not the raw budget. The budget is "how many MORE bodies the field
		# can take" (cap + desired - current), so using it directly spawned the swarm
		# up to the cap every time - on a lightly populated field that was 300+ bats
		# instead of the intended count, which is what made the event lag.
		var count = min(per_center, _get_event_spawn_budget(per_center))
		if count <= 0:
			continue
		var positions: Array[Vector2] = []
		for edge in range(4):
			if positions.size() >= count:
				break
			positions.append(_random_edge_position(edge, center, edge_distance, spread))
		while positions.size() < count:
			positions.append(_random_edge_position(randi() % 4, center, edge_distance, spread))
		_queue_bats(positions)

func _spawn_plant_wall() -> void:
	var centers := _event_target_centers()
	if centers.is_empty():
		return
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("PLAGUE WALL!", Color(0.3, 1.0, 0.3), 44, 2.4)
	var edge_distance = _get_edge_distance() + PLANT_WALL_EDGE_OFFSET
	# A wall rises against EACH player (FFA) so no one is spared.
	for center in centers:
		var desired = int(round(_get_plant_wall_count() * _get_event_scalar()))
		var count = min(desired, _get_event_spawn_budget(desired))
		if count <= 0:
			continue
		var side = randi() % 4
		var half_span = (count - 1) * 0.5 * PLANT_WALL_SPACING
		for i in range(count):
			var offset = -half_span + float(i) * PLANT_WALL_SPACING
			var position = _wall_position_for_side(side, center, edge_distance, offset)
			_spawn_plant(position)

func _spawn_bat(position: Vector2) -> void:
	if enemies_root == null:
		return
	var enemy = BAT_SCENE.instantiate()
	enemy.global_position = position
	var difficulty = _get_current_difficulty()
	if enemy.has_method("setup"):
		enemy.setup(game, difficulty)
	enemy.max_health *= BAT_SWARM_HEALTH_MULT
	enemy.health = enemy.max_health
	enemy.speed *= BAT_SWARM_SPEED_MULT
	enemy.attack_damage *= BAT_SWARM_DAMAGE_MULT
	enemy.scream_interval = 999.0
	enemy.scream_radius = 0.0
	enemy.slow_factor = 1.0
	enemy.slow_duration = 0.0
	enemies_root.add_child(enemy)

func _spawn_plant(position: Vector2) -> void:
	if enemies_root == null:
		return
	var enemy = PLANT_SCENE.instantiate()
	enemy.global_position = position
	var difficulty = _get_current_difficulty()
	if enemy.has_method("setup"):
		enemy.setup(game, difficulty)
	enemy.max_health *= PLANT_WALL_HEALTH_MULT
	enemy.health = enemy.max_health
	enemy.speed *= PLANT_WALL_SPEED_MULT
	enemy.attack_damage *= PLANT_WALL_DAMAGE_MULT
	enemies_root.add_child(enemy)

func _random_edge_position(edge: int, center: Vector2, edge_distance: float, spread: float) -> Vector2:
	var edge_offset = edge_distance + randf_range(-BAT_SWARM_EDGE_JITTER, BAT_SWARM_EDGE_JITTER)
	var span = randf_range(-spread, spread)
	match edge:
		0:
			return center + Vector2(span, -edge_offset)
		1:
			return center + Vector2(edge_offset, span)
		2:
			return center + Vector2(span, edge_offset)
		_:
			return center + Vector2(-edge_offset, span)

func _wall_position_for_side(side: int, center: Vector2, edge_distance: float, offset: float) -> Vector2:
	match side:
		0:
			return center + Vector2(offset, -edge_distance)
		1:
			return center + Vector2(edge_distance, offset)
		2:
			return center + Vector2(offset, edge_distance)
		_:
			return center + Vector2(-edge_distance, offset)

func _get_edge_distance() -> float:
	if game == null:
		return 900.0
	return float(game.spawn_radius_max)

func _get_current_difficulty() -> float:
	if game != null and game.has_method("_get_spawn_settings"):
		var settings = game._get_spawn_settings(game_time)
		return float(settings.get("difficulty", 1.0))
	return 1.0

func _get_event_spawn_budget(desired: int) -> int:
	if enemies_root == null or game == null:
		return 0
	var cap = int(game.max_enemies_cap)
	var current = enemies_root.get_child_count()
	var max_allowed = cap + desired
	return max(0, max_allowed - current)

# ============================================
# WAVE TRACKING
# ============================================

func get_current_wave() -> int:
	"""Return the current wave number based on triggered events"""
	var wave = 1 + _bat_swarm_count + _plant_wall_count
	return max(1, wave)

func reset() -> void:
	"""Reset wave manager state for new game"""
	_next_bat_swarm_time = BAT_SWARM_TIME
	_next_plant_wall_time = PLANT_WALL_TIME
	_bat_swarm_count = 0
	_plant_wall_count = 0
	_pending_bats.clear()
	game_time = 0.0

func _get_plant_wall_count() -> int:
	var line_length = _get_edge_distance() * 2.0
	var count = int(round(line_length / PLANT_WALL_SPACING))
	return int(clamp(float(count), float(PLANT_WALL_MIN_COUNT), float(PLANT_WALL_MAX_COUNT)))

func _get_event_scalar() -> float:
	var time_scalar = clamp(game_time / 600.0, 0.0, 1.0)
	var wave_scalar = clamp((_bat_swarm_count + _plant_wall_count) * 0.05, 0.0, 0.35)
	var scalar = 1.0 + time_scalar * 0.6 + wave_scalar
	# Timed events ride the same global balance knob as the regular horde.
	if game != null and game.has_method("difficulty_count_mult"):
		scalar *= float(game.difficulty_count_mult())
	return scalar
