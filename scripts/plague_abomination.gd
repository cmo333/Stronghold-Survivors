extends "res://scripts/enemy_variant.gd"

var pulse_interval := 6.0
var pulse_radius := 220.0
var pulse_damage := 4.0
var slow_factor := 0.7
var slow_duration := 1.2
var _timer := 0.0

func _process(delta: float) -> void:
    if _game == null:
        return
    _timer += delta
    if _timer < pulse_interval:
        return
    _timer = 0.0
    var player := _game.player
    if player == null:
        return
    if global_position.distance_squared_to(player.global_position) <= pulse_radius * pulse_radius:
        if player.has_method("take_damage"):
            player.take_damage(pulse_damage)
        if player.has_method("apply_slow"):
            player.apply_slow(slow_factor, slow_duration)
        if _game.has_method("spawn_fx"):
            _game.spawn_fx("acid", global_position)
