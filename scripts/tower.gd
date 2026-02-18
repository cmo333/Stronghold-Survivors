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
	# Big dramatic effect
	if _game.has_method("spawn_fx"):
		_game.spawn_fx("upgrade_burst", global_position)
	if _game.has_method("shake_camera"):
		_game.shake_camera(10.0, 0.4)
	# Purple essence flash
	if _game.has_method("spawn_glow_particle"):
		for i in range(8):
			var angle = (TAU / 8.0) * i
			var dir = Vector2.RIGHT.rotated(angle)
			var vel = dir * randf_range(100.0, 200.0)
			_game.spawn_glow_particle(global_position, Color(0.7, 0.3, 1.0), randf_range(10.0, 18.0), 1.0, vel, 2.5, 0.8, 1.2, 5)

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

var _cooldown = 0.0
var _game: Node = null
@onready var body_sprite: AnimatedSprite2D = get_node_or_null("Body") as AnimatedSprite2D

# Tower type identifier (set by subclasses)
var tower_type: String = "base"

func _ready() -> void:
	super._ready()  # CRITICAL: Adds to "buildings" group for selection
	_game = get_tree().get_first_node_in_group("game")
	if body_sprite != null:
		body_sprite.stop()
		body_sprite.frame = 0
		body_sprite.scale = Vector2.ONE * 1.35
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

	# NOTE: _particles and _level_up_particles are created lazily in _ensure_particles()
	# NOTE: PointLight2D removed — too expensive with many towers
	_ensure_tier_badge()

func _ensure_tier_badge() -> void:
	if _tier_badge != null:
		return
	_tier_badge = Label.new()
	_tier_badge.name = "TierBadge"
	_tier_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tier_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tier_badge.position = Vector2(6, 8)
	_tier_badge.z_index = 20
	_tier_badge.add_theme_font_size_override("font_size", 10)
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
		var base_scale = Vector2.ONE * 2.4
		if body_sprite != null and body_sprite is Node2D:
			base_scale = (body_sprite as Node2D).scale * 2.6
		_tier_halo.scale = base_scale
		if is_evolved:
			_tier_halo.modulate.a = 0.95
		elif upgrade_level >= 3:
			_tier_halo.modulate.a = 0.85
		else:
			_tier_halo.modulate.a = 0.7

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
	_cooldown = max(0.0, _cooldown - delta)
	_upgrade_cooldown = max(0.0, _upgrade_cooldown - delta)
	
	# Rotate aura ring
	if _aura_ring != null and upgrade_level >= 2:
		_aura_ring.rotation += delta * (0.5 + upgrade_level * 0.3)
	
	# Animate floating elements for T3
	if upgrade_level >= 3:
		_animate_floating_elements(delta)

	# Show/hide EVO READY indicator
	if can_evolve() and _evo_ready_label == null:
		_show_evo_ready_label()
	elif not can_evolve() and _evo_ready_label != null:
		_hide_evo_ready_label()
	
	if _cooldown > 0.0:
		return
	var target = _find_target()
	if target == null:
		_set_anim_active(false)
		return
	_set_anim_active(true)
	_fire_at(target)
	var rate_mult = 1.0
	if _game != null and _game.has_method("get_tower_rate_mult"):
		rate_mult = _game.get_tower_rate_mult()
	_cooldown = 1.0 / max(0.1, fire_rate * rate_mult)

# Override in subclasses for T3 floating element animation
func _animate_floating_elements(delta: float) -> void:
	pass

func _show_evo_ready_label() -> void:
	if _evo_ready_label != null:
		return
	_evo_ready_label = Label.new()
	_evo_ready_label.name = "EvoReady"
	_evo_ready_label.text = "EVO READY"
	_evo_ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_evo_ready_label.add_theme_font_size_override("font_size", 8)
	_evo_ready_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	_evo_ready_label.position = Vector2(-28, -42)
	_evo_ready_label.size = Vector2(56, 12)
	_evo_ready_label.z_index = 20
	add_child(_evo_ready_label)
	# Pulse animation
	if is_inside_tree():
		_evo_ready_tween = create_tween()
		_evo_ready_tween.set_loops()
		_evo_ready_tween.tween_property(_evo_ready_label, "modulate:a", 0.3, 0.7).set_trans(Tween.TRANS_SINE)
		_evo_ready_tween.tween_property(_evo_ready_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

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
			_glow_sprite.modulate = Color(1.0, 1.0, 1.0, 0.65)
		else:  # T3 - colored glow
			_glow_sprite.modulate = Color(element_color.r, element_color.g, element_color.b, 0.9)
	
	if body_sprite != null:
		body_sprite.scale = Vector2.ONE * scale
		# Slight brightness boost for higher tiers
		var brightness = 1.0 + (upgrade_level - 1) * 0.1
		body_sprite.modulate = Color(brightness, brightness, brightness, 1.0)
	
	# Particles for T3 (lazy created)
	if upgrade_level >= 3:
		_ensure_particles()
		if _particles != null:
			_particles.color = element_color
			_particles.visible = true
			_particles.emitting = true
	
	# Aura ring
	if _aura_ring != null:
		if upgrade_level == 1:
			_aura_ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
		elif upgrade_level == 2:
			_aura_ring.modulate = Color(1.0, 1.0, 1.0, 0.4)
		else:
			_aura_ring.modulate = Color(element_color.r, element_color.g, element_color.b, 0.55)
		_aura_ring.scale = Vector2.ONE * (1.2 + upgrade_level * 0.3)
	
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
			body_sprite.modulate = Color(element_color.r * 2.2, element_color.g * 2.2, element_color.b * 2.2, 1.0)
		else:
			body_sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)

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
		mod_tween.tween_property(body_sprite, "modulate", Color(1.0 + (upgrade_level - 1) * 0.1, 1.0 + (upgrade_level - 1) * 0.1, 1.0 + (upgrade_level - 1) * 0.1, 1.0), 0.3)

	# Glow fade in
	if _glow_sprite != null and is_inside_tree():
		var glow_tween = create_tween()
		if upgrade_level == 2:
			glow_tween.tween_property(_glow_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.65), 0.5)
		else:  # T3
			glow_tween.tween_property(_glow_sprite, "modulate", Color(element_color.r, element_color.g, element_color.b, 0.9), 0.5)

	# Aura ring animation
	if _aura_ring != null and upgrade_level >= 2 and is_inside_tree():
		var aura_tween = create_tween()
		aura_tween.set_parallel(true)
		if upgrade_level == 2:
			aura_tween.tween_property(_aura_ring, "modulate", Color(1.0, 1.0, 1.0, 0.4), 0.5)
		else:
			aura_tween.tween_property(_aura_ring, "modulate", Color(element_color.r, element_color.g, element_color.b, 0.55), 0.5)
		aura_tween.tween_property(_aura_ring, "scale", Vector2.ONE * (1.2 + upgrade_level * 0.3), 0.5)
	
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
	pulse.modulate = Color(color.r, color.g, color.b, 0.7)
	pulse.scale = Vector2.ONE * 0.6
	add_child(pulse)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(pulse, "scale", Vector2.ONE * 3.5, 0.75)
	tween.tween_property(pulse, "modulate:a", 0.0, 0.75)
	tween.chain().tween_callback(pulse.queue_free)

func play_upgrade_juice() -> void:
	"""Called by build_manager to trigger all upgrade effects"""
	if _is_upgrading:
		return  # Prevent spam
	
	# Note: upgrade_level is still the OLD level here (called before upgrade())
	# We use upgrade_level + 1 for effects that should match the NEW tier
	var next_level = upgrade_level + 1
	
	# Time dilation moment - 0.2x for 1 second as specified
	if _game != null and _game.has_method("trigger_time_accent"):
		_game.trigger_time_accent(0.2, 1.0)
	
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
	timer.timeout.connect(func(): if is_instance_valid(swirl): swirl.queue_free())

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
	range = float(tier_data.get("range", range))
	fire_rate = float(tier_data.get("fire_rate", fire_rate))
	damage = float(tier_data.get("damage", damage))
	projectile_speed = float(tier_data.get("projectile_speed", projectile_speed))
	projectile_range = float(tier_data.get("projectile_range", projectile_range))
	explosion_radius = float(tier_data.get("explosion_radius", explosion_radius))
	# Update upgrade level based on tier
	var old_level = upgrade_level
	upgrade_level = tier + 1
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
	for enemy: Node2D in enemies:
		if enemy == null:
			continue
		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best

func _get_enemies() -> Array:
	if _game != null and "cached_enemies" in _game:
		return _game.cached_enemies
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
	_game.spawn_projectile(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius)
	
	# Audio: Tower fire sound based on tower type
	AudioManager.play_weapon_sound(tower_type, global_position)

	# Recoil animation: brief scale punch for satisfying fire feedback
	if body_sprite != null and is_inside_tree():
		var base_scale = body_sprite.scale
		var recoil_tween = create_tween()
		recoil_tween.tween_property(body_sprite, "scale", base_scale * 1.15, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		recoil_tween.tween_property(body_sprite, "scale", base_scale, 0.08).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _set_anim_active(active: bool) -> void:
	if body_sprite == null:
		return
	if active:
		if not body_sprite.is_playing():
			body_sprite.play()
	else:
		if body_sprite.is_playing():
			body_sprite.stop()
			body_sprite.frame = 0

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
