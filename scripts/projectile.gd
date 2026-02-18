extends Area2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")

var direction = Vector2.RIGHT
var speed = 500.0
var damage = 8.0
var max_range = 260.0
var explosion_radius = 0.0
var _travelled = 0.0
var _game: Node = null
var pierce = 0
var remaining_pierce = 0
var slow_factor = 1.0
var slow_duration = 0.0
var damage_type: String = "normal"
var burn_damage = 5.0
var burn_duration = 3.0
var _last_position = Vector2.ZERO
var _trail_timer = 0.0
var _has_impacted = false
var _trail: Node2D = null
@onready var sprite: AnimatedSprite2D = $Body

func setup(game_ref: Node, dir: Vector2, proj_speed: float, dmg: float, range: float, explode_radius: float, pierce_count: int = 0, slow_factor_in: float = 1.0, slow_duration_in: float = 0.0, damage_type_in: String = "normal") -> void:
	_game = game_ref
	direction = dir.normalized()
	speed = proj_speed
	damage = dmg
	max_range = range
	explosion_radius = explode_radius
	pierce = max(0, pierce_count)
	remaining_pierce = pierce
	slow_factor = slow_factor_in
	slow_duration = slow_duration_in
	damage_type = damage_type_in

func _ready() -> void:
	collision_layer = GameLayers.PROJECTILE
	collision_mask = GameLayers.ENEMY
	_last_position = global_position
	if sprite != null:
		sprite.scale = Vector2.ONE * 1.5
	# Spawn trail immediately
	_spawn_trail()

func _physics_process(delta: float) -> void:
	if _has_impacted:
		return
	
	var step = speed * delta
	var from = global_position
	var to = from + direction * step
	
	# Motion blur - stretch sprite based on velocity
	_update_motion_blur(step)
	
	# Spawn particle trail
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_spawn_trail()
		_trail_timer = FeedbackConfig.PROJECTILE_TRAIL_INTERVAL
	
	var hit = _raycast_hit(from, to)
	if hit:
		var hit_pos = hit.position
		_travelled += from.distance_to(hit_pos)
		global_position = hit_pos
		if not _handle_hit(hit.collider):
			return
	else:
		global_position = to
		_travelled += step
	if _travelled >= max_range:
		_explode_if_needed()
		queue_free()

func _update_motion_blur(velocity_magnitude: float) -> void:
	if sprite == null:
		return
	# Stretch sprite in direction of movement
	var stretch = 1.0 + (velocity_magnitude / speed) * (FeedbackConfig.PROJECTILE_MOTION_BLUR_STRETCH - 1.0)
	sprite.scale = Vector2(stretch, 1.0 / stretch) * 1.5
	sprite.rotation = direction.angle()

func _spawn_trail() -> void:
	# Use FX Manager for high-quality trail if available
	if _game != null and _game.fx_manager != null:
		_trail = _game.fx_manager.spawn_projectile_trail(self, damage_type)
	else:
		# Fallback to simple glow particles
		if _game == null or not _game.has_method("spawn_glow_particle"):
			return
		var trail_color = Color(1.0, 0.9, 0.7, 0.6)
		if damage_type == "fire":
			trail_color = Color(1.0, 0.5, 0.2, 0.6)
		elif damage_type == "ice":
			trail_color = Color(0.5, 0.8, 1.0, 0.6)
		_game.spawn_glow_particle(global_position, trail_color, 4.0, 0.15, Vector2.ZERO, 1.2, 0.5, 0.8, -1)

func _handle_hit(body: Node) -> bool:
	if body == null or not body.is_in_group("enemies"):
		return true
	
	_has_impacted = true
	
	# Impact flash
	_spawn_impact_flash()
	
	# Cleanup trail immediately on impact
	if _trail != null and is_instance_valid(_trail):
		_trail.queue_free()
		_trail = null
	
	if explosion_radius > 0.0:
		_trigger_explosion()
		queue_free()
		return false
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position, true, true, damage_type)
		# Track damage dealt
		if _game != null and _game.has_method("track_damage_dealt"):
			_game.track_damage_dealt(damage)
	if slow_factor < 0.99 and body.has_method("apply_slow"):
		body.apply_slow(get_instance_id(), slow_factor, slow_duration)
	if remaining_pierce > 0:
		remaining_pierce -= 1
		_has_impacted = false
		return true
	queue_free()
	return false

func _spawn_impact_flash() -> void:
	# Use FX Manager for enhanced impact effects
	if _game != null and _game.fx_manager != null:
		var is_crit = false  # Could be passed in from damage calculation
		_game.fx_manager.spawn_impact(global_position, damage_type, is_crit, direction)
	
	# Also spawn legacy glow particle
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	var flash_color = Color(1.0, 1.0, 0.8, 0.9)
	if damage_type == "fire":
		flash_color = Color(1.0, 0.6, 0.2, 0.9)
	elif damage_type == "ice":
		flash_color = Color(0.7, 0.9, 1.0, 0.9)
	_game.spawn_glow_particle(global_position, flash_color, 8.0, FeedbackConfig.IMPACT_SPARK_LIFETIME, Vector2.ZERO, 2.0, 0.0, 0.5, 2)

func _explode_if_needed() -> void:
	if explosion_radius <= 0.0:
		return
	_trigger_explosion()

func _trigger_explosion() -> void:
	if not is_inside_tree():
		return
	if _game != null:
		if _game.has_method("damage_enemies_in_radius"):
			_game.damage_enemies_in_radius(global_position, explosion_radius, damage, 1.0, damage_type)
		if _game.has_method("spawn_fx"):
			_game.spawn_fx("explosion", global_position)
		if _game.has_method("shake_camera"):
			_game.shake_camera(FeedbackConfig.SCREEN_SHAKE_EXPLOSION)
		
		# Handle cluster bombs (T3 cannon tower)
		var has_cluster = get_meta("cluster_bombs", false)
		var has_burn = get_meta("burn_effect", false)
		
		if has_cluster and _game != null:
			# Spawn 3 secondary explosions in random directions
			for i in range(3):
				var angle = randf() * TAU
				var dist = explosion_radius * (0.5 + randf() * 0.5)
				var offset = Vector2(cos(angle), sin(angle)) * dist
				var cluster_pos = global_position + offset
				
				# Smaller secondary explosion
				var cluster_damage = damage * 0.6
				var cluster_radius = explosion_radius * 0.7
				
				# Delayed cluster explosion
				var timer = get_tree().create_timer(0.1 * (i + 1))
				timer.timeout.connect(func():
					if not is_instance_valid(self) or not is_inside_tree():
						return
					if _game == null:
						return
					
					if _game.has_method("damage_enemies_in_radius"):
						_game.damage_enemies_in_radius(cluster_pos, cluster_radius, cluster_damage, 0.9, "fire" if has_burn else damage_type)
					if _game.has_method("spawn_fx"):
						_game.spawn_fx("explosion", cluster_pos)
						# Extra burn FX
						if has_burn:
							_game.spawn_fx("fire_burst", cluster_pos)
					
					# Apply burn to enemies
					if has_burn:
						var burn_enemies = _get_enemies_in_radius(cluster_pos, cluster_radius * 1.2)
						for enemy in burn_enemies:
							if enemy.has_method("apply_burn"):
								enemy.apply_burn(get_instance_id(), burn_damage, burn_duration)
							elif enemy.has_method("take_damage"):
								# Fallback: apply damage over time manually
								for j in range(3):
									if not is_instance_valid(self) or not is_inside_tree():
										return
									await get_tree().create_timer(1.0).timeout
									if not is_instance_valid(self) or not is_inside_tree():
										return
									if is_instance_valid(enemy) and enemy.has_method("take_damage"):
										enemy.take_damage(burn_damage * 0.5, cluster_pos, false, false, "fire")
					
					# Mini screen shake for each cluster
					if _game.has_method("shake_camera"):
						_game.shake_camera(2.0, 0.1)
				)

func _get_enemies_in_radius(pos: Vector2, radius: float) -> Array:
	var result = []
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = radius
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, pos)
	params.collision_mask = GameLayers.ENEMY
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hits: Array = space.intersect_shape(params, 10)
	for hit in hits:
		var body = hit.get("collider")
		if body != null and body.is_in_group("enemies"):
			result.append(body)
	return result

func _raycast_hit(from: Vector2, to: Vector2) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var params = PhysicsRayQueryParameters2D.create(from, to, collision_mask)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	return space.intersect_ray(params)
