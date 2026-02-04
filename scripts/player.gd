extends CharacterBody2D

var speed := 210.0
var attack_range := 260.0
var attack_rate := 1.2
var damage := 10.0
var projectile_speed := 640.0
var projectile_range := 280.0

var max_health := 100.0
var health := 100.0

var _attack_cooldown := 0.0
var _game: Node = null
var _shot_counter := 0
var _base_damage := 10.0
var _base_attack_rate := 1.2
var _slow_timer := 0.0
var _slow_factor := 1.0

var gun_pierce := 0
var burst_level := 0
var burst_every := 0
var burst_spread := 0.25
var slow_factor := 1.0
var slow_duration := 0.0

func _ready() -> void:
    _game = get_tree().get_first_node_in_group("game")
    add_to_group("player")
    collision_layer = GameLayers.PLAYER
    collision_mask = GameLayers.ENEMY | GameLayers.BUILDING
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    _base_damage = damage
    _base_attack_rate = attack_rate

func _physics_process(delta: float) -> void:
    if _slow_timer > 0.0:
        _slow_timer = max(0.0, _slow_timer - delta)
    else:
        _slow_factor = 1.0
    var input_vector := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
        Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
    )
    if input_vector.length() > 1.0:
        input_vector = input_vector.normalized()
    velocity = input_vector * speed * _slow_factor
    move_and_slide()

    _attack_cooldown = max(0.0, _attack_cooldown - delta)
    if _attack_cooldown <= 0.0:
        var target := _find_target()
        if target != null and _game != null:
            var dir := (target.global_position - global_position).normalized()
            _shot_counter += 1
            if burst_level > 0 and burst_every > 0 and _shot_counter % burst_every == 0:
                var angles := [-burst_spread, 0.0, burst_spread]
                for angle in angles:
                    _game.spawn_projectile(global_position, dir.rotated(angle), projectile_speed, damage, projectile_range, 0.0, gun_pierce, slow_factor, slow_duration)
            else:
                _game.spawn_projectile(global_position, dir, projectile_speed, damage, projectile_range, 0.0, gun_pierce, slow_factor, slow_duration)
            _attack_cooldown = 1.0 / max(0.1, attack_rate)

func _find_target() -> Node:
    var best: Node = null
    var best_dist := attack_range * attack_range
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy == null:
            continue
        var dist := global_position.distance_squared_to(enemy.global_position)
        if dist <= best_dist:
            best = enemy
            best_dist = dist
    return best

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        health = 0.0
        if _game != null and _game.has_method("on_player_death"):
            _game.on_player_death()

func heal(amount: float) -> void:
    health = min(max_health, health + amount)

func apply_gun_tech(id: String, level: int) -> void:
    match id:
        "gun_pierce":
            gun_pierce = level
        "gun_burst":
            burst_level = level
            burst_every = max(2, 5 - level)
        "gun_slow":
            slow_factor = max(0.5, 0.8 - (level - 1) * 0.15)
            slow_duration = 0.8 + 0.3 * level

func apply_global_bonuses(damage_bonus: float) -> void:
    damage = _base_damage + damage_bonus
    attack_rate = _base_attack_rate

func apply_slow(factor: float, duration: float) -> void:
    _slow_factor = min(_slow_factor, factor)
    _slow_timer = max(_slow_timer, duration)
