extends CharacterBody2D

const FeedbackConfig = preload("res://scripts/feedback_config.gd")
const PLAYER_HALO_TEXTURE = preload("res://assets/ui/ui_selection_ring_64x64_v001.png")

var speed = 250.0
var attack_range = 520.0
var attack_rate = 2.1
var damage = 15.0
var projectile_speed = 720.0
var projectile_range = 420.0

var max_health = 130.0
var health = 130.0
var _base_speed = 250.0
var _speed_bonus = 0.0
var _base_max_health = 130.0
var _max_health_bonus = 0.0
var _damage_taken_mult = 1.0

var _attack_cooldown = 0.0
var _game: Node = null
var _shot_counter = 0

# --- Multiplayer identity (solo: peer_id stays 1, is_local() always true) ---
var peer_id: int = 1
var is_bot: bool = false
# When a bot drives this player, the controller writes a desired move vector
# here each frame; _get_move_vector() reads it instead of hardware input.
var bot_move_vector: Vector2 = Vector2.ZERO
# Inert players (dead/left in FFA) stop moving, firing, and contributing.
var inert: bool = false
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
var _contrast_plate: Sprite2D = null
var _visibility_halo: Sprite2D = null
var _focus_marker: Sprite2D = null
var _visibility_halo_time: float = 0.0
var _combat_density: float = 0.0
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
const PLAYER_HP_BAR_WIDTH = 38.0
const PLAYER_HP_BAR_HEIGHT = 4.0
const PLAYER_HP_BAR_OFFSET_Y = 22.0
const DAMAGE_GRACE_WINDOW = 0.10
const DAMAGE_GRACE_MAX_STACKED_HIT = 20.0
const OCCLUSION_SCAN_INTERVAL = 0.08
const OCCLUSION_RADIUS_MIN = 72.0
const OCCLUSION_RADIUS_MAX = 108.0
# Crowding transparency keeps the player readable in a melee, but enemies must
# stay clearly visible so incoming threats register. Floor raised from 0.16.
const OCCLUSION_ALPHA_NEAR = 0.55
const OCCLUSION_ALPHA_FAR = 0.72
static var _shared_focus_marker_tex: ImageTexture = null
static var _shared_contrast_plate_tex: ImageTexture = null

var _damage_grace_timer: float = 0.0
var _occlusion_scan_timer: float = 0.0
var _occluded_enemy_bodies: Dictionary = {}

# --- Snappy-arcade movement model ---
const MOVE_ACCEL = 2600.0          # ramp to full speed fast
const MOVE_DECEL = 3200.0          # stop a touch faster than we start = crisp
const MOVE_TURN_BOOST = 1.35       # extra accel when reversing direction
const MOVE_IDLE_EPS = 12.0         # speed below this counts as "stopped"
var _is_moving: bool = false
var _speed_ratio: float = 0.0

# --- Body juice (secondary motion on the $Body sprite) ---
var _body_base_scale: Vector2 = Vector2.ONE
var _body_base_pos: Vector2 = Vector2.ZERO
var _body_juice_ready: bool = false
var _body_anim_phase: float = 0.0
var _body_smooth_scale: Vector2 = Vector2.ONE
var _body_smooth_skew: float = 0.0
var _body_smooth_offset: Vector2 = Vector2.ZERO
var _body_stop_impulse: float = 0.0
var _body_fire_impulse: float = 0.0
var _body_fire_dir: Vector2 = Vector2.RIGHT
var _was_moving: bool = false
var _juice_scale: float = 1.0

func _ready() -> void:
	_ensure_game_ref()
	add_to_group("player")
	z_as_relative = false
	z_index = 120
	collision_layer = GameLayers.PLAYER
	# Player should phase through enemy bodies in frantic maze-survivor combat.
	collision_mask = GameLayers.BUILDING
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if sprite != null and sprite is CanvasItem:
		(sprite as CanvasItem).z_index = 16
	_base_damage = damage
	_base_attack_rate = attack_rate
	_base_speed = speed
	_base_max_health = max_health
	_setup_contrast_plate()
	_setup_visibility_halo()
	_setup_focus_marker()
	_create_health_bar()
	_update_health_bar()
	_init_body_juice()

func _init_body_juice() -> void:
	if sprite != null and sprite is Node2D:
		_body_base_scale = (sprite as Node2D).scale
		_body_base_pos = (sprite as Node2D).position
		_body_smooth_scale = _body_base_scale
		_body_smooth_offset = Vector2.ZERO
		_body_juice_ready = true
	var manager = _get_settings_manager_safe()
	if manager != null and manager.has_method("is_reduced_motion") and bool(manager.is_reduced_motion()):
		_juice_scale = 0.0
	else:
		_juice_scale = 1.0

func _get_settings_manager_safe() -> Node:
	if _game != null and _game.has_method("_get_settings_manager"):
		return _game._get_settings_manager()
	return get_node_or_null("/root/SettingsManager")

func set_character(base_path: String, prefix: String) -> void:
	if sprite != null and sprite.has_method("configure"):
		sprite.configure(base_path, prefix)

func _physics_process(delta: float) -> void:
	_ensure_game_ref()
	# While dying, the death sequence owns the frame: advance it and skip the
	# normal movement/combat update so the run-end screen can be triggered.
	if _is_dying:
		_process_death_animation(delta)
		return
	# Once the run has ended (game over / run-end screen up) the player must
	# stay put: the death animation flips _is_dying back off, so without this
	# guard movement input would resume behind the end screen.
	if _game != null and _game.game_over:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_update_visibility_halo(delta)
	_update_contrast_plate(delta)
	_update_focus_marker(delta)
	_update_enemy_occlusion(delta)
	_update_health_bar()
	_damage_grace_timer = max(0.0, _damage_grace_timer - delta)
	if _slow_timer > 0.0:
		_slow_timer = max(0.0, _slow_timer - delta)
	else:
		_slow_factor = 1.0
	
	# Update berserk timer
	if _berserk_timer > 0.0:
		_berserk_timer = max(0.0, _berserk_timer - delta)
		if _berserk_timer <= 0.0:
			_deactivate_berserk()
	
	# In FFA, a non-authority player's transform is replicated by the
	# MultiplayerSynchronizer — skip local integration so it doesn't fight the
	# synced position. Solo and the local/bot-owned player run the full sim.
	if not is_local():
		_update_remote_visuals(delta)
		return
	# Inert players (spectating after death / left the match) freeze in place.
	if inert:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := _get_move_vector()
	_update_facing(input_vector)

	# Snappy-arcade acceleration: ramp toward target velocity instead of snapping.
	var has_input := input_vector.length() > 0.05
	var target_velocity: Vector2 = input_vector * speed * _slow_factor
	var rate: float = MOVE_ACCEL if has_input else MOVE_DECEL
	# Reversing direction? give it extra bite so quick turns feel responsive.
	if has_input and velocity.length() > 1.0 and velocity.dot(target_velocity) < 0.0:
		rate *= MOVE_TURN_BOOST
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()
	if _game != null and _game.has_method("clamp_to_play_area"):
		global_position = _game.clamp_to_play_area(global_position)

	# Movement state for animation + juice systems (skip during death so the
	# death sequence owns the transform).
	if not _is_dying:
		var spd := velocity.length()
		_is_moving = spd > MOVE_IDLE_EPS
		_speed_ratio = clampf(spd / max(1.0, speed), 0.0, 1.4)
		_update_move_animation()
		_update_body_juice(delta)

	# Auto-fire only on the input-authority side (host owns damage). In solo
	# is_local() is always true, so firing is unchanged.
	if inert:
		return
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
			# Body fire kick (juice): brief punch along shot direction.
			if _juice_scale > 0.0:
				_body_fire_impulse = max(_body_fire_impulse, 0.5)
				_body_fire_dir = dir
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
	var enemies: Array = []
	if _game != null and _game.has_method("get_cached_enemies"):
		enemies = _game.get_cached_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	for raw_enemy in enemies:
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		if not (raw_enemy is Node2D):
			continue
		var enemy := raw_enemy as Node2D
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

func _update_move_animation() -> void:
	if sprite == null:
		return
	if sprite.has_method("set_moving"):
		sprite.set_moving(_is_moving)
	if sprite.has_method("set_speed_ratio"):
		sprite.set_speed_ratio(_speed_ratio)

# Drive walk animation + facing for a REMOTE player (FFA, non-authority) from
# the position delta the synchronizer replicates. No physics integration here.
func _update_remote_visuals(delta: float) -> void:
	var moved: Vector2 = global_position - _body_base_pos_world()
	var spd: float = moved.length() / max(0.0001, delta)
	_is_moving = spd > MOVE_IDLE_EPS
	_speed_ratio = clampf(spd / max(1.0, speed), 0.0, 1.4)
	if _is_moving:
		_update_facing(moved)
	_update_move_animation()
	_remote_last_pos = global_position

var _remote_last_pos: Vector2 = Vector2.ZERO
func _body_base_pos_world() -> Vector2:
	# Seed on first frame so the initial delta is zero.
	if _remote_last_pos == Vector2.ZERO:
		_remote_last_pos = global_position
	return _remote_last_pos

func _update_body_juice(delta: float) -> void:
	if not _body_juice_ready or sprite == null or not (sprite is Node2D):
		return
	var body := sprite as Node2D
	_body_anim_phase += delta

	# Decay one-shot impulses.
	_body_stop_impulse = lerpf(_body_stop_impulse, 0.0, clampf(delta * 9.0, 0.0, 1.0))
	_body_fire_impulse = lerpf(_body_fire_impulse, 0.0, clampf(delta * 11.0, 0.0, 1.0))

	# Detect move->idle transition to kick a settle overshoot.
	if _was_moving and not _is_moving:
		_body_stop_impulse = max(_body_stop_impulse, 0.06)
	_was_moving = _is_moving

	var js := _juice_scale
	var dir := velocity
	var travel := dir.normalized() if dir.length() > 1.0 else _vector_from_dir(_facing_dir)

	# The hunter frames already carry a baked walk cycle, so the procedural
	# secondary motion is kept subtle to avoid a rubbery/bouncy double-animation.
	# --- Target scale: gentle run squash/stretch + impulses ---
	var stretch := 0.04 * _speed_ratio * js
	# Stretch along travel (use horizontal/vertical bias so it reads in 2D top-down).
	var horiz_bias := absf(travel.x)
	var target_scale := _body_base_scale
	target_scale.x *= 1.0 + stretch * horiz_bias - stretch * (1.0 - horiz_bias) * 0.5
	target_scale.y *= 1.0 + stretch * (1.0 - horiz_bias) - stretch * horiz_bias * 0.5
	# Settle overshoot on stop (squash down then recover via decay).
	target_scale.y *= 1.0 - _body_stop_impulse
	target_scale.x *= 1.0 + _body_stop_impulse * 0.6
	# Fire kick: brief punch along shot direction.
	if _body_fire_impulse > 0.001:
		var fb := absf(_body_fire_dir.x)
		target_scale.x *= 1.0 + _body_fire_impulse * 0.10 * fb
		target_scale.y *= 1.0 + _body_fire_impulse * 0.10 * (1.0 - fb)

	# --- Target skew: slight lean into horizontal travel ---
	var target_skew := -travel.x * 0.05 * _speed_ratio * js

	# --- Vertical bob (subtle run bob while moving, breathing while idle) ---
	var bob := 0.0
	if _is_moving:
		bob = sin(_body_anim_phase * (10.0 + 6.0 * _speed_ratio)) * 0.4 * _speed_ratio * js
	else:
		bob = sin(_body_anim_phase * 2.4) * 0.45 * js
	var target_offset := _body_base_pos + Vector2(0.0, -absf(bob) if _is_moving else bob)

	# Smooth everything (exp-style alpha so nothing snaps).
	var a_fast := clampf(delta * 18.0, 0.0, 1.0)
	var a_slow := clampf(delta * 12.0, 0.0, 1.0)
	_body_smooth_scale = _body_smooth_scale.lerp(target_scale, a_fast)
	_body_smooth_skew = lerpf(_body_smooth_skew, target_skew, a_slow)
	_body_smooth_offset = _body_smooth_offset.lerp(target_offset, a_fast)

	body.scale = _body_smooth_scale
	body.skew = _body_smooth_skew
	body.position = _body_smooth_offset

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
	if _game != null and _game.has_method("is_damage_blocked") and _game.is_damage_blocked():
		return
	if _damage_grace_timer > 0.0 and amount <= DAMAGE_GRACE_MAX_STACKED_HIT:
		return
	health -= amount * _damage_taken_mult
	_damage_grace_timer = DAMAGE_GRACE_WINDOW
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
	# Camera zoom punch scales with hit severity (only meaningful hits, avoids jitter)
	if _game != null and _game.has_method("kick_camera_zoom") and amount >= 8.0:
		var kick = clampf(0.025 + amount * 0.0016, 0.025, 0.08)
		_game.kick_camera_zoom(kick)
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
		# FFA: dying does NOT end the match or trigger global slow-mo. The player
		# goes inert (spectates), their score locks in, and their towers stop. The
		# host owns this transition and tells every peer via the game.
		if _game != null and _game.has_method("is_ffa") and _game.is_ffa():
			if _game.has_method("ffa_on_player_died"):
				_game.ffa_on_player_died(peer_id)
		else:
			# Start death animation instead of immediate game over
			start_death_animation()
	_update_health_bar()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	_update_health_bar()

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
	_update_health_bar()

# Fold persistent meta-progression bonuses into the player's run baseline so that
# in-run additive bonuses (chest/tech) still stack correctly on top.
func apply_meta_bonuses(max_hp_bonus: float, speed_mult: float, damage_taken_mult: float = 1.0) -> void:
	_base_max_health = 130.0 + max(0.0, max_hp_bonus)
	max_health = _base_max_health + _max_health_bonus
	health = max_health
	_base_speed = 250.0 * max(0.1, speed_mult)
	speed = _base_speed + _speed_bonus
	_damage_taken_mult = max(0.1, damage_taken_mult)
	_update_health_bar()

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

# True when this client (or the host, for bots) owns this player's input.
# In solo, always true. In FFA, the input authority drives movement/fire; other
# peers receive the transform via the MultiplayerSynchronizer.
func is_local() -> bool:
	var net := get_node_or_null("/root/Net")
	if net == null or not net.is_multiplayer():
		return true
	# Host drives bots; clients/host drive their own player.
	if is_bot:
		return net.is_host
	return is_multiplayer_authority()

# Movement source: hardware input for a local human, the bot vector for a bot.
func _get_move_vector() -> Vector2:
	if is_bot:
		var v := bot_move_vector
		if v.length() > 1.0:
			v = v.normalized()
		return v
	var input_vector := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	return input_vector

func _setup_visibility_halo() -> void:
	# Cyan glow ring removed (it cluttered the player silhouette). The dark
	# contrast plate below the feet still provides readability against the horde.
	return

func _setup_contrast_plate() -> void:
	if _contrast_plate != null:
		return
	_contrast_plate = Sprite2D.new()
	_contrast_plate.name = "ContrastPlate"
	_contrast_plate.texture = _get_contrast_plate_texture()
	_contrast_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_contrast_plate.z_index = 108
	_contrast_plate.position = Vector2(0, 8)
	_contrast_plate.scale = Vector2.ONE * 1.42
	_contrast_plate.modulate = Color(0.0, 0.0, 0.0, 0.68)
	add_child(_contrast_plate)

func _get_contrast_plate_texture() -> ImageTexture:
	if _shared_contrast_plate_tex != null:
		return _shared_contrast_plate_tex
	var img = Image.create(56, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(28.0, 20.0)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dx = (float(x) - center.x) / 26.0
			var dy = (float(y) - center.y) / 14.0
			var dist = sqrt(dx * dx + dy * dy)
			if dist > 1.0:
				continue
			var alpha = clampf((1.0 - dist) * 0.92, 0.0, 0.92)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_shared_contrast_plate_tex = ImageTexture.create_from_image(img)
	return _shared_contrast_plate_tex

func _update_contrast_plate(delta: float) -> void:
	if _contrast_plate == null:
		return
	if _is_dying:
		_contrast_plate.visible = false
		return
	_contrast_plate.visible = true
	var pulse = 0.5 + 0.5 * sin(_visibility_halo_time * 3.2 + delta * 4.0)
	_contrast_plate.scale = Vector2(1.26 + _combat_density * 0.54, 1.10 + _combat_density * 0.34) * (1.0 + pulse * 0.08)
	_contrast_plate.modulate.a = clampf(0.58 + _combat_density * 0.24, 0.0, 0.94)

func _update_visibility_halo(delta: float) -> void:
	if _visibility_halo == null:
		return
	_visibility_halo_time += delta
	var pulse = 0.5 + 0.5 * sin(_visibility_halo_time * 5.2)
	_visibility_halo.scale = Vector2.ONE * (1.18 + pulse * 0.22 + _combat_density * 0.36)
	var alpha = clampf(0.86 + pulse * 0.14 + _combat_density * 0.12, 0.0, 1.0)
	_visibility_halo.modulate = Color(0.42, 1.0, 0.98, alpha)

func _setup_focus_marker() -> void:
	if _focus_marker != null:
		return
	_focus_marker = Sprite2D.new()
	_focus_marker.name = "FocusMarker"
	_focus_marker.texture = _get_focus_marker_texture()
	_focus_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_focus_marker.z_index = 172
	_focus_marker.position = Vector2(0, -32)
	_focus_marker.scale = Vector2.ONE * 1.28
	_focus_marker.modulate = Color(1.0, 1.0, 0.62, 0.96)
	var marker_mat = CanvasItemMaterial.new()
	marker_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_focus_marker.material = marker_mat
	add_child(_focus_marker)

func _get_focus_marker_texture() -> ImageTexture:
	if _shared_focus_marker_tex != null:
		return _shared_focus_marker_tex
	var img = Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill = Color(1.0, 1.0, 0.85, 0.95)
	var edge = Color(0.1, 0.1, 0.1, 0.95)
	for y in range(12):
		var w = int(floor(float(y) * 0.6))
		for x in range(-w, w + 1):
			var px = 11 + x
			var py = y + 3
			if px < 0 or py < 0 or px >= 22 or py >= 22:
				continue
			img.set_pixel(px, py, fill)
	for y in range(2, 17):
		img.set_pixel(11, y, fill)
	for x in range(22):
		for y in range(22):
			var c = img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			for ox in range(-1, 2):
				for oy in range(-1, 2):
					var nx = x + ox
					var ny = y + oy
					if nx < 0 or ny < 0 or nx >= 22 or ny >= 22:
						continue
					if img.get_pixel(nx, ny).a <= 0.0:
						img.set_pixel(nx, ny, edge)
	_shared_focus_marker_tex = ImageTexture.create_from_image(img)
	return _shared_focus_marker_tex

func _update_focus_marker(_delta: float) -> void:
	if _focus_marker == null:
		return
	if _is_dying:
		_focus_marker.visible = false
		return
	_focus_marker.visible = true
	var t = Time.get_ticks_msec() * 0.001
	var bob = sin(t * 6.0) * 2.8
	var pulse = 0.98 + (0.10 + _combat_density * 0.22) * (0.5 + 0.5 * sin(t * 9.0))
	_focus_marker.position = Vector2(0, -33 + bob)
	_focus_marker.scale = Vector2.ONE * pulse
	_focus_marker.modulate = Color(1.0, 1.0, 0.72, clampf(0.92 + _combat_density * 0.08, 0.0, 1.0))

func _update_enemy_occlusion(delta: float) -> void:
	if _is_dying:
		_clear_enemy_occlusion()
		_combat_density = 0.0
		return
	_occlusion_scan_timer = max(0.0, _occlusion_scan_timer - delta)
	if _occlusion_scan_timer > 0.0:
		return
	_occlusion_scan_timer = OCCLUSION_SCAN_INTERVAL
	var enemies: Array = []
	if _game != null and _game.has_method("get_cached_enemies"):
		enemies = _game.get_cached_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	var density = clampf(float(enemies.size()) / 90.0, 0.0, 1.0)
	_combat_density = density
	var radius = lerpf(OCCLUSION_RADIUS_MIN, OCCLUSION_RADIUS_MAX, density)
	var alpha = lerpf(OCCLUSION_ALPHA_FAR, OCCLUSION_ALPHA_NEAR, density)
	var radius_sq = radius * radius
	var visible_now: Dictionary = {}
	for raw_enemy in enemies:
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		if not (raw_enemy is Node2D):
			continue
		var enemy := raw_enemy as Node2D
		if global_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		var enemy_body = enemy.get_node_or_null("Body")
		if enemy_body == null or not (enemy_body is CanvasItem):
			continue
		var enemy_body_item := enemy_body as CanvasItem
		enemy_body_item.self_modulate = Color(1.0, 1.0, 1.0, alpha)
		visible_now[enemy.get_instance_id()] = enemy_body_item
	for enemy_id in _occluded_enemy_bodies.keys():
		if visible_now.has(enemy_id):
			continue
		var old_body = _occluded_enemy_bodies[enemy_id]
		if old_body != null and is_instance_valid(old_body):
			old_body.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	_occluded_enemy_bodies = visible_now

func _clear_enemy_occlusion() -> void:
	for enemy_id in _occluded_enemy_bodies.keys():
		var body = _occluded_enemy_bodies[enemy_id]
		if body != null and is_instance_valid(body):
			body.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	_occluded_enemy_bodies.clear()

func _create_health_bar() -> void:
	if _health_bar_bg != null and is_instance_valid(_health_bar_bg):
		return
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.name = "PlayerHealthBarBg"
	_health_bar_bg.size = Vector2(PLAYER_HP_BAR_WIDTH, PLAYER_HP_BAR_HEIGHT)
	_health_bar_bg.position = Vector2(-PLAYER_HP_BAR_WIDTH / 2.0, PLAYER_HP_BAR_OFFSET_Y)
	_health_bar_bg.color = Color(0.05, 0.05, 0.05, 0.72)
	_health_bar_bg.z_index = 95
	add_child(_health_bar_bg)

	_health_bar_fill = ColorRect.new()
	_health_bar_fill.name = "PlayerHealthBarFill"
	_health_bar_fill.size = Vector2(PLAYER_HP_BAR_WIDTH, PLAYER_HP_BAR_HEIGHT)
	_health_bar_fill.position = Vector2.ZERO
	_health_bar_fill.color = Color(0.22, 0.96, 0.35, 0.92)
	_health_bar_bg.add_child(_health_bar_fill)

func _update_health_bar() -> void:
	if _health_bar_bg == null or _health_bar_fill == null:
		return
	var max_hp = max(max_health, 1.0)
	var ratio = clampf(health / max_hp, 0.0, 1.0)
	_health_bar_fill.size.x = PLAYER_HP_BAR_WIDTH * ratio
	if ratio > 0.55:
		_health_bar_fill.color = Color(0.22, 0.96, 0.35, 0.92)
	elif ratio > 0.25:
		_health_bar_fill.color = Color(0.96, 0.82, 0.24, 0.95)
	else:
		_health_bar_fill.color = Color(0.98, 0.22, 0.22, 0.98)
	_health_bar_bg.visible = not _is_dying

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
	if _contrast_plate != null:
		_contrast_plate.visible = false
	if _visibility_halo != null:
		_visibility_halo.visible = false
	if _health_bar_bg != null:
		_health_bar_bg.visible = false
	
	# Phase 0: The fatal blow - dramatic impact
	_spawn_fatal_blow_effect()
	
	# Camera zoom in and shake handled by main.gd
	if _game != null and _game.has_method("start_death_camera_zoom"):
		_game.start_death_camera_zoom(global_position)
	
	if _game != null and _game.has_method("shake_camera"):
		_game.shake_camera(15.0, 2.0)

func _process_death_animation(delta: float) -> void:
	# delta is already scaled by Engine.time_scale (0.15 during the death slow-mo).
	# Convert back to REAL seconds so the 6s sequence lasts ~6 real seconds and
	# actually reaches completion (the old `* Engine.time_scale` double-scaled it,
	# stretching the run to minutes and stalling the run-end screen).
	var ts: float = max(Engine.time_scale, 0.0001)
	_death_animation_time += delta / ts

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
	_clear_enemy_occlusion()
	_combat_density = 0.0

	# Reset time scale
	Engine.time_scale = 1.0

	# Notify game that animation is done
	if _game != null and _game.has_method("on_death_animation_complete"):
		_game.on_death_animation_complete()

func is_dying() -> bool:
	return _is_dying

func clear_run_modifiers() -> void:
	# Reset all run-scoped combat modifiers back to character baseline.
	gun_pierce = 0
	burst_level = 0
	burst_every = 0
	burst_spread = 0.25
	slow_factor = 1.0
	slow_duration = 0.0
	explosive_radius = 0.0
	_speed_bonus = 0.0
	_max_health_bonus = 0.0
	speed = _base_speed
	max_health = _base_max_health
	health = max_health
	_shot_counter = 0
	_berserk_active = false
	_berserk_multiplier = 1.0
	_berserk_timer = 0.0
	_remove_berserk_glow()
	_clear_enemy_occlusion()
	_combat_density = 0.0
	apply_global_bonuses(0.0)
	_update_health_bar()

func reset() -> void:
	"""Reset player state for new game"""
	_is_dying = false
	_death_animation_time = 0.0
	scale = _original_scale if _original_scale != Vector2.ZERO else Vector2.ONE
	if sprite != null:
		sprite.modulate = Color.WHITE
	if _visibility_halo != null:
		_visibility_halo.visible = true
		_visibility_halo_time = 0.0
	if _focus_marker != null:
		_focus_marker.visible = true
	_clear_enemy_occlusion()
	_combat_density = 0.0
	health = max_health
	velocity = Vector2.ZERO
	_update_health_bar()

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
	
	if not is_instance_valid(_berserk_glow) or not _berserk_glow.is_inside_tree():
		return
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
