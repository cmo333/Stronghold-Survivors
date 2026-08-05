extends "res://scripts/building.gd"
class_name Tower

# Base stats
var range = 220.0
var fire_rate = 1.0
var damage = 8.0
var projectile_speed = 500.0
var projectile_range = 260.0
var explosion_radius = 0.0

# Upgrade system
var upgrade_level = 1  # 1 = Base, 2 = Enhanced, 3 = Master
var max_upgrade_level = 3
var _is_upgrading = false  # Prevents spam
var _upgrade_cooldown = 0.0
const ESSENCE_INFUSION_GOLD_COST = 500
const ESSENCE_INFUSION_ESSENCE_COST = 1
const ESSENCE_INFUSION_DAMAGE_MULT = [1.0, 1.30, 1.65]
const ESSENCE_INFUSION_RANGE_MULT = [1.0, 1.15, 1.30]
const ESSENCE_INFUSION_RATE_MULT = [1.0, 1.18, 1.40]
const ESSENCE_INFUSION_HEALTH_MULT = [1.0, 1.40, 1.90]

# Evolution system
var is_evolved: bool = false
var evolution_id: String = ""
var evolution_name: String = ""

# Synergy bonus tracking
var synergy_damage_bonus: float = 0.0
var synergy_rate_bonus: float = 0.0
var synergy_range_bonus: float = 0.0
var synergy_chain_bonus: int = 0
var synergy_explosion_bonus: float = 0.0

# Evolution definitions per tower type (override in subclasses)
func get_evolution_options() -> Array:
	return []  # Each subclass returns [{"id": "gatling", "name": "Gatling Turret", "desc": "...", "cost": 3}, ...]

func can_evolve() -> bool:
	return upgrade_level >= 3 and not is_evolved

func get_evolution_cost(evo_id: String) -> int:
	for opt in get_evolution_options():
		if opt.get("id", "") == evo_id:
			return int(opt.get("cost", 3))
	return 3

func evolve(evo_id: String) -> void:
	if not can_evolve():
		return
	is_evolved = true
	evolution_id = evo_id
	for opt in get_evolution_options():
		if opt.get("id", "") == evo_id:
			evolution_name = opt.get("name", evo_id)
			break
	_apply_evolution_stats()
	_apply_evolution_visuals()
	_play_evolution_animation()
	_update_tier_badge()

# Override in subclasses
func _apply_evolution_stats() -> void:
	pass

func _apply_evolution_visuals() -> void:
	pass

func _play_evolution_animation() -> void:
	if _game == null:
		return
	# Phase 3 set-piece evolution cue.
	if _game.has_method("spawn_setpiece_fx"):
		_game.spawn_setpiece_fx("tower_evolution", global_position, 1.0, tower_type)
	elif _game.has_method("spawn_fx"):
		_game.spawn_fx("upgrade_burst", global_position)
		if _game.has_method("shake_camera"):
			_game.shake_camera(10.0, 0.4)

# Shared static textures (created once, reused by all instances)
static var _shared_aura_tex: ImageTexture = null

static func _get_aura_texture() -> ImageTexture:
	if _shared_aura_tex != null:
		return _shared_aura_tex
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center = Vector2(32, 32)
	for x in range(64):
		for y in range(64):
			var dist = Vector2(x, y).distance_to(center)
			if dist > 28 and dist < 32:
				img.set_pixel(x, y, Color(1, 1, 1, 0.3))
	_shared_aura_tex = ImageTexture.create_from_image(img)
	return _shared_aura_tex

# Visual progression - Tower-specific elements
var _glow_sprite: Sprite2D = null
var _glow_tween: Tween = null
var _particles: CPUParticles2D = null
var _level_up_particles: CPUParticles2D = null
var _aura_ring: Sprite2D = null
var _fire_flash_sprite: Sprite2D = null
var _fire_flash_tween: Tween = null
var _tier_badge: Label = null
var _tier_halo: Sprite2D = null
var _evo_ready_label: Label = null
var _evo_ready_tween: Tween = null

# Tower-specific visual elements (overridden by subclasses)
var _tier_sprites: Array[Sprite2D] = []  # T2, T3 additive elements
var _floating_elements: Array[Node2D] = []  # Orbiting/floating items
var _crystal_core: Sprite2D = null
var _lightning_orb: Sprite2D = null
var _steam_vents: Array[CPUParticles2D] = []
var _rune_glows: Array[Sprite2D] = []

# Element colors for T3 glow
const ELEMENT_COLORS = {
	"arrow": Color(0.2, 0.9, 0.3, 0.8),    # Green
	"tesla": Color(0.2, 0.6, 1.0, 0.8),    # Blue
	"cannon": Color(1.0, 0.2, 0.2, 0.8)    # Red
}
const TIER_HALO_TEXTURES = {
	1: "res://assets/ui/tech/ui_upgrade_halo_t1_96_v001.png",
	2: "res://assets/ui/tech/ui_upgrade_halo_t2_96_v001.png",
	3: "res://assets/ui/tech/ui_upgrade_halo_t3_96_v001.png",
	"evo": "res://assets/ui/tech/ui_upgrade_halo_evo_96_v001.png"
}

# Tier colors for glow effects
const TIER_COLORS = {
	1: Color(0.9, 0.9, 0.9, 0.0),      # Base - no glow
	2: Color(1.0, 1.0, 1.0, 0.4),      # Enhanced - white glow
	3: Color(1.0, 1.0, 1.0, 0.0)       # Master - set per element
}

# Particle colors for upgrade swirls
const UPGRADE_SWIRL_COLORS = {
	2: Color(1.0, 0.85, 0.2, 1.0),     # Gold for T2
	3: Color(0.8, 0.2, 1.0, 1.0)       # Purple for T3
}
const SHOW_WORLD_TIER_BADGES = false
# Legacy per-tower upgrade indicators (rotating halo ring) removed — they read as
# clutter on upgraded towers. Tier is communicated by the body art / glow instead.
const SHOW_WORLD_TIER_HALO = false
const SHOW_WORLD_EVO_READY = false

var _cooldown = 0.0
var _game: Node = null
@onready var body_sprite: AnimatedSprite2D = get_node_or_null("Body") as AnimatedSprite2D
var _body_base_sprite: Sprite2D = null
var _body_head_sprite: Sprite2D = null
var _body_split_mode: bool = false
var _body_base_region_offset: Vector2 = Vector2.ZERO
var _body_head_region_offset: Vector2 = Vector2.ZERO
var _body_presentation_texture_rid: RID = RID()

# Tower type identifier (set by subclasses)
var tower_type: String = "base"
var _body_anim_base_scale: Vector2 = Vector2.ONE
var _body_anim_smooth_scale: Vector2 = Vector2.ONE
var _body_anim_idle_phase: float = 0.0
var _body_anim_target_blend: float = 0.0
var _body_anim_fire_impulse: float = 0.0
var _body_anim_windup_blend: float = 0.0
var _body_anim_recover_blend: float = 0.0
var _body_anim_aim_dir: Vector2 = Vector2.RIGHT
var _body_anim_track_rotation: float = 0.0
var _body_anim_base_position: Vector2 = Vector2.ZERO
var _body_anim_stop_hold: float = 0.0
var _target_refresh_timer: float = 0.0
var _active_target = null
var _fire_phase: int = 0
var _fire_phase_timer: float = 0.0
var _instance_motion_phase_offset: float = 0.0
var _last_fire_dir: Vector2 = Vector2.RIGHT

enum FirePhase {
	IDLE = 0,
	WINDUP = 1,
	RECOVER = 2
}

const BODY_IDLE_BOB_AMP := 0.014
const BODY_IDLE_BOB_RATE := 2.0
const BODY_TARGET_BOB_MULT := 0.55
const BODY_FIRE_PUNCH_SCALE := 0.18
const BODY_FIRE_PUNCH_ROT := 0.05
const BODY_FIRE_IMPULSE_DECAY := 7.8
const BODY_TRACK_LEAN := 1.8
const BODY_WINDUP_PULL := 2.1
const BODY_RECOVER_SETTLE := 1.35
const BODY_STOP_HOLD_TIME := 0.22
const TARGET_REFRESH_TRACKING := 0.06
const TARGET_REFRESH_IDLE := 0.12

func _smoothing_alpha(rate: float, delta: float) -> float:
	return clampf(1.0 - exp(-max(0.01, rate) * max(0.0, delta)), 0.0, 1.0)

func _ready() -> void:
	super._ready()  # CRITICAL: Adds to "buildings" group for selection
	_game = get_tree().get_first_node_in_group("game")
	_instance_motion_phase_offset = float(get_instance_id() % 997) * 0.017
	_body_anim_idle_phase = _instance_motion_phase_offset
	_fire_phase = FirePhase.IDLE
	_fire_phase_timer = 0.0
	_target_refresh_timer = 0.0
	_active_target = null
	var idle_dir := get_body_idle_direction()
	if idle_dir.length_squared() <= 0.0001:
		idle_dir = Vector2.RIGHT
	_last_fire_dir = idle_dir.normalized()
	_body_anim_aim_dir = _last_fire_dir
	_body_anim_track_rotation = get_body_orientation_offset()
	if body_sprite != null:
		body_sprite.stop()
		body_sprite.frame = 0
		body_sprite.scale = Vector2.ONE * 1.35
		_body_anim_base_position = body_sprite.position
		_sync_body_anim_base_scale(true)
	_setup_body_presentation()
	_setup_premium_visuals()
	_setup_tower_specific_visuals()
	_update_visuals_for_upgrade_level(true)  # true = instant, no animation

func _setup_premium_visuals() -> void:
	# Create aura ring (rotating glow behind tower) — uses shared texture
	_aura_ring = Sprite2D.new()
	_aura_ring.name = "AuraRing"
	_aura_ring.z_index = -2
	_aura_ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_aura_ring.texture = _get_aura_texture()
	add_child(_aura_ring)

	# Create glow sprite for T2+ (using CanvasItemMaterial for additive blend)
	_glow_sprite = Sprite2D.new()
	_glow_sprite.name = "UpgradeGlow"
	_glow_sprite.z_index = -1
	_glow_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var glow_material = CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_sprite.material = glow_material

	if body_sprite != null and body_sprite.sprite_frames != null:
		_glow_sprite.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
	add_child(_glow_sprite)
	_setup_fire_flash()

	# NOTE: _particles and _level_up_particles are created lazily in _ensure_particles()
	# NOTE: PointLight2D removed — too expensive with many towers
	_ensure_tier_badge()

func _setup_fire_flash() -> void:
	_fire_flash_sprite = Sprite2D.new()
	_fire_flash_sprite.name = "FireFlash"
	_fire_flash_sprite.z_index = 12
	_fire_flash_sprite.texture = _get_aura_texture()
	_fire_flash_sprite.scale = Vector2.ONE * 0.22
	_fire_flash_sprite.modulate = Color(1.0, 0.85, 0.45, 0.0)
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fire_flash_sprite.material = mat
	add_child(_fire_flash_sprite)

func _ensure_tier_badge() -> void:
	if not SHOW_WORLD_TIER_BADGES:
		# Halo can render even when text badges are off.
		if SHOW_WORLD_TIER_HALO:
			_ensure_tier_halo()
		return
	if _tier_badge != null:
		return
	_tier_badge = Label.new()
	_tier_badge.name = "TierBadge"
	_tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier_badge.position = Vector2(6, 8)
	_tier_badge.z_index = 20
	_tier_badge.add_theme_font_size_override("font_size", 8)
	var font = load("res://assets/ui/pixel_font.ttf") if ResourceLoader.exists("res://assets/ui/pixel_font.ttf") else null
	if font != null:
		_tier_badge.add_theme_font_override("font", font)
	_tier_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	_tier_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_tier_badge.add_theme_constant_override("outline_size", 2)
	_update_tier_badge()
	add_child(_tier_badge)
	_ensure_tier_halo()

func _ensure_tier_halo() -> void:
	if _tier_halo != null:
		return
	_tier_halo = Sprite2D.new()
	_tier_halo.name = "TierHalo"
	_tier_halo.z_index = -2
	_tier_halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_tier_halo.material = mat
	add_child(_tier_halo)
	_update_tier_halo()

func _ensure_particles() -> void:
	if _particles != null:
		return
	_particles = CPUParticles2D.new()
	_particles.name = "UpgradeParticles"
	_particles.amount = 6
	_particles.lifetime = 2.0
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_particles.emission_sphere_radius = 18.0
	_particles.gravity = Vector2(0, -15)
	_particles.initial_velocity_min = 5.0
	_particles.initial_velocity_max = 15.0
	_particles.scale_amount_min = 0.5
	_particles.scale_amount_max = 1.0
	_particles.color = Color(1.0, 1.0, 1.0, 0.8)
	_particles.emitting = false
	_particles.visible = false
	add_child(_particles)

func _ensure_level_up_particles() -> void:
	if _level_up_particles != null:
		return
	_level_up_particles = CPUParticles2D.new()
	_level_up_particles.name = "LevelUpParticles"
	_level_up_particles.amount = 16
	_level_up_particles.lifetime = 0.8
	_level_up_particles.one_shot = true
	_level_up_particles.explosiveness = 0.9
	_level_up_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_level_up_particles.emission_sphere_radius = 12.0
	_level_up_particles.gravity = Vector2(0, -30)
	_level_up_particles.initial_velocity_min = 30.0
	_level_up_particles.initial_velocity_max = 70.0
	_level_up_particles.scale_amount_min = 0.8
	_level_up_particles.scale_amount_max = 2.0
	_level_up_particles.color = Color(1.0, 0.9, 0.5, 1.0)
	_level_up_particles.emitting = false
	add_child(_level_up_particles)

	_ensure_tier_badge()

func _update_tier_badge() -> void:
	if not SHOW_WORLD_TIER_BADGES:
		if _tier_badge != null:
			_tier_badge.visible = false
		# Keep the tier halo in sync even without text badges.
		if SHOW_WORLD_TIER_HALO:
			_ensure_tier_halo()
			_update_tier_halo()
		return
	if _tier_badge == null:
		return
	if is_evolved:
		# Show evolution name abbreviation
		_tier_badge.text = "EVO"
		_tier_badge.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 1.0))
		_update_tier_halo()
		return
	var roman = ["I", "II", "III"]
	_tier_badge.text = roman[clampi(upgrade_level - 1, 0, 2)]
	# Color by tier
	match upgrade_level:
		1:
			_tier_badge.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
		2:
			_tier_badge.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 1.0))
		3:
			var element_color = ELEMENT_COLORS.get(tower_type, Color(1.0, 0.7, 1.0, 1.0))
			_tier_badge.add_theme_color_override("font_color", element_color)
	_update_tier_halo()

func _update_tier_halo() -> void:
	if _tier_halo == null:
		return
	var tex_path = ""
	var visible = false
	if is_evolved:
		tex_path = str(TIER_HALO_TEXTURES.get("evo", ""))
		visible = true
	elif upgrade_level >= 2:
		tex_path = str(TIER_HALO_TEXTURES.get(upgrade_level, ""))
		visible = true
	if tex_path != "" and ResourceLoader.exists(tex_path):
		_tier_halo.texture = load(tex_path)
		_tier_halo.visible = visible
	else:
		_tier_halo.visible = false
	if _tier_halo.visible:
		var base_scale = Vector2.ONE * 1.9
		if body_sprite != null and body_sprite is Node2D:
			base_scale = (body_sprite as Node2D).scale * 2.0
		_tier_halo.scale = base_scale
		if is_evolved:
			_tier_halo.modulate.a = 0.55
		elif upgrade_level >= 3:
			_tier_halo.modulate.a = 0.45
		else:
			_tier_halo.modulate.a = 0.3

func get_display_name() -> String:
	var base = definition.get("name", "Tower")
	if is_evolved:
		return evolution_name
	var tier_names = ["", " II", " III"]
	return base + tier_names[clampi(upgrade_level - 1, 0, 2)]

# Override this in subclasses to set up tower-specific visuals
func _setup_tower_specific_visuals() -> void:
	pass

func _process(delta: float) -> void:
	# Inert towers (owner dead/left in FFA) stop acquiring targets and firing.
	if inert:
		return
	_cooldown = max(0.0, _cooldown - delta)
	_upgrade_cooldown = max(0.0, _upgrade_cooldown - delta)
	var perf_scale = 1.0
	if _game != null and _game.has_method("get_adaptive_perf_scale"):
		perf_scale = float(_game.get_adaptive_perf_scale())
	
	# Legacy spinning aura ring + orbiting/pulsing T3 "floating elements" removed.
	# Ambient T3 particles below are kept.
	if _particles != null and upgrade_level >= 3:
		if perf_scale < 0.75:
			_particles.emitting = false
			_particles.visible = false
		elif not _particles.emitting:
			_particles.visible = true
			_particles.emitting = true

	# Show/hide EVO READY indicator
	if SHOW_WORLD_EVO_READY and can_evolve() and _evo_ready_label == null:
		_show_evo_ready_label()
	elif (not SHOW_WORLD_EVO_READY or not can_evolve()) and _evo_ready_label != null:
		_hide_evo_ready_label()

	var target := _acquire_target(delta)
	if target != null:
		var to_target = target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			_last_fire_dir = to_target.normalized()
	_advance_fire_state(delta, target)
	var has_target_context: bool = target != null or _fire_phase != FirePhase.IDLE
	_set_anim_active(has_target_context, delta)
	_update_body_anim_speed(has_target_context)
	_update_body_motion(delta, has_target_context, perf_scale)
	_sync_body_presentation_state()

func get_fire_windup_time() -> float:
	return 0.055

func get_fire_recover_time() -> float:
	return 0.09

func get_fire_impulse_scale() -> float:
	return 1.0

func get_body_orientation_offset() -> float:
	return 0.0

func get_body_idle_direction() -> Vector2:
	return Vector2.RIGHT

func get_body_tracking_enabled() -> bool:
	return true

func get_body_tracking_speed() -> float:
	return 12.0

func get_body_tracking_max_angle() -> float:
	return PI

func get_body_motion_profile() -> Dictionary:
	return {
		"idle_direction": Vector2.RIGHT,
		"tracking_enabled": true,
		"tracking_speed": 12.0,
		"tracking_max_angle": PI,
		"split_presentation": false,
		"split_ratio": 0.56,
		"split_overlap_px": 4,
	}

func uses_split_body_presentation() -> bool:
	return bool(get_body_motion_profile().get("split_presentation", false))

func get_body_split_ratio() -> float:
	return float(get_body_motion_profile().get("split_ratio", 0.56))

func get_body_split_overlap_px() -> int:
	return int(get_body_motion_profile().get("split_overlap_px", 4))

func get_body_anim_idle_speed() -> float:
	return 0.72

func get_body_anim_target_speed() -> float:
	return 1.0

func get_body_anim_windup_speed() -> float:
	return 1.28

func get_body_anim_recover_speed() -> float:
	return 1.06

func uses_body_frame_animation() -> bool:
	return false

# Per-tower motion tuning. Multipliers scale individual ingredients of the
# shared _update_body_motion recipe so a tower can read "planted/mechanical"
# (no body lunge, no roll) without forking the whole function.
# Defaults reproduce the original behavior (all 1.0).
func get_body_motion_tuning() -> Dictionary:
	return {
		"lunge": 1.0,        # directional position pull on windup/track
		"roll": 1.0,         # windup/recover/idle rotation sway
		"bob": 1.0,          # idle vertical bob
		"recoil": 0.0,       # 0 = original vertical kick; 1 = directional backward recoil
		"fire_punch": 1.0,   # fire scale punch
	}

func get_projectile_visual_profile() -> Dictionary:
	return {}

func get_muzzle_fx_profile() -> Dictionary:
	return {}

func _update_body_anim_speed(has_target: bool) -> void:
	if body_sprite == null:
		return
	var speed_scale := get_body_anim_idle_speed()
	match _fire_phase:
		FirePhase.WINDUP:
			speed_scale = get_body_anim_windup_speed()
		FirePhase.RECOVER:
			speed_scale = get_body_anim_recover_speed()
		_:
			speed_scale = get_body_anim_target_speed() if has_target else get_body_anim_idle_speed()
	body_sprite.speed_scale = max(0.05, speed_scale)

func _has_valid_target(target) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if not (target is Node2D):
		return false
	var node := target as Node
	if node != null and node.is_queued_for_deletion():
		return false
	return _is_target_in_range(target)

func _sanitize_active_target() -> void:
	if _active_target == null:
		return
	if not is_instance_valid(_active_target):
		_active_target = null
		return
	if not (_active_target is Node2D):
		_active_target = null
		return
	var node := _active_target as Node
	if node != null and node.is_queued_for_deletion():
		_active_target = null

func _is_target_in_range(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not (target is Node2D):
		return false
	var node := target as Node2D
	var range_mult = 1.0
	if _game != null and _game.has_method("get_tower_range_mult"):
		range_mult = float(_game.get_tower_range_mult())
	var effective_range = range * range_mult
	return global_position.distance_squared_to(node.global_position) <= effective_range * effective_range

func _acquire_target(delta: float, force_refresh: bool = false) -> Node2D:
	_sanitize_active_target()
	if not force_refresh and _cooldown > 0.0 and _fire_phase == FirePhase.IDLE and _active_target == null:
		_target_refresh_timer = 0.0
		return null
	_target_refresh_timer = max(0.0, _target_refresh_timer - delta)
	var has_valid_active_target := _active_target != null and _has_valid_target(_active_target)
	var should_refresh: bool = force_refresh or _target_refresh_timer <= 0.0 or not has_valid_active_target
	if should_refresh:
		_active_target = _find_target()
		_target_refresh_timer = TARGET_REFRESH_TRACKING if _active_target != null else TARGET_REFRESH_IDLE
	if _active_target != null and is_instance_valid(_active_target) and _active_target is Node2D:
		return _active_target as Node2D
	_active_target = null
	return null

func _advance_fire_state(delta: float, target) -> void:
	match _fire_phase:
		FirePhase.IDLE:
			if target != null and _cooldown <= 0.0:
				_begin_windup()
		FirePhase.WINDUP:
			_fire_phase_timer = max(0.0, _fire_phase_timer - delta)
			var windup_total = max(0.001, get_fire_windup_time())
			_body_anim_windup_blend = 1.0 - (_fire_phase_timer / windup_total)
			if _fire_phase_timer <= 0.0:
				var fire_target := _resolve_fire_target()
				if fire_target != null:
					_fire_at(fire_target)
					_last_fire_dir = (fire_target.global_position - global_position).normalized()
				_fire_phase = FirePhase.RECOVER
				_fire_phase_timer = max(0.0, get_fire_recover_time())
				_body_anim_windup_blend = 0.0
				_body_anim_recover_blend = 1.0
		FirePhase.RECOVER:
			_fire_phase_timer = max(0.0, _fire_phase_timer - delta)
			var recover_total = max(0.001, get_fire_recover_time())
			_body_anim_recover_blend = _fire_phase_timer / recover_total
			if _fire_phase_timer <= 0.0:
				_fire_phase = FirePhase.IDLE
				_body_anim_recover_blend = 0.0

func _begin_windup() -> void:
	_fire_phase = FirePhase.WINDUP
	_fire_phase_timer = max(0.0, get_fire_windup_time())
	_body_anim_windup_blend = 0.0
	var rate_mult = 1.0
	if _game != null and _game.has_method("get_tower_rate_mult"):
		rate_mult = float(_game.get_tower_rate_mult())
	_cooldown = 1.0 / max(0.1, fire_rate * rate_mult)

func _resolve_fire_target() -> Node2D:
	_sanitize_active_target()
	if _has_valid_target(_active_target):
		return _active_target as Node2D
	_active_target = _find_target()
	if _active_target != null and is_instance_valid(_active_target) and _active_target is Node2D:
		return _active_target as Node2D
	_active_target = null
	return null

# Override in subclasses for T3 floating element animation
func _animate_floating_elements(delta: float) -> void:
	pass

func _show_evo_ready_label() -> void:
	if _evo_ready_label != null:
		return
	_evo_ready_label = Label.new()
	_evo_ready_label.name = "EvoReady"
	_evo_ready_label.text = "EVO"
	_evo_ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_evo_ready_label.add_theme_font_size_override("font_size", 7)
	_evo_ready_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9, 0.7))
	_evo_ready_label.position = Vector2(-16, -36)
	_evo_ready_label.size = Vector2(32, 10)
	_evo_ready_label.z_index = 20
	add_child(_evo_ready_label)
	# Pulse animation
	if is_inside_tree():
		_evo_ready_tween = create_tween()
		_evo_ready_tween.set_loops()
		_evo_ready_tween.tween_property(_evo_ready_label, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
		_evo_ready_tween.tween_property(_evo_ready_label, "modulate:a", 0.7, 0.7).set_trans(Tween.TRANS_SINE)

func _hide_evo_ready_label() -> void:
	if _evo_ready_tween != null:
		_evo_ready_tween.kill()
		_evo_ready_tween = null
	if _evo_ready_label != null:
		_evo_ready_label.queue_free()
		_evo_ready_label = null

func _update_visuals_for_upgrade_level(instant: bool = false) -> void:
	var target_scale = 1.4 + (upgrade_level - 1) * 0.2
	var element_color = ELEMENT_COLORS.get(tower_type, Color(1.0, 1.0, 1.0, 0.8))
	
	if instant:
		# Instant update (initial load)
		_apply_tier_visuals_immediate(target_scale, element_color)
	else:
		# Animated upgrade transition
		_play_upgrade_animation(target_scale, element_color)

func _apply_tier_visuals_immediate(scale: float, element_color: Color) -> void:
	# Base glow
	if _glow_sprite != null:
		if upgrade_level == 1:
			_glow_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		elif upgrade_level == 2:
			_glow_sprite.modulate = Color(1.0, 1.0, 1.0, 0.35)
		else:  # T3 - colored glow
			_glow_sprite.modulate = Color(element_color.r, element_color.g, element_color.b, 0.5)
	
	if body_sprite != null:
		body_sprite.scale = Vector2.ONE * scale
		# Slight brightness boost for higher tiers
		var brightness = 1.0 + (upgrade_level - 1) * 0.08
		body_sprite.modulate = Color(brightness, brightness, brightness, 1.0)
		_sync_body_anim_base_scale(false)
	
	# Particles for T3 (lazy created)
	if upgrade_level >= 3:
		_ensure_particles()
		if _particles != null:
			_particles.color = element_color
			_particles.visible = true
			_particles.emitting = true
	
	# Aura ring kept invisible (legacy spinning ring removed); node remains only as
	# a texture source for the one-shot upgrade pulse.
	if _aura_ring != null:
		_aura_ring.modulate = Color(1.0, 1.0, 1.0, 0.0)

	# Tower-specific visuals
	_update_tower_specific_visuals()

	# Tier badge
	_update_tier_badge()

# Override in subclasses
func _update_tower_specific_visuals() -> void:
	pass

func _play_upgrade_animation(target_scale: float, element_color: Color) -> void:
	_is_upgrading = true
	if not is_inside_tree():
		_is_upgrading = false
		return

	# Flash white
	if body_sprite != null:
		if upgrade_level >= 3:
			body_sprite.modulate = Color(element_color.r * 1.6, element_color.g * 1.6, element_color.b * 1.6, 1.0)
		else:
			body_sprite.modulate = Color(1.6, 1.6, 1.6, 1.0)

	# Scale pop effect
	if body_sprite != null:
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(body_sprite, "scale", Vector2.ONE * target_scale * 1.2, 0.15)
		tween.tween_property(body_sprite, "scale", Vector2.ONE * target_scale, 0.4)

		# Return to normal brightness
		var mod_tween = create_tween()
		mod_tween.tween_property(body_sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.0)
		mod_tween.tween_property(body_sprite, "modulate", Color(1.0 + (upgrade_level - 1) * 0.08, 1.0 + (upgrade_level - 1) * 0.08, 1.0 + (upgrade_level - 1) * 0.08, 1.0), 0.3)

	# Glow fade in
	if _glow_sprite != null and is_inside_tree():
		var glow_tween = create_tween()
		if upgrade_level == 2:
			glow_tween.tween_property(_glow_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.35), 0.5)
		else:  # T3
			glow_tween.tween_property(_glow_sprite, "modulate", Color(element_color.r, element_color.g, element_color.b, 0.5), 0.5)

	# Legacy aura-ring fade-in removed (the ring no longer shows or spins).

	# Particle burst (lazy created)
	_ensure_level_up_particles()
	if _level_up_particles != null:
		_level_up_particles.color = UPGRADE_SWIRL_COLORS.get(upgrade_level, Color(1.0, 0.9, 0.5, 1.0))
		_level_up_particles.restart()

	# Start ambient particles for T3 (lazy created)
	if upgrade_level >= 3:
		_ensure_particles()
		if _particles != null:
			_particles.color = element_color
			_particles.visible = true
			_particles.emitting = true
	
	# Pulse ring effect
	_spawn_upgrade_pulse(element_color if upgrade_level >= 3 else Color(1.0, 0.85, 0.2, 1.0))
	
	# Tower-specific upgrade effects
	_play_tower_specific_upgrade_effects()

	# Update tier badge
	_update_tier_badge()

	if is_inside_tree():
		await get_tree().create_timer(0.5).timeout
	if not is_inside_tree():
		return
	# Finalize all tier visuals after animation completes
	_apply_tier_visuals_immediate(target_scale, element_color)
	_is_upgrading = false

# Override in subclasses for tower-specific upgrade effects
func _play_tower_specific_upgrade_effects() -> void:
	pass

func _spawn_upgrade_pulse(color: Color) -> void:
	if not is_inside_tree():
		return
	var pulse = Sprite2D.new()
	pulse.z_index = -3
	pulse.texture = _aura_ring.texture if _aura_ring != null else null
	pulse.modulate = Color(color.r, color.g, color.b, 0.45)
	pulse.scale = Vector2.ONE * 0.5
	add_child(pulse)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2.ONE * 2.2, 0.6)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(pulse.queue_free)

func play_upgrade_juice(target_level: int = -1) -> void:
	"""Called by build_manager to trigger all upgrade effects"""
	if _is_upgrading and target_level <= 0:
		return  # Prevent spam when auto-previewing
	
	# Use explicit target level when provided (upgrade already applied)
	# Otherwise assume we're called before upgrade and preview the next tier
	var next_level = target_level if target_level > 0 else upgrade_level + 1
	
	# Subtle time accent (avoid constant slow-mo feel)
	if _game != null and _game.has_method("trigger_time_accent"):
		_game.trigger_time_accent(0.75, 0.15)
	
	# Tower levitation effect
	_play_levitation_effect()
	
	# Screen shake - stronger for higher tiers
	if _game != null and _game.has_method("shake_camera"):
		var shake_strength = 4.0 + next_level * 2.0
		_game.shake_camera(shake_strength, 0.3)
	
	# Spawn upgrade swirl particles (gold for T2, purple for T3)
	var upgrade_color = _get_upgrade_color(next_level)
	_spawn_upgrade_swirl(next_level)
	
	# Flash of light on completion
	_spawn_upgrade_flash(upgrade_color)
	_spawn_upgrade_glow_burst(upgrade_color, next_level)
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("upgrade_burst", global_position)
	if _game != null and _game.has_method("flash_screen"):
		_game.flash_screen(Color(upgrade_color.r, upgrade_color.g, upgrade_color.b, 0.14), 0.18)
	
	# Note: The actual visual transformation happens in _apply_tier_stats()
	# when upgrade_level is incremented. This method just triggers the FX.
	
	# Cooldown to prevent spam
	_upgrade_cooldown = 0.5

func _play_levitation_effect() -> void:
	"""Make the tower float up slightly during upgrade"""
	if body_sprite == null or not is_inside_tree():
		return

	var original_y = body_sprite.position.y
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# Float up
	tween.tween_property(body_sprite, "position:y", original_y - 8.0, 0.3)
	# Hold
	tween.tween_interval(0.4)
	# Float down
	tween.tween_property(body_sprite, "position:y", original_y, 0.3)

func _spawn_upgrade_swirl(target_level: int = 2) -> void:
	"""Create swirling particle effect around tower during upgrade"""
	if not is_inside_tree():
		return
	var swirl = CPUParticles2D.new()
	swirl.name = "UpgradeSwirl"
	swirl.amount = 18
	swirl.lifetime = 1.0
	swirl.one_shot = true
	swirl.explosiveness = 0.3
	swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	swirl.emission_sphere_radius = 24.0
	swirl.gravity = Vector2(0, 0)
	swirl.initial_velocity_min = 35.0
	swirl.initial_velocity_max = 70.0
	swirl.angular_velocity_min = 180.0
	swirl.angular_velocity_max = 360.0
	swirl.scale_amount_min = 0.9
	swirl.scale_amount_max = 2.3
	swirl.color = UPGRADE_SWIRL_COLORS.get(target_level, Color(1.0, 0.85, 0.2, 1.0))
	swirl.emitting = true
	add_child(swirl)
	
	# Auto-remove after effect completes
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		if is_instance_valid(swirl):
			swirl.queue_free()
	)

func _spawn_upgrade_flash(color: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	"""Bright flash when upgrade completes"""
	if not is_inside_tree():
		return
	var flash = ColorRect.new()
	flash.name = "UpgradeFlash"
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.size = Vector2(140, 140)
	flash.position = Vector2(-70, -70)
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.85, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.45)
	tween.chain().tween_callback(flash.queue_free)

func _get_upgrade_color(target_level: int) -> Color:
	if target_level >= 3:
		return ELEMENT_COLORS.get(tower_type, Color(0.8, 0.2, 1.0, 1.0))
	return Color(1.0, 0.85, 0.2, 1.0)

func _spawn_upgrade_glow_burst(color: Color, target_level: int) -> void:
	if _game == null or not _game.has_method("spawn_glow_particle"):
		return
	var count = 6 + target_level * 2
	for i in range(count):
		var angle = randf() * TAU
		var dir = Vector2.RIGHT.rotated(angle)
		var vel = dir * randf_range(90.0, 170.0)
		_game.spawn_glow_particle(
			global_position + dir * randf_range(4.0, 14.0),
			color,
			randf_range(10.0, 16.0),
			0.6,
			vel,
			2.3,
			0.8,
			1.15,
			5
		)

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	var base_health = max_health
	range = float(tier_data.get("range", range))
	fire_rate = float(tier_data.get("fire_rate", fire_rate))
	damage = float(tier_data.get("damage", damage))
	projectile_speed = float(tier_data.get("projectile_speed", projectile_speed))
	projectile_range = float(tier_data.get("projectile_range", projectile_range))
	explosion_radius = float(tier_data.get("explosion_radius", explosion_radius))
	# Update upgrade level based on tier
	var old_level = upgrade_level
	upgrade_level = tier + 1
	var infusion_index = clampi(upgrade_level - 1, 0, 2)
	range *= float(ESSENCE_INFUSION_RANGE_MULT[infusion_index])
	projectile_range *= float(ESSENCE_INFUSION_RANGE_MULT[infusion_index])
	fire_rate *= float(ESSENCE_INFUSION_RATE_MULT[infusion_index])
	damage *= float(ESSENCE_INFUSION_DAMAGE_MULT[infusion_index])
	max_health = base_health * float(ESSENCE_INFUSION_HEALTH_MULT[infusion_index])
	health = max_health
	if old_level != upgrade_level and is_inside_tree():
		_update_visuals_for_upgrade_level(false)

func _on_upgraded() -> void:
	"""Called when upgrade is applied - triggers visual update"""
	super._on_upgraded()
	# Visual update is handled in _apply_tier_stats when upgrade_level changes
	pass

func _find_target() -> Node2D:
	var best: Node2D = null
	var range_mult = 1.0
	if _game != null and _game.has_method("get_tower_range_mult"):
		range_mult = _game.get_tower_range_mult()
	var effective_range = range * range_mult
	var best_dist = effective_range * effective_range
	var enemies: Array = _get_enemies()
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

func _get_enemies() -> Array:
	# Only consider enemies in nearby grid cells rather than the whole map.
	if _game != null and _game.has_method("get_enemies_near"):
		return _game.get_enemies_near(global_position, get_range())
	if _game != null and _game.has_method("get_cached_enemies"):
		return _game.get_cached_enemies()
	return get_tree().get_nodes_in_group("enemies")

func get_range() -> float:
	var range_mult = 1.0
	if _game != null and _game.has_method("get_tower_range_mult"):
		range_mult = _game.get_tower_range_mult()
	return range * range_mult

func _fire_at(target: Node2D) -> void:
	if _game == null:
		return
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
	var dmg_bonus = 0.0
	if _game != null and _game.has_method("get_tower_damage_bonus"):
		dmg_bonus = _game.get_tower_damage_bonus()
	var dmg_mult = 1.0
	if _game != null and _game.has_method("get_tower_damage_mult"):
		dmg_mult = _game.get_tower_damage_mult()
	_game.spawn_projectile(
		global_position,
		dir,
		projectile_speed,
		(damage + dmg_bonus) * dmg_mult,
		projectile_range,
		explosion_radius,
		0,
		1.0,
		0.0,
		"normal",
		get_projectile_visual_profile()
	)
	
	# Audio: Tower fire sound based on tower type
	AudioManager.play_weapon_sound(tower_type, global_position)
	_trigger_fire_motion(1.0)
	_spawn_tower_fire_emitter(dir, 1.0)

func _trigger_fire_motion(intensity: float = 1.0) -> void:
	var scaled_impulse = clampf(intensity * get_fire_impulse_scale(), 0.25, 2.0)
	_body_anim_fire_impulse = max(_body_anim_fire_impulse, scaled_impulse)
	_play_fire_flash(scaled_impulse)

func _play_fire_flash(intensity: float) -> void:
	if _fire_flash_sprite == null or not is_inside_tree():
		return
	var perf_scale = 1.0
	if _game != null and _game.has_method("get_adaptive_perf_scale"):
		perf_scale = float(_game.get_adaptive_perf_scale())
	if perf_scale < 0.55:
		return
	if _fire_flash_tween != null and _fire_flash_tween.is_valid():
		_fire_flash_tween.kill()
	var flash_strength = clampf(0.38 + intensity * 0.22, 0.35, 0.95)
	_fire_flash_sprite.modulate.a = flash_strength
	_fire_flash_sprite.scale = Vector2.ONE * (0.18 + intensity * 0.07)
	_fire_flash_tween = create_tween()
	_fire_flash_tween.set_parallel(true)
	_fire_flash_tween.tween_property(_fire_flash_sprite, "modulate:a", 0.0, 0.10)
	_fire_flash_tween.tween_property(_fire_flash_sprite, "scale", Vector2.ONE * 0.30, 0.10)

func _spawn_tower_fire_emitter(direction: Vector2, intensity: float = 1.0) -> void:
	if _game == null:
		return
	if _game.has_method("should_spawn_optional_fx") and not bool(_game.should_spawn_optional_fx()):
		return
	if not ("fx_manager" in _game):
		return
	var manager = _game.fx_manager
	if manager == null or not is_instance_valid(manager):
		return
	if manager.has_method("spawn_tower_fire_emitter"):
		manager.spawn_tower_fire_emitter(global_position, direction, tower_type, intensity, get_muzzle_fx_profile())

func _setup_body_presentation() -> void:
	_body_split_mode = uses_split_body_presentation()
	if body_sprite == null:
		return
	if not _body_split_mode:
		body_sprite.visible = true
		return
	if _body_base_sprite == null:
		_body_base_sprite = Sprite2D.new()
		_body_base_sprite.name = "BodyBase"
		_body_base_sprite.centered = true
		_body_base_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_body_base_sprite.z_index = 0
		add_child(_body_base_sprite)
	if _body_head_sprite == null:
		_body_head_sprite = Sprite2D.new()
		_body_head_sprite.name = "BodyHead"
		_body_head_sprite.centered = true
		_body_head_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_body_head_sprite.z_index = 2
		add_child(_body_head_sprite)
	body_sprite.visible = false
	_refresh_body_presentation(true)

func refresh_body_presentation(force_texture: bool = false) -> void:
	_refresh_body_presentation(force_texture)

func _refresh_body_presentation(force_texture: bool = false) -> void:
	if not _body_split_mode or body_sprite == null:
		return
	if _body_base_sprite == null or _body_head_sprite == null:
		return
	var tex := _get_body_source_texture()
	if tex == null:
		return
	if not force_texture and tex.get_rid() == _body_presentation_texture_rid:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0 or tex_size.y <= 1:
		return
	var tex_w: int = int(tex_size.x)
	var tex_h: int = int(tex_size.y)
	var split_y: int = clampi(int(round(float(tex_h) * clampf(get_body_split_ratio(), 0.2, 0.8))), 1, tex_h - 1)
	var overlap: int = clampi(get_body_split_overlap_px(), 0, min(split_y - 1, tex_h - split_y))
	var head_rect := Rect2(0.0, 0.0, float(tex_w), float(split_y + overlap))
	var base_y: int = max(0, split_y - overlap)
	var base_rect := Rect2(0.0, float(base_y), float(tex_w), float(tex_h - base_y))
	_body_head_sprite.texture = tex
	_body_head_sprite.region_enabled = true
	_body_head_sprite.region_rect = head_rect
	_body_base_sprite.texture = tex
	_body_base_sprite.region_enabled = true
	_body_base_sprite.region_rect = base_rect
	_body_head_region_offset = _calc_body_region_offset(tex_h, head_rect)
	_body_base_region_offset = _calc_body_region_offset(tex_h, base_rect)
	_body_presentation_texture_rid = tex.get_rid()
	_sync_body_presentation_state()

func _get_body_source_texture() -> Texture2D:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return null
	var frame_count: int = body_sprite.sprite_frames.get_frame_count("default")
	if frame_count <= 0:
		return null
	return body_sprite.sprite_frames.get_frame_texture("default", clampi(body_sprite.frame, 0, frame_count - 1))

func _calc_body_region_offset(full_height: int, region_rect: Rect2) -> Vector2:
	var full_center_y: float = float(full_height) * 0.5
	var region_center_y: float = region_rect.position.y + region_rect.size.y * 0.5
	return Vector2(0.0, region_center_y - full_center_y)

func _sync_body_presentation_state() -> void:
	if not _body_split_mode or body_sprite == null:
		return
	if _body_base_sprite == null or _body_head_sprite == null:
		return
	_refresh_body_presentation()
	var scale_vec: Vector2 = body_sprite.scale
	var scaled_base_offset := Vector2(_body_base_region_offset.x * scale_vec.x, _body_base_region_offset.y * scale_vec.y)
	var scaled_head_offset := Vector2(_body_head_region_offset.x * scale_vec.x, _body_head_region_offset.y * scale_vec.y)
	var idle_rot: float = get_body_orientation_offset() + sin(_body_anim_idle_phase * 0.65) * 0.006 * (1.0 - _body_anim_target_blend)
	_body_base_sprite.visible = not body_sprite.visible
	_body_head_sprite.visible = not body_sprite.visible
	_body_base_sprite.position = body_sprite.position + scaled_base_offset
	_body_head_sprite.position = body_sprite.position + scaled_head_offset
	_body_base_sprite.scale = scale_vec
	_body_head_sprite.scale = scale_vec
	_body_base_sprite.rotation = idle_rot
	_body_head_sprite.rotation = body_sprite.rotation
	_body_base_sprite.modulate = body_sprite.modulate
	_body_head_sprite.modulate = body_sprite.modulate

func _sync_body_anim_base_scale(force_reset: bool) -> void:
	if body_sprite == null:
		return
	_body_anim_base_scale = body_sprite.scale
	if force_reset:
		_body_anim_base_position = body_sprite.position
	if force_reset or _body_anim_smooth_scale == Vector2.ONE:
		_body_anim_smooth_scale = _body_anim_base_scale
	_sync_body_presentation_state()

func _update_body_motion(delta: float, has_target: bool, perf_scale: float) -> void:
	if body_sprite == null:
		return
	if _is_upgrading:
		return
	var dt: float = minf(delta, 0.05)
	var runtime_target_fps: float = 60.0
	if _game != null and _game.has_method("get_runtime_target_fps"):
		runtime_target_fps = max(30.0, float(_game.get_runtime_target_fps()))
	var fps_stability_mult: float = clampf(runtime_target_fps / 60.0, 0.5, 1.0)
	var phase_rate = 1.0 + sin(_instance_motion_phase_offset) * 0.08
	_body_anim_idle_phase += dt * BODY_IDLE_BOB_RATE * phase_rate * lerpf(0.74, 1.18, perf_scale) * fps_stability_mult
	var target_blend_alpha: float = _smoothing_alpha(8.0, dt)
	_body_anim_target_blend = lerpf(_body_anim_target_blend, 1.0 if has_target else 0.0, target_blend_alpha)
	_body_anim_fire_impulse = max(0.0, _body_anim_fire_impulse - dt * BODY_FIRE_IMPULSE_DECAY * lerpf(0.72, 1.22, perf_scale))
	var aim_alpha: float = _smoothing_alpha(10.0, dt)
	var idle_dir := get_body_idle_direction()
	if idle_dir.length_squared() <= 0.0001:
		idle_dir = Vector2.RIGHT
	var target_dir: Vector2 = _last_fire_dir if has_target else idle_dir.normalized()
	if target_dir.length_squared() <= 0.0001:
		target_dir = Vector2.RIGHT
	_body_anim_aim_dir = _body_anim_aim_dir.lerp(target_dir, aim_alpha)

	var tuning := get_body_motion_tuning()
	var tune_lunge: float = float(tuning.get("lunge", 1.0))
	var tune_roll: float = float(tuning.get("roll", 1.0))
	var tune_bob: float = float(tuning.get("bob", 1.0))
	var tune_recoil: float = float(tuning.get("recoil", 1.0))
	var tune_punch: float = float(tuning.get("fire_punch", 1.0))

	var idle_strength = lerpf(1.0, BODY_TARGET_BOB_MULT, _body_anim_target_blend)
	var bob_y = sin(_body_anim_idle_phase) * BODY_IDLE_BOB_AMP * idle_strength * 18.0 * lerpf(0.72, 1.0, fps_stability_mult) * tune_bob
	var fire_scale = 1.0 + _body_anim_fire_impulse * BODY_FIRE_PUNCH_SCALE * tune_punch
	var windup_pull = _body_anim_windup_blend * BODY_WINDUP_PULL
	var recover_settle = _body_anim_recover_blend * BODY_RECOVER_SETTLE
	var track_lean = _body_anim_target_blend * BODY_TRACK_LEAN * 0.25
	var directional_pull = _body_anim_aim_dir.normalized() * (windup_pull - recover_settle + track_lean) * tune_lunge
	var track_scale = 1.0 + _body_anim_target_blend * 0.03
	var target_scale = _body_anim_base_scale * fire_scale * track_scale
	var scale_alpha: float = _smoothing_alpha(16.0, dt)
	_body_anim_smooth_scale = _body_anim_smooth_scale.lerp(target_scale, scale_alpha)
	var base_rot = get_body_orientation_offset()
	var target_rot = base_rot
	if get_body_tracking_enabled():
		var idle_angle = idle_dir.normalized().angle()
		var desired_angle = _body_anim_aim_dir.angle()
		target_rot = base_rot + wrapf(desired_angle - idle_angle, -PI, PI)
		var max_track = clampf(get_body_tracking_max_angle(), 0.0, PI)
		if max_track < PI:
			var rel = wrapf(target_rot - base_rot, -PI, PI)
			target_rot = base_rot + clampf(rel, -max_track, max_track)
	var tracking_speed = get_body_tracking_speed() * (1.0 if has_target else 0.65)
	var rot_alpha = _smoothing_alpha(tracking_speed, dt)
	_body_anim_track_rotation = lerp_angle(_body_anim_track_rotation, target_rot, rot_alpha)
	body_sprite.scale = _body_anim_smooth_scale
	# Recoil: vertical kick by default; planted towers (recoil tuning) instead
	# kick backward along the aim direction so the body reads as bracing, not flopping.
	var recoil_kick: Vector2 = -_body_anim_aim_dir.normalized() * _body_anim_fire_impulse * 1.6 * tune_recoil
	var vertical_kick: float = -_body_anim_fire_impulse * 1.6 * (1.0 - clampf(tune_recoil, 0.0, 1.0))
	body_sprite.position.x = _body_anim_base_position.x + directional_pull.x * 0.65 + recoil_kick.x
	body_sprite.position.y = _body_anim_base_position.y + bob_y + directional_pull.y * 0.65 + vertical_kick + recoil_kick.y
	# When tracking is disabled the body uses baked iso / front-facing flipbook
	# art that must never rotate: pin rotation to its neutral orientation so
	# no aim tracking, sway, or fire-roll can spin it.
	if get_body_tracking_enabled():
		var windup_roll = -_body_anim_windup_blend * 0.012 * sign(_body_anim_aim_dir.x if abs(_body_anim_aim_dir.x) > 0.05 else 1.0) * tune_roll
		var recover_roll = _body_anim_recover_blend * 0.008 * sign(_body_anim_aim_dir.x if abs(_body_anim_aim_dir.x) > 0.05 else 1.0) * tune_roll
		var idle_sway = sin(_body_anim_idle_phase * 0.65) * 0.015 * (1.0 - _body_anim_target_blend) * tune_roll
		body_sprite.rotation = _body_anim_track_rotation + idle_sway - _body_anim_fire_impulse * BODY_FIRE_PUNCH_ROT * tune_roll + windup_roll + recover_roll
	else:
		body_sprite.rotation = get_body_orientation_offset()

func _set_anim_active(active: bool, delta: float) -> void:
	if body_sprite == null:
		return
	if not uses_body_frame_animation():
		if body_sprite.is_playing():
			body_sprite.stop()
		if body_sprite.frame != 0:
			body_sprite.frame = 0
		_body_anim_stop_hold = 0.0
		return
	if active:
		_body_anim_stop_hold = BODY_STOP_HOLD_TIME
		if not body_sprite.is_playing():
			body_sprite.play()
	else:
		_body_anim_stop_hold = max(0.0, _body_anim_stop_hold - delta)
		if _body_anim_stop_hold <= 0.0 and body_sprite.is_playing():
			body_sprite.stop()
			body_sprite.frame = 0

func get_upgrade_cost() -> int:
	if not can_upgrade():
		return 0
	return ESSENCE_INFUSION_GOLD_COST

func get_upgrade_essence_cost() -> int:
	if not can_upgrade():
		return 0
	return ESSENCE_INFUSION_ESSENCE_COST

func get_upgrade_label() -> String:
	return "Essence Infusion"

func can_upgrade() -> bool:
	# Check if upgrade is in cooldown
	if _upgrade_cooldown > 0:
		return false
	if _is_upgrading:
		return false
	return super.can_upgrade()

func take_damage(amount: float) -> void:
	# Flash red on damage
	if body_sprite != null and is_inside_tree():
		var tween = create_tween()
		tween.tween_property(body_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.0)
		tween.tween_property(body_sprite, "modulate", Color(1.0 + (upgrade_level - 1) * 0.1, 1.0 + (upgrade_level - 1) * 0.1, 1.0 + (upgrade_level - 1) * 0.1, 1.0), 0.2)
	super.take_damage(amount)

func _exit_tree() -> void:
	# Clean up tweens to avoid errors
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	if _fire_flash_tween != null and _fire_flash_tween.is_valid():
		_fire_flash_tween.kill()
	_active_target = null
	_fire_phase = FirePhase.IDLE
