extends Tower

var flame_length: float = 148.0
var flame_cone_deg: float = 48.0
var max_targets: int = 8
var slow_factor: float = 0.58
var slow_duration: float = 1.25

func _ready() -> void:
	tower_type = "cannon"
	super._ready()

func get_fire_windup_time() -> float:
	return 0.028

func get_fire_recover_time() -> float:
	return 0.048

func get_fire_impulse_scale() -> float:
	return 0.92

func get_body_orientation_offset() -> float:
	return 0.0

func get_body_anim_idle_speed() -> float:
	return 0.8

func get_body_anim_target_speed() -> float:
	return 1.3

func get_body_anim_windup_speed() -> float:
	return 1.45

func get_body_anim_recover_speed() -> float:
	return 1.15

func get_evolution_options() -> Array:
	return [
		{
			"id": "long_range",
			"name": "Inferno Lance",
			"desc": "Long-range jet flame with tighter cone and higher DPS.",
			"cost": 3
		},
		{
			"id": "ice_flame",
			"name": "Cryoflame Emitter",
			"desc": "Converts to freezing flame that slows and controls hordes.",
			"cost": 3
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"long_range":
			flame_length *= 1.42
			flame_cone_deg = max(26.0, flame_cone_deg - 14.0)
			fire_rate *= 1.18
			damage *= 1.2
		"ice_flame":
			damage *= 0.86
			flame_length *= 1.18
			flame_cone_deg *= 1.08
			slow_factor = 0.48
			slow_duration = 1.6

func _apply_evolution_visuals() -> void:
	if body_sprite == null:
		return
	match evolution_id:
		"long_range":
			body_sprite.modulate = Color(1.1, 0.76, 0.48, 1.0)
		"ice_flame":
			body_sprite.modulate = Color(0.7, 0.92, 1.0, 1.0)

func get_muzzle_fx_profile() -> Dictionary:
	var profile = {
		"core_color": Color(1.0, 0.78, 0.35, 0.95),
		"glow_color": Color(1.0, 0.36, 0.08, 0.82),
		"pulse_mult": 1.3,
		"beam_length_mult": 1.2,
		"beam_width_mult": 1.28,
		"ring_scale_mult": 1.26,
		"particle_mult": 1.55
	}
	if upgrade_level >= 2:
		profile["pulse_mult"] = 1.42
		profile["beam_length_mult"] = 1.34
		profile["beam_width_mult"] = 1.4
	if upgrade_level >= 3:
		profile["pulse_mult"] = 1.58
		profile["beam_length_mult"] = 1.5
		profile["beam_width_mult"] = 1.52
		profile["ring_scale_mult"] = 1.45
		profile["particle_mult"] = 1.8
	if is_evolved and evolution_id == "ice_flame":
		profile["core_color"] = Color(0.84, 0.96, 1.0, 0.96)
		profile["glow_color"] = Color(0.44, 0.84, 1.0, 0.88)
		profile["particle_mult"] = 1.45
	elif is_evolved and evolution_id == "long_range":
		profile["beam_length_mult"] = 1.85
		profile["beam_width_mult"] = 1.26
	return profile

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	flame_length = float(tier_data.get("flame_length", flame_length))
	flame_cone_deg = float(tier_data.get("flame_cone_deg", flame_cone_deg))
	max_targets = int(tier_data.get("max_targets", max_targets))

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return
	var fire_dir = Vector2.RIGHT
	if target != null and is_instance_valid(target):
		fire_dir = (target.global_position - global_position).normalized()
	_trigger_fire_motion(0.95)
	_spawn_tower_fire_emitter(fire_dir, 1.25)
	var dmg_bonus: float = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = float(_game.get_tower_damage_bonus())
	var total_hits = _apply_cone_damage(fire_dir, damage + dmg_bonus)
	if total_hits > 0 and _game.has_method("spawn_fx"):
		var fx_kind = "fire_burst"
		if is_evolved and evolution_id == "ice_flame":
			fx_kind = "ice"
		_game.spawn_fx(fx_kind, global_position + fire_dir * (flame_length * 0.45))
	if total_hits >= max_targets and _game.has_method("spawn_setpiece_fx"):
		_game.spawn_setpiece_fx("cannon_impact", global_position + fire_dir * (flame_length * 0.5), 0.95, "ice" if (is_evolved and evolution_id == "ice_flame") else "fire")
	AudioManager.play_weapon_sound("cannon", global_position)

func _apply_cone_damage(forward: Vector2, base_damage: float) -> int:
	var enemies = _get_enemies()
	if enemies.is_empty():
		return 0
	var forward_norm = forward.normalized()
	var cone_radians = deg_to_rad(flame_cone_deg)
	var dot_threshold = cos(cone_radians * 0.5)
	var hit_count = 0
	var damage_type = "ice" if (is_evolved and evolution_id == "ice_flame") else "fire"
	for raw_enemy in enemies:
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		if not (raw_enemy is Node2D):
			continue
		var enemy = raw_enemy as Node2D
		var to_enemy = enemy.global_position - global_position
		var dist = to_enemy.length()
		if dist <= 0.01 or dist > flame_length:
			continue
		var to_enemy_norm = to_enemy / dist
		if to_enemy_norm.dot(forward_norm) < dot_threshold:
			continue
		var falloff = clampf(1.0 - (dist / flame_length) * 0.38, 0.45, 1.0)
		var dealt = base_damage * falloff
		if enemy.has_method("take_damage"):
			enemy.take_damage(dealt, enemy.global_position, false, true, damage_type)
		if damage_type == "ice" and enemy.has_method("apply_slow"):
			enemy.apply_slow(get_instance_id(), slow_factor, slow_duration)
		if _game != null and _game.has_method("track_damage_dealt"):
			_game.track_damage_dealt(dealt)
		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx("ice" if damage_type == "ice" else "fire_burst", enemy.global_position)
		hit_count += 1
		if hit_count >= max_targets:
			break
	return hit_count
