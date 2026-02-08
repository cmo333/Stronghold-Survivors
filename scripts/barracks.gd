extends "res://scripts/building.gd"

var spawn_interval: float = 30.0
var ally_health: float = 120.0
var ally_damage: float = 14.0
var ally_speed: float = 110.0
var ally_attack_rate: float = 1.1
var ally_attack_range: float = 22.0
var vulture_chance: float = 0.25
var _timer: float = 0.0
var _game: Node = null
var _spawned_once: bool = false

const SKELETON_FRAMES = [
	"res://assets/level1/level1_anim60/unit_undead_skeleton_warrior_32_move_f001_v001.png",
	"res://assets/level1/level1_anim60/unit_undead_skeleton_warrior_32_move_f002_v001.png",
	"res://assets/level1/level1_anim60/unit_undead_skeleton_warrior_32_move_f003_v001.png",
	"res://assets/level1/level1_anim60/unit_undead_skeleton_warrior_32_move_f004_v001.png"
]

const VULTURE_FRAMES = [
	"res://assets/level1/level1_anim60/unit_undead_vulture_flying_48_move_f001_v001.png",
	"res://assets/level1/level1_anim60/unit_undead_vulture_flying_48_move_f002_v001.png",
	"res://assets/level1/level1_anim60/unit_undead_vulture_flying_48_move_f003_v001.png",
	"res://assets/level1/level1_anim60/unit_undead_vulture_flying_48_move_f004_v001.png"
]

func _ready() -> void:
	super._ready()
	_game = get_tree().get_first_node_in_group("game")

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	spawn_interval = float(tier_data.get("spawn_interval", spawn_interval))
	ally_health = float(tier_data.get("ally_health", ally_health))
	ally_damage = float(tier_data.get("ally_damage", ally_damage))
	ally_speed = float(tier_data.get("ally_speed", ally_speed))
	ally_attack_rate = float(tier_data.get("ally_attack_rate", ally_attack_rate))
	ally_attack_range = float(tier_data.get("ally_attack_range", ally_attack_range))
	vulture_chance = float(tier_data.get("vulture_chance", vulture_chance))

func _process(delta: float) -> void:
	if _game == null:
		return
	if _game.has_method("is_game_started") and not _game.is_game_started():
		return
	if not _spawned_once:
		_spawned_once = true
		_spawn_ally()
	_timer += delta
	if _timer < spawn_interval:
		return
	_timer = 0.0
	_spawn_ally()

func _spawn_ally() -> void:
	if _game == null or not _game.has_method("spawn_ally"):
		return
	var is_vulture = randf() < vulture_chance
	var frames = VULTURE_FRAMES if is_vulture else SKELETON_FRAMES
	var config: Dictionary = {
		"frame_paths": frames,
		"fps": 7.0 if is_vulture else 6.0,
		"max_health": ally_health * (0.8 if is_vulture else 1.0),
		"attack_damage": ally_damage * (0.8 if is_vulture else 1.0),
		"attack_rate": ally_attack_rate * (1.2 if is_vulture else 1.0),
		"attack_range": ally_attack_range,
		"speed": ally_speed * (1.35 if is_vulture else 1.0),
		"aggro_range": 280.0,
		"orbit_radius": 150.0 if is_vulture else 120.0,
		"leash_radius": 300.0,
		"attack_fx": "ally_slash",
		"spawn_fx": "summon_shadow",
		"death_fx": "kill_pop",
		"scale": 1.2 if is_vulture else 1.05,
		"z": 3 if is_vulture else 2
	}
	var spawn_pos = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
	_game.spawn_ally(config, spawn_pos)
