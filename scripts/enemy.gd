extends CharacterBody2D

var speed := 120.0
var max_health := 30.0
var health := 30.0
var attack_damage := 6.0
var attack_rate := 0.8
var attack_range := 18.0
var aggro_range := 260.0
var is_siege := false

var _attack_cooldown := 0.0
var _game: Node = null
var _slow_sources: Dictionary = {}
var _slow_multiplier := 1.0
var _stun_timer := 0.0
var _was_stunned := false
var _was_slowed := false

@onready var body: CanvasItem = $Body
var _base_color: Color = Color.WHITE

func setup(game_ref: Node, difficulty: float) -> void:
    _game = game_ref
    max_health = max_health * difficulty
    health = max_health
    speed = speed * (1.0 + difficulty * 0.05)

func _ready() -> void:
    add_to_group("enemies")
    collision_layer = GameLayers.ENEMY
    collision_mask = GameLayers.PLAYER | GameLayers.BUILDING
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    if body != null:
        _base_color = body.modulate

func _physics_process(delta: float) -> void:
    if _game == null:
        return
    if _stun_timer > 0.0:
        _stun_timer = max(0.0, _stun_timer - delta)
        velocity = Vector2.ZERO
        _update_status_visuals()
        return
    var target := _find_target()
    if target == null:
        return
    var dist := global_position.distance_to(target.global_position)
    _attack_cooldown = max(0.0, _attack_cooldown - delta)
    if dist <= attack_range:
        if _attack_cooldown <= 0.0:
            if target.has_method("take_damage"):
                target.take_damage(attack_damage)
            _attack_cooldown = 1.0 / max(0.1, attack_rate)
        velocity = Vector2.ZERO
    else:
        var dir := (target.global_position - global_position).normalized()
        velocity = dir * speed * _slow_multiplier
        move_and_slide()
    _update_status_visuals()

func _find_target() -> Node:
    var player: Node = _game.player
    if player != null:
        var player_dist := global_position.distance_squared_to(player.global_position)
        if player_dist <= aggro_range * aggro_range:
            return player
    var best_building: Node = null
    var best_dist := aggro_range * aggro_range
    for building in get_tree().get_nodes_in_group("buildings"):
        if building == null:
            continue
        var dist := global_position.distance_squared_to(building.global_position)
        if dist <= best_dist:
            best_building = building
            best_dist = dist
    if best_building != null:
        return best_building
    return player

func take_damage(amount: float) -> void:
    health -= amount
    if health <= 0.0:
        if _game != null:
            _game.spawn_pickup(global_position, 1)
            var xp_reward := 1
            if is_siege:
                xp_reward = 3
            _game.add_xp(xp_reward)
        queue_free()

func apply_slow(source_id: int, factor: float, duration: float = 0.0) -> void:
    _slow_sources[source_id] = clamp(factor, 0.1, 1.0)
    _recalc_slow()
    _update_status_visuals()
    if duration > 0.0:
        var timer := get_tree().create_timer(duration)
        timer.timeout.connect(func(): remove_slow(source_id))

func remove_slow(source_id: int) -> void:
    _slow_sources.erase(source_id)
    _recalc_slow()
    _update_status_visuals()

func _recalc_slow() -> void:
    _slow_multiplier = 1.0
    for factor in _slow_sources.values():
        _slow_multiplier = min(_slow_multiplier, float(factor))

func stun(duration: float) -> void:
    _stun_timer = max(_stun_timer, duration)
    _update_status_visuals()

func is_siege_unit() -> bool:
    return is_siege

func _update_status_visuals() -> void:
    if body == null:
        return
    var stunned_now := _stun_timer > 0.0
    var slowed_now := not _slow_sources.is_empty()
    if stunned_now and not _was_stunned:
        if _game != null and _game.has_method("spawn_fx"):
            _game.spawn_fx("stun", global_position)
    if stunned_now == _was_stunned and slowed_now == _was_slowed:
        return
    _was_stunned = stunned_now
    _was_slowed = slowed_now
    if stunned_now:
        body.modulate = _base_color.lerp(Color(1.0, 0.9, 0.4), 0.6)
    elif slowed_now:
        body.modulate = _base_color.lerp(Color(0.5, 0.8, 1.0), 0.5)
    else:
        body.modulate = _base_color
