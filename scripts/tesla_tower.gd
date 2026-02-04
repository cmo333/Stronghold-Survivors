extends Tower

var chain_count := 3

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    chain_count = int(tier_data.get("chain_count", chain_count))

func _fire_at(target: Node) -> void:
    var enemies := get_tree().get_nodes_in_group("enemies")
    enemies.sort_custom(func(a, b):
        return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
    )
    var emp_level := 0
    if _game != null and _game.has_method("get_tech_level"):
        emp_level = _game.get_tech_level("tesla_emp")
    var hits := 0
    for enemy in enemies:
        if enemy == null:
            continue
        if global_position.distance_squared_to(enemy.global_position) > range * range:
            continue
        if enemy.has_method("take_damage"):
            enemy.take_damage(damage)
        if emp_level > 0 and enemy.has_method("apply_slow"):
            var slow_factor := max(0.45, 0.8 - emp_level * 0.12)
            var slow_duration := 0.6 + 0.2 * emp_level
            enemy.apply_slow(get_instance_id(), slow_factor, slow_duration)
        if emp_level > 0 and enemy.has_method("stun"):
            enemy.stun(0.08 * emp_level)
        hits += 1
        if hits >= chain_count:
            break
