extends Node2D
class_name MultishotIndicator

# Visual fan pattern showing multishot spread angles
# Fades out quickly after showing the pattern

var _spread_angles: Array[float] = []
var _lifetime: float = 0.25
var _elapsed: float = 0.0
var _base_color: Color = Color(0.9, 0.7, 0.3, 0.6)

func setup(spread_angles: Array[float], indicator_color: Color = Color(0.9, 0.7, 0.3, 0.6), lifetime: float = 0.25) -> void:
    _spread_angles = spread_angles
    _base_color = indicator_color
    _lifetime = lifetime
    
    z_index = 5
    
    # Create visual elements
    _create_fan_pattern()

func _create_fan_pattern() -> void:
    # Create lines showing each shot direction
    for angle in _spread_angles:
        var line = Line2D.new()
        line.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(angle) * 40.0])
        line.default_color = _base_color
        line.width = 2.0
        line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        add_child(line)
        
        # Fade out animation
        if not is_instance_valid(line) or not line.is_inside_tree():
            continue
        var tween = line.create_tween()
        tween.tween_property(line, "modulate:a", 0.0, _lifetime)
    
    # Add arc connecting the outer shots
    if _spread_angles.size() >= 2:
        _create_fan_arc()

func _create_fan_arc() -> void:
    var min_angle = _spread_angles.min()
    var max_angle = _spread_angles.max()
    var arc_segments = 12
    
    var arc_points: PackedVector2Array = []
    var arc_radius = 35.0
    
    for i in range(arc_segments + 1):
        var t = float(i) / arc_segments
        var angle = lerp(min_angle, max_angle, t)
        arc_points.append(Vector2.RIGHT.rotated(angle) * arc_radius)
    
    var arc = Line2D.new()
    arc.points = arc_points
    arc.default_color = Color(_base_color.r, _base_color.g, _base_color.b, _base_color.a * 0.5)
    arc.width = 1.5
    arc.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(arc)
    
    # Fade out
    if not is_instance_valid(arc) or not arc.is_inside_tree():
        return
    var tween = arc.create_tween()
    tween.tween_property(arc, "modulate:a", 0.0, _lifetime)

func _process(delta: float) -> void:
    _elapsed += delta
    
    if _elapsed >= _lifetime:
        queue_free()
