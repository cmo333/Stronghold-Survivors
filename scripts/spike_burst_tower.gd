extends Tower

var burst_count: int = 8
var projectile_pierce: int = 0
var projectile_slow_factor: float = 1.0
var projectile_slow_duration: float = 0.0

func _ready() -> void:
	tower_type = "arrow"
	super._ready()

func get_fire_windup_time() -> float:
	return 0.07

func get_fire_recover_time() -> float:
	return 0.11

func get_fire_impulse_scale() -> float:
	return 1.08

func get_body_orientation_offset() -> float:
	return 0.0

func get_body_anim_idle_speed() -> float:
	return 0.74

func get_body_anim_target_speed() -> float:
	return 1.04

func get_body_anim_windup_speed() -> float:
	return 1.22

func get_body_anim_recover_speed() -> float:
	return 0.96

func get_evolution_options() -> Array:
	return [
		{
			"id": "razorstorm",
			"name": "Razorstorm Matrix",
			"desc": "Adds more spikes, higher cadence, and extra pierce.",
			"cost": 3
		},
		{
			"id": "frostburst",
			"name": "Cryo Spike Halo",
			"desc": "Converts spikes to cryo shards that heavily slow enemies.",
			"cost": 3
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"razorstorm":
			fire_rate *= 1.28
			damage *= 1.2
			burst_count += 2
			projectile_pierce = max(projectile_pierce, 1)
		"frostburst":
			damage *= 0.88
			projectile_speed *= 1.08
			projectile_slow_factor = 0.58
			projectile_slow_duration = 1.25

func _apply_evolution_visuals() -> void:
	if body_sprite == null:
		return
	match evolution_id:
		"razorstorm":
			body_sprite.modulate = Color(1.0, 0.78, 0.5, 1.0)
		"frostburst":
			body_sprite.modulate = Color(0.7, 0.92, 1.0, 1.0)

func get_projectile_visual_profile() -> Dictionary:
	var profile = {
		"projectile_frames": [
			"res://assets/fx/fx_stab_star_16_f001_v002.png",
			"res://assets/fx/fx_stab_star_16_f002_v002.png",
			"res://assets/fx/fx_stab_star_16_f003_v002.png",
			"res://assets/fx/fx_stab_star_16_f004_v002.png"
		],
		"projectile_fps": 17.0,
		"projectile_static_frame": 0,
		"projectile_scale": 1.18,
		"trail_damage_type": "normal",
		"impact_damage_type": "normal",
		"impact_fx_kind": "hit",
		"projectile_tint": Color(1.0, 0.92, 0.7, 1.0)
	}
	if upgrade_level >= 2:
		profile["projectile_scale"] = 1.3
		profile["projectile_fps"] = 19.0
		profile["impact_fx_kind"] = "crit"
		profile["projectile_tint"] = Color(1.0, 0.72, 0.35, 1.0)
	if upgrade_level >= 3:
		profile["projectile_scale"] = 1.42
		profile["projectile_fps"] = 21.0
		profile["impact_fx_kind"] = "chain_hit"
		profile["projectile_tint"] = Color(1.0, 0.56, 0.18, 1.0)
	if is_evolved and evolution_id == "frostburst":
		profile["trail_damage_type"] = "ice"
		profile["impact_damage_type"] = "ice"
		profile["impact_fx_kind"] = "ice"
		profile["projectile_tint"] = Color(0.62, 0.9, 1.0, 1.0)
	elif is_evolved and evolution_id == "razorstorm":
		profile["impact_fx_kind"] = "hero_cannon_impact"
		profile["projectile_tint"] = Color(1.0, 0.48, 0.2, 1.0)
	return profile

func get_muzzle_fx_profile() -> Dictionary:
	var profile = {
		"core_color": Color(1.0, 0.9, 0.64, 0.95),
		"glow_color": Color(1.0, 0.54, 0.2, 0.78),
		"pulse_mult": 1.08,
		"beam_length_mult": 0.95,
		"beam_width_mult": 1.2,
		"ring_scale_mult": 1.16,
		"particle_mult": 1.15
	}
	if is_evolved and evolution_id == "frostburst":
		profile["core_color"] = Color(0.86, 0.98, 1.0, 0.95)
		profile["glow_color"] = Color(0.42, 0.85, 1.0, 0.8)
		profile["beam_length_mult"] = 1.1
	elif is_evolved and evolution_id == "razorstorm":
		profile["pulse_mult"] = 1.25
		profile["beam_width_mult"] = 1.4
		profile["ring_scale_mult"] = 1.35
		profile["particle_mult"] = 1.35
	return profile

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	burst_count = int(tier_data.get("burst_count", burst_count))
	projectile_pierce = int(tier_data.get("projectile_pierce", projectile_pierce))

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return
	var fire_dir = Vector2.RIGHT
	if target != null and is_instance_valid(target):
		fire_dir = (target.global_position - global_position).normalized()
	_trigger_fire_motion(1.05)
	_spawn_tower_fire_emitter(fire_dir, 1.12)
	var dmg_bonus: float = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = float(_game.get_tower_damage_bonus())
	var radial_count = max(6, burst_count)
	var damage_type = "ice" if (is_evolved and evolution_id == "frostburst") else "normal"
	var profile = get_projectile_visual_profile()
	var base_angle = fire_dir.angle()
	for i in range(radial_count):
		var angle = base_angle + (TAU * float(i) / float(radial_count))
		var dir = Vector2.RIGHT.rotated(angle)
		_game.spawn_projectile(
			global_position,
			dir,
			projectile_speed,
			damage + dmg_bonus,
			projectile_range,
			0.0,
			projectile_pierce,
			projectile_slow_factor,
			projectile_slow_duration,
			damage_type,
			profile
		)
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("chain_hit" if damage_type == "ice" else "blood", global_position)
	if _game.has_method("spawn_setpiece_fx") and radial_count >= 10:
		_game.spawn_setpiece_fx("energy_impact", global_position, 1.0 if damage_type == "ice" else 0.85, "lightning" if damage_type == "ice" else "normal")
	AudioManager.play_weapon_sound("arrow", global_position)
