extends "res://scripts/building.gd"

var heal_amount = 4.0
var heal_radius = 140.0
var interval = 4.0
var _timer = 0.0
var _game: Node = null

func _ready() -> void:
    super._ready()
    _game = get_tree().get_first_node_in_group("game")

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    heal_amount = float(tier_data.get("heal_amount", heal_amount))
    heal_radius = float(tier_data.get("heal_radius", heal_radius))
    interval = float(tier_data.get("interval", interval))

func _process(delta: float) -> void:
    _timer += delta
    if _timer < interval:
        return
    _timer = 0.0
    _pulse_heal()

func _pulse_heal() -> void:
    if _game == null:
        return
    var radius_sq = heal_radius * heal_radius
    var player = _game.player
    if player != null and player.has_method("heal"):
        if global_position.distance_squared_to(player.global_position) <= radius_sq:
            player.heal(heal_amount)
    for building in get_tree().get_nodes_in_group("buildings"):
        if building == null:
            continue
        if global_position.distance_squared_to(building.global_position) <= radius_sq:
            if building.has_method("heal"):
                building.heal(heal_amount)
    if _game.has_method("spawn_fx"):
        _game.spawn_fx("ice", global_position)
