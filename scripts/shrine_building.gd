extends "res://scripts/building.gd"

var summon_interval: float = 28.0
var demon_health: float = 220.0
var demon_damage: float = 34.0
var demon_speed: float = 118.0
var demon_attack_rate: float = 0.95
var demon_attack_range: float = 34.0
var caster_chance: float = 0.35
var caster_aoe_radius: float = 96.0
var caster_aoe_damage: float = 54.0
# Tier 3 ("greater") demons. The tier data turns this on; everything below reads
# it rather than testing `tier == 2`, so the flag stays the single source of
# truth if tiers are ever reordered.
var greater: bool = false
var _timer: float = 0.0
var _game: Node = null
var _spawned_once: bool = false

const STARGATE_DEMON_FRAMES = [
	"res://assets/level1/level1_anim60/unit_demon_void_gargant_64_move_f001_v001.png",
	"res://assets/level1/level1_anim60/unit_demon_void_gargant_64_move_f002_v001.png",
	"res://assets/level1/level1_anim60/unit_demon_void_gargant_64_move_f003_v001.png",
	"res://assets/level1/level1_anim60/unit_demon_void_gargant_64_move_f004_v001.png"
]

const STARGATE_FALLBACK_FRAMES = [
	"res://assets/level1/level1_monsters_more/unit_demon_gargoyle_flying_48_move_f001_v001.png",
	"res://assets/level1/level1_monsters_more/unit_demon_gargoyle_flying_48_move_f002_v001.png",
	"res://assets/level1/level1_monsters_more/unit_demon_gargoyle_flying_48_move_f003_v001.png",
	"res://assets/level1/level1_monsters_more/unit_demon_gargoyle_flying_48_move_f004_v001.png"
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
	greater = bool(tier_data.get("greater", false))

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

func _all_paths_exist(paths: Array) -> bool:
	for raw_path in paths:
		if not ResourceLoader.exists(str(raw_path)):
			return false
	return true

func _pick_demon_frames() -> Array:
	if _all_paths_exist(STARGATE_DEMON_FRAMES):
		return STARGATE_DEMON_FRAMES
	return STARGATE_FALLBACK_FRAMES

func _summon_demon() -> void:
	if _game == null or not _game.has_method("spawn_ally"):
		return
	var is_overlord = randf() < caster_chance
	var frames = _pick_demon_frames()
	var hp_mult = 2.2 if is_overlord else 1.8
	var dmg_mult = 1.55 if is_overlord else 1.25
	var scale_mult = 1.95 if is_overlord else 1.65
	var aoe_mult = 1.5 if is_overlord else 1.2
	# Tier 3 sets caster_chance to 1.0, so every greater demon is already an
	# overlord and takes the branches above; this is what makes it read as a
	# different creature rather than a bigger number. Splash is doubled again on
	# top of the overlord multiplier because "splash" is the stated point of the
	# tier -- a greater demon should be clearing the pack, not duelling.
	if greater:
		scale_mult *= 1.45
		aoe_mult *= 2.0
	var config: Dictionary = {
		"frame_paths": frames,
		"fps": 8.5,
		"max_health": demon_health * hp_mult,
		"attack_damage": demon_damage * dmg_mult,
		"attack_rate": demon_attack_rate * (0.95 if is_overlord else 1.08),
		"attack_range": demon_attack_range + (8.0 if is_overlord else 4.0),
		"speed": demon_speed * (0.88 if is_overlord else 0.95),
		"aggro_range": 430.0,
		"orbit_radius": 250.0 if is_overlord else 220.0,
		"leash_radius": 540.0,
		"orbit_speed": 1.7 if is_overlord else 2.0,
		"attack_fx": "hero_energy_impact" if is_overlord else "ally_lightning",
		"spawn_fx": "summon_shadow",
		"death_fx": "hero_elite_death",
		"damage_type": "lightning",
		"scale": scale_mult,
		"z": 4,
		"hit_radius": 16.0 if is_overlord else 13.0,
		"aoe_radius": caster_aoe_radius * aoe_mult,
		"aoe_damage": caster_aoe_damage * aoe_mult,
		"aoe_fx": "hero_energy_impact"
	}
	if greater:
		# Red, and read as red: the source frames are a cold void purple, so a
		# plain multiply leaves them muddy. Lifting red above 1.0 pushes the
		# tint through the existing pixels instead of just darkening the other
		# two channels.
		config["tint"] = Color(1.6, 0.32, 0.28)
		config["hit_radius"] = 22.0
		config["damage_type"] = "fire"
		config["attack_fx"] = "explosion"
		config["aoe_fx"] = "explosion"
		config["z"] = 5
	var spawn_pos = global_position + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
	if _game.has_method("spawn_setpiece_fx"):
		_game.spawn_setpiece_fx("energy_impact", spawn_pos, 1.2 if is_overlord else 1.0, "lightning")
	elif _game.has_method("spawn_fx"):
		_game.spawn_fx("summon_shadow", spawn_pos)
	_game.spawn_ally(config, spawn_pos)
