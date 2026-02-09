extends CharacterBody2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")

var speed = 230.0
var attack_range = 520.0
var attack_rate = 2.1
var damage = 15.0
var projectile_speed = 720.0
var projectile_range = 420.0

var max_health = 100.0
var health = 100.0
var _base_speed = 230.0
var _speed_bonus = 0.0
var _base_max_health = 100.0
var _max_health_bonus = 0.0

var _attack_cooldown = 0.0
var _game: Node = null
var _shot_counter = 0
var _base_damage = 15.0
var _base_attack_rate = 1.2
var _slow_timer = 0.0
var _slow_factor = 1.0
var _facing_dir = "S"
var _last_hit_fx_ms = -999999

@onready var sprite: Node = $Body

var _is_dying = false
var _death_animation_time = 0.0
var _death_animation_duration = 6.0  # Extended to 6 seconds for drama
var _original_scale: Vector2 = Vector2.ONE
var _death_phase = 0  # Track which phase of death we're in
var _death_shake_intensity = 0.0
var _soul_particles: Array = []


var gun_pierce = 0
var burst_level = 0
var burst_every = 0
var burst_spread = 0.25
var slow_factor = 1.0
var slow_duration = 0.0
var explosive_radius = 0.0  # Added for chest upgrade

# Berserk buff
var _berserk_active = false
var _berserk_multiplier = 1.0
var _berserk_timer = 0.0
var _berserk_glow: Sprite2D = null

func _ready() -> void:
	_ensure_game_ref()
	add_to_group("player")
	collision_layer = GameLayers.PLAYER
	collision_mask = GameLayers.ENEMY | GameLayers.BUILDING
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_base_damage = damage
	_base_attack_rate = attack_rate
	_base_speed = speed
	_base_max_health = max_health

func set_character(base_path: String, prefix: String) -> void:
	if sprite != null and sprite.has_method("configure"):
		sprite.configure(base_path, prefix)

func _physics_process(delta: float) -> void:
	_ensure_game_ref()
	if _slow_timer > 0.0:
		_slow_timer = max(0.0, _slow_timer - delta)
	else:
		_slow_factor = 1.0
	
	# Update berserk timer
	if _berserk_timer > 0.0:
		_berserk_timer = max(0.0, _berserk_timer - delta)
		if _berserk_timer <= 0.0:
			_deactivate_berserk()
	
	var input_vector = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	_update_facing(input_vector)
	velocity = input_vector * speed * _slow_factor
	move_and_slide()

	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	if _attack_cooldown <= 0.0:
		var target = _find_target()
		if _game != null:
			var dir: Vector2 = Vector2.ZERO
			if target != null:
				dir = (target.global_position - global_position).normalized()
			else:
				dir = _vector_from_dir(_facing_dir)
			_shot_counter += 1
			# Muzzle flash and shell casing effects
			_spawn_muzzle_flash(dir)
			_spawn_shell_casing(dir)
			if burst_level > 0 and burst_every > 0 and _shot_counter % burst_every == 0:
				var angles = [-burst_spread, 0.0, burst_spread]
				for angle in angles:
					_game.spawn_projectile(global_position, dir.rotated(angle), projectile_speed, damage, projectile_range, explosive_radius, gun_pierce, slow_factor, slow_duration)
			else:
				_game.spawn_projectile(global_position, dir, projectile_speed, damage, projectile_range, explosive_radius, gun_pierce, slow_factor, slow_duration)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
			# Audio: Gun fire sound
			AudioManager.play_weapon_sound("gun", global_position)

func _find_target() -> Node2D:
	var best: Node2D = null
	var best_dist = attack_range * attack_range
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if enemy == null:
			continue
		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best

func _update_facing(input_vector: Vector2) -> void:
	if sprite == null or not sprite.has_method("set_direction"):
		return
	if input_vector.length() > 0.05:
		_facing_dir = _direction_from_vector(input_vector)
		sprite.set_direction(_facing_dir)
	else:
		sprite.set_direction(_facing_dir)

func _direction_from_vector(vec: Vector2) -> String:
	var angle = atan2(vec.y, vec.x)
	var dirs = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	var idx = int(round(angle / (PI / 4.0)))
	if idx < 0:
		idx += 8
	return dirs[idx % 8]

func _vector_from_dir(dir: String) -> Vector2:
	match dir:
		"N":
			return Vector2(0, -1)
		"NE":
			return Vector2(1, -1).normalized()
		"E":
			return Vector2(1, 0)
		"SE":
			return Vector2(1, 1).normalized()
		"S":
			return Vector2(0, 1)
		"SW":
			return Vector2(-1, 1).normalized()
		"W":
			return Vector2(-1, 0)
		"NW":
			return Vector2(-1, -1).normalized()
	return Vector2(1, 0)

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true) -> void:
	if amount <= 0.0:
		return
	health -= amount
	# Reset kill streak when taking damage
	if _game != null and _game.has_method("reset_kill_streak"):
		_game.reset_kill_streak()
	# Screen shake on player damage - intensity scales with damage
	if _game != null and _game.has_method("shake_camera"):
		var shake_intensity = FeedbackConfig.SCREEN_SHAKE_PLAYER_HIT + (amount * FeedbackConfig.SCREEN_SHAKE_DAMAGE_MULTIPLIER)
		_game.shake_camera(shake_intensity)
	# Chromatic aberration / red flash effect when damaged
	if _game != null and _game.has_method("trigger_damage_flash"):
		_game.trigger_damage_flash()
	# Audio: Shield hit sound when taking damage
	AudioManager.play_one_shot("shield_hit", global_position, AudioManager.HIGH_PRIORITY)
	if _game != null and show_hit_fx and FeedbackConfig.ENABLE_HIT_SPARKS and amount >= FeedbackConfig.HIT_SPARK_MIN_DAMAGE:
		var now_ms = Time.get_ticks_msec()
		var elapsed = float(now_ms - _last_hit_fx_ms) / 1000.0
		if elapsed >= FeedbackConfig.PLAYER_HIT_SPARK_COOLDOWN:
			var hit_pos = hit_position
			if hit_pos == Vector2.ZERO:
				hit_pos = global_position
			if _game.has_method("spawn_fx"):
				_game.spawn_fx("hit", hit_pos)
			_last_hit_fx_ms = now_ms
	if health <= 0.0:
		health = 0.0
		# Start death animation instead of immediate game over
		start_death_animation()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)

func apply_gun_tech(id: String, level: int) -> void:
	match id:
		"gun_pierce":
			gun_pierce = level
		"gun_burst":
			burst_level = level
			burst_every = max(2, 5 - level)
		"gun_slow":
			slow_factor = max(0.5, 0.8 - (level - 1) * 0.15)
			slow_duration = 0.8 + 0.3 * level

func apply_global_bonuses(damage_bonus: float) -> void:
	damage = _base_damage + damage_bonus
	attack_rate = _base_attack_rate

func apply_speed_bonus(bonus: float) -> void:
	_speed_bonus = bonus
	speed = _base_speed + _speed_bonus

func apply_max_health_bonus(bonus: float) -> void:
	var prev_max = max_health
	_max_health_bonus = bonus
	max_health = _base_max_health + _max_health_bonus
	var delta = max_health - prev_max
	if delta > 0.0:
		health += delta
	health = min(health, max_health)

func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = min(_slow_factor, factor)
	_slow_timer = max(_slow_timer, duration)

# Hitstop - freeze frame effect for critical hits
func trigger_hitstop() -> void:
	if _game != null and _game.has_method("trigger_hitstop"):
		_game.trigger_hitstop()

# Muzzle flash effect when shooting
func _spawn_muzzle_flash(dir: Vector2) -> void:
	if _game == null:
		return
	var flash_pos = global_position + dir * 12.0
	if _game.has_method("spawn_muzzle_flash"):
		_game.spawn_muzzle_flash(flash_pos, dir)

# Shell casing ejection effect
func _spawn_shell_casing(dir: Vector2) -> void:
	if _game == null:
		return
	var casing_pos = global_position + dir * 8.0
	var eject_dir = dir.rotated(PI * 0.7)  # Eject backward and to the side
	if _game.has_method("spawn_shell_casing"):
		_game.spawn_shell_casing(casing_pos, eject_dir)

func _ensure_game_ref() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")

# ============================================
# DRAMATIC ROGUELIKE DEATH SEQUENCE
# ============================================

func start_death_animation() -> void:
	"""Epic 6-second death sequence inspired by Hades/Isaac/Vampire Survivors"""
	if _is_dying:
		return
	_is_dying = true
	_death_animation_time = 0.0
	_death_phase = 0
	_original_scale = scale
	_death_shake_intensity = 3.0
	
	# EXTREME slow motion - time nearly stops
	Engine.time_scale = 0.15
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Phase 0: The fatal blow - dramatic impact
	_spawn_fatal_blow_effect()
	
	# Camera zoom in and shake handled by main.gd
	if _game != null and _game.has_method("start_death_camera_zoom"):
		_game.start_death_camera_zoom(global_position)
	
	if _game != null and _game.has_method("shake_camera"):
		_game.shake_camera(15.0, 2.0)

func _process_death_animation(delta: float) -> void:
	_death_animation_time += delta * Engine.time_scale
	
	var progress = _death_animation_time / _death_animation_duration
	
	# PHASE 0: The Impact (0.0 - 0.1) - First 0.6 real seconds
	if progress < 0.1:
		if _death_phase == 0:
			_death_phase = 1
			_spawn_blood_explosion()
		
		# Screen flash red
		var flash = 1.0 - (progress / 0.1)
		if sprite != null:
			sprite.modulate = Color(1.0, flash * 0.3, flash * 0.3)
		
		# Shake violently
		_death_shake_intensity = 5.0 * (1.0 - progress / 0.1)
		_apply_death_shake()
	
	# PHASE 1: Realization (0.1 - 0.25) - "Oh no..."
	elif progress < 0.25:
		if _death_phase == 1:
			_death_phase = 2
			_spawn_soul_fragments()
		
		# Fade to white-ish shock
		var shock = (progress - 0.1) / 0.15
		if sprite != null:
			sprite.modulate = Color(1.0, 1.0 - shock * 0.2, 1.0 - shock * 0.2)
		
		# Slow shake
		_death_shake_intensity = 1.0 * (1.0 - shock)
		_apply_death_shake()
		
		# Spawn periodic blood
		if int(_death_animation_time * 5) % 2 == 0:
			_spawn_blood_drip()
	
	# PHASE 2: Collapse (0.25 - 0.5) - Falling to knees
	elif progress < 0.5:
		if _death_phase == 2:
			_death_phase = 3
		
		var collapse = (progress - 0.25) / 0.25
		
		# Compress vertically (falling to knees)
		var scale_y = lerp(1.0, 0.4, collapse)
		var scale_x = lerp(1.0, 1.3, collapse)
		scale = Vector2(scale_x, scale_y)
		
		# Rotate slightly (falling over)
		rotation = lerp(0.0, 0.3, collapse)
		
		# Fade to gray
		var gray = 1.0 - collapse * 0.5
		if sprite != null:
			sprite.modulate = Color(gray, gray, gray)
		
		# Blood pooling effect
		if int(_death_animation_time * 3) % 2 == 0:
			_spawn_blood_pool()
	
	# PHASE 3: The Soul Departs (0.5 - 0.75) - Soul rises from body
	elif progress < 0.75:
		if _death_phase == 3:
			_death_phase = 4
			_start_soul_rise()
		
		var soul_progress = (progress - 0.5) / 0.25
		
		# Body stays dim
		var brightness = 0.5 - soul_progress * 0.3
		if sprite != null:
			sprite.modulate = Color(brightness, brightness, brightness)
		
		# Continue soul animation
		_update_soul_rise(soul_progress)
	
	# PHASE 4: Fade to Darkness (0.75 - 1.0) - World fades
	else:
		if _death_phase == 4:
			_death_phase = 5
		
		var fade = (progress - 0.75) / 0.25
		
		# Everything goes black
		var black = 0.2 - fade * 0.2
		if sprite != null:
			sprite.modulate = Color(black, black, black)
		
		# Vignette effect would be applied by main.gd
		if _game != null and _game.has_method("set_death_vignette"):
			_game.set_death_vignette(fade)
	
	# Animation complete
	if _death_animation_time >= _death_animation_duration:
		_finish_death_animation()

func _spawn_fatal_blow_effect() -> void:
	"""Spawn the dramatic fatal blow impact"""
	if _game == null:
		return
	
	# Screen-wide flash
	if _game.has_method("flash_screen"):
		_game.flash_screen(Color(0.9, 0.1, 0.1, 0.6), 0.4)
	
	# Blood explosion
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("elite_kill", global_position)
		_game.spawn_fx("blood", global_position)
	
	# Radial blood burst
	for i in range(32):
		var angle = (TAU / 32) * i + randf_range(-0.1, 0.1)
		var speed = randf_range(100, 400)
		var vel = Vector2.RIGHT.rotated(angle) * speed
		if _game.has_method("spawn_death_particle"):
			_game.spawn_death_particle(global_position, vel, Color(0.6, 0.05, 0.05))

func _spawn_blood_explosion() -> void:
	"""Massive blood explosion"""
	if _game == null:
		return
	
	for i in range(48):
		var angle = randf() * TAU
		var speed = randf_range(50, 300)
		var vel = Vector2.RIGHT.rotated(angle) * speed
		if _game.has_method("spawn_death_particle"):
			var size = randf_range(6, 16)
			_game.spawn_death_particle(global_position, vel, Color(0.5, 0.05, 0.05), size)

func _spawn_soul_fragments() -> void:
	"""Spawn soul particles that will rise"""
	if _game == null:
		return
	
	_soul_particles.clear()
	
	for i in range(12):
		var angle = (TAU / 12) * i
		var offset = Vector2.RIGHT.rotated(angle) * randf_range(10, 25)
		if _game.has_method("spawn_soul_fragment"):
			var particle = _game.spawn_soul_fragment(global_position + offset)
			if particle != null:
				_soul_particles.append(particle)

func _start_soul_rise() -> void:
	"""Begin soul rising animation"""
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("ghost", global_position)

func _update_soul_rise(progress: float) -> void:
	"""Update soul particles rising"""
	# This would be handled by the particle system
	pass

func _spawn_blood_drip() -> void:
	"""Spawn dripping blood effect"""
	if _game == null or randf() > 0.6:
		return
	
	var offset = Vector2(randf_range(-15, 15), randf_range(-10, 10))
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("blood", global_position + offset)

func _spawn_blood_pool() -> void:
	"""Spawn expanding blood pool"""
	if _game == null or randf() > 0.4:
		return
	
	var offset = Vector2(randf_range(-20, 20), randf_range(10, 30))
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("blood", global_position + offset)

func _apply_death_shake() -> void:
	"""Apply screen shake during death"""
	if _game != null and _game.has_method("shake_camera"):
		_game.shake_camera(_death_shake_intensity, 0.1)

func _spawn_death_particles() -> void:
	"""Legacy - now handled by phase-specific spawns"""
	_spawn_fatal_blow_effect()

func _spawn_blood_burst() -> void:
	"""Legacy - now handled by phase-specific spawns"""
	_spawn_blood_drip()

func _finish_death_animation() -> void:
	"""Called when death animation completes"""
	_is_dying = false
	
	# Reset time scale
	Engine.time_scale = 1.0
	
	# Notify game
	if _game != null and _game.has_method("on_death_animation_complete"):
		_game.on_death_animation_complete()"
	if _game == null or randf() > 0.3:
		return
	
	var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("blood", global_position + offset)

func _finish_death_animation() -> void:
	"""Called when death animation completes"""
	_is_dying = false
	
	# Notify game that animation is done
	if _game != null and _game.has_method("on_death_animation_complete"):
		_game.on_death_animation_complete()

func is_dying() -> bool:
	return _is_dying

func reset() -> void:
	"""Reset player state for new game"""
	_is_dying = false
	_death_animation_time = 0.0
	scale = _original_scale if _original_scale != Vector2.ZERO else Vector2.ONE
	if sprite != null:
		sprite.modulate = Color.WHITE
	health = max_health
	velocity = Vector2.ZERO

# ============================================
# BERSERK BUFF - Power-up effect
# ============================================

func apply_berserk_buff(multiplier: float, duration: float) -> void:
	_berserk_active = true
	_berserk_multiplier = multiplier
	_berserk_timer = duration
	
	# Apply damage multiplier
	damage = _base_damage * _berserk_multiplier
	
	# Create visual glow effect
	_create_berserk_glow()
	
	# Audio: Berserk activation sound
	AudioManager.play_one_shot("berserk_activate", global_position, AudioManager.HIGH_PRIORITY)
	
	# Show floating text
	if _game != null and _game.has_method("show_floating_text"):
		_game.show_floating_text("BERSERK!", global_position + Vector2(0, -50), Color(1.0, 0.3, 0.2))

func _deactivate_berserk() -> void:
	_berserk_active = false
	_berserk_multiplier = 1.0
	
	# Restore damage (respecting any damage bonuses)
	damage = _base_damage
	
	# Remove glow effect
	_remove_berserk_glow()
	
	# Show floating text
	if _game != null and _game.has_method("show_floating_text"):
		_game.show_floating_text("Berserk Ended", global_position + Vector2(0, -40), Color(0.7, 0.7, 0.7))

func _create_berserk_glow() -> void:
	if _berserk_glow != null:
		return
	
	_berserk_glow = Sprite2D.new()
	_berserk_glow.name = "BerserkGlow"
	
	var glow_texture = load("res://assets/ui/ui_selection_ring_64x64_v001.png")
	if glow_texture != null:
		_berserk_glow.texture = glow_texture
	
	_berserk_glow.modulate = Color(1.0, 0.2, 0.2, 0.6)
	_berserk_glow.scale = Vector2.ONE * 2.0
	_berserk_glow.z_index = -1
	
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_berserk_glow.material = mat
	
	add_child(_berserk_glow)
	
	var tween = _berserk_glow.create_tween()
	tween.set_loops()
	tween.tween_property(_berserk_glow, "scale", Vector2.ONE * 2.3, 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_berserk_glow, "modulate:a", 0.8, 0.4)
	tween.tween_property(_berserk_glow, "scale", Vector2.ONE * 2.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_berserk_glow, "modulate:a", 0.4, 0.4)

func _remove_berserk_glow() -> void:
	if _berserk_glow != null:
		_berserk_glow.queue_free()
		_berserk_glow = null

func is_berserk_active() -> bool:
	return _berserk_active
