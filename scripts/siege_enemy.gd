extends "res://scripts/enemy.gd"

func setup(game_ref: Node, difficulty: float) -> void:
    super.setup(game_ref, difficulty)
    is_siege = true
    max_health *= 2.6
    health = max_health
    speed *= 0.7
    attack_damage *= 1.8
    attack_rate *= 0.75
    attack_range = max(attack_range, 22.0)

func _ready() -> void:
    super._ready()
    is_siege = true

func _find_target() -> Node:
    if _game == null:
        return null
    var best_building: Node = null
    var best_dist := INF
    for building in get_tree().get_nodes_in_group("buildings"):
        if building == null:
            continue
        var dist := global_position.distance_squared_to(building.global_position)
        if dist < best_dist:
            best_building = building
            best_dist = dist
    if best_building != null:
        return best_building
    return _game.player
