extends Node

const BAT_SWARM_TIME = 120.0
const PLANT_WALL_TIME = 240.0
const ANNOUNCE_LEAD_TIME = 12.0
const BAT_SWARM_INTERVAL = 180.0
const PLANT_WALL_INTERVAL = 240.0

const BAT_SWARM_COUNT = 60
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

func setup(game_ref: Node2D, ui_ref: CanvasLayer) -> void:
	game = game_ref
	ui = ui_ref
	if game != null:
		enemies_root = game.enemies_root
		player = game.player

func update(_delta: float, time_sec: float) -> void:
	game_time = time_sec
	_check_events()
	_update_announcement()

func _check_events() -> void:
	if game == null or player == null or enemies_root == null:
		return
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
	var count = _get_event_spawn_budget(int(round(BAT_SWARM_COUNT * _get_event_scalar())))
	if count <= 0:
		return
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("BAT SWARM!", Color(0.7, 0.3, 1.0), 44, 2.4)
	var center = player.global_position
	var edge_distance = _get_edge_distance()
	var spread = edge_distance
	var spawned = 0
	for edge in range(4):
		if spawned >= count:
			break
		var position = _random_edge_position(edge, center, edge_distance, spread)
		_spawn_bat(position)
		spawned += 1
	while spawned < count:
		var edge = randi() % 4
		var position = _random_edge_position(edge, center, edge_distance, spread)
		_spawn_bat(position)
		spawned += 1

func _spawn_plant_wall() -> void:
	var desired = int(round(_get_plant_wall_count() * _get_event_scalar()))
	var count = min(desired, _get_event_spawn_budget(desired))
	if count <= 0:
		return
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("PLAGUE WALL!", Color(0.3, 1.0, 0.3), 44, 2.4)
	var center = player.global_position
	var edge_distance = _get_edge_distance() + PLANT_WALL_EDGE_OFFSET
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
	game_time = 0.0

func _get_plant_wall_count() -> int:
	var line_length = _get_edge_distance() * 2.0
	var count = int(round(line_length / PLANT_WALL_SPACING))
	return int(clamp(float(count), float(PLANT_WALL_MIN_COUNT), float(PLANT_WALL_MAX_COUNT)))

func _get_event_scalar() -> float:
	var time_scalar = clamp(game_time / 600.0, 0.0, 1.0)
	var wave_scalar = clamp((_bat_swarm_count + _plant_wall_count) * 0.05, 0.0, 0.35)
	return 1.0 + time_scalar * 0.6 + wave_scalar
