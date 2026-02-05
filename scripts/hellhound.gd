extends "res://scripts/enemy_variant.gd"

var dash_cooldown = 2.5
var dash_duration = 0.4
var dash_mult = 1.8
var _dash_timer = 0.0
var _dash_cd = 0.0
var _base_speed = 0.0

func _ready() -> void:
    super._ready()
    _base_speed = speed

func _physics_process(delta: float) -> void:
    _dash_cd = max(0.0, _dash_cd - delta)
    if _dash_timer > 0.0:
        _dash_timer = max(0.0, _dash_timer - delta)
        speed = _base_speed * dash_mult
    else:
        speed = _base_speed
        if _dash_cd <= 0.0 and _game != null and _game.player != null:
            var dist = global_position.distance_to(_game.player.global_position)
            if dist < 240.0:
                _dash_timer = dash_duration
                _dash_cd = dash_cooldown
    super._physics_process(delta)
