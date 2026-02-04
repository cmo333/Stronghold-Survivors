extends Building

@onready var body: Polygon2D = $Body
var is_open := false

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
        if is_open:
            body.color = Color(0.2, 0.7, 0.3, 1.0)
        else:
            body.color = Color(0.4, 0.25, 0.15, 1.0)

func get_display_name() -> String:
    var base := definition.get("name", "Gate")
    var state := "Open" if is_open else "Closed"
    return "%s (%s)" % [base, state]
