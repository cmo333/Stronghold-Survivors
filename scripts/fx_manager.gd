extends Node
class_name FXManager

# FX Manager - Centralized particle and visual effects system
# Geometry Wars quality FX with high particle density

const FeedbackConfig = preload("res://scripts/feedback_config.gd")

# Scene preloads
const PROJECTILE_TRAIL_SCENE = preload("res://scenes/fx/projectile_trail.tscn")
const IMPACT_SPARKS_SCENE = preload("res://scenes/fx/impact_sparks.tscn")
const GROUND_CRACK_SCENE = preload("res://scenes/fx/ground_crack.tscn")
const SHOCKWAVE_RING_SCENE = preload("res://scenes/fx/shockwave_ring.tscn")
const LIGHTNING_BEAM_SCENE = preload("res://scenes/fx/lightning_beam.tscn")
const MULTISHOT_INDICATOR_SCENE = preload("res://scenes/fx/multishot_indicator.tscn")
const ENVIRONMENTAL_DUST_SCENE = preload("res://scenes/fx/environmental_dust.tscn")
const CORPSE_FADE_SCENE = preload("res://scenes/fx/corpse_fade.tscn")

# Parent nodes
var _fx_root: Node2D
var _game: Node

# Color constants for damage types
const COLOR_FIRE = Color(1.0, 0.3, 0.1, 1.0)
const COLOR_ICE = Color(0.3, 0.7, 1.0, 1.0)
const COLOR_LIGHTNING = Color(1.0, 0.95, 0.3, 1.0)
const COLOR_NORMAL = Color(0.9, 0.85, 0.7, 1.0)
const COLOR_CRIT = Color(1.0, 0.2, 0.6, 1.0)

# Pooling for performance
var _trail_pool: Array[Node2D] = []
var _spark_pool: Array[Node2D] = []
var _shockwave_pool: Array[Node2D] = []
const MAX_POOL_SIZE = 20
const MAX_FX_CHILDREN = 150  # Global cap on FX to prevent memory issues

func setup(game: Node, fx_root: Node2D) -> void:
    _game = game
    _fx_root = fx_root

func _can_spawn_fx() -> bool:
    """Check if we can spawn more FX without exceeding limits"""
    if _fx_root == null:
        return false
    return _fx_root.get_child_count() < MAX_FX_CHILDREN

# ============================================
# PROJECTILE TRAILS
# ============================================

func spawn_projectile_trail(projectile: Node2D, damage_type: String = "normal") -> Node2D:
    """Create a fading trail that follows a projectile"""
    if _fx_root == null or not is_instance_valid(projectile):
        return null
    
    var trail = _get_pooled_trail()
    if trail == null:
        trail = PROJECTILE_TRAIL_SCENE.instantiate()
    
    trail.global_position = projectile.global_position
    _fx_root.add_child(trail)
    
    # Configure based on damage type
    var color = _get_damage_type_color(damage_type)
    var width = 3.0
    var fade_time = 0.3
    
    if trail.has_method("setup"):
        trail.setup(projectile, color, width, fade_time)
    
    return trail

func _get_pooled_trail() -> Node2D:
    for trail in _trail_pool:
        if trail != null and not trail.visible:
            return trail
    if _trail_pool.size() < MAX_POOL_SIZE:
        return null
    return _trail_pool[0] if not _trail_pool.is_empty() else null

# ============================================
# IMPACT EFFECTS
# ============================================

func spawn_impact(position: Vector2, damage_type: String = "normal", is_crit: bool = false, impact_normal: Vector2 = Vector2.UP) -> void:
    """Spawn impact effects - sparks, ground crack, screen shake"""
    
    # Hit sparks (4-8 particles bouncing away)
    var spark_count = randi_range(4, 8)
    if is_crit:
        spark_count = randi_range(8, 14)
    
    spawn_impact_sparks(position, spark_count, damage_type, impact_normal)
    
    # Ground crack decal (fades over 2s)
    spawn_ground_crack(position, damage_type, impact_normal)
    
    # Screen micro-shake
    if _game != null and _game.has_method("shake_camera"):
        var shake_strength = FeedbackConfig.SCREEN_SHAKE_BASE_INTENSITY * (2.0 if is_crit else 1.0)
        _game.shake_camera(shake_strength, 0.08 if is_crit else 0.05)

func spawn_impact_sparks(position: Vector2, count: int, damage_type: String, normal: Vector2 = Vector2.UP) -> void:
    """Spawn bouncing spark particles"""
    if not _can_spawn_fx():
        return
    
    var color = _get_damage_type_color(damage_type)
    
    for i in range(count):
        var spark = IMPACT_SPARKS_SCENE.instantiate() if _spark_pool.is_empty() else _spark_pool.pop_back()
        spark.global_position = position
        _fx_root.add_child(spark)
        
        # Bounce direction - mostly away from impact normal with spread
        var bounce_angle = normal.angle() + randf_range(-PI * 0.4, PI * 0.4)
        var bounce_speed = randf_range(80.0, 180.0) * (1.0 + randf() * 0.5)
        var velocity = Vector2.RIGHT.rotated(bounce_angle) * bounce_speed
        
        # Gravity for arc
        velocity += Vector2(0, -randf_range(30.0, 80.0))  # Upward initial velocity
        
        var size = randf_range(2.0, 5.0)
        var lifetime = randf_range(0.3, 0.6)
        
        if spark.has_method("setup"):
            spark.setup(color, size, lifetime, velocity, true)  # true = bounce

func spawn_ground_crack(position: Vector2, damage_type: String, normal: Vector2 = Vector2.UP) -> void:
    """Spawn ground crack decal that fades over 2 seconds"""
    if not _can_spawn_fx():
        return
    
    var crack = GROUND_CRACK_SCENE.instantiate()
    crack.global_position = position
    crack.rotation = normal.angle() + randf_range(-0.3, 0.3)
    _fx_root.add_child(crack)
    
    var color = _get_damage_type_color(damage_type)
    color.a = 0.7
    
    if crack.has_method("setup"):
        crack.setup(color, 2.0)  # 2 second fade time

# ============================================
# DEATH EFFECTS
# ============================================

func spawn_death_effect(enemy: Node2D, enemy_color: Color, corpse_texture: Texture2D = null) -> void:
    """Enhanced death sequence with flash, scale, particles, corpse"""
    if enemy == null or not is_instance_valid(enemy):
        return
    
    var position = enemy.global_position
    
    # 1. White flash (instant)
    spawn_flash(position, Color.WHITE, 0.1, 1.5)
    
    # 2. Particle explosion matching enemy color
    spawn_death_burst(position, enemy_color, 6)

    # 3. Leave fading corpse for 1s
    if corpse_texture != null:
        spawn_corpse_fade(position, corpse_texture, enemy_color, enemy.scale, enemy.rotation)

    # 4. Blood/gore particles
    spawn_gore_particles(position, enemy_color)

func spawn_death_burst(position: Vector2, base_color: Color, particle_count: int) -> void:
    """Explosion of particles in all directions"""
    if not _can_spawn_fx() or not _game:
        return
    
    for i in range(particle_count):
        var angle = (TAU / particle_count) * i + randf_range(-0.3, 0.3)
        var speed = randf_range(60.0, 150.0)
        var velocity = Vector2.RIGHT.rotated(angle) * speed
        
        var color = base_color.lerp(Color.WHITE, randf_range(0.0, 0.5))
        var size = randf_range(4.0, 10.0)
        var lifetime = randf_range(0.4, 0.8)
        
        if _game.has_method("spawn_glow_particle"):
            _game.spawn_glow_particle(position, color, size, lifetime, velocity, 1.8, 0.6, 0.9, 2)

func spawn_corpse_fade(position: Vector2, texture: Texture2D, color: Color, scale: Vector2, rotation: float) -> void:
    """Create a fading corpse that stays for 1 second"""
    if not _can_spawn_fx():
        return
    
    var corpse = CORPSE_FADE_SCENE.instantiate()
    corpse.global_position = position
    corpse.rotation = rotation
    _fx_root.add_child(corpse)
    
    if corpse.has_method("setup"):
        corpse.setup(texture, color, scale, 1.0)  # 1 second fade

func spawn_gore_particles(position: Vector2, enemy_color: Color) -> void:
    """Blood and gore particle spray"""
    if not _can_spawn_fx() or not _game:
        return
    
    var gore_color = enemy_color.darkened(0.3)
    gore_color = gore_color.lerp(Color(0.4, 0.05, 0.05), 0.5)  # Blood tint
    
    for i in range(3):
        var angle = randf() * TAU
        var speed = randf_range(40.0, 100.0)
        var velocity = Vector2.RIGHT.rotated(angle) * speed
        velocity.y -= randf_range(20.0, 50.0)  # Arc up slightly

        var size = randf_range(3.0, 7.0)
        var lifetime = randf_range(0.4, 0.7)

        if _game.has_method("spawn_glow_particle"):
            _game.spawn_glow_particle(position, gore_color, size, lifetime, velocity, 1.2, 0.8, 0.7, 1)

func spawn_flash(position: Vector2, color: Color, duration: float, max_size: float) -> void:
    """Bright flash effect that expands and fades"""
    if not _can_spawn_fx():
        return
    if not is_inside_tree():
        return
    
    var flash = Sprite2D.new()
    flash.texture = _create_flash_texture()
    flash.global_position = position
    flash.modulate = color
    flash.z_index = 10
    _fx_root.add_child(flash)
    
    flash.scale = Vector2.ZERO
    if not flash.is_inside_tree():
        flash.queue_free()
        return
    var tween = flash.create_tween()
    tween.tween_property(flash, "scale", Vector2.ONE * max_size, duration * 0.3)
    tween.parallel().tween_property(flash, "modulate:a", 0.0, duration)
    tween.tween_callback(flash.queue_free)

# ============================================
# ENVIRONMENTAL PARTICLES
# ============================================

func spawn_environmental_particles(zone_type: String = "grass") -> void:
    """Spawn zone-appropriate ambient particles"""
    if _fx_root == null:
        return
    
    match zone_type:
        "grass":
            _spawn_fireflies()
        "wasteland":
            _spawn_embers()
        _:
            _spawn_dust_motes()

func _spawn_fireflies() -> void:
    """Floating fireflies in grass zones"""
    var dust_system = ENVIRONMENTAL_DUST_SCENE.instantiate()
    _fx_root.add_child(dust_system)
    
    if dust_system.has_method("setup_fireflies"):
        dust_system.setup_fireflies()

func _spawn_embers() -> void:
    """Floating embers in wasteland zones"""
    var dust_system = ENVIRONMENTAL_DUST_SCENE.instantiate()
    _fx_root.add_child(dust_system)
    
    if dust_system.has_method("setup_embers"):
        dust_system.setup_embers()

func _spawn_dust_motes() -> void:
    """Dust particles floating in light"""
    var dust_system = ENVIRONMENTAL_DUST_SCENE.instantiate()
    _fx_root.add_child(dust_system)
    
    if dust_system.has_method("setup_dust"):
        dust_system.setup_dust()

func spawn_generator_smoke(generator_position: Vector2) -> void:
    """Smoke trail from resource generator"""
    if _fx_root == null or not _game:
        return
    
    var smoke_color = Color(0.4, 0.4, 0.4, 0.6)
    var velocity = Vector2(0, -30.0)  # Float up
    
    if _game.has_method("spawn_glow_particle"):
        _game.spawn_glow_particle(
            generator_position + Vector2(randf_range(-8, 8), -10),
            smoke_color,
            randf_range(8.0, 14.0),
            randf_range(1.5, 2.5),
            velocity + Vector2(randf_range(-5, 5), 0),
            1.0, 0.3, 0.5, -1
        )

# ============================================
# ABILITY FX
# ============================================

func spawn_tesla_lightning(from_pos: Vector2, to_positions: Array[Vector2], color: Color = COLOR_LIGHTNING) -> void:
    """Arcing lightning beams between tower and targets"""
    if not _can_spawn_fx():
        return
    
    var beam = LIGHTNING_BEAM_SCENE.instantiate()
    beam.global_position = from_pos
    _fx_root.add_child(beam)
    
    if beam.has_method("setup"):
        beam.setup(from_pos, to_positions, color)

func spawn_cannon_shockwave(position: Vector2, radius: float, damage_type: String = "fire") -> void:
    """Expanding shockwave ring for cannon explosions"""
    if not _can_spawn_fx():
        return
    
    var shockwave = _get_pooled_shockwave()
    if shockwave == null:
        shockwave = SHOCKWAVE_RING_SCENE.instantiate()
    
    shockwave.global_position = position
    _fx_root.add_child(shockwave)
    
    var color = _get_damage_type_color(damage_type)
    
    if shockwave.has_method("setup"):
        shockwave.setup(radius, color, 0.4)

func spawn_multishot_indicator(position: Vector2, direction: Vector2, spread_angles: Array[float]) -> void:
    """Visual fan pattern showing multishot spread"""
    if not _can_spawn_fx():
        return
    
    var indicator = MULTISHOT_INDICATOR_SCENE.instantiate()
    indicator.global_position = position
    indicator.rotation = direction.angle()
    _fx_root.add_child(indicator)
    
    if indicator.has_method("setup"):
        indicator.setup(spread_angles)

func _get_pooled_shockwave() -> Node2D:
    for sw in _shockwave_pool:
        if sw != null and not sw.visible:
            return sw
    return null

# ============================================
# UTILITY
# ============================================

func _get_damage_type_color(damage_type: String) -> Color:
    match damage_type:
        "fire":
            return COLOR_FIRE
        "ice":
            return COLOR_ICE
        "lightning":
            return COLOR_LIGHTNING
        "crit":
            return COLOR_CRIT
        _:
            return COLOR_NORMAL

var _cached_flash_texture: Texture2D = null

func _create_flash_texture() -> Texture2D:
    if _cached_flash_texture == null:
        var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
        img.fill(Color.WHITE)
        _cached_flash_texture = ImageTexture.create_from_image(img)
    return _cached_flash_texture

func return_to_pool(node: Node2D, pool_type: String) -> void:
    """Return a pooled object to its pool for reuse"""
    node.visible = false
    
    match pool_type:
        "trail":
            if not _trail_pool.has(node):
                _trail_pool.append(node)
                if _trail_pool.size() > MAX_POOL_SIZE:
                    _trail_pool.pop_front().queue_free()
        "spark":
            if not _spark_pool.has(node):
                _spark_pool.append(node)
                if _spark_pool.size() > MAX_POOL_SIZE:
                    _spark_pool.pop_front().queue_free()
        "shockwave":
            if not _shockwave_pool.has(node):
                _shockwave_pool.append(node)
                if _shockwave_pool.size() > MAX_POOL_SIZE:
                    _shockwave_pool.pop_front().queue_free()
