extends Area2D

const GOLD_TEX = preload("res://assets/ui/ui_icon_gold_32_v002.png")
const HEAL_TEX = preload("res://assets/ui/ui_icon_crystal_32_v002.png")

var value = 1
var kind = "gold"
var _game: Node = null
var magnet_radius = 120.0
var magnet_speed = 240.0
var _player: Node2D = null
var _pulse_tween: Tween = null
@onready var sprite: Sprite2D = $Body

func setup(game_ref: Node, amount: int, kind_name: String = "gold") -> void:
    _game = game_ref
    value = amount
    kind = kind_name
    _apply_visual()
    _apply_magnet_settings()

func _ready() -> void:
    add_to_group("pickups")
    collision_layer = GameLayers.PICKUP
    collision_mask = GameLayers.PLAYER
    body_entered.connect(_on_body_entered)
    _player = get_tree().get_first_node_in_group("player")
    _apply_visual()
    _apply_magnet_settings()

func _process(delta: float) -> void:
    # Magnet toward the NEAREST player (FFA). In solo this is just the one player.
    var target := _magnet_target()
    if target == null:
        return
    var dist = global_position.distance_to(target.global_position)
    if dist <= magnet_radius:
        var dir = (target.global_position - global_position).normalized()
        global_position += dir * magnet_speed * delta

func _magnet_target() -> Node2D:
    if _game != null and _game.has_method("get_nearest_player"):
        var n = _game.get_nearest_player(global_position)
        if n != null:
            return n
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
    return _player

func _on_body_entered(body: Node) -> void:
    if body == null:
        return
    if body.is_in_group("player"):
        # Credit the collecting player's pool (FFA). owner_id == 0 => local/solo.
        var owner_id := 0
        if "peer_id" in body:
            owner_id = int(body.peer_id)
        # Only the local player's pickups show floating feedback on this screen;
        # a bot/remote player grabbing loot is still credited to THEIR ledger but
        # doesn't spam this machine's HUD with text/heals it doesn't own.
        var is_local := _is_local_player_body(body)
        if _game != null:
            if kind == "heal":
                if _game.has_method("heal_player"):
                    _game.heal_player(value, owner_id)
                if is_local and _game.has_method("show_floating_text"):
                    _game.show_floating_text("+%d HP" % value, global_position + Vector2(0.0, -10.0), Color(0.45, 1.0, 0.55, 1.0))
            elif kind == "essence":
                if _game.has_method("add_essence"):
                    _game.add_essence(value, owner_id)
            else:
                _game.add_resources(value, owner_id)
        queue_free()

# True only for the player this machine controls (so HUD feedback stays local).
func _is_local_player_body(body: Node) -> bool:
    if _game == null or not is_instance_valid(_game):
        return true
    if _game.has_method("is_solo") and _game.is_solo():
        return true
    if "is_bot" in body and bool(body.is_bot):
        return false
    var lp = _game.local_player if "local_player" in _game else null
    if lp != null and is_instance_valid(lp):
        return body == lp
    if "peer_id" in body and _game.has_method("local_player_id"):
        return int(body.peer_id) == int(_game.local_player_id())
    return true

func _apply_visual() -> void:
    if sprite == null:
        return
    if _pulse_tween != null:
        _pulse_tween.kill()
        _pulse_tween = null
    sprite.scale = Vector2.ONE
    sprite.modulate = Color.WHITE
    if kind == "heal":
        sprite.texture = HEAL_TEX
        sprite.modulate = Color(0.45, 1.0, 0.58, 0.98)
        sprite.scale = Vector2.ONE * 1.16
        if not is_inside_tree():
            return
        if not sprite.is_inside_tree():
            return
        _pulse_tween = create_tween()
        _pulse_tween.set_loops()
        _pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.28, 0.32).set_trans(Tween.TRANS_SINE)
        _pulse_tween.parallel().tween_property(sprite, "modulate:a", 0.78, 0.32).set_trans(Tween.TRANS_SINE)
        _pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.16, 0.32).set_trans(Tween.TRANS_SINE)
        _pulse_tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
    elif kind == "essence":
        sprite.texture = HEAL_TEX
        sprite.modulate = Color(0.7, 0.3, 1.0, 1.0)
        sprite.scale = Vector2.ONE * 1.08
        if not is_inside_tree():
            return
        if not sprite.is_inside_tree():
            return
        _pulse_tween = create_tween()
        _pulse_tween.set_loops()
        _pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.18, 0.4).set_trans(Tween.TRANS_SINE)
        _pulse_tween.parallel().tween_property(sprite, "modulate:a", 0.62, 0.4).set_trans(Tween.TRANS_SINE)
        _pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.08, 0.4).set_trans(Tween.TRANS_SINE)
        _pulse_tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
    else:
        sprite.texture = GOLD_TEX
        sprite.modulate = Color(1.0, 0.95, 0.7, 1.0)
        sprite.scale = Vector2.ONE * 1.15
        if not is_inside_tree():
            return
        if not sprite.is_inside_tree():
            return
        _pulse_tween = create_tween()
        _pulse_tween.set_loops()
        _pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.3, 0.5).set_trans(Tween.TRANS_SINE)
        _pulse_tween.parallel().tween_property(sprite, "modulate:a", 0.8, 0.5).set_trans(Tween.TRANS_SINE)
        _pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.15, 0.5).set_trans(Tween.TRANS_SINE)
        _pulse_tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

func _apply_magnet_settings() -> void:
    var base_radius = 120.0
    var base_speed = 240.0
    if kind == "gold":
        base_radius = 150.0
        base_speed = 260.0
    elif kind == "essence":
        base_radius = 135.0
        base_speed = 250.0
    if _game != null and _game.has_method("get_pickup_range_mult"):
        base_radius *= float(_game.get_pickup_range_mult())
    magnet_radius = base_radius
    magnet_speed = base_speed
