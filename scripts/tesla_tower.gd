extends Tower

# Shared static textures
static var _shared_orb_tex: ImageTexture = null
static var _shared_storm_field_tex: ImageTexture = null

# --- Baked 8-direction isometric art (same convention as arrow_turret) ---
const DIRECTIONAL_BASE_FRAMES := {
	"N": "res://assets/level1/towers_directional/tesla_t1_N.png",
	"NE": "res://assets/level1/towers_directional/tesla_t1_NE.png",
	"E": "res://assets/level1/towers_directional/tesla_t1_E.png",
	"SE": "res://assets/level1/towers_directional/tesla_t1_SE.png",
	"S": "res://assets/level1/towers_directional/tesla_t1_S.png",
	"SW": "res://assets/level1/towers_directional/tesla_t1_SW.png",
	"W": "res://assets/level1/towers_directional/tesla_t1_W.png",
	"NW": "res://assets/level1/towers_directional/tesla_t1_NW.png"
}
const DIRECTIONAL_BASE_FRAMES_T2 := {
	"N": "res://assets/level1/towers_directional/tesla_t2_N.png",
	"NE": "res://assets/level1/towers_directional/tesla_t2_NE.png",
	"E": "res://assets/level1/towers_directional/tesla_t2_E.png",
	"SE": "res://assets/level1/towers_directional/tesla_t2_SE.png",
	"S": "res://assets/level1/towers_directional/tesla_t2_S.png",
	"SW": "res://assets/level1/towers_directional/tesla_t2_SW.png",
	"W": "res://assets/level1/towers_directional/tesla_t2_W.png",
	"NW": "res://assets/level1/towers_directional/tesla_t2_NW.png"
}
# Matched to the arrow turret's rendered size (see cannon_tower.gd for the
# derivation). Tesla content is ~283x383px, so 0.210 renders 59.4 x 80.4 —
# the same silhouette height as the arrow instead of the previous 12% overshoot.
# Per-tier scales chosen so this tower renders the same silhouette height as
# the arrow turret (80.3 / 96.8 / 107.2 px at T1/T2/T3). A single base value
# with a shared growth rate could not hold: each tower's source art is a
# different size AND grows by a different amount between tiers, so they drifted
# apart again on upgrade. Regenerate with tools/measure_tower_scales.py if the
# art changes.
const DIRECTIONAL_BODY_SCALE_BY_TIER := [0.2096, 0.2489, 0.2756]
const DIRECTIONAL_BODY_SCALE := 0.2096
const _DIR_ORDER := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const _DIR_ANGLES := {
	"E": 0.0, "SE": PI * 0.25, "S": PI * 0.5, "SW": PI * 0.75,
	"W": PI, "NW": -PI * 0.75, "N": -PI * 0.5, "NE": -PI * 0.25
}
var _dir_tex_t1: Dictionary = {}
var _dir_tex_t2: Dictionary = {}
var _directional_loaded: bool = false
var _directional_active: bool = false
var _current_dir_key: String = ""
var _current_dir_tier: int = 0

var chain_count = 3
var lightning_storm = false
var stun_chance = 0.0
var storm_radius = 120.0
var _storm_timer = 0.0
var _storm_interval = 0.5

# Tesla tower specific visuals (note: _lightning_orb inherited from Tower)
var _secondary_coil: Sprite2D = null
var _arc_beams: Array[Line2D] = []
var _crackle_particles: CPUParticles2D = null
var _orb_float_angle: float = 0.0
var _line: Line2D = null

# Evolution: Storm Spire
var _storm_field_timer: float = 0.0
var _storm_field_interval: float = 0.5
var _storm_field_damage: float = 6.0
var _storm_field_radius: float = 200.0
var _storm_field_circle: Sprite2D = null

# Evolution: Arc Conduit
var _arc_bounce_damage_mult: float = 0.1  # +10% per bounce

func _ready() -> void:
	tower_type = "tesla"
	_load_directional_textures()
	super._ready()
	_setup_lightning_line()
	if _use_directional_art():
		_directional_active = true
		_enforce_directional_scale()
		_apply_directional_body(_dir_key_for(_last_fire_dir), true)

# --- Directional art system (mirrors arrow_turret) ---
func _load_directional_textures() -> void:
	if _directional_loaded:
		return
	_directional_loaded = true
	_dir_tex_t1 = _load_dir_frame_set(DIRECTIONAL_BASE_FRAMES)
	_dir_tex_t2 = _load_dir_frame_set(DIRECTIONAL_BASE_FRAMES_T2)

func _load_dir_frame_set(frame_paths: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in frame_paths.keys():
		var path := str(frame_paths[key])
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture2D:
				out[key] = tex
	return out

func _dir_tex_set() -> Dictionary:
	if upgrade_level >= 2 and not _dir_tex_t2.is_empty():
		return _dir_tex_t2
	return _dir_tex_t1

func _use_directional_art() -> bool:
	if is_evolved:
		return false
	return not _dir_tex_t1.is_empty()

func _dir_key_for(aim: Vector2) -> String:
	if aim.length_squared() <= 0.0001:
		return "S"
	var angle := aim.angle()
	var best_key := "S"
	var best_diff := TAU
	var tex_set := _dir_tex_set()
	for key in _DIR_ORDER:
		if not tex_set.has(key):
			continue
		var diff: float = abs(wrapf(angle - float(_DIR_ANGLES[key]), -PI, PI))
		if diff < best_diff:
			best_diff = diff
			best_key = key
	return best_key

func _apply_directional_body(dir_key: String, force: bool = false) -> void:
	if body_sprite == null:
		return
	var tex_set := _dir_tex_set()
	if not tex_set.has(dir_key):
		return
	var tier := 2 if (upgrade_level >= 2 and not _dir_tex_t2.is_empty()) else 1
	if not force and dir_key == _current_dir_key and tier == _current_dir_tier:
		return
	_current_dir_key = dir_key
	_current_dir_tier = tier
	var tex: Texture2D = tex_set[dir_key]
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", 1.0)
	frames.set_animation_loop("default", false)
	frames.add_frame("default", tex)
	body_sprite.sprite_frames = frames
	body_sprite.animation = "default"
	body_sprite.stop()
	body_sprite.frame = 0
	body_sprite.visible = true
	if _glow_sprite != null:
		_glow_sprite.texture = tex

func _enforce_directional_scale() -> void:
	if not _use_directional_art() or body_sprite == null:
		return
	var tier := clampi(upgrade_level, 1, 3)
	var s: float = float(DIRECTIONAL_BODY_SCALE_BY_TIER[clampi(tier - 1, 0, 2)])
	set_body_base_scale(s)
	_sync_body_anim_base_scale(true)

func get_fire_windup_time() -> float:
	return 0.026

func get_fire_recover_time() -> float:
	return 0.055

func get_fire_impulse_scale() -> float:
	return 0.72

func get_body_anim_idle_speed() -> float:
	return 0.84

func get_body_anim_target_speed() -> float:
	return 1.22

func get_body_anim_windup_speed() -> float:
	return 1.4

func get_body_anim_recover_speed() -> float:
	return 1.16

func get_body_orientation_offset() -> float:
	return 0.0

func get_body_idle_direction() -> Vector2:
	return Vector2.DOWN

func get_body_tracking_speed() -> float:
	return 11.5

func uses_split_body_presentation() -> bool:
	# Baked iso art and evolved flipbook bodies are both single front-facing
	# views; never split them.
	return not (_use_directional_art() or is_evolved)

func get_body_tracking_enabled() -> bool:
	# Orientation is chosen by swapping the baked iso frame, not by rotating.
	# Evolved bodies are front-facing flipbook art, so never rotate them either.
	if _use_directional_art() or is_evolved:
		return false
	return super.get_body_tracking_enabled()

func get_body_motion_profile() -> Dictionary:
	if _use_directional_art() or is_evolved:
		# Baked directional art: hold a static per-heading frame; no procedural
		# rotation/tracking/split, the frame swap in _process handles facing.
		return {
			"idle_direction": Vector2.DOWN,
			"tracking_enabled": false,
			"tracking_speed": 0.0,
			"tracking_max_angle": 0.0,
			"split_presentation": false,
		}
	return {
		"idle_direction": Vector2.DOWN,
		"tracking_enabled": true,
		"tracking_speed": 11.5,
		"tracking_max_angle": PI,
		"split_presentation": true,
		"split_ratio": 0.52,
		"split_overlap_px": 6,
	}

func get_muzzle_fx_profile() -> Dictionary:
	var profile = {
		"core_color": Color(0.7, 0.98, 1.0, 0.95),
		"glow_color": Color(0.24, 0.78, 1.0, 0.78),
		"pulse_mult": 0.9,
		"beam_length_mult": 1.15,
		"beam_width_mult": 1.08,
		"ring_scale_mult": 1.08,
		"particle_mult": 1.1
	}
	if upgrade_level >= 2:
		profile["pulse_mult"] = 1.0
		profile["beam_length_mult"] = 1.35
		profile["beam_width_mult"] = 1.16
		profile["particle_mult"] = 1.22
	if upgrade_level >= 3:
		profile["pulse_mult"] = 1.15
		profile["beam_length_mult"] = 1.55
		profile["beam_width_mult"] = 1.28
		profile["ring_scale_mult"] = 1.2
		profile["particle_mult"] = 1.4
	if is_evolved and evolution_id == "storm_spire":
		profile["core_color"] = Color(0.86, 0.98, 1.0, 0.98)
		profile["glow_color"] = Color(0.24, 0.62, 1.0, 0.85)
		profile["pulse_mult"] = 1.25
	elif is_evolved and evolution_id == "arc_conduit":
		profile["core_color"] = Color(0.72, 1.0, 1.0, 0.98)
		profile["glow_color"] = Color(0.16, 0.9, 1.0, 0.9)
		profile["beam_length_mult"] = 1.75
		profile["beam_width_mult"] = 1.36
	return profile

func _tesla_hit_fx_kind() -> String:
	if is_evolved and evolution_id == "arc_conduit":
		return "hero_energy_impact"
	if is_evolved and evolution_id == "storm_spire":
		return "chain_hit"
	if upgrade_level >= 3:
		return "chain_hit"
	return "tesla"

func get_evolution_options() -> Array:
	return [
		{
			"id": "storm_spire",
			"name": "Storm Spire",
			"desc": "Permanent lightning field damages all nearby enemies. Pure area denial.",
			"cost": 3
		},
		{
			"id": "arc_conduit",
			"name": "Arc Conduit",
			"desc": "15 chain targets, can bounce to same enemy. Each bounce +10% damage.",
			"cost": 3
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"storm_spire":
			chain_count = 4
			_storm_field_radius = 200.0
			_storm_field_damage = 6.0
		"arc_conduit":
			chain_count = 15
			damage = 16.0

func _apply_evolution_visuals() -> void:
	match evolution_id:
		"storm_spire":
			if body_sprite != null:
				body_sprite.modulate = Color(0.8, 0.9, 1.3, 1.0)
			# Create field circle visual — shared texture
			_storm_field_circle = Sprite2D.new()
			_storm_field_circle.z_index = -3
			if _shared_storm_field_tex == null:
				var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
				img.fill(Color(0, 0, 0, 0))
				var center = Vector2(32, 32)
				for x in range(64):
					for y in range(64):
						var d = Vector2(x, y).distance_to(center)
						if d < 30 and d > 24:
							img.set_pixel(x, y, Color(0.3, 0.7, 1.0, 0.25))
						elif d < 24:
							img.set_pixel(x, y, Color(0.2, 0.5, 0.9, 0.08))
				_shared_storm_field_tex = ImageTexture.create_from_image(img)
			_storm_field_circle.texture = _shared_storm_field_tex
			_storm_field_circle.scale = Vector2.ONE * (_storm_field_radius / 32.0)
			var mat = CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_storm_field_circle.material = mat
			add_child(_storm_field_circle)
		"arc_conduit":
			if body_sprite != null:
				body_sprite.modulate = Color(0.6, 0.8, 1.4, 1.0)

static func _get_orb_tex() -> ImageTexture:
	if _shared_orb_tex != null:
		return _shared_orb_tex
	var img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(10, 10)
	for x in range(20):
		for y in range(20):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 9:
				var intensity = 1.0 - (dist / 9.0)
				img.set_pixel(x, y, Color(0.4, 0.8, 1.0, intensity))
	_shared_orb_tex = ImageTexture.create_from_image(img)
	return _shared_orb_tex

func _setup_tower_specific_visuals() -> void:
	# Secondary coil for T2 (initially hidden)
	_secondary_coil = Sprite2D.new()
	_secondary_coil.name = "SecondaryCoil"
	_secondary_coil.z_index = -1
	_secondary_coil.modulate = Color(0.5, 0.7, 1.0, 0.0)
	_secondary_coil.position = Vector2(8, 0)
	if body_sprite != null and body_sprite.sprite_frames != null:
		_secondary_coil.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
	var coil_material = CanvasItemMaterial.new()
	coil_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_secondary_coil.material = coil_material
	add_child(_secondary_coil)

	# Legacy T3 floating/pulsing lightning orb + jagged arc beams removed.

	# Crackle particles for T3 — reduced amount
	_crackle_particles = CPUParticles2D.new()
	_crackle_particles.name = "CrackleParticles"
	_crackle_particles.amount = 6
	_crackle_particles.lifetime = 0.5
	_crackle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_crackle_particles.emission_sphere_radius = 20.0
	_crackle_particles.gravity = Vector2(0, -20)
	_crackle_particles.initial_velocity_min = 10.0
	_crackle_particles.initial_velocity_max = 30.0
	_crackle_particles.scale_amount_min = 0.3
	_crackle_particles.scale_amount_max = 0.8
	_crackle_particles.color = Color(0.4, 0.9, 1.0, 0.0)
	_crackle_particles.emitting = false
	add_child(_crackle_particles)

func _setup_lightning_line() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(0.3, 0.8, 1.0, 0.9)
	_line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_line.z_index = 10
	# Start empty + hidden so an un-fired arc-conduit line never renders a stray
	# segment from the tower toward the origin (the "white line across screen").
	_line.points = PackedVector2Array()
	_line.visible = false
	add_child(_line)

func _update_tower_specific_visuals() -> void:
	if not is_inside_tree():
		return
	# Directional art path: the baked sprite already depicts the upgraded look,
	# so swap to the active-tier frame and suppress the procedural overlays.
	if _use_directional_art():
		_enforce_directional_scale()
		_current_dir_key = ""
		_apply_directional_body(_dir_key_for(_last_fire_dir), true)
		if _secondary_coil != null:
			_secondary_coil.modulate = Color(0.5, 0.7, 1.0, 0.0)
		if _crackle_particles != null:
			_crackle_particles.emitting = false
			_crackle_particles.modulate = Color(0.4, 0.9, 1.0, 0.0)
		return
	# T2: Show secondary coil with arcing
	if _secondary_coil != null:
		var tween = create_tween()
		if upgrade_level >= 2:
			_secondary_coil.scale = Vector2.ONE * 1.15
			tween.tween_property(_secondary_coil, "modulate", Color(0.7, 0.9, 1.2, 0.9), 0.3)
		else:
			tween.tween_property(_secondary_coil, "modulate", Color(0.5, 0.7, 1.0, 0.0), 0.3)
	
	# T3: ambient crackle particles only (floating orb + arc beams removed)
	if upgrade_level >= 3:
		if _crackle_particles != null:
			_crackle_particles.emitting = true
			_crackle_particles.modulate = Color(0.5, 1.0, 1.0, 0.85)
	else:
		if _crackle_particles != null:
			_crackle_particles.emitting = false
			_crackle_particles.modulate = Color(0.4, 0.9, 1.0, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
	if not is_inside_tree():
		return
	if upgrade_level == 2:
		# Secondary coil fades in with electric flash
		if _secondary_coil != null:
			_secondary_coil.modulate = Color(2.0, 2.5, 3.0, 0.0)
			var tween = create_tween()
			tween.tween_property(_secondary_coil, "modulate", Color(0.6, 0.8, 1.0, 0.7), 0.4)
	
func _process(delta: float) -> void:
	super._process(delta)
	# Swap to the baked frame matching the current aim heading.
	if _directional_active and _use_directional_art():
		_apply_directional_body(_dir_key_for(_last_fire_dir))
	# Handle lightning storm AOE for T3
	if lightning_storm and upgrade_level >= 3:
		_storm_timer -= delta
		if _storm_timer <= 0:
			_storm_timer = _storm_interval
			_trigger_lightning_storm()

	# Storm Spire evolution: permanent aura damage
	if is_evolved and evolution_id == "storm_spire":
		_storm_field_timer -= delta
		if _storm_field_timer <= 0:
			_storm_field_timer = _storm_field_interval
			_tick_storm_field()
		# Pulse visual
		if _storm_field_circle != null:
			var pulse = 0.8 + sin(Time.get_ticks_msec() * 0.003) * 0.2
			_storm_field_circle.modulate.a = pulse

func _tick_storm_field() -> void:
	if _game == null:
		return
	var field_dmg = _storm_field_damage
	# Double damage during lightning storm
	if lightning_storm:
		field_dmg *= 2.0
	var dmg_bonus = 0.0
	if _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var enemies = _get_enemies()
	var hits = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) <= _storm_field_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(field_dmg + dmg_bonus, enemy.global_position, false, true)
			hits += 1
			if hits >= 8:  # Cap per tick
				break
	# Occasional visual spark
	if hits > 0 and _game.has_method("spawn_fx") and randf() < 0.3:
		var random_enemy = enemies[randi() % enemies.size()] if enemies.size() > 0 else null
		if random_enemy != null and is_instance_valid(random_enemy):
			_game.spawn_fx(_tesla_hit_fx_kind(), random_enemy.global_position)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	chain_count = int(tier_data.get("chain_count", chain_count))
	lightning_storm = bool(tier_data.get("lightning_storm", false))
	stun_chance = float(tier_data.get("stun_chance", 0.0))
	storm_radius = range * 0.5  # Storm radius is half of tower range

func _trigger_lightning_storm() -> void:
	if _game == null:
		return
	# Find enemies in storm radius around tower
	var enemies = _get_enemies()
	var storm_hits = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_pos = enemy.global_position
		var dist = global_position.distance_to(enemy_pos)
		if dist <= storm_radius:
			# Random AOE lightning strike
			var dmg_bonus = 0.0
			if _game.has_method("get_tower_damage_bonus"):
				dmg_bonus = _game.get_tower_damage_bonus()
			
			if enemy.has_method("take_damage"):
				enemy.take_damage((damage + dmg_bonus) * 0.5, enemy_pos, false, true)
			
			# Stun chance
			if stun_chance > 0 and randf() < stun_chance and enemy.has_method("stun"):
				enemy.stun(0.5)
			
			if _game.has_method("spawn_fx"):
				_game.spawn_fx(_tesla_hit_fx_kind(), enemy_pos)
			
			storm_hits += 1
			if storm_hits >= 3:  # Max 3 storm strikes per interval
				break

func _fire_at(target: Node2D) -> void:
	_trigger_fire_motion(0.8)
	AudioManager.play_weapon_sound(tower_type, global_position)
	var fire_dir = Vector2.RIGHT
	if target != null and is_instance_valid(target):
		fire_dir = (target.global_position - global_position).normalized()
	_spawn_tower_fire_emitter(fire_dir, 0.82)
	# Arc Conduit: special chain logic that allows re-hitting
	if is_evolved and evolution_id == "arc_conduit":
		_fire_arc_conduit(target)
		return

	# Snapshot distance before sort so comparator never dereferences potentially freed nodes.
	var enemy_entries: Array = []
	for raw_enemy in _get_enemies():
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		if not (raw_enemy is Node2D):
			continue
		var enemy := raw_enemy as Node2D
		enemy_entries.append({
			"enemy": enemy,
			"dist_sq": global_position.distance_squared_to(enemy.global_position)
		})
	enemy_entries.sort_custom(func(a, b):
		return float(a.get("dist_sq", INF)) < float(b.get("dist_sq", INF))
	)
	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var emp_level = 0
	if _game != null and _game.has_method("get_tech_level"):
		emp_level = _game.get_tech_level("tesla_emp")
	var chain_bonus = 0
	if _game != null and _game.has_method("get_tower_chain_bonus"):
		chain_bonus = int(_game.get_tower_chain_bonus())
	var effective_chain_count = max(1, chain_count + chain_bonus)

	var hits = 0
	var last_pos = global_position
	var line_points: PackedVector2Array = [Vector2.ZERO]  # Start at tower center
	var hit_positions: Array[Vector2] = []

	for entry in enemy_entries:
		var raw_enemy = entry.get("enemy", null)
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		var enemy := raw_enemy as Node2D
		if enemy == null:
			continue
		var enemy_pos = enemy.global_position
		if global_position.distance_squared_to(enemy_pos) > range * range:
			continue

		# Visual lightning arc to this enemy
		var arc_points = _generate_arc(last_pos, enemy_pos, 3)
		for pt in arc_points:
			line_points.append(pt - global_position)

		if enemy.has_method("take_damage"):
			enemy.take_damage(damage + dmg_bonus, enemy_pos, false, true)

		# Stun chance for T3
		if stun_chance > 0 and randf() < stun_chance and enemy.has_method("stun"):
			enemy.stun(0.3)

		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx(_tesla_hit_fx_kind(), enemy_pos)
			if hits > 0:
				_game.spawn_fx("chain_hit", enemy_pos)

		if emp_level > 0 and enemy.has_method("apply_slow"):
			var slow_factor = max(0.45, 0.8 - emp_level * 0.12)
			var slow_duration = 0.6 + 0.2 * emp_level
			enemy.apply_slow(get_instance_id(), slow_factor, slow_duration)

		if emp_level > 0 and enemy.has_method("stun"):
			enemy.stun(0.08 * emp_level)

		last_pos = enemy_pos
		hit_positions.append(enemy_pos)
		hits += 1
		if hits >= effective_chain_count:
			break
	if hits >= 3 and _game != null and _game.has_method("spawn_setpiece_fx"):
		_game.spawn_setpiece_fx("energy_impact", last_pos, clampf(float(hits) / 4.0, 0.8, 1.35), "lightning")

func _fire_arc_conduit(target: Node2D) -> void:
	var enemies = _get_enemies()
	var in_range: Array = []
	for e in enemies:
		if e != null and is_instance_valid(e) and global_position.distance_squared_to(e.global_position) <= range * range:
			in_range.append(e)
	if in_range.is_empty():
		return

	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var emp_level = 0
	if _game != null and _game.has_method("get_tech_level"):
		emp_level = _game.get_tech_level("tesla_emp")
	var chain_bonus = 0
	if _game != null and _game.has_method("get_tower_chain_bonus"):
		chain_bonus = int(_game.get_tower_chain_bonus())
	var effective_chain_count = max(1, chain_count + chain_bonus)

	var hits = 0
	var current_dmg = damage + dmg_bonus
	var last_pos = global_position
	var line_points: PackedVector2Array = [Vector2.ZERO]
	var hit_positions: Array[Vector2] = []
	var current_target = target

	while hits < effective_chain_count:
		if current_target == null or not is_instance_valid(current_target):
			break
		var current_pos = current_target.global_position

		# Arc visual
		var arc_points = _generate_arc(last_pos, current_pos, 3)
		for pt in arc_points:
			line_points.append(pt - global_position)

		# Deal escalating damage
		if current_target.has_method("take_damage"):
			current_target.take_damage(current_dmg, current_pos, false, true)

		if stun_chance > 0 and randf() < stun_chance and current_target.has_method("stun"):
			current_target.stun(0.3)

		if _game != null and _game.has_method("spawn_fx"):
			_game.spawn_fx(_tesla_hit_fx_kind(), current_pos)
			if hits > 0:
				_game.spawn_fx("chain_hit", current_pos)

		if emp_level > 0 and current_target.has_method("apply_slow"):
			current_target.apply_slow(get_instance_id(), max(0.45, 0.8 - emp_level * 0.12), 0.6 + 0.2 * emp_level)

		last_pos = current_pos
		hit_positions.append(current_pos)
		hits += 1
		current_dmg *= (1.0 + _arc_bounce_damage_mult)  # Escalate!

		# Find next target (can bounce to any in-range enemy, including already-hit)
		var best: Node2D = null
		var best_dist = 999999.0
		for e in in_range:
			if e == null or not is_instance_valid(e) or e == current_target:
				continue
			var e_pos = e.global_position
			var d = last_pos.distance_to(e_pos)
			if d < best_dist and d < range * 0.7:
				best_dist = d
				best = e
		# If no other target, bounce back to any random one
		if best == null and in_range.size() > 1:
			var candidates = in_range.filter(func(e):
				return e != null and is_instance_valid(e) and e != current_target
			)
			if not candidates.is_empty():
				best = candidates[randi() % candidates.size()]
		# If still no target but original is alive, bounce back to it
			if best == null and current_target != null and is_instance_valid(current_target):
				best = current_target
			current_target = best
	if hits >= 4 and _game != null and _game.has_method("spawn_setpiece_fx"):
		_game.spawn_setpiece_fx("energy_impact", last_pos, clampf(float(hits) / 5.0, 0.9, 1.5), "lightning")

	# Show arc conduit lightning lines
	_line.points = line_points
	_line.visible = true
	_line.default_color = Color(0.4, 0.9, 1.0, 0.9)
	_line.modulate.a = 1.0
	if _game != null and _game.fx_manager != null and hit_positions.size() > 0:
		_game.fx_manager.spawn_tesla_lightning(global_position, hit_positions)
	if not is_inside_tree():
		return
	var arc_tween = create_tween()
	arc_tween.tween_property(_line, "modulate:a", 0.0, 0.12)
	arc_tween.tween_callback(func():
		_line.visible = false
	)
	arc_tween.tween_property(_line, "modulate:a", 0.9, 0.0)

func _generate_arc(from: Vector2, to: Vector2, segments: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var mid = (from + to) / 2.0
	var jitter = (to - from).length() * 0.15
	mid += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
	
	for i in range(1, segments + 1):
		var t = float(i) / (segments + 1)
		# Quadratic bezier-ish with jitter
		var pos = from.lerp(to, t)
		var curve = sin(t * PI) * jitter * 0.5
		pos += Vector2(randf_range(-curve, curve), randf_range(-curve, curve))
		points.append(pos)
	
	points.append(to)
	return points
