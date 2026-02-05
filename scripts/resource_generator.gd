extends "res://scripts/building.gd"

var income = 2
var interval = 2.0
var _timer = 0.0
var _game: Node = null

func _ready() -> void:
    super._ready()
    _game = get_tree().get_first_node_in_group("game")

func _apply_tier_stats(tier_data: Dictionary) -> void:
    super._apply_tier_stats(tier_data)
    income = int(tier_data.get("income", income))
    interval = float(tier_data.get("interval", interval))

func _process(delta: float) -> void:
    if _game == null:
        return
    _timer += delta
    if _timer >= interval:
        _timer -= interval
        _game.add_resources(income)
