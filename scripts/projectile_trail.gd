extends Line2D
class_name ProjectileTrail

# Fading projectile trail using Line2D for ribbon effect
# Trails fade over 0.3s as specified

var _target: Node2D
var _fade_time: float = 0.3
var _max_points: int = 12
var _points_data: Array[Dictionary] = []
var _is_dying: bool = false
var _color: Color = Color.WHITE
var _base_width: float = 3.0

func setup(target: Node2D, trail_color: Color, trail_width: float = 3.0, fade_time: float = 0.3) -> void:
    _target = target
    _color = trail_color
    _base_width = trail_width
    _fade_time = fade_time
    
    # Configure Line2D
    default_color = trail_color
    width = trail_width
    width_curve = _create_width_curve()
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = -1
    
    # Gradient for fade effect
    gradient = _create_gradient(trail_color)
    
    # Add initial point
    if target != null and is_instance_valid(target):
        add_point(target.global_position)
        _points_data.append({"pos": target.global_position, "age": 0.0})

func _create_width_curve() -> Curve:
    var curve = Curve.new()
    curve.add_point(Vector2(0, 1.0))
    curve.add_point(Vector2(0.5, 0.7))
    curve.add_point(Vector2(1.0, 0.0))
    return curve

func _create_gradient(base_color: Color) -> Gradient:
    var grad = Gradient.new()
    var start_color = base_color
    start_color.a = 0.9
    var end_color = base_color
    end_color.a = 0.0
    grad.add_point(0.0, start_color)
    grad.add_point(1.0, end_color)
    return grad

func _process(delta: float) -> void:
    if _is_dying:
        _update_fade(delta)
        return
    
    if _target == null or not is_instance_valid(_target):
        _start_fade_out()
        return
    
    # Add new point at target position
    var current_pos = _target.global_position
    
    # Only add point if moved enough
    if points.size() == 0 or current_pos.distance_squared_to(points[points.size() - 1]) > 4.0:
        add_point(current_pos)
        _points_data.append({"pos": current_pos, "age": 0.0})
        
        # Remove oldest point if too many
        if points.size() > _max_points:
            remove_point(0)
            _points_data.pop_front()
    
    # Age all points
    for i in range(_points_data.size()):
        _points_data[i]["age"] += delta
    
    # Remove points that exceed fade time
    while _points_data.size() > 0 and _points_data[0]["age"] > _fade_time:
        remove_point(0)
        _points_data.pop_front()
    
    # Update gradient alpha based on age
    _update_gradient_alpha()

func _update_gradient_alpha() -> void:
    if gradient == null or _points_data.size() < 2:
        return
    
    gradient.offsets = []
    gradient.colors = []
    
    for i in range(_points_data.size()):
        var t = float(i) / max(1, _points_data.size() - 1)
        var age_ratio = _points_data[i]["age"] / _fade_time
        var alpha = clamp(1.0 - age_ratio, 0.0, 1.0) * 0.9
        
        var col = _color
        col.a = alpha
        
        gradient.add_point(t, col)

func _start_fade_out() -> void:
    _is_dying = true
    if not is_inside_tree():
        queue_free()
        return
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.15)
    tween.tween_callback(queue_free)

func _update_fade(delta: float) -> void:
    # Trail is fading out, shrink width
    width = lerp(width, 0.0, delta * 5.0)
    if width < 0.1:
        queue_free()
