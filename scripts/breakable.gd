extends Area2D

var value := 6
var xp := 2
var _game: Node = null

func setup(game_ref: Node, amount: int, xp_amount: int) -> void:
    _game = game_ref
    value = amount
    xp = xp_amount

func _ready() -> void:
    collision_layer = 0
    collision_mask = GameLayers.PLAYER
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.is_in_group("player"):
        if _game != null:
            _game.add_resources(value)
            _game.add_xp(xp)
        queue_free()
