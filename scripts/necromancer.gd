extends "res://scripts/enemy_variant.gd"

var summon_interval := 7.0
var _timer := 0.0

func _process(delta: float) -> void:
    if _game == null:
        return
    _timer += delta
    if _timer < summon_interval:
        return
    _timer = 0.0
    if _game.has_method("spawn_minion"):
        _game.spawn_minion(global_position)
