extends Line2D

# Ground crack decal that fades over time
# Creates a jagged crack pattern on impact

var _fade_duration: float = 2.0
var _elapsed: float = 0.0
var _base_color: Color = Color.WHITE

func setup(color: Color, fade_time: float = 2.0) -> void:
    _base_color = color
    _fade_duration = fade_time
    
    # Configure Line2D
    default_color = color
    width = 2.0
    width_curve = _create_width_curve()
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = -5  # Below entities
    
    # Generate crack pattern
    _generate_crack_pattern()
    
    # Setup fade
    modulate.a = 0.7

func _create_width_curve() -> Curve:
    var curve = Curve.new()
    curve.add_point(Vector2(0, 0.3))
    curve.add_point(Vector2(0.3, 1.0))
    curve.add_point(Vector2(0.7, 0.8))
    curve.add_point(Vector2(1.0, 0.2))
    return curve

func _generate_crack_pattern() -> void:
    # Generate main crack line with jagged branches
    var main_length = randf_range(20.0, 40.0)
    var segments = 8
    
    clear_points()
    
    # Main crack
    var current_pos = Vector2.ZERO
    add_point(current_pos)
    
    for i in range(segments):
        var progress = float(i + 1) / segments
        var base_pos = Vector2.RIGHT * main_length * progress
        
        # Add jaggedness
        var jitter = (1.0 - progress) * 8.0
        base_pos += Vector2(randf_range(-jitter, jitter), randf_range(-jitter * 0.5, jitter * 0.5))
        
        add_point(base_pos)
        
        # Chance for branch
        if randf() < 0.3 and i > 1:
            _add_branch(base_pos, progress)
    
    # Center the crack
    var bounds = get_bounds()
    var offset = -bounds.get_center()
    for i in range(points.size()):
        set_point_position(i, points[i] + offset)

func _add_branch(from_pos: Vector2, parent_progress: float) -> void:
    # This creates a simple branch - in a full implementation we'd add child Line2Ds
    # For now, we just add a point that looks like a branch
    var branch_angle = randf_range(-PI * 0.6, PI * 0.6)
    var branch_length = randf_range(5.0, 12.0) * (1.0 - parent_progress)
    
    var branch_end = from_pos + Vector2.RIGHT.rotated(branch_angle) * branch_length
    
    # Add branch as additional points (simplified)
    var branch_point = from_pos.lerp(branch_end, 0.5)
    add_point(branch_point)
    add_point(branch_end)

func get_bounds() -> Rect2:
    if points.size() == 0:
        return Rect2()
    
    var min_x = points[0].x
    var max_x = points[0].x
    var min_y = points[0].y
    var max_y = points[0].y
    
    for p in points:
        min_x = min(min_x, p.x)
        max_x = max(max_x, p.x)
        min_y = min(min_y, p.y)
        max_y = max(max_y, p.y)
    
    return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _process(delta: float) -> void:
    _elapsed += delta
    
    var fade_ratio = _elapsed / _fade_duration
    modulate.a = clamp(0.7 * (1.0 - fade_ratio), 0.0, 0.7)
    
    # Slightly expand the crack as it fades
    width = lerp(2.0, 3.0, fade_ratio)
    
    if _elapsed >= _fade_duration:
        queue_free()
