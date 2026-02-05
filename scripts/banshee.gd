extends "res://scripts/enemy_variant.gd"

var scream_interval = 5.0
var scream_radius = 220.0
var slow_factor = 0.6
var slow_duration = 1.4
var _timer = 0.0

func _process(delta: float) -> void:
    if _game == null:
        return
    _timer += delta
    if _timer < scream_interval:
        return
    _timer = 0.0
    var player = _game.player
    if player == null:
        return
    if global_position.distance_squared_to(player.global_position) <= scream_radius * scream_radius:
        if player.has_method("apply_slow"):
            player.apply_slow(slow_factor, slow_duration)
        if _game != null and _game.has_method("spawn_fx"):
            _game.spawn_fx("ghost", global_position)
        if _game.has_method("spawn_fx"):
            _game.spawn_fx("ice", global_position)
