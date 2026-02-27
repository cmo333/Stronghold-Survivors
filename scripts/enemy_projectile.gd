extends Area2D

# Lightweight projectile fired by enemies (e.g. Spitter).
# Hits the player, not other enemies.

var direction = Vector2.RIGHT
var speed = 320.0
var damage = 5.0
var max_range = 300.0
var _travelled = 0.0
var _game: Node = null
var _last_position = Vector2.ZERO
var _trail_distance = 0.0
var _trail_step = 12.0

func setup(game_ref: Node, dir: Vector2, proj_speed: float, dmg: float, proj_range: float) -> void:
	_game = game_ref
	direction = dir.normalized()
	speed = proj_speed
	damage = dmg
	max_range = proj_range

func _ready() -> void:
	collision_layer = GameLayers.PROJECTILE
	collision_mask = GameLayers.PLAYER | GameLayers.ALLY | GameLayers.BUILDING
	body_entered.connect(_on_body_entered)
	_last_position = global_position

func _physics_process(delta: float) -> void:
	var step = speed * delta
	var next_pos = global_position + direction * step
	var hit = _raycast_hit(global_position, next_pos)
	if not hit.is_empty():
		_handle_hit(hit.get("collider"), hit.get("position", next_pos))
		return
	global_position = next_pos
	_travelled += step
	_spawn_trail()
	if _travelled >= max_range:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_handle_hit(body, global_position)

func _raycast_hit(from: Vector2, to: Vector2) -> Dictionary:
	var space = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	params.exclude = [self]
	params.collide_with_areas = true
	params.collide_with_bodies = true
	return space.intersect_ray(params)

func _handle_hit(body: Node, hit_pos: Vector2) -> void:
	if body == null:
		return
	var target = _resolve_hit_target(body)
	if target == null:
		return
	if target.is_in_group("buildings"):
		queue_free()
		return
	if target.is_in_group("player") or target.is_in_group("allies"):
		if target.has_method("take_damage"):
			target.take_damage(damage, hit_pos, true)
		queue_free()

func _resolve_hit_target(body: Node) -> Node:
	if body.is_in_group("player") or body.is_in_group("allies") or body.is_in_group("buildings"):
		return body
	var parent = body.get_parent()
	if parent != null and parent.is_in_group("buildings"):
		return parent
	return body

func _spawn_trail() -> void:
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	var moved = global_position.distance_to(_last_position)
	_trail_distance += moved
	if _trail_distance < _trail_step:
		_last_position = global_position
		return
	_trail_distance = 0.0
	var trail_color = Color(1.0, 0.35, 0.25).lerp(Color.WHITE, 0.15)
	var trail_velocity = -direction * speed * 0.08
	_game.spawn_glow_particle(global_position, trail_color, 5.0, 0.3, trail_velocity, 1.6, 0.75, 1.0, 2)
	_last_position = global_position
