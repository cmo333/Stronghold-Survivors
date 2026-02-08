extends CharacterBody2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")

var speed = 92.0
var max_health = 30.0
var health = 30.0
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
var _last_hit_fx_ms = -999999
var _last_damage_number_ms = -999999

# Elite modifier system: "", "aura", "speed_burst", "regen"
var elite_modifier = ""
var _elite_mod_timer = 0.0

# Aura: boosts nearby mob damage every few seconds
var _aura_interval = 3.0
var _aura_radius = 140.0
var _aura_damage_bonus = 0.3

# Speed burst: intermittent dash
var _burst_interval = 4.0
var _burst_duration = 0.8
var _burst_mult = 1.7
var _burst_active = false
var _burst_timer = 0.0
var _burst_base_speed = 0.0

# Regen: passive HP per second
var _regen_rate = 3.0

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

func _physics_process(delta: float) -> void:
	if _game == null:
		return
	_tick_elite(delta)
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
	if player != null and is_instance_valid(player):
		best = player
		best_dist = global_position.distance_squared_to(player.global_position)
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally == null or not is_instance_valid(ally):
			continue
		var dist = global_position.distance_squared_to(ally.global_position)
		if dist < best_dist and dist <= aggro_range * aggro_range:
			best = ally
			best_dist = dist
	if best == null:
		return player
	if best_dist <= aggro_range * aggro_range:
		return best
	return player

func take_damage(amount: float, hit_position: Vector2 = Vector2.ZERO, show_hit_fx: bool = true, show_damage_number: bool = true, damage_type: String = "normal") -> void:
	if amount <= 0.0:
		return
	var hit_pos = hit_position
	if hit_pos == Vector2.ZERO:
		hit_pos = global_position
	var now_ms = Time.get_ticks_msec()
	var will_die = health - amount <= 0.0
	var is_crit = _is_crit_hit(amount)

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
	if health <= 0.0:
		if _game != null:
			if _game.has_method("spawn_fx"):
				_game.spawn_fx("blood", global_position)
				if FeedbackConfig.ENABLE_DEATH_FEEDBACK:
					if is_elite or is_siege:
						_game.spawn_fx("elite_kill", global_position)
					else:
						_game.spawn_fx("kill_pop", global_position)
			if _game.has_method("spawn_pickup"):
				var gold_amount = 1
				if is_elite:
					gold_amount = 3
				_game.spawn_pickup(global_position, gold_amount, "gold")
				if is_elite and randf() < 0.35:
					_game.spawn_pickup(global_position, 18, "heal")
			var xp_reward = 1
			if is_siege:
				xp_reward = 3
			if is_elite:
				xp_reward = 5
			_game.add_xp(xp_reward)
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
		body.scale = body.scale * 1.25
		body.modulate = _base_color.lerp(Color(1.0, 0.85, 0.35), 0.6)
	# Assign a random elite modifier
	var roll = randf()
	if roll < 0.33:
		elite_modifier = "aura"
		_base_color = _base_color.lerp(Color(1.0, 0.4, 0.2), 0.3)
	elif roll < 0.66:
		elite_modifier = "speed_burst"
		_burst_base_speed = speed
	else:
		elite_modifier = "regen"
		_base_color = _base_color.lerp(Color(0.3, 1.0, 0.4), 0.3)

func _tick_elite(delta: float) -> void:
	if not is_elite or elite_modifier == "" or _stun_timer > 0.0:
		return
	match elite_modifier:
		"regen":
			_process_regen(delta)
		"aura":
			_process_aura(delta)
		"speed_burst":
			_process_speed_burst(delta)

func _process_regen(delta: float) -> void:
	if health < max_health:
		health = min(max_health, health + _regen_rate * delta)

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
			enemy.attack_damage += _aura_damage_bonus
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("fire", global_position)

func _process_speed_burst(delta: float) -> void:
	_elite_mod_timer += delta
	if _burst_active:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_active = false
			speed = _burst_base_speed
	elif _elite_mod_timer >= _burst_interval:
		_elite_mod_timer = 0.0
		_burst_active = true
		_burst_timer = _burst_duration
		_burst_base_speed = speed
		speed = speed * _burst_mult

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
