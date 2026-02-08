extends Tower

var pierce_count = 1

# Arrow tower specific visuals
var _crystal_core: Sprite2D = null
var _floating_arrows: Array[Sprite2D] = []
var _arrow_orbit_angle: float = 0.0
var _metal_bands: Sprite2D = null

func _ready() -> void:
    tower_type = "arrow"
    super._ready()

func _setup_tower_specific_visuals() -> void:
    # Create metal bands for T2 (initially hidden)
    _metal_bands = Sprite2D.new()
    _metal_bands.name = "MetalBands"
    _metal_bands.z_index = 1
    _metal_bands.modulate = Color(0.6, 0.6, 0.7, 0.0)  # Metallic gray, hidden initially
    
    # Create a simple metal band texture procedurally
    var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    # Draw horizontal metal bands
    for x in range(48):
        for y in range(48):
            # Top band
            if y >= 8 and y <= 12:
                var shade = 0.5 + 0.3 * sin(x * 0.3)
                img.set_pixel(x, y, Color(shade, shade, shade + 0.1, 0.9))
            # Bottom band
            if y >= 36 and y <= 40:
                var shade = 0.5 + 0.3 * sin(x * 0.3 + 1.0)
                img.set_pixel(x, y, Color(shade, shade, shade + 0.1, 0.9))
    var tex = ImageTexture.create_from_image(img)
    _metal_bands.texture = tex
    add_child(_metal_bands)
    
    # Create crystal core for T3 (initially hidden)
    _crystal_core = Sprite2D.new()
    _crystal_core.name = "CrystalCore"
    _crystal_core.z_index = 2
    _crystal_core.modulate = Color(0.2, 0.9, 0.3, 0.0)  # Green glow, hidden initially
    
    # Create crystal texture
    var crystal_img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
    crystal_img.fill(Color(0, 0, 0, 0))
    var center = Vector2(12, 12)
    for x in range(24):
        for y in range(24):
            var dist = Vector2(x, y).distance_to(center)
            if dist < 10:
                var intensity = 1.0 - (dist / 10.0)
                var color = Color(0.2, 0.95, 0.3, intensity * 0.9)
                crystal_img.set_pixel(x, y, color)
    var crystal_tex = ImageTexture.create_from_image(crystal_img)
    _crystal_core.texture = crystal_tex
    
    # Add pulsing glow to crystal
    var crystal_material = CanvasItemMaterial.new()
    crystal_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _crystal_core.material = crystal_material
    add_child(_crystal_core)
    
    # Create floating arrows for T3 (initially hidden)
    for i in range(3):
        var arrow = Sprite2D.new()
        arrow.name = "FloatingArrow%d" % i
        arrow.z_index = 3
        arrow.modulate = Color(0.3, 0.9, 0.4, 0.0)
        
        # Create arrow texture
        var arrow_img = Image.create(12, 16, false, Image.FORMAT_RGBA8)
        arrow_img.fill(Color(0, 0, 0, 0))
        # Draw arrow shape
        for x in range(12):
            for y in range(16):
                # Arrow head
                if y < 6 and abs(x - 6) < (6 - y) * 0.8:
                    arrow_img.set_pixel(x, y, Color(0.9, 0.95, 0.9, 1.0))
                # Arrow shaft
                if y >= 6 and y < 14 and abs(x - 6) < 2:
                    arrow_img.set_pixel(x, y, Color(0.8, 0.9, 0.8, 1.0))
                # Arrow fletching
                if y >= 14 and abs(x - 6) < 4:
                    arrow_img.set_pixel(x, y, Color(0.6, 0.8, 0.6, 0.9))
        var arrow_tex = ImageTexture.create_from_image(arrow_img)
        arrow.texture = arrow_tex
        
        var arrow_material = CanvasItemMaterial.new()
        arrow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        arrow.material = arrow_material
        
        add_child(arrow)
        _floating_arrows.append(arrow)

func _animate_floating_elements(delta: float) -> void:
    if upgrade_level < 3:
        return
    
    # Orbit the floating arrows around the tower
    _arrow_orbit_angle += delta * 2.0  # Rotation speed
    
    for i in range(_floating_arrows.size()):
        var arrow = _floating_arrows[i]
        if arrow == null:
            continue
        
        # Each arrow at different height and radius
        var angle = _arrow_orbit_angle + (i * TAU / 3.0)  # 120 degrees apart
        var radius = 22.0 + i * 3.0
        var height_offset = sin(_arrow_orbit_angle * 1.5 + i) * 3.0
        
        arrow.position = Vector2(cos(angle) * radius, sin(angle) * radius * 0.3 + height_offset - 10)
        arrow.rotation = angle + PI / 2  # Point in direction of orbit
    
    # Pulse the crystal core
    if _crystal_core != null:
        var pulse = 0.8 + sin(Time.get_time_dict_from_system()["second"] * 5.0) * 0.2
        _crystal_core.scale = Vector2.ONE * (0.9 + pulse * 0.2)
        _crystal_core.modulate = Color(0.2, 0.9, 0.3, 0.8 * pulse)

func _update_tower_specific_visuals() -> void:
    # T2: Show metal bands
    if _metal_bands != null:
        var tween = create_tween()
        if upgrade_level >= 2:
            tween.tween_property(_metal_bands, "modulate", Color(0.7, 0.7, 0.8, 0.9), 0.3)
        else:
            tween.tween_property(_metal_bands, "modulate", Color(0.6, 0.6, 0.7, 0.0), 0.3)
    
    # T3: Show crystal core and floating arrows
    if upgrade_level >= 3:
        if _crystal_core != null:
            var crystal_tween = create_tween()
            crystal_tween.tween_property(_crystal_core, "modulate", Color(0.2, 0.9, 0.3, 0.9), 0.5)
        
        for arrow in _floating_arrows:
            if arrow != null:
                var arrow_tween = create_tween()
                arrow_tween.tween_property(arrow, "modulate", Color(0.3, 0.9, 0.4, 0.85), 0.5)
    else:
        if _crystal_core != null:
            _crystal_core.modulate = Color(0.2, 0.9, 0.3, 0.0)
        for arrow in _floating_arrows:
            if arrow != null:
                arrow.modulate = Color(0.3, 0.9, 0.4, 0.0)

func _play_tower_specific_upgrade_effects() -> void:
    if upgrade_level == 2:
        # Metal bands shimmer in
        if _metal_bands != null:
            _metal_bands.modulate = Color(1.5, 1.5, 1.6, 0.0)
            var tween = create_tween()
            tween.tween_property(_metal_bands, "modulate", Color(0.7, 0.7, 0.8, 0.9), 0.4)
    
    elif upgrade_level == 3:
        # Crystal and arrows appear with flash
        if _crystal_core != null:
            _crystal_core.modulate = Color(2.0, 3.0, 2.0, 1.0)
            var tween = create_tween()
            tween.tween_property(_crystal_core, "modulate", Color(0.2, 0.9, 0.3, 0.9), 0.5)
        
        # Arrows spiral in
        for i in range(_floating_arrows.size()):
            var arrow = _floating_arrows[i]
            if arrow != null:
                arrow.modulate = Color(1.0, 1.0, 1.0, 0.0)
                var tween = create_tween()
                tween.tween_property(arrow, "modulate", Color(0.3, 0.9, 0.4, 0.85), 0.6)

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    pierce_count = int(tier_data.get("pierce_count", 1))

func _fire_at(target: Node) -> void:
    if _game == null:
        return
    var dir = (target.global_position - global_position).normalized()
    var dmg_bonus = 0.0
    if _game.has_method("get_tower_damage_bonus"):
        dmg_bonus = _game.get_tower_damage_bonus()
    
    # Get multishot level and angles
    var level = 0
    if _game.has_method("get_tech_level"):
        level = _game.get_tech_level("arrow_fan")
    var extra_angles: Array = []
    if level == 1:
        extra_angles = [-0.2, 0.2]
    elif level == 2:
        extra_angles = [-0.35, -0.15, 0.15, 0.35]
    elif level >= 3:
        extra_angles = [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]
    
    # Spawn multishot indicator if we have spread shots
    if extra_angles.size() > 0 and _game != null and _game.fx_manager != null:
        _game.fx_manager.spawn_multishot_indicator(global_position, dir, extra_angles)
    
    # Spawn main projectile with pierce capability
    _game.spawn_projectile(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, pierce_count)
    
    # Spawn extra projectiles
    for angle in extra_angles:
        _game.spawn_projectile(global_position, dir.rotated(angle), projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius, pierce_count)
