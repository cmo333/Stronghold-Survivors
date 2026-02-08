extends "res://scripts/building.gd"
class_name Tower

var range = 220.0
var fire_rate = 1.0
var damage = 8.0
var projectile_speed = 500.0
var projectile_range = 260.0
var explosion_radius = 0.0

var _cooldown = 0.0
var _game: Node = null
@onready var body_sprite: AnimatedSprite2D = get_node_or_null("Body") as AnimatedSprite2D

func _ready() -> void:
    _game = get_tree().get_first_node_in_group("game")
    if body_sprite != null:
        body_sprite.stop()
        body_sprite.frame = 0
        body_sprite.scale = Vector2.ONE * 1.35

func _process(delta: float) -> void:
    _cooldown = max(0.0, _cooldown - delta)
    if _cooldown > 0.0:
        return
    var target = _find_target()
    if target == null:
        _set_anim_active(false)
        return
    _set_anim_active(true)
    _fire_at(target)
    var rate_mult = 1.0
    if _game != null and _game.has_method("get_tower_rate_mult"):
        rate_mult = _game.get_tower_rate_mult()
    _cooldown = 1.0 / max(0.1, fire_rate * rate_mult)

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    range = float(tier_data.get("range", range))
    fire_rate = float(tier_data.get("fire_rate", fire_rate))
    damage = float(tier_data.get("damage", damage))
    projectile_speed = float(tier_data.get("projectile_speed", projectile_speed))
    projectile_range = float(tier_data.get("projectile_range", projectile_range))
    explosion_radius = float(tier_data.get("explosion_radius", explosion_radius))

func _find_target() -> Node2D:
    var best: Node2D = null
    var range_mult = 1.0
    if _game != null and _game.has_method("get_tower_range_mult"):
        range_mult = _game.get_tower_range_mult()
    var effective_range = range * range_mult
    var best_dist = effective_range * effective_range
    for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
        if enemy == null:
            continue
        var dist = global_position.distance_squared_to(enemy.global_position)
        if dist <= best_dist:
            best = enemy
            best_dist = dist
    return best

func get_range() -> float:
    var range_mult = 1.0
    if _game != null and _game.has_method("get_tower_range_mult"):
        range_mult = _game.get_tower_range_mult()
    return range * range_mult

func _fire_at(target: Node2D) -> void:
    if _game == null:
        return
    var target_pos = target.global_position
    var target_vel = Vector2.ZERO
    if "velocity" in target:
        target_vel = target.velocity
    var to_target = target_pos - global_position
    var distance = to_target.length()
    var lead_time = distance / max(1.0, projectile_speed)
    if target_vel.length() > 0.1:
        target_pos += target_vel * lead_time
    var dir = (target_pos - global_position).normalized()
    var dmg_bonus = 0.0
    if _game != null and _game.has_method("get_tower_damage_bonus"):
        dmg_bonus = _game.get_tower_damage_bonus()
    _game.spawn_projectile(global_position, dir, projectile_speed, damage + dmg_bonus, projectile_range, explosion_radius)

func _set_anim_active(active: bool) -> void:
    if body_sprite == null:
        return
    if active:
        if not body_sprite.is_playing():
            body_sprite.play()
    else:
        if body_sprite.is_playing():
            body_sprite.stop()
            body_sprite.frame = 0
