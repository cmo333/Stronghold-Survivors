extends "res://scripts/enemy_variant.gd"

# Healer: periodically restores HP to nearby enemies.
# Stays behind the front line — prefers distance from the player.
# Priority target for the player.

var heal_interval = 4.0
var heal_radius = 160.0
var heal_amount = 8.0
var preferred_distance = 200.0
var _timer = 0.0

func _process(delta: float) -> void:
	if _game == null:
		return
	_timer += delta
	if _timer < heal_interval:
		return
	_timer = 0.0
	_heal_nearby()

func _heal_nearby() -> void:
	var radius_sq = heal_radius * heal_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self or enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		if not enemy.has_method("take_damage"):
			continue
		# Heal: clamp to max_health
		if "health" in enemy and "max_health" in enemy:
			enemy.health = min(enemy.max_health, enemy.health + heal_amount)
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("necrotic", global_position)

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

	var to_target = target.global_position - global_position
	var dist = to_target.length()

	_attack_cooldown = max(0.0, _attack_cooldown - delta)

	if dist <= attack_range:
		if _attack_cooldown <= 0.0:
			if target.has_method("take_damage"):
				target.take_damage(attack_damage)
			_attack_cooldown = 1.0 / max(0.1, attack_rate)
		velocity = Vector2.ZERO
	elif dist < preferred_distance:
		# Stay back from the player
		var away = -to_target.normalized()
		velocity = away * speed * 0.4 * _slow_multiplier
		move_and_slide()
	else:
		# Approach but not aggressively
		var dir = to_target.normalized()
		velocity = dir * speed * _slow_multiplier
		move_and_slide()
	_update_status_visuals()
