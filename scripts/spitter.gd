extends "res://scripts/enemy_variant.gd"

# Spitter: ranged enemy that stops, winds up, fires a projectile, then resumes.
# Keeps distance — won't close to melee unless player is right on top of it.

var shoot_range = 260.0
var shoot_cooldown = 2.5
var windup_time = 0.5
var proj_speed = 320.0
var proj_damage_mult = 0.8
var proj_range = 340.0
var preferred_distance = 180.0

var _shoot_cd = 0.0
var _windup_timer = 0.0
var _is_winding_up = false
var _shoot_dir = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if _game == null:
		return
	_tick_elite(delta)
	if _stun_timer > 0.0:
		_stun_timer = max(0.0, _stun_timer - delta)
		velocity = Vector2.ZERO
		_is_winding_up = false
		_update_status_visuals()
		return

	_shoot_cd = max(0.0, _shoot_cd - delta)

	var target = _find_target()
	if target == null or not is_instance_valid(target):
		return

	var to_target = target.global_position - global_position
	var dist = to_target.length()

	# Windup: standing still, about to fire
	if _is_winding_up:
		velocity = Vector2.ZERO
		_windup_timer -= delta
		if _windup_timer <= 0.0:
			_fire_projectile()
			_is_winding_up = false
			_shoot_cd = shoot_cooldown
		_update_status_visuals()
		return

	# In shoot range and off cooldown — start windup
	if dist <= shoot_range and _shoot_cd <= 0.0:
		_shoot_dir = to_target.normalized()
		_is_winding_up = true
		_windup_timer = windup_time
		velocity = Vector2.ZERO
		_update_status_visuals()
		return

	# Movement: approach but try to keep preferred distance
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	if dist <= attack_range:
		# Melee fallback if player is right on top
		if _attack_cooldown <= 0.0:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
		velocity = Vector2.ZERO
	elif dist < preferred_distance:
		# Back away slightly
		var away = -to_target.normalized()
		velocity = away * speed * 0.5 * _slow_multiplier
		move_and_slide()
	else:
		var dir = to_target.normalized()
		velocity = dir * speed * _slow_multiplier
		move_and_slide()
	_update_status_visuals()

func _fire_projectile() -> void:
	if _game == null or not _game.has_method("spawn_enemy_projectile"):
		return
	var dmg = attack_damage * proj_damage_mult
	_game.spawn_enemy_projectile(global_position, _shoot_dir, proj_speed, dmg, proj_range)
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("hit", global_position)
