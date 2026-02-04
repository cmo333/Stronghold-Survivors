extends Node2D

@onready var shape: Polygon2D = $Shape
@onready var icon: Sprite2D = $Icon
var radius: float = 12.0
const TEX_OK := preload("res://assets/ui/ui_build_ok_64x64_v001.png")
const TEX_BLOCKED := preload("res://assets/ui/ui_build_blocked_64x64_v001.png")

func _ready() -> void:
    _update_shape()
    if icon != null:
        icon.texture = TEX_OK

func set_radius(value: float) -> void:
    radius = max(2.0, value)
    _update_shape()

func set_color(color: Color) -> void:
    shape.color = color

func set_state(can_place: bool) -> void:
    if icon == null:
        return
    icon.texture = TEX_OK if can_place else TEX_BLOCKED

func _update_shape() -> void:
    var r := radius
    shape.polygon = PackedVector2Array([
        Vector2(-r, -r),
        Vector2(-r, r),
        Vector2(r, r),
        Vector2(r, -r)
    ])
