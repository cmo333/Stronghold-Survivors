extends Node2D

@onready var shape: Polygon2D = $Shape
@onready var icon: Sprite2D = $Icon
@onready var ghost: Sprite2D = $Ghost
var radius: float = 12.0
const TEX_OK = preload("res://assets/ui/ui_build_ok_64x64_v001.png")
const TEX_BLOCKED = preload("res://assets/ui/ui_build_blocked_64x64_v001.png")
const SHAPE_SEGMENTS = 16

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
