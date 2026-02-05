extends Tower

func _fire_at(target: Node) -> void:
    if _game == null:
        return
    var dir = (target.global_position - global_position).normalized()
    var dmg_bonus = 0.0
    if _game.has_method("get_tower_damage_bonus"):
        dmg_bonus = _game.get_tower_damage_bonus()
    _game.spawn_projectile(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius)
    var level = 0
    if _game.has_method("get_tech_level"):
        level = _game.get_tech_level("arrow_fan")
    var extra_angles: Array = []
    if level == 1:
        extra_angles = [-0.2, 0.2]
    elif level == 2:
        extra_angles = [-0.35, -0.15, 0.15, 0.35]
    elif level >= 3:
        extra_angles = [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]
    for angle in extra_angles:
        _game.spawn_projectile(global_position, dir.rotated(angle), projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius)
