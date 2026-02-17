extends Line2D

# Fading projectile trail using Line2D for ribbon effect
# Trails fade over 0.3s as specified

var _target: Node2D
var _fade_time: float = 0.3
var _max_points: int = 12
var _points_data: Array[Dictionary] = []
var _is_dying: bool = false
var _color: Color = Color.WHITE
var _base_width: float = 3.0

func setup(target: Node2D, color: Color, width: float = 3.0, fade_time: float = 0.3) -> void:
    _target = target
    _color = color
    _base_width = width
    _fade_time = fade_time
    
    # Configure Line2D
    default_color = color
    self.width = width
    width_curve = _create_width_curve()
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    z_index = -1
    
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
    self.width = lerp(self.width, 0.0, delta * 5.0)
    if self.width < 0.1:
        queue_free()
