extends Area2D

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 8.0
var max_range := 260.0
var explosion_radius := 0.0
var _travelled := 0.0
var _game: Node = null
var pierce := 0
var remaining_pierce := 0
var slow_factor := 1.0
var slow_duration := 0.0

func setup(game_ref: Node, dir: Vector2, proj_speed: float, dmg: float, range: float, explode_radius: float, pierce_count: int = 0, slow_factor_in: float = 1.0, slow_duration_in: float = 0.0) -> void:
    _game = game_ref
    direction = dir.normalized()
    speed = proj_speed
    damage = dmg
    max_range = range
    explosion_radius = explode_radius
    pierce = max(0, pierce_count)
    remaining_pierce = pierce
    slow_factor = slow_factor_in
    slow_duration = slow_duration_in

func _ready() -> void:
    collision_layer = GameLayers.PROJECTILE
    collision_mask = GameLayers.ENEMY
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    var step := speed * delta
    global_position += direction * step
    _travelled += step
    if _travelled >= max_range:
        _explode_if_needed()
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body == null or not body.is_in_group("enemies"):
        return
    if explosion_radius > 0.0:
        _explode_if_needed()
        if _game != null and _game.has_method("spawn_fx"):
            _game.spawn_fx("explosion", global_position)
        queue_free()
        return
    if body.has_method("take_damage"):
        body.take_damage(damage)
    if _game != null and _game.has_method("spawn_fx"):
        _game.spawn_fx("hit", global_position)
    if slow_factor < 0.99 and body.has_method("apply_slow"):
        body.apply_slow(get_instance_id(), slow_factor, slow_duration)
    if remaining_pierce > 0:
        remaining_pierce -= 1
        return
    queue_free()

func _explode_if_needed() -> void:
    if explosion_radius <= 0.0:
        return
    if _game != null:
        _game.damage_enemies_in_radius(global_position, explosion_radius, damage)
