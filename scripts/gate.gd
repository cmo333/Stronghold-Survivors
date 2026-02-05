extends "res://scripts/building.gd"

@export var texture_closed: Texture2D
@export var texture_open: Texture2D

@onready var body: Sprite2D = $Body
var is_open = false

func _ready() -> void:
    super._ready()
    _apply_gate_state()

func toggle() -> void:
    is_open = not is_open
    _apply_gate_state()

func _apply_gate_state() -> void:
    if collider_body != null:
        collider_body.collision_layer = 0 if is_open else GameLayers.BUILDING
    if body != null:
        if is_open and texture_open != null:
            body.texture = texture_open
        elif not is_open and texture_closed != null:
            body.texture = texture_closed

func get_display_name() -> String:
    var base = definition.get("name", "Gate")
    var state = "Open" if is_open else "Closed"
    return "%s (%s)" % [base, state]
