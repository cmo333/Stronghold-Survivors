extends "res://scripts/enemy.gd"

@export var speed_mult := 1.0
@export var health_mult := 1.0
@export var damage_mult := 1.0
@export var attack_rate_mult := 1.0
@export var attack_range_mult := 1.0
@export var aggro_range_mult := 1.0

func setup(game_ref: Node, difficulty: float) -> void:
    super.setup(game_ref, difficulty)
    max_health *= health_mult
    health = max_health
    speed *= speed_mult
    attack_damage *= damage_mult
    attack_rate *= attack_rate_mult
    attack_range *= attack_range_mult
    aggro_range *= aggro_range_mult
