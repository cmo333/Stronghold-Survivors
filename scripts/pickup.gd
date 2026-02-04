extends Area2D

var value := 1
var _game: Node = null
var magnet_radius := 120.0
var magnet_speed := 240.0
var _player: Node2D = null

func setup(game_ref: Node, amount: int) -> void:
    _game = game_ref
    value = amount

func _ready() -> void:
    collision_layer = GameLayers.PICKUP
    collision_mask = GameLayers.PLAYER
    body_entered.connect(_on_body_entered)
    _player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
    if _player == null:
        return
    var dist := global_position.distance_to(_player.global_position)
    if dist <= magnet_radius:
        var dir := (_player.global_position - global_position).normalized()
        global_position += dir * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.is_in_group("player"):
        if _game != null:
            _game.add_resources(value)
        queue_free()
