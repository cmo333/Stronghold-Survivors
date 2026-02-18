extends Control

const MAP_SIZE = Vector2(140, 140)
const MAP_MARGIN = 10.0
const BG_COLOR = Color(0.1, 0.1, 0.1, 0.6)
const BORDER_COLOR = Color(1.0, 1.0, 1.0, 1.0)

const PLAYER_COLOR = Color(1.0, 1.0, 1.0)
const ENEMY_COLOR = Color(1.0, 0.2, 0.2)
const ELITE_COLOR = Color(1.0, 1.0, 0.0)
const TOWER_COLOR = Color(0.0, 1.0, 1.0)
const GENERATOR_COLOR = Color(0.2, 1.0, 0.2)
const BOSS_COLOR = Color(1.0, 0.2, 1.0)
const CORE_COLOR = Color(1.0, 1.0, 1.0)
const ZONE_COLOR = Color(1.0, 0.8, 0.1)
const ZONE_DEPLETED_COLOR = Color(0.4, 0.4, 0.4)

const TOWER_IDS = ["arrow_turret", "cannon_tower", "tesla_tower"]
const GENERATOR_ID = "resource_generator"
const CORE_ID = "stronghold_core"

var _game: Node2D = null
var _player: Node2D = null
var _redraw_timer: Timer = null
var _world_radius: float = 900.0
var _enemy_draw_radius: float = 900.0
var _max_enemy_dots: int = 200

func _ready() -> void:
	custom_minimum_size = MAP_SIZE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_right = -MAP_MARGIN
	offset_top = MAP_MARGIN
	offset_left = offset_right - MAP_SIZE.x
	offset_bottom = offset_top + MAP_SIZE.y
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_redraw_timer = Timer.new()
	_redraw_timer.wait_time = 0.2
	_redraw_timer.one_shot = false
	_redraw_timer.autostart = true
	add_child(_redraw_timer)
	_redraw_timer.timeout.connect(_on_redraw_timer)

func setup(game_ref: Node2D) -> void:
	_game = game_ref
	_refresh_refs()
	if _game != null:
		var spawn_radius = float(_game.get("spawn_radius_max"))
		if spawn_radius > 0.0:
			_world_radius = spawn_radius
			_enemy_draw_radius = spawn_radius

func _on_redraw_timer() -> void:
	queue_redraw()

func _refresh_refs() -> void:
	if _game == null:
		return
	var maybe_player = _game.get("player")
	if maybe_player is Node2D:
		_player = maybe_player

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG_COLOR, true)
	draw_rect(rect, BORDER_COLOR, false, 1.0)

	if _player == null or not is_instance_valid(_player):
		_refresh_refs()
	if _player == null or not is_instance_valid(_player):
		return

	if _world_radius <= 0.0:
		return
	var center = rect.size * 0.5
	var inset = 6.0
	var map_radius = min(rect.size.x, rect.size.y) * 0.5 - inset
	var scale = map_radius / _world_radius

	_draw_zones(center, scale)
	_draw_buildings(center, scale)
	_draw_enemies(center, scale)
	draw_circle(center, 4.0, PLAYER_COLOR)

func _draw_zones(center: Vector2, scale: float) -> void:
	if _game == null:
		return
	var zones = _game.get("resource_zones")
	if zones == null:
		return
	for zone in zones:
		if zone == null or not is_instance_valid(zone):
			continue
		var offset = zone.global_position - _player.global_position
		var local = center + offset * scale
		var zone_r = zone.ZONE_RADIUS * scale
		# Clamp to minimap bounds but still draw partial circles
		if local.x < -zone_r or local.x > size.x + zone_r:
			continue
		if local.y < -zone_r or local.y > size.y + zone_r:
			continue
		var is_depleted = zone.get("_is_depleted")
		var color = ZONE_DEPLETED_COLOR if is_depleted else ZONE_COLOR
		var alpha = 0.15 if is_depleted else 0.5
		draw_arc(local, zone_r, 0, TAU, 24, Color(color.r, color.g, color.b, alpha), 1.5)
		if not is_depleted:
			draw_circle(local, zone_r, Color(color.r, color.g, color.b, alpha * 0.2))

func _draw_buildings(center: Vector2, scale: float) -> void:
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building == null or not is_instance_valid(building):
			continue
		var id = str(building.get("structure_id"))
		if id == "":
			continue
		if id != GENERATOR_ID and id != CORE_ID and not TOWER_IDS.has(id):
			continue
		var local = _world_to_minimap(building.global_position, center, scale)
		if local == null:
			continue
		if id == CORE_ID:
			_draw_square(local, 5.0, CORE_COLOR)
		elif id == GENERATOR_ID:
			draw_circle(local, 3.0, GENERATOR_COLOR)
		else:
			draw_circle(local, 3.0, TOWER_COLOR)

func _draw_enemies(center: Vector2, scale: float) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var max_dist_sq = _enemy_draw_radius * _enemy_draw_radius
	var drawn = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset = enemy.global_position - _player.global_position
		if offset.length_squared() > max_dist_sq:
			continue
		var local = _world_offset_to_minimap(offset, center, scale)
		if local == null:
			continue
		if _is_boss(enemy):
			draw_circle(local, 5.0, BOSS_COLOR)
		elif "is_elite" in enemy and enemy.is_elite:
			draw_circle(local, 3.0, ELITE_COLOR)
		else:
			draw_circle(local, 2.0, ENEMY_COLOR)
		drawn += 1
		if drawn >= _max_enemy_dots:
			break

func _world_to_minimap(world_pos: Vector2, center: Vector2, scale: float) -> Variant:
	var offset = world_pos - _player.global_position
	return _world_offset_to_minimap(offset, center, scale)

func _world_offset_to_minimap(offset: Vector2, center: Vector2, scale: float) -> Variant:
	if offset.length() > _world_radius:
		return null
	return center + offset * scale

func _is_boss(enemy: Node) -> bool:
	if "boss_wave" in enemy or "boss_name" in enemy:
		return true
	var script = enemy.get_script()
	if script == null:
		return false
	var path = script.resource_path
	return path.find("boss_") != -1

func _draw_square(pos: Vector2, size: float, color: Color) -> void:
	var half = size * 0.5
	draw_rect(Rect2(pos - Vector2(half, half), Vector2(size, size)), color, true)
