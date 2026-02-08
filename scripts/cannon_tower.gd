extends Tower

var cluster_bombs = false
var burn_effect = false
var burn_damage = 5.0
var burn_duration = 3.0

# Cannon tower specific visuals
var _steam_vents: Array[CPUParticles2D] = []
var _reinforced_barrel: Sprite2D = null
var _multi_barrels: Array[Sprite2D] = []
var _rune_glows: Array[Sprite2D] = []
var _smoke_trails: CPUParticles2D = null
var _barrel_rotation: float = 0.0

func _ready() -> void:
    tower_type = "cannon"
    super._ready()

func _setup_tower_specific_visuals() -> void:
    # Create reinforced barrel overlay for T2 (initially hidden)
    _reinforced_barrel = Sprite2D.new()
    _reinforced_barrel.name = "ReinforcedBarrel"
    _reinforced_barrel.z_index = 1
    _reinforced_barrel.modulate = Color(0.8, 0.3, 0.2, 0.0)  # Red-tinted metal, hidden
    
    # Create barrel texture - darker, heavier look
    if body_sprite != null and body_sprite.sprite_frames != null:
        _reinforced_barrel.texture = body_sprite.sprite_frames.get_frame_texture("default", 0)
    
    add_child(_reinforced_barrel)
    
    # Create steam vents for T2 (initially hidden)
    for i in range(2):
        var vent = CPUParticles2D.new()
        vent.name = "SteamVent%d" % i
        vent.z_index = 2
        vent.position = Vector2(-6 + i * 12, -8)
        vent.amount = 8
        vent.lifetime = 0.8
        vent.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
        vent.gravity = Vector2(0, -30)
        vent.initial_velocity_min = 5.0
        vent.initial_velocity_max = 15.0
        vent.scale_amount_min = 0.5
        vent.scale_amount_max = 1.5
        vent.color = Color(0.9, 0.9, 0.95, 0.0)  # Steam color, hidden
        vent.emitting = false
        add_child(vent)
        _steam_vents.append(vent)
    
    # Create multi-barrel assembly for T3 (initially hidden)
    for i in range(3):
        var barrel = Sprite2D.new()
        barrel.name = "MultiBarrel%d" % i
        barrel.z_index = 3
        barrel.modulate = Color(0.6, 0.2, 0.2, 0.0)  # Dark red, hidden
        
        # Create smaller barrel texture
        var barrel_img = Image.create(16, 24, false, Image.FORMAT_RGBA8)
        barrel_img.fill(Color(0, 0, 0, 0))
        # Draw cylindrical barrel
        for x in range(16):
            for y in range(24):
                var dx = abs(x - 8)
                if dx < 5 and y > 2 and y < 22:
                    var shade = 0.3 + 0.2 * sin(y * 0.3)
                    barrel_img.set_pixel(x, y, Color(shade + 0.3, shade, shade, 1.0))
                # Barrel rim
                if y >= 20 and dx < 6:
                    barrel_img.set_pixel(x, y, Color(0.2, 0.1, 0.1, 1.0))
        var barrel_tex = ImageTexture.create_from_image(barrel_img)
        barrel.texture = barrel_tex
        
        add_child(barrel)
        _multi_barrels.append(barrel)
    
    # Create glowing runes for T3 (initially hidden)
    for i in range(4):
        var rune = Sprite2D.new()
        rune.name = "RuneGlow%d" % i
        rune.z_index = 4
        rune.modulate = Color(1.0, 0.3, 0.1, 0.0)  # Orange-red glow
        
        # Create rune symbol texture
        var rune_img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
        rune_img.fill(Color(0, 0, 0, 0))
        # Draw simple rune pattern
        var patterns = [
            [" XX ", "X  X", " XX ", "X  X"],  # Rune 1
            ["XXXX", "  X ", " X  ", "XXXX"],  # Rune 2
            ["X  X", "X  X", "XXXX", "X  X"],  # Rune 3
            ["XXXX", "X   ", "XXXX", "   X"],  # Rune 4
        ]
        var pattern = patterns[i % patterns.size()]
        for y in range(4):
            for x in range(4):
                if pattern[y][x] == "X":
                    rune_img.set_pixel(x * 3 + 1, y * 3 + 1, Color(1.0, 0.5, 0.2, 1.0))
                    rune_img.set_pixel(x * 3 + 2, y * 3 + 1, Color(1.0, 0.5, 0.2, 1.0))
                    rune_img.set_pixel(x * 3 + 1, y * 3 + 2, Color(1.0, 0.5, 0.2, 1.0))
                    rune_img.set_pixel(x * 3 + 2, y * 3 + 2, Color(1.0, 0.5, 0.2, 1.0))
        var rune_tex = ImageTexture.create_from_image(rune_img)
        rune.texture = rune_tex
        
        var rune_material = CanvasItemMaterial.new()
        rune_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        rune.material = rune_material
        
        # Position runes around the base
        var angle = (i / 4.0) * TAU
        rune.position = Vector2(cos(angle) * 12, sin(angle) * 8 + 5)
        
        add_child(rune)
        _rune_glows.append(rune)
    
    # Create smoke trails for T3
    _smoke_trails = CPUParticles2D.new()
    _smoke_trails.name = "SmokeTrails"
    _smoke_trails.z_index = -1
    _smoke_trails.amount = 20
    _smoke_trails.lifetime = 2.0
    _smoke_trails.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    _smoke_trails.emission_sphere_radius = 10.0
    _smoke_trails.gravity = Vector2(0, -10)
    _smoke_trails.initial_velocity_min = 5.0
    _smoke_trails.initial_velocity_max = 20.0
    _smoke_trails.scale_amount_min = 1.0
    _smoke_trails.scale_amount_max = 3.0
    _smoke_trails.color = Color(0.3, 0.3, 0.3, 0.0)  # Dark smoke, hidden
    _smoke_trails.emitting = false
    add_child(_smoke_trails)

func _animate_floating_elements(delta: float) -> void:
    if upgrade_level < 3:
        return
    
    # Rotate the multi-barrel assembly
    _barrel_rotation += delta * 1.5  # Rotation speed
    
    for i in range(_multi_barrels.size()):
        var barrel = _multi_barrels[i]
        if barrel == null:
            continue
        
        # Arrange barrels in a triangle formation that rotates
        var base_angle = _barrel_rotation + (i * TAU / 3.0)
        var radius = 8.0
        barrel.position = Vector2(cos(base_angle) * radius, sin(base_angle) * radius - 5)
        barrel.rotation = base_angle + PI / 2
    
    # Pulse the runes
    for i in range(_rune_glows.size()):
        var rune = _rune_glows[i]
        if rune == null:
            continue
        var pulse = 0.7 + sin(Time.get_time_dict_from_system()["second"] * 4.0 + i) * 0.3
        rune.modulate = Color(1.0, 0.3, 0.1, 0.8 * pulse)
    
    # Enable smoke trails
    if _smoke_trails != null:
        _smoke_trails.emitting = true
        _smoke_trails.modulate = Color(0.3, 0.3, 0.3, 0.4)

func _update_tower_specific_visuals() -> void:
    # T2: Show reinforced barrel and steam vents
    if _reinforced_barrel != null:
        var tween = create_tween()
        if upgrade_level >= 2:
            tween.tween_property(_reinforced_barrel, "modulate", Color(0.8, 0.3, 0.2, 0.85), 0.3)
        else:
            tween.tween_property(_reinforced_barrel, "modulate", Color(0.8, 0.3, 0.2, 0.0), 0.3)
    
    for vent in _steam_vents:
        if vent != null:
            if upgrade_level >= 2:
                vent.emitting = true
                vent.modulate = Color(0.9, 0.9, 0.95, 0.6)
            else:
                vent.emitting = false
                vent.modulate = Color(0.9, 0.9, 0.95, 0.0)
    
    # T3: Show multi-barrels, runes, and smoke
    if upgrade_level >= 3:
        for barrel in _multi_barrels:
            if barrel != null:
                var barrel_tween = create_tween()
                barrel_tween.tween_property(barrel, "modulate", Color(0.6, 0.2, 0.2, 0.9), 0.4)
        
        for rune in _rune_glows:
            if rune != null:
                var rune_tween = create_tween()
                rune_tween.tween_property(rune, "modulate", Color(1.0, 0.3, 0.1, 0.8), 0.5)
        
        if _smoke_trails != null:
            _smoke_trails.emitting = true
            _smoke_trails.modulate = Color(0.3, 0.3, 0.3, 0.4)
    else:
        for barrel in _multi_barrels:
            if barrel != null:
                barrel.modulate = Color(0.6, 0.2, 0.2, 0.0)
        for rune in _rune_glows:
            if rune != null:
                rune.modulate = Color(1.0, 0.3, 0.1, 0.0)
        if _smoke_trails != null:
            _smoke_trails.emitting = false
            _smoke_trails.modulate = Color(0.3, 0.3, 0.3, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
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
    
    elif upgrade_level == 3:
        # Multi-barrels spin in
        for i in range(_multi_barrels.size()):
            var barrel = _multi_barrels[i]
            if barrel != null:
                barrel.modulate = Color(2.0, 0.5, 0.3, 0.0)
                var tween = create_tween()
                tween.tween_property(barrel, "modulate", Color(0.6, 0.2, 0.2, 0.9), 0.5)
        
        # Runes ignite
        for rune in _rune_glows:
            if rune != null:
                rune.modulate = Color(3.0, 1.0, 0.2, 0.0)
                var rune_tween = create_tween()
                rune_tween.tween_property(rune, "modulate", Color(1.0, 0.3, 0.1, 0.8), 0.6)

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    cluster_bombs = bool(tier_data.get("cluster_bombs", false))
    burn_effect = bool(tier_data.get("burn_effect", false))

func _fire_at(target: Node) -> void:
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
    
    # Spawn main cannonball with cluster and burn capability
    var projectile = _game.spawn_cannonball(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, cluster_bombs, burn_effect)
    
    # Spawn shockwave effect at cannon position
    if _game != null and _game.fx_manager != null:
        _game.fx_manager.spawn_cannon_shockwave(global_position, explosion_radius * 0.5, "fire" if burn_effect else "normal")
    
    # If cluster bombs enabled (T3), the projectile will handle secondary explosions
    # Burn effect is also handled by the projectile
    
    # Puff steam when firing (if T2+)
    if upgrade_level >= 2:
        for vent in _steam_vents:
            if vent != null and vent.emitting:
                vent.amount = 12  # Burst of steam
                await get_tree().create_timer(0.1).timeout
                if is_instance_valid(vent):
                    vent.amount = 8  # Back to normal
