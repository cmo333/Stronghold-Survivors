extends Area2D

const TEX_SMALL = preload("res://assets/level1/level1_props/prop_graveyard_tombstone_small_32_v001.png")
const TEX_LARGE = preload("res://assets/level1/level1_props/prop_graveyard_tombstone_large_48_v001.png")
const TEX_SKULL = preload("res://assets/level1/level1_props/prop_graveyard_skull_pile_32_v001.png")
const TEX_PILLAR = preload("res://assets/level1/level1_props/prop_graveyard_broken_pillar_48_v001.png")
const TEX_FENCE = preload("res://assets/level1/level1_props/prop_graveyard_broken_fence_32_v001.png")

var value = 6
var xp = 2
var style = "small"
var is_chest = false
var _game: Node = null
@onready var sprite: Sprite2D = $Body

func setup(game_ref: Node, amount: int, xp_amount: int, style_name: String = "small", chest: bool = false) -> void:
    _game = game_ref
    value = amount
    xp = xp_amount
    style = style_name
    is_chest = chest
    _apply_style()

func _ready() -> void:
    collision_layer = 0
    collision_mask = GameLayers.PLAYER
    body_entered.connect(_on_body_entered)
    _apply_style()

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.is_in_group("player"):
        if _game != null:
            _game.add_resources(value)
            _game.add_xp(xp)
            var heal_chance = 0.12
            if is_chest:
                heal_chance = 0.4
            if _game.has_method("spawn_pickup") and randf() < heal_chance:
                _game.spawn_pickup(global_position, 14 if is_chest else 12, "heal")
        queue_free()

func _apply_style() -> void:
    if sprite == null:
        return
    var tex: Texture2D = TEX_SMALL
    match style:
        "large":
            tex = TEX_LARGE
        "skull":
            tex = TEX_SKULL
        "pillar":
            tex = TEX_PILLAR
        "fence":
            tex = TEX_FENCE
        _:
            tex = TEX_SMALL
    if is_chest and tex == TEX_SMALL:
        tex = TEX_LARGE
    sprite.texture = tex
