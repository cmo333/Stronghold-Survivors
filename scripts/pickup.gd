extends Area2D

const GOLD_TEX = preload("res://assets/ui/ui_icon_gold_32_v001.png")
const HEAL_TEX = preload("res://assets/ui/ui_icon_crystal_32_v001.png")

var value = 1
var kind = "gold"
var _game: Node = null
var magnet_radius = 120.0
var magnet_speed = 240.0
var _player: Node2D = null
@onready var sprite: Sprite2D = $Body

func setup(game_ref: Node, amount: int, kind_name: String = "gold") -> void:
    _game = game_ref
    value = amount
    kind = kind_name
    _apply_visual()

func _ready() -> void:
    collision_layer = GameLayers.PICKUP
    collision_mask = GameLayers.PLAYER
    body_entered.connect(_on_body_entered)
    _player = get_tree().get_first_node_in_group("player")
    _apply_visual()

func _process(delta: float) -> void:
    if _player == null:
        return
    var dist = global_position.distance_to(_player.global_position)
    if dist <= magnet_radius:
        var dir = (_player.global_position - global_position).normalized()
        global_position += dir * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.is_in_group("player"):
        if _game != null:
            if kind == "heal":
                if _game.has_method("heal_player"):
                    _game.heal_player(value)
            else:
                _game.add_resources(value)
        queue_free()

func _apply_visual() -> void:
    if sprite == null:
        return
    if kind == "heal":
        sprite.texture = HEAL_TEX
    else:
        sprite.texture = GOLD_TEX
