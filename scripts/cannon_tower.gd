extends Tower

var cluster_bombs = false
var burn_effect = false
var burn_damage = 5.0
var burn_duration = 3.0

# --- Baked 8-direction isometric art (same convention as arrow_turret) ---
const DIRECTIONAL_BASE_FRAMES := {
	"N": "res://assets/level1/towers_directional/cannon_t1_N.png",
	"NE": "res://assets/level1/towers_directional/cannon_t1_NE.png",
	"E": "res://assets/level1/towers_directional/cannon_t1_E.png",
	"SE": "res://assets/level1/towers_directional/cannon_t1_SE.png",
	"S": "res://assets/level1/towers_directional/cannon_t1_S.png",
	"SW": "res://assets/level1/towers_directional/cannon_t1_SW.png",
	"W": "res://assets/level1/towers_directional/cannon_t1_W.png",
	"NW": "res://assets/level1/towers_directional/cannon_t1_NW.png"
}
const DIRECTIONAL_BASE_FRAMES_T2 := {
	"N": "res://assets/level1/towers_directional/cannon_t2_N.png",
	"NE": "res://assets/level1/towers_directional/cannon_t2_NE.png",
	"E": "res://assets/level1/towers_directional/cannon_t2_E.png",
	"SE": "res://assets/level1/towers_directional/cannon_t2_SE.png",
	"S": "res://assets/level1/towers_directional/cannon_t2_S.png",
	"SW": "res://assets/level1/towers_directional/cannon_t2_SW.png",
	"W": "res://assets/level1/towers_directional/cannon_t2_W.png",
	"NW": "res://assets/level1/towers_directional/cannon_t2_NW.png"
}
# Source cells are ~360-390px; this scale fills the build cell like arrow art.
# Normalised so every tower reads at the same on-screen size as the arrow
# turret. Source art differs wildly (arrow content is ~988x1147px, cannon
# ~347x385), so a shared scale value would not have matched — these are derived
# from the measured opaque bounds:
#   arrow renders 988*0.070 = 69.2 wide, 1147*0.070 = 80.3 tall
#   cannon at 0.199 renders 347*0.199 = 69.0 x 76.6, fitting that same box
# Previously 0.235, which rendered 18% wider and 13% taller than the arrow and
# made the cannon read as a much bigger building than it is.
# Per-tier scales chosen so this tower renders the same silhouette height as
# the arrow turret (80.3 / 96.8 / 107.2 px at T1/T2/T3). A single base value
# with a shared growth rate could not hold: each tower's source art is a
# different size AND grows by a different amount between tiers, so they drifted
# apart again on upgrade. Regenerate with tools/measure_tower_scales.py if the
# art changes.
const DIRECTIONAL_BODY_SCALE_BY_TIER := [0.2085, 0.2464, 0.2728]
const DIRECTIONAL_BODY_SCALE := 0.2085
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

# Shared static textures
static var _shared_barrel_tex: ImageTexture = null
static var _shared_rune_texes: Array[ImageTexture] = []

# Cannon tower specific visuals (note: _steam_vents and _rune_glows inherited from Tower)
var _reinforced_barrel: Sprite2D = null
var _multi_barrels: Array[Sprite2D] = []
var _smoke_trails: CPUParticles2D = null
var _barrel_rotation: float = 0.0

# Evolution: Hellfire
var hellfire_pool_damage: float = 8.0
var hellfire_pool_duration: float = 3.0

# Shared fire pool texture
static var _shared_fire_pool_tex: ImageTexture = null

# Evolution: Shockwave
var shockwave_knockback: float = 120.0
var shockwave_stun_chance: float = 0.4
var shockwave_stun_duration: float = 0.5

func _ready() -> void:
	tower_type = "cannon"
	_load_directional_textures()
	super._ready()
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
	body_sprite.scale = Vector2.ONE * s
	_sync_body_anim_base_scale(true)

# Directional art is a single baked iso view: don't split/rotate the body.
# Evolved bodies are front-facing flipbook art: keep them whole (no split).
func uses_split_body_presentation() -> bool:
	if _use_directional_art() or is_evolved:
		return false
	return true

func get_body_tracking_enabled() -> bool:
	# Orientation is chosen by swapping the baked iso frame, not by rotating.
	# Evolved bodies are front-facing flipbook art, so never rotate them either.
	if _use_directional_art() or is_evolved:
		return false
	return super.get_body_tracking_enabled()

func _process(delta: float) -> void:
	super._process(delta)
	if _directional_active and not is_evolved:
		_apply_directional_body(_dir_key_for(_last_fire_dir))

func get_fire_windup_time() -> float:
	return 0.095

func get_fire_recover_time() -> float:
	return 0.18

func get_fire_impulse_scale() -> float:
	return 1.45

func get_body_anim_idle_speed() -> float:
	return 0.62

func get_body_anim_target_speed() -> float:
	return 0.92

func get_body_anim_windup_speed() -> float:
	return 1.18

func get_body_anim_recover_speed() -> float:
	return 0.82

func get_body_orientation_offset() -> float:
	return 0.0

func get_body_idle_direction() -> Vector2:
	return Vector2.DOWN

func get_body_tracking_speed() -> float:
	return 8.5

func get_body_motion_profile() -> Dictionary:
	# Directional baked art is a single static iso view — disable split/tracking
	# so the base Tower doesn't rotate it; per-heading frame swap handles aiming.
	if _use_directional_art() or is_evolved:
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
		"tracking_speed": 8.5,
		"tracking_max_angle": PI,
		"split_presentation": true,
		"split_ratio": 0.54,
		"split_overlap_px": 4,
	}

func get_projectile_visual_profile() -> Dictionary:
	var profile = {
		"projectile_frames": [
			"res://assets/fx/fx_explosion_small_32_f001_v003.png",
			"res://assets/fx/fx_explosion_small_32_f002_v003.png",
			"res://assets/fx/fx_explosion_small_32_f003_v003.png",
			"res://assets/fx/fx_explosion_small_32_f004_v003.png"
		],
		"projectile_fps": 16.0,
		"projectile_static_frame": 0,
		"projectile_scale": 1.2,
		"trail_damage_type": "fire",
		"impact_damage_type": "fire",
		"impact_fx_kind": "hero_cannon_impact",
		"projectile_tint": Color(1.0, 0.68, 0.28, 0.95)
	}
	if upgrade_level == 2:
		profile["projectile_fps"] = 18.0
		profile["projectile_scale"] = 1.38
		profile["projectile_tint"] = Color(1.0, 0.58, 0.2, 0.96)
	elif upgrade_level >= 3:
		profile["projectile_fps"] = 20.0
		profile["projectile_scale"] = 1.55
		profile["impact_fx_kind"] = "elite_kill"
		profile["projectile_tint"] = Color(1.0, 0.48, 0.16, 1.0)
	if is_evolved and evolution_id == "shockwave":
		profile["trail_damage_type"] = "lightning"
		profile["impact_damage_type"] = "lightning"
		profile["impact_fx_kind"] = "hero_energy_impact"
		profile["projectile_tint"] = Color(0.45, 0.85, 1.0, 1.0)
	elif is_evolved and evolution_id == "hellfire":
		profile["impact_fx_kind"] = "hero_cannon_impact"
		profile["projectile_tint"] = Color(1.0, 0.35, 0.1, 1.0)
	return profile

func get_muzzle_fx_profile() -> Dictionary:
	var profile = {
		"core_color": Color(1.0, 0.84, 0.44, 0.96),
		"glow_color": Color(1.0, 0.45, 0.18, 0.8),
		"pulse_mult": 1.2,
		"beam_length_mult": 0.95,
		"beam_width_mult": 1.35,
		"ring_scale_mult": 1.3,
		"particle_mult": 1.3
	}
	if upgrade_level >= 2:
		profile["pulse_mult"] = 1.32
		profile["beam_width_mult"] = 1.5
		profile["ring_scale_mult"] = 1.42
	if upgrade_level >= 3:
		profile["pulse_mult"] = 1.5
		profile["beam_width_mult"] = 1.7
		profile["ring_scale_mult"] = 1.62
	if is_evolved and evolution_id == "shockwave":
		profile["core_color"] = Color(0.72, 0.92, 1.0, 0.98)
		profile["glow_color"] = Color(0.3, 0.7, 1.0, 0.88)
	elif is_evolved and evolution_id == "hellfire":
		profile["core_color"] = Color(1.0, 0.66, 0.28, 0.98)
		profile["glow_color"] = Color(1.0, 0.28, 0.08, 0.9)
	return profile

func get_evolution_options() -> Array:
	return [
		{
			"id": "hellfire",
			"name": "Hellfire Mortar",
			"desc": "Larger explosions that leave fire pools. Burns enemies over time.",
			"cost": 4
		},
		{
			"id": "shockwave",
			"name": "Shockwave Cannon",
			"desc": "Knockback + stun on hit. Faster fire rate. Crowd control king.",
			"cost": 4
		}
	]

func _apply_evolution_stats() -> void:
	match evolution_id:
		"hellfire":
			explosion_radius = 200.0
			fire_rate = 0.6
			cluster_bombs = true
			burn_effect = true
		"shockwave":
			explosion_radius = 180.0
			damage = 25.0
			fire_rate = 1.0

func _apply_evolution_visuals() -> void:
	match evolution_id:
		"hellfire":
			if body_sprite != null:
				body_sprite.modulate = Color(1.3, 0.8, 0.5, 1.0)
		"shockwave":
			if body_sprite != null:
				body_sprite.modulate = Color(0.7, 0.8, 1.2, 1.0)

static func _get_barrel_tex() -> ImageTexture:
	if _shared_barrel_tex != null:
		return _shared_barrel_tex
	var img = Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(16):
		for y in range(24):
			var dx = abs(x - 8)
			if dx < 5 and y > 2 and y < 22:
				var shade = 0.3 + 0.2 * sin(y * 0.3)
				img.set_pixel(x, y, Color(shade + 0.3, shade, shade, 1.0))
			if y >= 20 and dx < 6:
				img.set_pixel(x, y, Color(0.2, 0.1, 0.1, 1.0))
	_shared_barrel_tex = ImageTexture.create_from_image(img)
	return _shared_barrel_tex

static func _get_rune_texes() -> Array[ImageTexture]:
	if not _shared_rune_texes.is_empty():
		return _shared_rune_texes
	var patterns = [
		[" XX ", "X  X", " XX ", "X  X"],
		["XXXX", "  X ", " X  ", "XXXX"],
		["X  X", "X  X", "XXXX", "X  X"],
		["XXXX", "X   ", "XXXX", "   X"],
	]
	for i in range(4):
		var img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var pattern = patterns[i]
		for y in range(4):
			for x in range(4):
				if pattern[y][x] == "X":
					img.set_pixel(x * 3 + 1, y * 3 + 1, Color(1.0, 0.5, 0.2, 1.0))
					img.set_pixel(x * 3 + 2, y * 3 + 1, Color(1.0, 0.5, 0.2, 1.0))
					img.set_pixel(x * 3 + 1, y * 3 + 2, Color(1.0, 0.5, 0.2, 1.0))
					img.set_pixel(x * 3 + 2, y * 3 + 2, Color(1.0, 0.5, 0.2, 1.0))
		_shared_rune_texes.append(ImageTexture.create_from_image(img))
	return _shared_rune_texes

func _setup_tower_specific_visuals() -> void:
	# Reinforced barrel overlay for T2 (initially hidden)
	_reinforced_barrel = Sprite2D.new()
	_reinforced_barrel.name = "ReinforcedBarrel"
	_reinforced_barrel.z_index = 1
	_reinforced_barrel.modulate = Color(0.8, 0.3, 0.2, 0.0)
	if body_sprite != null and body_sprite.sprite_frames != null:
		_reinforced_barrel.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
	add_child(_reinforced_barrel)

	# Steam vents for T2 — reduced to 1 vent, lower particle count
	var vent = CPUParticles2D.new()
	vent.name = "SteamVent"
	vent.z_index = 2
	vent.position = Vector2(0, -8)
	vent.amount = 4
	vent.lifetime = 0.6
	vent.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	vent.gravity = Vector2(0, -30)
	vent.initial_velocity_min = 5.0
	vent.initial_velocity_max = 15.0
	vent.scale_amount_min = 0.5
	vent.scale_amount_max = 1.0
	vent.color = Color(0.9, 0.9, 0.95, 0.0)
	vent.emitting = false
	add_child(vent)
	_steam_vents.append(vent)

	# Legacy T3 rotating multi-barrel assembly + pulsing glowing runes removed.

	# Smoke trails for T3 — reduced amount
	_smoke_trails = CPUParticles2D.new()
	_smoke_trails.name = "SmokeTrails"
	_smoke_trails.z_index = -1
	_smoke_trails.amount = 8
	_smoke_trails.lifetime = 1.5
	_smoke_trails.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke_trails.emission_sphere_radius = 8.0
	_smoke_trails.gravity = Vector2(0, -10)
	_smoke_trails.initial_velocity_min = 5.0
	_smoke_trails.initial_velocity_max = 15.0
	_smoke_trails.scale_amount_min = 0.8
	_smoke_trails.scale_amount_max = 2.0
	_smoke_trails.color = Color(0.3, 0.3, 0.3, 0.0)
	_smoke_trails.emitting = false
	add_child(_smoke_trails)

func _update_tower_specific_visuals() -> void:
	if not is_inside_tree():
		return
	# Directional baked art already depicts each tier's look (twin-barrel T2),
	# so swap to the right tier frame and skip the procedural barrel/rune overlays.
	if _use_directional_art():
		_enforce_directional_scale()
		_current_dir_key = ""
		_apply_directional_body(_dir_key_for(_last_fire_dir), true)
		if _reinforced_barrel != null:
			_reinforced_barrel.modulate = Color(1, 1, 1, 0)
		return
	# T2: Show reinforced barrel and steam vents
	if _reinforced_barrel != null:
		var tween = create_tween()
		if upgrade_level >= 2:
			_reinforced_barrel.scale = Vector2.ONE * 1.15
			tween.tween_property(_reinforced_barrel, "modulate", Color(0.95, 0.35, 0.25, 1.0), 0.3)
		else:
			tween.tween_property(_reinforced_barrel, "modulate", Color(0.8, 0.3, 0.2, 0.0), 0.3)
	
	for vent in _steam_vents:
		if vent != null:
			if upgrade_level >= 2:
				vent.emitting = true
				vent.modulate = Color(0.95, 0.95, 1.0, 0.8)
			else:
				vent.emitting = false
				vent.modulate = Color(0.9, 0.9, 0.95, 0.0)
	
	# T3: ambient smoke only (rotating barrels + pulsing runes removed)
	if upgrade_level >= 3:
		if _smoke_trails != null:
			_smoke_trails.emitting = true
			_smoke_trails.modulate = Color(0.35, 0.35, 0.35, 0.6)
	else:
		if _smoke_trails != null:
			_smoke_trails.emitting = false
			_smoke_trails.modulate = Color(0.3, 0.3, 0.3, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
	if not is_inside_tree():
		return
	if upgrade_level == 2:
		# Reinforced barrel clangs in
		if _reinforced_barrel != null:
			_reinforced_barrel.modulate = Color(2.0, 1.0, 0.5, 0.0)
			var tween = create_tween()
			tween.tween_property(_reinforced_barrel, "modulate", Color(0.8, 0.3, 0.2, 0.85), 0.4)
		
		# Steam vents puff
		for vent in _steam_vents:
			if vent != null:
				vent.modulate = Color(1.0, 1.0, 1.0, 1.0)
				var vent_tween = create_tween()
				vent_tween.tween_property(vent, "modulate", Color(0.9, 0.9, 0.95, 0.6), 0.5)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	cluster_bombs = bool(tier_data.get("cluster_bombs", false))
	burn_effect = bool(tier_data.get("burn_effect", false))

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return
	_trigger_fire_motion(1.25)
	var target_pos = target.global_position
	var target_vel = Vector2.ZERO
	if "velocity" in target:
		target_vel = target.velocity
	var to_target = target_pos - global_position
	var distance = to_target.length()
	var lead_time = distance / max(1.0, projectile_speed)
	if target_vel.length() > 0.1:
		target_pos += target_vel * lead_time
	var dir = (target_pos - global_position).normalized()
	_spawn_tower_fire_emitter(dir, 1.25)
	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var aoe_mult = 1.0
	if _game != null and _game.has_method("get_tower_aoe_mult"):
		aoe_mult = float(_game.get_tower_aoe_mult())
	var effective_explosion_radius = explosion_radius * aoe_mult
	
	# Spawn main cannonball with cluster and burn capability
	_game.spawn_cannonball(
		global_position,
		dir,
		projectile_speed,
		damage + dmg_bonus,
		projectile_range,
		effective_explosion_radius,
		cluster_bombs,
		burn_effect,
		get_projectile_visual_profile()
	)

	# Spawn shockwave effect at cannon position
	if _game != null and _game.fx_manager != null:
		_game.fx_manager.spawn_cannon_shockwave(global_position, effective_explosion_radius * 0.5, "fire" if burn_effect else "normal")

	# Shockwave evolution: knockback + stun on impact
	if is_evolved and evolution_id == "shockwave":
		_apply_shockwave_at(target_pos, effective_explosion_radius)

	# Hellfire evolution: spawn fire pool at target position
	if is_evolved and evolution_id == "hellfire":
		_spawn_fire_pool(target_pos, effective_explosion_radius)

	# Puff steam when firing (if T2+)
	if upgrade_level >= 2 and is_inside_tree():
		for vent in _steam_vents:
			if vent != null and vent.emitting:
				vent.amount = 12  # Burst of steam
				var t = get_tree().create_timer(0.1)
				t.timeout.connect(func():
					if is_instance_valid(vent):
						vent.amount = 8  # Back to normal
				)
	AudioManager.play_weapon_sound(tower_type, global_position)

func _apply_shockwave_at(pos: Vector2, blast_radius: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.3).timeout  # Delay for projectile travel
	if not is_inside_tree():
		return
	var enemies = _get_enemies()
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist = pos.distance_to(enemy.global_position)
		if dist <= blast_radius:
			# Knockback
			var push_dir = (enemy.global_position - pos).normalized()
			if push_dir.length() < 0.1:
				push_dir = Vector2.RIGHT.rotated(randf() * TAU)
			enemy.global_position += push_dir * shockwave_knockback * (1.0 - dist / blast_radius)
			# Stun chance
			if randf() < shockwave_stun_chance and enemy.has_method("stun"):
				enemy.stun(shockwave_stun_duration)
	# Visual: expanding blue ring
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("shockwave", pos)

func _spawn_fire_pool(pos: Vector2, blast_radius: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.3).timeout  # Delay for projectile travel
	if not is_inside_tree() or _game == null:
		return
	# Create a fire pool that damages enemies over time
	var pool = Node2D.new()
	pool.global_position = pos
	pool.z_index = -2
	var fx_parent = _game.get_node_or_null("World/FX")
	if fx_parent != null:
		fx_parent.add_child(pool)
	else:
		_game.add_child(pool)

	# Visual: orange circle — shared texture
	var sprite = Sprite2D.new()
	if _shared_fire_pool_tex == null:
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var center = Vector2(32, 32)
		for x in range(64):
			for y in range(64):
				var d = Vector2(x, y).distance_to(center)
				if d < 28:
					var a = (1.0 - d / 28.0) * 0.5
					img.set_pixel(x, y, Color(1.0, 0.4, 0.1, a))
		_shared_fire_pool_tex = ImageTexture.create_from_image(img)
	sprite.texture = _shared_fire_pool_tex
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	sprite.scale = Vector2.ONE * (blast_radius / 32.0)
	pool.add_child(sprite)

	# Damage tick timer — use pool's tree since pool outlives the tower
	var tick_count = 0
	var tick_interval = 0.5
	var max_ticks = int(hellfire_pool_duration / tick_interval)
	var fade_start_tick = int(max_ticks * 0.6)
	var game_ref = _game  # Capture reference since tower may be freed
	while tick_count < max_ticks and is_instance_valid(pool) and pool.is_inside_tree():
		await pool.get_tree().create_timer(tick_interval).timeout
		tick_count += 1
		if not is_instance_valid(pool) or not pool.is_inside_tree():
			break
		var enemies: Array = []
		if game_ref != null and is_instance_valid(game_ref) and "cached_enemies" in game_ref:
			enemies = game_ref.cached_enemies
		elif pool.is_inside_tree():
			enemies = pool.get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			if pool.global_position.distance_to(enemy.global_position) <= blast_radius * 0.8:
				if enemy.has_method("take_damage"):
					enemy.take_damage(hellfire_pool_damage, enemy.global_position, false, false)
		# Fade out near end
		if tick_count > fade_start_tick and is_instance_valid(sprite):
			sprite.modulate.a = lerpf(sprite.modulate.a, 0.0, 0.3)
	if is_instance_valid(pool):
		pool.queue_free()
