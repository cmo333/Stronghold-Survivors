extends Node2D

@onready var shape: Polygon2D = $Shape
@onready var icon: Sprite2D = $Icon
@onready var ghost: Sprite2D = $Ghost
var radius: float = 12.0
const TEX_OK = preload("res://assets/ui/ui_build_ok_64x64_v001.png")
const TEX_BLOCKED = preload("res://assets/ui/ui_build_blocked_64x64_v001.png")
const SHAPE_SEGMENTS = 16
const RANGE_COLOR_OK = Color(0.2, 1.0, 1.0, 0.42)
const RANGE_COLOR_BLOCKED = Color(1.0, 0.22, 0.22, 0.38)
const FOCUS_FILL_COLOR_OK = Color(0.02, 0.16, 0.18, 0.38)
const FOCUS_FILL_COLOR_BLOCKED = Color(0.24, 0.04, 0.04, 0.34)
const FOCUS_RING_COLOR_OK = Color(0.18, 1.0, 0.98, 0.9)
const FOCUS_RING_COLOR_BLOCKED = Color(1.0, 0.3, 0.3, 0.92)
const FOCUS_RADIUS_MULT = 2.9

var _range_radius: float = 0.0
var _show_range: bool = false
var _range_can_place: bool = true

func _ready() -> void:
    z_as_relative = false
    z_index = 240
    _update_shape()
    if icon != null:
        icon.texture = TEX_OK
        icon.centered = true
        icon.visible = true
        icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
        icon.scale = Vector2.ONE * 1.24
    if ghost != null:
        ghost.texture = null
        ghost.centered = true
        ghost.visible = true
        ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        ghost.modulate = Color(1.0, 1.0, 1.0, 0.98)
        ghost.scale = Vector2.ONE * 1.12

func set_radius(value: float) -> void:
    radius = max(2.0, value)
    _update_shape()

func set_range_radius(value: float) -> void:
    _range_radius = max(0.0, value)
    _show_range = _range_radius > 0.0
    queue_redraw()

func set_range_state(can_place: bool) -> void:
    _range_can_place = can_place
    queue_redraw()

func set_color(color: Color) -> void:
    shape.color = color

func set_state(can_place: bool) -> void:
    if icon == null:
        return
    icon.texture = TEX_OK if can_place else TEX_BLOCKED
    icon.modulate = Color(1.0, 1.0, 1.0, 0.95) if can_place else Color(1.0, 0.88, 0.88, 1.0)
    icon.scale = Vector2.ONE * (1.22 if can_place else 1.3)
    if ghost != null:
        ghost.modulate = Color(1.0, 1.0, 1.0, 0.92) if can_place else Color(1.0, 0.64, 0.64, 0.72)

func set_ghost_texture(path: String) -> void:
    if ghost == null:
        return
    if path == "":
        ghost.texture = null
        return
    if ResourceLoader.exists(path):
        ghost.texture = load(path)
    else:
        ghost.texture = null

func _update_shape() -> void:
    var r = radius
    var points = PackedVector2Array()
    var segments = max(8, SHAPE_SEGMENTS)
    for i in range(segments):
        var angle = TAU * float(i) / float(segments)
        points.append(Vector2(cos(angle), sin(angle)) * r)
    shape.polygon = points

func _draw() -> void:
    var focus_radius = radius * FOCUS_RADIUS_MULT
    var can_place = _range_can_place
    draw_circle(
        Vector2.ZERO,
        focus_radius,
        FOCUS_FILL_COLOR_OK if can_place else FOCUS_FILL_COLOR_BLOCKED
    )
    draw_arc(
        Vector2.ZERO,
        focus_radius,
        0.0,
        TAU,
        72,
        FOCUS_RING_COLOR_OK if can_place else FOCUS_RING_COLOR_BLOCKED,
        4.0,
        true
    )
    var cross_col = Color(0.92, 1.0, 1.0, 0.76) if can_place else Color(1.0, 0.82, 0.82, 0.8)
    draw_line(Vector2(-radius, 0), Vector2(radius, 0), cross_col, 3.0, true)
    draw_line(Vector2(0, -radius), Vector2(0, radius), cross_col, 3.0, true)
    draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.74), 3.0, true)
    if not _show_range or _range_radius <= 0.0:
        return
    var color = RANGE_COLOR_OK if _range_can_place else RANGE_COLOR_BLOCKED
    draw_arc(Vector2.ZERO, _range_radius, 0.0, TAU, 64, color, 4.0, true)
