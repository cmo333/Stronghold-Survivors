extends "res://scripts/building.gd"

var summon_interval: float = 30.0
var demon_health: float = 160.0
var demon_damage: float = 24.0
var demon_speed: float = 125.0
var demon_attack_rate: float = 1.0
var demon_attack_range: float = 24.0
var caster_chance: float = 0.35
var caster_aoe_radius: float = 70.0
var caster_aoe_damage: float = 36.0
var _timer: float = 0.0
var _game: Node = null
var _spawned_once: bool = false

const DEMON_FRAMES = [
	"res://assets/level1/level1_buildings_traps_anim60/unit_demon_fiend_duelist_32_move_f001_v001.png",
	"res://assets/level1/level1_buildings_traps_anim60/unit_demon_fiend_duelist_32_move_f002_v001.png",
	"res://assets/level1/level1_buildings_traps_anim60/unit_demon_fiend_duelist_32_move_f003_v001.png",
	"res://assets/level1/level1_buildings_traps_anim60/unit_demon_fiend_duelist_32_move_f004_v001.png"
]

const DEMON_CASTER_FRAMES = [
	"res://assets/level1/level1_monsters_more/unit_demon_cultist_32_move_f001_v001.png",
	"res://assets/level1/level1_monsters_more/unit_demon_cultist_32_move_f002_v001.png",
	"res://assets/level1/level1_monsters_more/unit_demon_cultist_32_move_f003_v001.png",
	"res://assets/level1/level1_monsters_more/unit_demon_cultist_32_move_f004_v001.png"
]

func _ready() -> void:
	super._ready()
	_game = get_tree().get_first_node_in_group("game")

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	summon_interval = float(tier_data.get("summon_interval", summon_interval))
	demon_health = float(tier_data.get("demon_health", demon_health))
	demon_damage = float(tier_data.get("demon_damage", demon_damage))
	demon_speed = float(tier_data.get("demon_speed", demon_speed))
	demon_attack_rate = float(tier_data.get("demon_attack_rate", demon_attack_rate))
	demon_attack_range = float(tier_data.get("demon_attack_range", demon_attack_range))
	caster_chance = float(tier_data.get("caster_chance", caster_chance))
	caster_aoe_radius = float(tier_data.get("caster_aoe_radius", caster_aoe_radius))
	caster_aoe_damage = float(tier_data.get("caster_aoe_damage", caster_aoe_damage))

func _process(delta: float) -> void:
	if _game == null:
		return
	if _game.has_method("is_game_started") and not _game.is_game_started():
		return
	if not _spawned_once:
		_spawned_once = true
		_summon_demon()
	_timer += delta
	if _timer < summon_interval:
		return
	_timer = 0.0
	_summon_demon()

func _summon_demon() -> void:
	if _game == null or not _game.has_method("spawn_ally"):
		return
	var is_caster = randf() < caster_chance
	var frames = DEMON_CASTER_FRAMES if is_caster else DEMON_FRAMES
	var config: Dictionary = {
		"frame_paths": frames,
		"fps": 7.0,
		"max_health": demon_health * (0.9 if is_caster else 1.0),
		"attack_damage": demon_damage * (1.25 if is_caster else 1.0),
		"attack_rate": demon_attack_rate * (1.15 if is_caster else 1.0),
		"attack_range": demon_attack_range,
		"speed": demon_speed * (0.95 if is_caster else 1.0),
		"aggro_range": 300.0,
		"orbit_radius": 170.0 if is_caster else 140.0,
		"leash_radius": 340.0,
		"attack_fx": "ally_lightning" if is_caster else "ally_slash",
		"spawn_fx": "summon_fire",
		"death_fx": "elite_kill",
		"scale": 1.15 if is_caster else 1.1,
		"z": 3,
		"aoe_radius": caster_aoe_radius if is_caster else 0.0,
		"aoe_damage": caster_aoe_damage if is_caster else 0.0,
		"aoe_fx": "summon_fire"
	}
	var spawn_pos = global_position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	_game.spawn_ally(config, spawn_pos)
