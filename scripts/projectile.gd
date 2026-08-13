extends Area2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")
const DEFAULT_PROJECTILE_FRAMES = [
	"res://assets/fx/fx_arrow_bolt_16_f001_v002.png",
	"res://assets/fx/fx_arrow_bolt_16_f002_v002.png",
	"res://assets/fx/fx_arrow_bolt_16_f003_v002.png",
	"res://assets/fx/fx_arrow_bolt_16_f004_v002.png"
]

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
var _trail_interval_scale: float = 1.0
var _visual_profile: Dictionary = {}
var _trail_damage_type_override: String = ""
var _impact_damage_type_override: String = ""
var _impact_fx_kind_override: String = ""
var _projectile_tint_override: Color = Color.WHITE
var _projectile_scale_override: float = 1.5
var _projectile_static_frame_override: int = -1
static var _sprite_frames_cache: Dictionary = {}

# Bodies this shot has already damaged: instance ids for the damage guard, the
# matching collider RIDs so the ray physically cannot re-acquire them.
# _handle_hit used to only decrement remaining_pierce and clear _has_impacted,
# keeping no record of what it had hit and leaving the projectile parked on the
# collider surface, so the next frame's ray - cast from that same point into
# that same body - landed again. Measured on one stationary enemy,
# pierce_count = 1 dealt exactly 2 hits and pierce_count = 3 exactly 4: pierce
# meant "hit the first enemy pierce_count + 1 times", not "pass through".
var _hit_ids: Dictionary = {}
var _excluded_rids: Array[RID] = []
# A frame's step is ~12 px at arrow-turret speeds against a 9 px enemy radius,
# so a handful of bodies per segment is already generous. The cap only exists
# so a degenerate ray can never spin inside one physics frame.
const MAX_HITS_PER_FRAME = 8
@onready var sprite: AnimatedSprite2D = $Body

func setup(game_ref: Node, dir: Vector2, proj_speed: float, dmg: float, range: float, explode_radius: float, pierce_count: int = 0, slow_factor_in: float = 1.0, slow_duration_in: float = 0.0, damage_type_in: String = "normal", visual_profile: Dictionary = {}) -> void:
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
	_visual_profile = visual_profile
	_apply_visual_profile()
	_update_trail_interval_scale()

func _ready() -> void:
	collision_layer = GameLayers.PROJECTILE
	collision_mask = GameLayers.ENEMY
	_last_position = global_position
	if sprite != null:
		_apply_visual_profile()
	# Spawn trail immediately
	_spawn_trail()

func _apply_visual_profile() -> void:
	if sprite == null:
		return
	var profile = _visual_profile
	var frame_paths: Array = DEFAULT_PROJECTILE_FRAMES
	var fps: float = 12.0
	_projectile_scale_override = 1.5
	_projectile_tint_override = Color.WHITE
	_projectile_static_frame_override = -1
	_trail_damage_type_override = ""
	_impact_damage_type_override = ""
	_impact_fx_kind_override = ""
	if not profile.is_empty():
		var paths_variant = profile.get("projectile_frames", [])
		if paths_variant is Array and not (paths_variant as Array).is_empty():
			frame_paths = paths_variant
		fps = float(profile.get("projectile_fps", fps))
		_projectile_scale_override = float(profile.get("projectile_scale", _projectile_scale_override))
		_projectile_static_frame_override = int(profile.get("projectile_static_frame", -1))
		var tint_variant = profile.get("projectile_tint", _projectile_tint_override)
		if tint_variant is Color:
			_projectile_tint_override = tint_variant
		_trail_damage_type_override = str(profile.get("trail_damage_type", ""))
		_impact_damage_type_override = str(profile.get("impact_damage_type", ""))
		_impact_fx_kind_override = str(profile.get("impact_fx_kind", ""))
	var frames = _get_cached_frames(frame_paths, fps, _projectile_static_frame_override)
	if frames != null:
		sprite.sprite_frames = frames
		sprite.animation = "default"
		sprite.play()
	sprite.scale = Vector2.ONE * _projectile_scale_override
	sprite.modulate = _projectile_tint_override

func _frame_cache_key(paths: Array, fps: float, static_frame_index: int) -> String:
	var key_parts: PackedStringArray = []
	key_parts.append(str(snappedf(fps, 0.01)))
	key_parts.append("static:%d" % static_frame_index)
	for raw_path in paths:
		key_parts.append(str(raw_path))
	return "|".join(key_parts)

func _get_cached_frames(paths: Array, fps: float, static_frame_index: int = -1) -> SpriteFrames:
	var valid_paths: Array = []
	for raw_path in paths:
		var path = str(raw_path)
		if path == "" or not ResourceLoader.exists(path):
			continue
		valid_paths.append(path)
	if valid_paths.is_empty():
		for fallback_path in DEFAULT_PROJECTILE_FRAMES:
			if ResourceLoader.exists(fallback_path):
				valid_paths.append(fallback_path)
	if valid_paths.is_empty():
		return null
	if static_frame_index >= 0 and not valid_paths.is_empty():
		var clamped_idx = clampi(static_frame_index, 0, valid_paths.size() - 1)
		var selected_paths: Array = [valid_paths[clamped_idx]]
		valid_paths = selected_paths
	var key = _frame_cache_key(valid_paths, fps, static_frame_index)
	if _sprite_frames_cache.has(key):
		var cached = _sprite_frames_cache[key]
		if cached is SpriteFrames:
			return cached
	var frames = SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("default")
	frames.set_animation_speed("default", max(1.0, fps))
	frames.set_animation_loop("default", true)
	for path in valid_paths:
		var tex = load(path)
		if tex is Texture2D:
			frames.add_frame("default", tex)
	if frames.get_frame_count("default") <= 0:
		return null
	_sprite_frames_cache[key] = frames
	return frames

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
		_trail_timer = FeedbackConfig.PROJECTILE_TRAIL_INTERVAL * _trail_interval_scale
	
	# Resolve every body standing on this frame's segment inside this frame.
	# Stopping at the first collider and picking up next frame from its surface
	# is what let a pierced enemy be hit over and over; each body the ray finds
	# is excluded from the following cast, so the scan walks on to whatever is
	# behind it and the projectile always finishes the step it started.
	var scans = 0
	while scans < MAX_HITS_PER_FRAME:
		scans += 1
		var hit = _raycast_hit(global_position, to)
		if hit.is_empty():
			break
		var hit_pos: Vector2 = hit.position
		_travelled += global_position.distance_to(hit_pos)
		global_position = hit_pos
		_exclude_hit(hit)
		if not _handle_hit(hit.collider):
			return
	_travelled += global_position.distance_to(to)
	global_position = to
	if _travelled >= max_range:
		_explode_if_needed()
		queue_free()

# Reference speed at which a shot earns the full stretch. Slower shots (lobbed
# cannon shells) keep their shape; fast ones smear along travel.
const MOTION_BLUR_FULL_SPEED := 700.0

func _update_motion_blur(_velocity_magnitude: float) -> void:
	if sprite == null:
		return
	# This used to divide the per-frame step by the speed, which is just the
	# frame delta - so the stretch factor was 1.0167 every frame and the motion
	# blur never actually did anything. Scale it off the projectile's speed.
	var t := clampf(speed / MOTION_BLUR_FULL_SPEED, 0.0, 1.0)
	var stretch := lerpf(1.0, FeedbackConfig.PROJECTILE_MOTION_BLUR_STRETCH, t)
	# Squash across travel far less than the stretch along it; a full 1/stretch
	# reciprocal turns a bolt into a needle.
	var squash := lerpf(1.0, 0.85, t)
	sprite.scale = Vector2(stretch, squash) * _projectile_scale_override
	sprite.rotation = direction.angle()

func _spawn_trail() -> void:
	# Use FX Manager for high-quality trail if available
	var visual_damage_type = _trail_damage_type_override if _trail_damage_type_override != "" else damage_type
	if _game != null and _game.fx_manager != null:
		_trail = _game.fx_manager.spawn_projectile_trail(self, visual_damage_type, _trail_color())
	else:
		# Fallback to simple glow particles
		if _game == null or not _game.has_method("spawn_glow_particle"):
			return
		var trail_color = Color(1.0, 0.9, 0.7, 0.6)
		if visual_damage_type == "fire":
			trail_color = Color(1.0, 0.5, 0.2, 0.6)
		elif visual_damage_type == "ice":
			trail_color = Color(0.5, 0.8, 1.0, 0.6)
		_game.spawn_glow_particle(global_position, trail_color, 4.0, 0.15, Vector2.ZERO, 1.2, 0.5, 0.8, -1)

# The shot's own tint, so the streak matches the bolt instead of every tier
# trailing the same damage-type cream. Transparent means "no opinion" and the
# FX manager falls back to the damage-type colour.
func _trail_color() -> Color:
	if _projectile_tint_override.is_equal_approx(Color.WHITE):
		return Color(0, 0, 0, 0)
	var c := _projectile_tint_override
	c.a = 1.0
	return c

func _update_trail_interval_scale() -> void:
	_trail_interval_scale = 1.0
	if _game == null:
		return
	var settings_manager = _game.get_node_or_null("/root/SettingsManager")
	if settings_manager != null and settings_manager.has_method("get_trail_interval_scale"):
		_trail_interval_scale = clampf(float(settings_manager.get_trail_interval_scale()), 0.7, 3.0)

# Drop a body out of this projectile's raycasts for good. Called for every
# collider the ray reports, enemy or not, so the scan in _physics_process can
# never re-report the same collider and stall on it.
func _exclude_hit(hit: Dictionary) -> void:
	var rid = hit.get("rid", null)
	if rid is RID and (rid as RID).is_valid():
		_excluded_rids.append(rid)

func _handle_hit(body: Node) -> bool:
	if body == null or not body.is_in_group("enemies"):
		return true

	# One landing per body, forever. The RID exclusion above already keeps the
	# ray off a pierced enemy; this is the backstop for any other route back
	# into the same body (a second collider shape on it, a re-entrant overlap)
	# so a single shot can never double-dip on one enemy again.
	var body_id = body.get_instance_id()
	if _hit_ids.has(body_id):
		return true
	_hit_ids[body_id] = true

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
		body.take_damage(damage, global_position, true, true, damage_type, direction)
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
	var impact_damage_type = _impact_damage_type_override if _impact_damage_type_override != "" else damage_type
	if _game != null and _game.fx_manager != null:
		var is_crit = false  # Could be passed in from damage calculation
		_game.fx_manager.spawn_impact(global_position, impact_damage_type, is_crit, direction)
	if _game != null and _game.has_method("spawn_fx"):
		var impact_fx_kind = _impact_fx_kind_override if _impact_fx_kind_override != "" else "hit"
		_game.spawn_fx(impact_fx_kind, global_position)
	
	# Also spawn legacy glow particle
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	var flash_color = Color(1.0, 1.0, 0.8, 0.9)
	if impact_damage_type == "fire":
		flash_color = Color(1.0, 0.6, 0.2, 0.9)
	elif impact_damage_type == "ice":
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
		var has_cluster = bool(get_meta("cluster_bombs", false))
		var has_burn = bool(get_meta("burn_effect", false))
		var impact_power = clampf(explosion_radius / 64.0, 0.85, 1.9)
		var major_impact = explosion_radius >= 56.0 or has_cluster
		if _game.has_method("damage_enemies_in_radius"):
			_game.damage_enemies_in_radius(global_position, explosion_radius, damage, 1.0, damage_type)
		if _game.has_method("spawn_setpiece_fx") and major_impact:
			_game.spawn_setpiece_fx("cannon_impact", global_position, impact_power, damage_type)
		elif _game.has_method("spawn_fx"):
			_game.spawn_fx("explosion", global_position)
		if _game.has_method("shake_camera"):
			_game.shake_camera(FeedbackConfig.SCREEN_SHAKE_EXPLOSION)
			
		# Handle cluster bombs (T3 cannon tower)
		if has_cluster and _game != null:
			# Spawn 3 secondary explosions in random directions.
			# Keep this synchronous to avoid timer-churn and freed-instance callback issues.
			for i in range(3):
				var angle = randf() * TAU
				var dist = explosion_radius * (0.5 + randf() * 0.5)
				var offset = Vector2(cos(angle), sin(angle)) * dist
				var cluster_pos = global_position + offset
					
				# Smaller secondary explosion
				var cluster_damage = damage * 0.6
				var cluster_radius = explosion_radius * 0.7

				if _game.has_method("damage_enemies_in_radius"):
					_game.damage_enemies_in_radius(cluster_pos, cluster_radius, cluster_damage, 0.9, "fire" if has_burn else damage_type)
				if _game.has_method("spawn_setpiece_fx"):
					_game.spawn_setpiece_fx("cannon_impact", cluster_pos, 0.82, "fire" if has_burn else damage_type)
				elif _game.has_method("spawn_fx"):
					_game.spawn_fx("explosion", cluster_pos)
				if has_burn and _game.has_method("spawn_fx"):
					_game.spawn_fx("fire_burst", cluster_pos)
				if has_burn:
					_apply_burn_in_radius(cluster_pos, cluster_radius * 1.2)
			if _game.has_method("shake_camera"):
				_game.shake_camera(2.0, 0.1)

func _apply_burn_in_radius(center: Vector2, radius: float) -> void:
	if _game == null:
		return
	var radius_sq = radius * radius
	var enemies: Array = []
	if _game.has_method("get_cached_enemies"):
		enemies = _game.get_cached_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	for raw_enemy in enemies:
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		if not (raw_enemy is Node2D):
			continue
		var enemy := raw_enemy as Node2D
		if center.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(get_instance_id(), burn_damage, burn_duration)
		elif enemy.has_method("take_damage"):
			enemy.take_damage(burn_damage * 1.2, center, false, false, "fire")

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
	# Already-pierced bodies are invisible to the ray. Without this the cast,
	# which starts on the surface point where the last hit landed, re-acquires
	# that same collider at distance zero and the shot never gets past it.
	if not _excluded_rids.is_empty():
		params.exclude = _excluded_rids
	return space.intersect_ray(params)
