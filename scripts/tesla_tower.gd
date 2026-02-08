extends Tower

var chain_count = 3
var _line: Line2D = null

func _ready() -> void:
    super._ready()
    _setup_lightning_line()

func _setup_lightning_line() -> void:
    _line = Line2D.new()
    _line.width = 2.0
    _line.default_color = Color(0.3, 0.8, 1.0, 0.9)
    _line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _line.z_index = 10
    add_child(_line)

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    chain_count = int(tier_data.get("chain_count", chain_count))

func _fire_at(target: Node) -> void:
    var enemies = get_tree().get_nodes_in_group("enemies")
    enemies.sort_custom(func(a, b):
        return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
    )
    var dmg_bonus = 0.0
    if _game != null and _game.has_method("get_tower_damage_bonus"):
        dmg_bonus = _game.get_tower_damage_bonus()
    var emp_level = 0
    if _game != null and _game.has_method("get_tech_level"):
        emp_level = _game.get_tech_level("tesla_emp")
    
    var hits = 0
    var last_pos = global_position
    var line_points: PackedVector2Array = [Vector2.ZERO]  # Start at tower center
    
    for enemy in enemies:
        if enemy == null or not is_instance_valid(enemy):
            continue
        if global_position.distance_squared_to(enemy.global_position) > range * range:
            continue
        
        # Visual lightning arc to this enemy
        var arc_points = _generate_arc(last_pos, enemy.global_position, 3)
        for pt in arc_points:
            line_points.append(pt - global_position)
        
        if enemy.has_method("take_damage"):
            enemy.take_damage(damage + dmg_bonus, enemy.global_position, false, true)
        
        if _game != null and _game.has_method("spawn_fx"):
            _game.spawn_fx("tesla", enemy.global_position)
            if hits > 0:
                _game.spawn_fx("chain_hit", enemy.global_position)
        
        if emp_level > 0 and enemy.has_method("apply_slow"):
            var slow_factor = max(0.45, 0.8 - emp_level * 0.12)
            var slow_duration = 0.6 + 0.2 * emp_level
            enemy.apply_slow(get_instance_id(), slow_factor, slow_duration)
        
        if emp_level > 0 and enemy.has_method("stun"):
            enemy.stun(0.08 * emp_level)
        
        last_pos = enemy.global_position
        hits += 1
        if hits >= chain_count:
            break
    
    # Show lightning line
    _line.points = line_points
    _line.visible = true
    
    # Flash effect
    var tween = create_tween()
    tween.tween_property(_line, "modulate:a", 0.0, 0.1)
    tween.tween_callback(func(): _line.visible = false)
    tween.tween_property(_line, "modulate:a", 0.9, 0.0)

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
