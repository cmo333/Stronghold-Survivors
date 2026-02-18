extends Node2D

@onready var shape: Polygon2D = $Shape
@onready var icon: Sprite2D = $Icon
@onready var ghost: Sprite2D = $Ghost
var radius: float = 12.0
const TEX_OK = preload("res://assets/ui/ui_build_ok_64x64_v001.png")
const TEX_BLOCKED = preload("res://assets/ui/ui_build_blocked_64x64_v001.png")
const SHAPE_SEGMENTS = 16
const RANGE_COLOR_OK = Color(0.0, 1.0, 1.0, 0.15)
const RANGE_COLOR_BLOCKED = Color(1.0, 0.0, 0.0, 0.10)

var _range_radius: float = 0.0
var _show_range: bool = false
var _range_can_place: bool = true

func _ready() -> void:
    _update_shape()
    if icon != null:
        icon.texture = TEX_OK
        icon.centered = true
        icon.visible = true
        icon.modulate = Color(1.0, 1.0, 1.0, 0.85)
    if ghost != null:
        ghost.texture = null
        ghost.centered = true
        ghost.visible = true
        ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        ghost.modulate = Color(1.0, 1.0, 1.0, 0.7)

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
    icon.modulate = Color(1.0, 1.0, 1.0, 0.85) if can_place else Color(1.0, 0.85, 0.85, 0.9)
    if ghost != null:
        ghost.modulate = Color(1.0, 1.0, 1.0, 0.7) if can_place else Color(1.0, 0.6, 0.6, 0.55)

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
    if not _show_range or _range_radius <= 0.0:
        return
    var color = RANGE_COLOR_OK if _range_can_place else RANGE_COLOR_BLOCKED
    draw_arc(Vector2.ZERO, _range_radius, 0.0, TAU, 64, color, 2.0, true)
