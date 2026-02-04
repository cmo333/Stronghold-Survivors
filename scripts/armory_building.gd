extends Building

var damage_bonus := 2.0

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    damage_bonus = float(tier_data.get("damage_bonus", damage_bonus))
    _register_effect()

func _register_effect() -> void:
    var game := get_tree().get_first_node_in_group("game")
    if game != null and game.has_method("register_building_effect"):
        game.register_building_effect("armory_damage", get_instance_id(), damage_bonus)

func _exit_tree() -> void:
    var game := get_tree().get_first_node_in_group("game")
    if game != null and game.has_method("unregister_building_effect"):
        game.unregister_building_effect("armory_damage", get_instance_id())
