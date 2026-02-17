extends CharacterBody2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")
const ResourceGenerator = preload("res://scripts/resource_generator.gd")
const ELITE_GLOW_TEXTURE = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")

var speed = 92.0
var max_health = 20.0
var health = 20.0
var attack_damage = 10.0
var attack_rate = 1.05
var attack_range = 20.0
var aggro_range = 260.0
var is_siege = false

var _attack_cooldown = 0.0
var _game: Node = null
var _slow_sources: Dictionary = {}
var _slow_multiplier = 1.0
var _stun_timer = 0.0
var _was_stunned = false
var _was_slowed = false
var is_elite = false
var is_split_child = false
var _last_hit_fx_ms = -999999
var _last_damage_number_ms = -999999
var _is_dying = false
var _death_timer = 0.0
var _corpse_fade_timer = 0.0

# Elite modifier system: "", "aura", "regen", "splitter"
var elite_modifier = ""
var _elite_mod_timer = 0.0

# Aura: boosts nearby mob damage every few seconds
var _aura_interval = 3.0
var _aura_radius = 140.0
var _aura_damage_bonus = 1.0
var _aura_buff_duration = 2.4

# Regen: passive HP per second
var _regen_rate = 3.0

# Splitter: spawns smaller minions on death
var _split_child_count = 2
var _split_child_scale = 0.78
var _split_child_health_mult = 0.65
var _split_child_damage_mult = 0.75
var _split_child_speed_mult = 1.15

var _aura_bonus_timer = 0.0
var _aura_bonus_amount = 0.0
var _elite_glow: Sprite2D = null
var _elite_glow_tween: Tween = null
var _elite_glow_timer = 0.0
var _elite_glow_interval = 0.18

# Health bar (only for elites/siege/bosses)
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
const HEALTH_BAR_WIDTH = 24.0
const HEALTH_BAR_HEIGHT = 3.0
const HEALTH_BAR_OFFSET_Y = -22.0

@onready var body: CanvasItem = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _base_color: Color = Color.WHITE

func setup(game_ref: Node, difficulty: float) -> void:
	_game = game_ref
	max_health = max_health * difficulty
	health = max_health
	speed = speed * (1.0 + difficulty * 0.03)

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = GameLayers.ENEMY
	collision_mask = GameLayers.PLAYER | GameLayers.BUILDING | GameLayers.ALLY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if body != null:
		_base_color = body.modulate
		body.scale = Vector2.ONE * 1.8
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius = max(shape.radius, 12.0)
	if is_elite or is_siege:
		_create_health_bar()

func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	if _game == null:
		return
	_tick_aura_bonus(delta)
	_tick_elite(delta)
	_tick_elite_glow_particles(delta)
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
		velocity = Vector2.ZERO
		_update_status_visuals()
		return
	var target = _find_target()
	if target == null or not is_instance_valid(target):
		return
	var dist = global_position.distance_to(target.global_position)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	if dist <= attack_range:
		if _attack_cooldown <= 0.0:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
		velocity = Vector2.ZERO
	else:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir * speed * _slow_multiplier
		move_and_slide()
	_update_status_visuals()

func _find_target() -> Node2D:
	if _game == null:
		return null
	
	var player: Node2D = _game.player as Node2D
	var best: Node2D = null
	var best_dist = INF
	var is_generator = false
	
	# First check: player
	if player != null and is_instance_valid(player):
		best = player
		best_dist = global_position.distance_squared_to(player.global_position)
		is_generator = false
	
	# Check allies (higher priority than generators, lower than player)
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally == null or not is_instance_valid(ally):
			continue
		var dist = global_position.distance_squared_to(ally.global_position)
		if dist < best_dist and dist <= aggro_range * aggro_range:
			best = ally
			best_dist = dist
			is_generator = false
	
	# Check generators (target if within aggro range)
	# Generators have lower priority than player/allies but will be attacked if closest
	for building in get_tree().get_nodes_in_group("buildings"):
		if building == null or not is_instance_valid(building):
			continue
		# Only target resource generators
		if not building is ResourceGenerator:
			continue
		if building.has_method("is_destroyed") and building.is_destroyed():
			continue
		
		var dist = global_position.distance_squared_to(building.global_position)
		# Generators must be within aggro range to be targeted
		if dist <= aggro_range * aggro_range and dist < best_dist:
			best = building
			best_dist = dist
			is_generator = true
	
	if best == null:
		return player
	
	# For generators, they must be within aggro range
	# For player/allies, they can be targeted at any distance (player is always valid)
	if is_generator:
		if best_dist <= aggro_range * aggro_range:
			return best
		return player
	
	if best_dist <= aggro_range * aggro_range:
		return best
	return player

func _create_health_bar() -> void:
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_bg.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, HEALTH_BAR_OFFSET_Y)
	_health_bar_bg.color = Color(0.15, 0.15, 0.15, 0.7)
	_health_bar_bg.z_index = 15
	add_child(_health_bar_bg)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_fill.position = Vector2.ZERO
	if is_elite:
		_health_bar_fill.color = Color(1.0, 0.85, 0.2, 0.9)  # Gold for elites
	elif is_siege:
		_health_bar_fill.color = Color(1.0, 0.3, 0.2, 0.9)  # Red for siege
	else:
		_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9)  # Green default
	_health_bar_bg.add_child(_health_bar_fill)

func _update_health_bar() -> void:
	if _health_bar_fill == null:
		return
	var ratio = clampf(health / max_health, 0.0, 1.0)
	_health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio
	# Color shift: green → yellow → red as health drops
	if not is_elite:
		if ratio > 0.5:
			_health_bar_fill.color = Color(0.2, 0.9, 0.2, 0.9).lerp(Color(1.0, 0.9, 0.2, 0.9), 1.0 - ratio * 2.0)
		else:
			_health_bar_fill.color = Color(1.0, 0.9, 0.2, 0.9).lerp(Color(1.0, 0.2, 0.2, 0.9), 1.0 - ratio * 2.0)

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true, show_damage_number: bool = true, damage_type: String = "normal") -> void:
	if amount <= 0.0:
		return
	var hit_pos = hit_position
	if hit_pos == Vector2.ZERO:
		hit_pos = global_position
	var now_ms = Time.get_ticks_msec()
	var will_die = health - amount <= 0.0
	var is_crit = _is_crit_hit(amount)

	if will_die:
		# Play death sound
		AudioManager.play_impact_sound(is_crit, true, hit_pos)
	else:
		# Play hit sound
		AudioManager.play_impact_sound(is_crit, false, hit_pos)
	
	if show_hit_fx and FeedbackConfig.ENABLE_HIT_SPARKS and amount >= FeedbackConfig.HIT_SPARK_MIN_DAMAGE:
		var elapsed = float(now_ms - _last_hit_fx_ms) / 1000.0
		if elapsed >= FeedbackConfig.HIT_SPARK_COOLDOWN or is_crit or will_die:
			if _game != null and _game.has_method("spawn_fx"):
				var hit_kind = "hit"
				if is_crit:
					hit_kind = "crit"
				_game.spawn_fx(hit_kind, hit_pos)
			_last_hit_fx_ms = now_ms

	if show_damage_number and FeedbackConfig.ENABLE_DAMAGE_NUMBERS:
		var elapsed_num = float(now_ms - _last_damage_number_ms) / 1000.0
		if elapsed_num >= FeedbackConfig.DAMAGE_NUMBER_COOLDOWN or is_crit or will_die:
			if _game != null and _game.has_method("spawn_damage_number"):
				_game.spawn_damage_number(amount, hit_pos, max_health, is_crit, will_die, is_elite, damage_type)
			_last_damage_number_ms = now_ms

	health -= amount
	_update_health_bar()

	# Trigger hitstop on crit
	if is_crit and _game != null and _game.has_method("trigger_hitstop"):
		_game.trigger_hitstop()
	
	if health <= 0.0 and not _is_dying:
		_start_death_sequence()

func _start_death_sequence() -> void:
	_is_dying = true
	health = 0.0
	
	# Disable collision and AI
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	set_physics_process(false)
	
	# White flash
	if body != null:
		body.modulate = Color.WHITE
		
	# Particle burst on death
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("blood", global_position)
		if FeedbackConfig.ENABLE_DEATH_FEEDBACK:
			if is_elite or is_siege:
				_game.spawn_fx("elite_kill", global_position)
			else:
				_game.spawn_fx("kill_pop", global_position)
		# Extra particle burst for satisfying death
		_game.spawn_glow_burst_death(global_position, _base_color)
	
	# Use FX Manager for enhanced death effects if available
	if _game != null and _game.fx_manager != null:
		var corpse_texture = null
		if body != null and body is Sprite2D:
			corpse_texture = (body as Sprite2D).texture
		_game.fx_manager.spawn_death_effect(self, _base_color, corpse_texture)

	# Hide health bar on death
	if _health_bar_bg != null:
		_health_bar_bg.visible = false

	# Death animation sequence using tween (safety check)
	if not is_inside_tree():
		queue_free()
		return
	var tween = create_tween()

	if body != null:
		var orig_scale = body.scale
		# Pop UP briefly (satisfying squash & stretch)
		tween.tween_property(body, "scale", orig_scale * 1.3, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Then SLAM down to nothing
		tween.tween_property(body, "scale", orig_scale * 0.15, FeedbackConfig.DEATH_SCALE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		# Fade out overlapping with scale
		tween.parallel().tween_property(body, "modulate:a", 0.0, FeedbackConfig.DEATH_FADE_DURATION)

	# Elite/siege screen flash
	if (is_elite or is_siege) and _game != null and _game.has_method("flash_screen"):
		_game.flash_screen(Color(1.0, 0.9, 0.3, 0.15), 0.15)

	# Corpse fade delay then cleanup
	tween.tween_interval(FeedbackConfig.DEATH_CORPSE_FADE_DELAY)
	tween.tween_callback(_finish_death)
	
	# Spawn drops immediately (don't wait for animation)
	if _game != null:
		if is_elite and elite_modifier == "splitter" and not is_split_child:
			_spawn_split_minions()
		if _game.has_method("spawn_pickup"):
			var gold_amount = 1
			if is_elite:
				gold_amount = 3
			_game.spawn_pickup(global_position, gold_amount, "gold")
			if is_elite and randf() < 0.35:
				_game.spawn_pickup(global_position, 18, "heal")
		if is_elite and _game.has_method("spawn_treasure_chest"):
			_game.spawn_treasure_chest(global_position)
		# Essence drops from elite/siege kills
		if is_elite and _game.has_method("spawn_pickup"):
			_game.spawn_pickup(global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1, "essence")
		if is_siege and not is_elite and randf() < 0.5 and _game.has_method("spawn_pickup"):
			_game.spawn_pickup(global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1, "essence")
		var xp_reward = 1
		if is_siege:
			xp_reward = 3
		if is_elite:
			xp_reward = 5
		_game.add_xp(xp_reward)
		if _game.has_method("on_enemy_killed"):
			_game.on_enemy_killed(is_elite, is_siege)

func _finish_death() -> void:
	queue_free()

func _is_crit_hit(amount: float) -> bool:
	if not FeedbackConfig.ENABLE_CRIT_POP:
		return false
	var pct = FeedbackConfig.CRIT_PCT_MAX_HEALTH
	if is_elite:
		pct = FeedbackConfig.CRIT_PCT_ELITE
	var threshold = max(FeedbackConfig.CRIT_MIN_DAMAGE, max_health * pct)
	return amount >= threshold

func apply_slow(source_id: int, factor: float, duration: float = 0.0) -> void:
	_slow_sources[source_id] = clamp(factor, 0.1, 1.0)
	_recalc_slow()
	_update_status_visuals()
	if duration > 0.0:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(func(): remove_slow(source_id))

func remove_slow(source_id: int) -> void:
	_slow_sources.erase(source_id)
	_recalc_slow()
	_update_status_visuals()

func _recalc_slow() -> void:
	_slow_multiplier = 1.0
	for factor in _slow_sources.values():
		_slow_multiplier = min(_slow_multiplier, float(factor))

func stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)
	_update_status_visuals()

func is_siege_unit() -> bool:
	return is_siege

func set_elite(multiplier: float) -> void:
	is_elite = true
	max_health *= multiplier
	health = max_health
	speed *= 1.1
	attack_damage *= 1.4
	if body != null:
		body.scale = body.scale * 1.35
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius *= 1.15
	var glow_color = Color(1.0, 0.8, 0.3)
	# Assign a random elite modifier
	var roll = randf()
	if roll < 0.34:
		elite_modifier = "aura"
		_base_color = _base_color.lerp(Color(1.0, 0.45, 0.25), 0.5)
		glow_color = Color(1.0, 0.5, 0.25)
	elif roll < 0.67:
		elite_modifier = "regen"
		_base_color = _base_color.lerp(Color(0.3, 1.0, 0.4), 0.5)
		glow_color = Color(0.3, 1.0, 0.5)
	else:
		elite_modifier = "splitter"
		_base_color = _base_color.lerp(Color(0.65, 0.55, 1.0), 0.5)
		glow_color = Color(0.7, 0.6, 1.0)
	if body != null:
		body.modulate = _base_color
	_create_elite_glow(glow_color)

func _tick_elite(delta: float) -> void:
	if not is_elite or elite_modifier == "" or _stun_timer > 0.0:
		return
	match elite_modifier:
		"regen":
			_process_regen(delta)
		"aura":
			_process_aura(delta)

func _process_regen(delta: float) -> void:
	if health < max_health:
		health = min(max_health, health + _regen_rate * delta)
		_update_health_bar()

func _process_aura(delta: float) -> void:
	_elite_mod_timer += delta
	if _elite_mod_timer < _aura_interval:
		return
	_elite_mod_timer = 0.0
	var radius_sq = _aura_radius * _aura_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		if "attack_damage" in enemy:
			if enemy.has_method("apply_aura_bonus"):
				enemy.apply_aura_bonus(_aura_damage_bonus, _aura_buff_duration)
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("summon_fire", global_position)

func _update_status_visuals() -> void:
	if body == null:
		return
	var stunned_now = _stun_timer > 0.0
	var slowed_now = not _slow_sources.is_empty()
	if stunned_now and not _was_stunned:
		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("stun", global_position)
	if stunned_now == _was_stunned and slowed_now == _was_slowed:
		return
	_was_stunned = stunned_now
	_was_slowed = slowed_now
	if stunned_now:
		body.modulate = _base_color.lerp(Color(1.0, 0.9, 0.4), 0.6)
	elif slowed_now:
		body.modulate = _base_color.lerp(Color(0.5, 0.8, 1.0), 0.5)
	else:
		body.modulate = _base_color

func apply_aura_bonus(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	if _aura_bonus_amount < amount:
		attack_damage += amount - _aura_bonus_amount
		_aura_bonus_amount = amount
	_aura_bonus_timer = max(_aura_bonus_timer, duration)

func _tick_aura_bonus(delta: float) -> void:
	if _aura_bonus_timer <= 0.0:
		return
	_aura_bonus_timer = max(0.0, _aura_bonus_timer - delta)
	if _aura_bonus_timer == 0.0 and _aura_bonus_amount > 0.0:
		attack_damage = max(0.0, attack_damage - _aura_bonus_amount)
		_aura_bonus_amount = 0.0

func apply_split_child() -> void:
	is_split_child = true
	is_elite = false
	elite_modifier = ""
	max_health *= _split_child_health_mult
	health = max_health
	speed *= _split_child_speed_mult
	attack_damage *= _split_child_damage_mult
	if body != null:
		body.scale = body.scale * _split_child_scale
		body.modulate = _base_color.lerp(Color(0.9, 0.9, 1.0), 0.2)
		_base_color = body.modulate
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		var shape: CircleShape2D = collision_shape.shape
		shape.radius *= _split_child_scale
	if _elite_glow != null:
		_elite_glow.queue_free()
		_elite_glow = null
	if _elite_glow_tween != null:
		_elite_glow_tween.kill()
		_elite_glow_tween = null

func _spawn_split_minions() -> void:
	if _game == null or not _game.has_method("spawn_split_minions"):
		return
	_game.spawn_split_minions(global_position, _split_child_count)

func _create_elite_glow(color: Color) -> void:
	if _elite_glow != null:
		return
	_elite_glow = Sprite2D.new()
	_elite_glow.name = "EliteGlow"
	_elite_glow.texture = ELITE_GLOW_TEXTURE
	_elite_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_elite_glow.z_index = -1
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_elite_glow.material = mat
	add_child(_elite_glow)
	var base_scale = Vector2.ONE * 2.0
	if body != null and body is Node2D:
		base_scale = (body as Node2D).scale * 1.35
	_elite_glow.scale = base_scale
	_elite_glow.modulate = Color(color.r, color.g, color.b, 0.55)
	_start_elite_glow_pulse(base_scale, color)

func _start_elite_glow_pulse(base_scale: Vector2, color: Color) -> void:
	if _elite_glow == null or not is_inside_tree():
		return
	if _elite_glow_tween != null:
		_elite_glow_tween.kill()
	var dim = Color(color.r, color.g, color.b, 0.35)
	var bright = Color(color.r, color.g, color.b, 0.7)
	_elite_glow_tween = create_tween()
	if _elite_glow_tween == null:
		return
	_elite_glow_tween.set_loops()
	_elite_glow_tween.tween_property(_elite_glow, "scale", base_scale * 1.1, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_elite_glow_tween.parallel().tween_property(_elite_glow, "modulate", bright, 0.65)
	_elite_glow_tween.tween_property(_elite_glow, "scale", base_scale, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_elite_glow_tween.parallel().tween_property(_elite_glow, "modulate", dim, 0.65)

func _tick_elite_glow_particles(delta: float) -> void:
	if not is_elite or _game == null or not _game.has_method("spawn_glow_particle"):
		return
	_elite_glow_timer += delta
	if _elite_glow_timer < _elite_glow_interval:
		return
	_elite_glow_timer = 0.0
	var glow_color = _base_color
	match elite_modifier:
		"aura":
			glow_color = Color(1.0, 0.45, 0.25)
		"regen":
			glow_color = Color(0.35, 1.0, 0.55)
		"splitter":
			glow_color = Color(0.75, 0.65, 1.0)
	glow_color = glow_color.lerp(Color.WHITE, 0.3)
	var offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(8.0, 18.0)
	var vel = offset.normalized() * randf_range(12.0, 32.0)
	_game.spawn_glow_particle(global_position + offset, glow_color, randf_range(6.0, 9.0), 0.5, vel, 1.8, 0.65, 1.0, 0)
