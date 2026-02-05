extends Node2D

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const SIEGE_ENEMY_SCENE = preload("res://scenes/siege_enemy.tscn")
const BANSHEE_SCENE = preload("res://scenes/enemies/banshee.tscn")
const NECROMANCER_SCENE = preload("res://scenes/enemies/necromancer.tscn")
const FIEND_DUELIST_SCENE = preload("res://scenes/enemies/fiend_duelist.tscn")
const HELLHOUND_SCENE = preload("res://scenes/enemies/hellhound.tscn")
const PLAGUE_ABOMINATION_SCENE = preload("res://scenes/enemies/plague_abomination.tscn")
const CHARGER_SCENE = preload("res://scenes/enemies/charger.tscn")
const SPITTER_SCENE = preload("res://scenes/enemies/spitter.tscn")
const HEALER_SCENE = preload("res://scenes/enemies/healer.tscn")
const FX_SCENE = preload("res://scenes/fx/fx.tscn")
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const ENEMY_PROJECTILE_SCENE = preload("res://scenes/enemy_projectile.tscn")
const PICKUP_SCENE = preload("res://scenes/pickup.tscn")
const BREAKABLE_SCENE = preload("res://scenes/breakable.tscn")

@onready var player: CharacterBody2D = $World/Player
@onready var enemies_root: Node2D = $World/Enemies
@onready var projectiles_root: Node2D = $World/Projectiles
@onready var fx_root: Node2D = $World/FX
@onready var buildings_root: Node2D = $World/Buildings
@onready var props_root: Node2D = $World/Props
@onready var pickups_root: Node2D = $World/Pickups
@onready var breakables_root: Node2D = $World/Breakables
@onready var ui: CanvasLayer = $UI
@onready var build_manager: Node = $BuildManager

var resources: int = 0
var elapsed: float = 0.0
var spawn_accumulator: float = 0.0
var game_over = false
var game_started = false
var start_timer = 0.0
var spawn_delay = 10.0
var auto_start_delay = 2.0

var xp = 0
var level = 1
var xp_next = 12
var pending_picks = 0
var tech_open = false
var tech_choices: Array = []
var tech_levels: Dictionary = {}
var unlocked_builds: Dictionary = {
	"arrow_turret": true,
	"wall": true,
	"gate": true
}
var characters = [
	{
		"id": "hunter",
		"name": "Hunter",
		"desc": "Balanced ranger with steady fire",
		"base_path": "res://assets/level1/level1_player_anim",
		"prefix": "player_hunter_32",
		"icon": "res://assets/level1/level1_player_anim/player_hunter_32_S_move_f001_v001.png"
	},
	{
		"id": "pyromancer",
		"name": "Pyromancer",
		"desc": "Fire caster with aggressive style",
		"base_path": "res://assets/level1/level1_player_anim_pyro",
		"prefix": "player_pyromancer_32",
		"icon": "res://assets/level1/level1_player_anim_pyro/player_pyromancer_32_S_move_f001_v001.png"
	}
]
var selected_character = 0
var building_effects = {
	"armory_damage": {},
	"tech_rate": {}
}
var tower_rate_mult = 1.0
var player_damage_bonus = 0.0
var tower_damage_bonus = 0.0
var tower_range_mult = 1.0

var spawn_radius_min = 720.0
var spawn_radius_max = 1050.0
var max_enemies_base = 12
var max_enemies_growth = 0.6
var max_enemies_cap = 180
var max_projectiles = 240
var elite_chance_base = 0.02
var elite_chance_growth = 0.08
var elite_health_mult = 2.2

var breakable_target = 18
var breakable_spawn_min = 240.0
var breakable_spawn_max = 920.0

var prop_spawn_radius = 1600.0
var prop_min_distance = 120.0
var prop_count = 180

const PROP_PATHS = [
	"res://assets/level1/level1_props/prop_graveyard_broken_fence_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_bone_pile_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_broken_cart_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_broken_pillar_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_crates_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_dead_tree_stump_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_lantern_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_ruined_pillar_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_skull_cairn_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_skull_pile_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_tombstone_large_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_tombstone_small_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_tombstone_tall_48_v001.png"
]

var tech_defs = {
	"arrow_fan": {
		"name": "Arrow: Fanfire",
		"desc": "Arrow turrets fire extra spread shots",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_wood_32_v001.png",
		"rarity": "common",
		"min_level": 1
	},
	"gun_pierce": {
		"name": "Gun: Piercing",
		"desc": "Shots pierce +1 enemy",
		"max": 2,
		"icon": "res://assets/ui/ui_icon_iron_32_v001.png",
		"rarity": "common",
		"min_level": 1
	},
	"gun_burst": {
		"name": "Gun: Burst Volley",
		"desc": "Every few shots fires a 3-shot spread",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png",
		"rarity": "rare",
		"min_level": 2
	},
	"gun_slow": {
		"name": "Gun: Cryo Rounds",
		"desc": "Shots slow enemies briefly",
		"max": 2,
		"icon": "res://assets/ui/ui_icon_ice_32_v001.png",
		"rarity": "rare",
		"min_level": 2
	},
	"unlock_cannon": {
		"name": "Unlock: Cannon Tower",
		"desc": "Build heavy AoE cannon towers",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_iron_32_v001.png",
		"rarity": "rare",
		"min_level": 2,
		"unlock_build": "cannon_tower"
	},
	"unlock_mine": {
		"name": "Unlock: Mine Trap",
		"desc": "Plant mines that detonate on contact",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png",
		"rarity": "common",
		"min_level": 2,
		"unlock_build": "mine_trap"
	},
	"unlock_resource": {
		"name": "Unlock: Resource Generator",
		"desc": "Build generators for steady income",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_gold_32_v001.png",
		"rarity": "common",
		"min_level": 2,
		"unlock_build": "resource_generator"
	},
	"unlock_ice_trap": {
		"name": "Unlock: Ice Trap",
		"desc": "Freeze fields to slow swarms",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_ice_32_v001.png",
		"rarity": "rare",
		"min_level": 3,
		"unlock_build": "ice_trap"
	},
	"unlock_barracks": {
		"name": "Unlock: Barracks",
		"desc": "Train allied fighters to help defend",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_bone_32_v001.png",
		"rarity": "rare",
		"min_level": 4,
		"unlock_build": "barracks"
	},
	"unlock_tech_lab": {
		"name": "Unlock: Tech Lab",
		"desc": "Boost tower fire rate globally",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_crystal_32_v001.png",
		"rarity": "rare",
		"min_level": 4,
		"unlock_build": "tech_lab"
	},
	"unlock_tesla": {
		"name": "Unlock: Tesla Tower",
		"desc": "Chain lightning between targets",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "epic",
		"min_level": 4,
		"unlock_build": "tesla_tower"
	},
	"unlock_armory": {
		"name": "Unlock: Armory",
		"desc": "Boost your gun damage",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_iron_32_v001.png",
		"rarity": "epic",
		"min_level": 5,
		"unlock_build": "armory"
	},
	"unlock_shrine": {
		"name": "Unlock: Shrine",
		"desc": "Heals you within its aura",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_skull_32_v001.png",
		"rarity": "epic",
		"min_level": 5,
		"unlock_build": "shrine"
	},
	"unlock_acid_trap": {
		"name": "Unlock: Acid Burst",
		"desc": "Explodes and melts siege units",
		"max": 1,
		"icon": "res://assets/ui/ui_icon_crystal_32_v001.png",
		"rarity": "rare",
		"min_level": 3,
		"unlock_build": "acid_trap"
	},
	"tesla_emp": {
		"name": "Tesla: EMP",
		"desc": "Tesla shocks slow and stun briefly",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "legendary",
		"min_level": 6,
		"requires_build": "tesla_tower"
	},
	"tower_range": {
		"name": "Towers: Long Range",
		"desc": "All towers gain +12% range",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_stone_32_v001.png",
		"rarity": "common",
		"min_level": 2
	},
	"tower_damage": {
		"name": "Towers: Brutality",
		"desc": "All towers gain +2 damage",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_iron_32_v001.png",
		"rarity": "rare",
		"min_level": 2
	}
}

var rarity_weights = {
	"common": 60.0,
	"rare": 25.0,
	"epic": 10.0,
	"legendary": 4.0,
	"mythic": 1.2,
	"diamond": 0.4
}

var fx_defs = {
	"hit": {
		"paths": [
			"res://assets/fx/fx_hit_spark_16_f001_v001.png",
			"res://assets/fx/fx_hit_spark_16_f002_v001.png",
			"res://assets/fx/fx_hit_spark_16_f003_v001.png",
			"res://assets/fx/fx_hit_spark_16_f004_v001.png"
		],
		"fps": 12.0,
		"lifetime": 0.3
	},
	"explosion": {
		"paths": [
			"res://assets/fx/fx_explosion_small_32_f001_v001.png",
			"res://assets/fx/fx_explosion_small_32_f002_v001.png",
			"res://assets/fx/fx_explosion_small_32_f003_v001.png",
			"res://assets/fx/fx_explosion_small_32_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.4
	},
	"acid": {
		"paths": [
			"res://assets/fx/fx_acid_burst_64_f001_v001.png",
			"res://assets/fx/fx_acid_burst_64_f002_v001.png",
			"res://assets/fx/fx_acid_burst_64_f003_v001.png",
			"res://assets/fx/fx_acid_burst_64_f004_v001.png"
		],
		"fps": 9.0,
		"lifetime": 0.45
	},
	"ice": {
		"paths": [
			"res://assets/fx/fx_ice_field_64_f001_v001.png",
			"res://assets/fx/fx_ice_field_64_f002_v001.png",
			"res://assets/fx/fx_ice_field_64_f003_v001.png",
			"res://assets/fx/fx_ice_field_64_f004_v001.png"
		],
		"fps": 6.0,
		"lifetime": 0.8
	},
	"stun": {
		"paths": [
			"res://assets/fx/fx_stun_star_16_f001_v001.png",
			"res://assets/fx/fx_stun_star_16_f002_v001.png",
			"res://assets/fx/fx_stun_star_16_f003_v001.png",
			"res://assets/fx/fx_stun_star_16_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.35
	},
	"tesla": {
		"paths": [
			"res://assets/fx/fx_tesla_arc_32_f001_v001.png",
			"res://assets/fx/fx_tesla_arc_32_f002_v001.png",
			"res://assets/fx/fx_tesla_arc_32_f003_v001.png",
			"res://assets/fx/fx_tesla_arc_32_f004_v001.png"
		],
		"fps": 12.0,
		"lifetime": 0.25
	},
	"poison": {
		"paths": [
			"res://assets/fx/fx_poison_cloud_64_f001_v001.png",
			"res://assets/fx/fx_poison_cloud_64_f002_v001.png",
			"res://assets/fx/fx_poison_cloud_64_f003_v001.png",
			"res://assets/fx/fx_poison_cloud_64_f004_v001.png"
		],
		"fps": 8.0,
		"lifetime": 0.6
	},
	"necrotic": {
		"paths": [
			"res://assets/fx/fx_necrotic_pulse_64_f001_v001.png",
			"res://assets/fx/fx_necrotic_pulse_64_f002_v001.png",
			"res://assets/fx/fx_necrotic_pulse_64_f003_v001.png",
			"res://assets/fx/fx_necrotic_pulse_64_f004_v001.png"
		],
		"fps": 8.0,
		"lifetime": 0.6
	},
	"blood": {
		"paths": [
			"res://assets/fx/fx_blood_splash_32_f001_v001.png",
			"res://assets/fx/fx_blood_splash_32_f002_v001.png",
			"res://assets/fx/fx_blood_splash_32_f003_v001.png",
			"res://assets/fx/fx_blood_splash_32_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.4
	},
	"fire": {
		"paths": [
			"res://assets/fx/fx_fire_burst_32_f001_v001.png",
			"res://assets/fx/fx_fire_burst_32_f002_v001.png",
			"res://assets/fx/fx_fire_burst_32_f003_v001.png",
			"res://assets/fx/fx_fire_burst_32_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.4
	},
	"ghost": {
		"paths": [
			"res://assets/fx/fx_ghost_trail_32_f001_v001.png",
			"res://assets/fx/fx_ghost_trail_32_f002_v001.png",
			"res://assets/fx/fx_ghost_trail_32_f003_v001.png",
			"res://assets/fx/fx_ghost_trail_32_f004_v001.png"
		],
		"fps": 8.0,
		"lifetime": 0.5
	}
}

func _ready() -> void:
	randomize()
	add_to_group("game")
	_ensure_input_map()
	resources = 60
	_update_ui()
	if ui != null and ui.has_method("show_start"):
		if ui.has_method("set_start_text"):
			ui.set_start_text("Stronghold Survivors", "Choose your hero\n1: Hunter  |  2: Pyromancer\nEnter to begin")
		if ui.has_method("set_start_options"):
			ui.set_start_options(characters, selected_character)
		ui.show_start(true)
	Engine.time_scale = 0.0
	if build_manager.has_method("setup"):
		build_manager.setup(self, buildings_root, ui)
	_spawn_props()
	_spawn_initial_breakables()

func _process(delta: float) -> void:
	if game_over:
		return
	if not game_started:
		_handle_start_input(delta)
		return
	if tech_open:
		_handle_tech_input()
		return
	start_timer += delta
	if start_timer < spawn_delay:
		return
	elapsed += delta
	_handle_spawning(delta)
	_maintain_breakables()
	_update_ui()

func _handle_start_input(delta: float) -> void:
	if Input.is_action_just_pressed("build_1"):
		_set_selected_character(0)
	if Input.is_action_just_pressed("build_2"):
		_set_selected_character(1)
	if Input.is_action_just_pressed("start_game"):
		_start_game()

func _start_game() -> void:
	game_started = true
	start_timer = 0.0
	Engine.time_scale = 1.0
	_apply_selected_character()
	if ui != null and ui.has_method("show_start"):
		ui.show_start(false)
	_refresh_build_palette()

func is_tech_open() -> bool:
	return tech_open

func is_game_started() -> bool:
	return game_started

func get_tech_level(id: String) -> int:
	return int(tech_levels.get(id, 0))

func is_build_unlocked(id: String) -> bool:
	return bool(unlocked_builds.get(id, false))

func unlock_build(id: String) -> void:
	if id == "":
		return
	unlocked_builds[id] = true

func _handle_tech_input() -> void:
	if Input.is_action_just_pressed("build_1"):
		_choose_tech(0)
	elif Input.is_action_just_pressed("build_2"):
		_choose_tech(1)
	elif Input.is_action_just_pressed("build_3"):
		_choose_tech(2)

func _handle_spawning(delta: float) -> void:
	var interval = max(0.45, 1.6 - (elapsed / 200.0))
	spawn_accumulator += delta
	while spawn_accumulator >= interval:
		spawn_accumulator -= interval
		var max_enemies = min(max_enemies_cap, max_enemies_base + int(elapsed * max_enemies_growth))
		if elapsed < 30.0:
			max_enemies = min(max_enemies, 8)
		if enemies_root.get_child_count() >= max_enemies:
			break
		spawn_enemy()

func spawn_enemy() -> void:
	if player == null:
		return
	var siege_chance = 0.0
	if elapsed > 90.0:
		siege_chance = clamp(0.05 + (elapsed - 90.0) / 300.0, 0.0, 0.35)
	var scene = _pick_enemy_scene()
	if randf() < siege_chance:
		scene = SIEGE_ENEMY_SCENE
	var enemy = scene.instantiate()
	var angle = randf() * TAU
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
	var difficulty = 1.0 + (elapsed / 60.0) * 0.25
	if enemy.has_method("setup"):
		enemy.setup(self, difficulty)
	var elite_chance = elite_chance_base
	if elapsed > 60.0:
		elite_chance += clamp((elapsed - 60.0) / 600.0, 0.0, elite_chance_growth)
	if randf() < elite_chance and enemy.has_method("set_elite"):
		enemy.set_elite(elite_health_mult)
	enemies_root.add_child(enemy)

func spawn_minion(position: Vector2) -> void:
	if enemies_root.get_child_count() >= max_enemies_cap:
		return
	var enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	var difficulty = 1.0 + (elapsed / 60.0) * 0.25
	if enemy.has_method("setup"):
		enemy.setup(self, difficulty)
	enemies_root.add_child(enemy)

func _pick_enemy_scene() -> PackedScene:
	# Weighted spawn pools by time phase.
	# Format: [[scene, weight], ...]
	# New enemies unlock progressively; weights shift toward specials over time.
	if elapsed < 30.0:
		return ENEMY_SCENE
	if elapsed < 60.0:
		return _weighted_pick([
			[ENEMY_SCENE, 55],
			[CHARGER_SCENE, 25],
			[HELLHOUND_SCENE, 20]
		])
	if elapsed < 120.0:
		return _weighted_pick([
			[ENEMY_SCENE, 35],
			[CHARGER_SCENE, 15],
			[HELLHOUND_SCENE, 15],
			[SPITTER_SCENE, 20],
			[BANSHEE_SCENE, 15]
		])
	if elapsed < 180.0:
		return _weighted_pick([
			[ENEMY_SCENE, 22],
			[CHARGER_SCENE, 12],
			[HELLHOUND_SCENE, 10],
			[SPITTER_SCENE, 15],
			[BANSHEE_SCENE, 10],
			[FIEND_DUELIST_SCENE, 11],
			[HEALER_SCENE, 8],
			[NECROMANCER_SCENE, 8]
		])
	if elapsed < 270.0:
		return _weighted_pick([
			[ENEMY_SCENE, 18],
			[CHARGER_SCENE, 10],
			[HELLHOUND_SCENE, 8],
			[SPITTER_SCENE, 12],
			[BANSHEE_SCENE, 8],
			[FIEND_DUELIST_SCENE, 10],
			[HEALER_SCENE, 10],
			[NECROMANCER_SCENE, 10],
			[PLAGUE_ABOMINATION_SCENE, 14]
		])
	return _weighted_pick([
		[ENEMY_SCENE, 14],
		[CHARGER_SCENE, 10],
		[HELLHOUND_SCENE, 8],
		[SPITTER_SCENE, 12],
		[BANSHEE_SCENE, 8],
		[FIEND_DUELIST_SCENE, 10],
		[HEALER_SCENE, 12],
		[NECROMANCER_SCENE, 12],
		[PLAGUE_ABOMINATION_SCENE, 14]
	])

func _weighted_pick(pool: Array) -> PackedScene:
	var total = 0.0
	for entry in pool:
		total += float(entry[1])
	var roll = randf() * total
	for entry in pool:
		roll -= float(entry[1])
		if roll <= 0.0:
			return entry[0]
	return ENEMY_SCENE

func _set_selected_character(index: int) -> void:
	if index < 0 or index >= characters.size():
		return
	selected_character = index
	if ui != null and ui.has_method("set_start_options"):
		ui.set_start_options(characters, selected_character)

func _apply_selected_character() -> void:
	if player == null or not player.has_method("set_character"):
		return
	if selected_character < 0 or selected_character >= characters.size():
		return
	var data: Dictionary = characters[selected_character]
	var base_path = str(data.get("base_path", ""))
	var prefix = str(data.get("prefix", ""))
	player.set_character(base_path, prefix)

func _pick_weighted_choices(pool: Array, count: int) -> Array:
	var picks: Array = []
	var remaining: Array = pool.duplicate()
	while picks.size() < count and not remaining.is_empty():
		var id = _pick_weighted_id(remaining)
		picks.append(id)
		remaining.erase(id)
	return picks

func _pick_weighted_id(pool: Array) -> String:
	var total = 0.0
	for id in pool:
		total += _rarity_weight_for(str(id))
	if total <= 0.0:
		return str(pool[0])
	var roll = randf() * total
	for id in pool:
		roll -= _rarity_weight_for(str(id))
		if roll <= 0.0:
			return str(id)
	return str(pool[0])

func _rarity_weight_for(id: String) -> float:
	var def: Dictionary = tech_defs.get(id, {})
	var rarity = str(def.get("rarity", "common"))
	return float(rarity_weights.get(rarity, 1.0))

func spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, explosion_radius: float, pierce: int = 0, slow_factor: float = 1.0, slow_duration: float = 0.0) -> void:
	if projectiles_root.get_child_count() >= max_projectiles:
		return
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = origin
	if projectile.has_method("setup"):
		projectile.setup(self, direction, speed, damage, max_range, explosion_radius, pierce, slow_factor, slow_duration)
	projectiles_root.add_child(projectile)

func spawn_enemy_projectile(origin: Vector2, direction: Vector2, proj_speed: float, damage: float, proj_range: float) -> void:
	if projectiles_root.get_child_count() >= max_projectiles:
		return
	var proj = ENEMY_PROJECTILE_SCENE.instantiate()
	proj.global_position = origin
	if proj.has_method("setup"):
		proj.setup(self, direction, proj_speed, damage, proj_range)
	projectiles_root.add_child(proj)

func spawn_pickup(position: Vector2, value: int, kind: String = "gold") -> void:
	var pickup = PICKUP_SCENE.instantiate()
	pickup.global_position = position
	if pickup.has_method("setup"):
		pickup.setup(self, value, kind)
	pickups_root.add_child(pickup)

func spawn_fx(kind: String, position: Vector2) -> void:
	if fx_root == null or not fx_defs.has(kind):
		return
	var fx = FX_SCENE.instantiate()
	fx.global_position = position
	var def = fx_defs[kind]
	if fx.has_method("setup"):
		fx.setup(def.get("paths", []), float(def.get("fps", 10.0)), float(def.get("lifetime", 0.35)), false)
	fx_root.add_child(fx)

func damage_enemies_in_radius(position: Vector2, radius: float, damage: float, siege_bonus: float = 1.0) -> void:
	var radius_sq = radius * radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_squared_to(position) <= radius_sq:
			var final_damage = damage
			if siege_bonus != 1.0 and enemy.has_method("is_siege_unit") and enemy.is_siege_unit():
				final_damage = damage * siege_bonus
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage)

func add_resources(amount: int) -> void:
	resources += amount
	_update_ui()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_next:
		xp -= xp_next
		xp_next = int(xp_next * 1.35 + 6)
		level += 1
		pending_picks += 1
	if pending_picks > 0 and not tech_open:
		_open_tech_menu()
	_update_ui()

func can_afford(cost: int) -> bool:
	return resources >= cost

func spend(cost: int) -> bool:
	if resources < cost:
		return false
	resources -= cost
	_update_ui()
	return true

func _open_tech_menu() -> void:
	tech_choices.clear()
	var available: Array = _get_available_tech_ids()
	if available.is_empty():
		pending_picks = 0
		tech_open = false
		return
	var picks: Array = []
	var unlocks: Array = []
	for id in available:
		var def = tech_defs.get(id, {})
		if def.has("unlock_build"):
			unlocks.append(id)
	if not unlocks.is_empty():
		var unlock_pick = _pick_weighted_id(unlocks)
		picks.append(unlock_pick)
		available.erase(unlock_pick)
	var remaining = 3 - picks.size()
	if remaining > 0:
		picks += _pick_weighted_choices(available, remaining)
	for id in picks:
		var def: Dictionary = tech_defs.get(id, {})
		tech_choices.append({
			"id": id,
			"name": def.get("name", id),
			"desc": def.get("desc", ""),
			"icon": def.get("icon", ""),
			"rarity": def.get("rarity", "common")
		})
	tech_open = true
	if ui.has_method("show_tech"):
		ui.show_tech(tech_choices)
	Engine.time_scale = 0.0

func _choose_tech(index: int) -> void:
	if index < 0 or index >= tech_choices.size():
		return
	var choice: Dictionary = tech_choices[index]
	var id: String = str(choice.get("id", ""))
	if id == "":
		return
	_apply_tech(id)
	tech_open = false
	if ui.has_method("hide_tech"):
		ui.hide_tech()
	Engine.time_scale = 1.0
	pending_picks = max(0, pending_picks - 1)
	if pending_picks > 0:
		_open_tech_menu()

func _apply_tech(id: String) -> void:
	tech_levels[id] = int(tech_levels.get(id, 0)) + 1
	var def: Dictionary = tech_defs.get(id, {})
	if def.has("unlock_build"):
		var build_id = str(def.get("unlock_build", ""))
		unlock_build(build_id)
		if build_manager != null and build_manager.has_method("refresh_controls"):
			build_manager.refresh_controls()
		_refresh_build_palette()
	if id == "tower_range":
		tower_range_mult = 1.0 + 0.12 * tech_levels[id]
	if id == "tower_damage":
		tower_damage_bonus = 2.0 * tech_levels[id]
	if player != null and player.has_method("apply_gun_tech"):
		player.apply_gun_tech(id, tech_levels[id])

func register_building_effect(effect: String, source_id: int, value: float) -> void:
	if not building_effects.has(effect):
		return
	building_effects[effect][source_id] = value
	_recalc_effects()

func unregister_building_effect(effect: String, source_id: int) -> void:
	if not building_effects.has(effect):
		return
	building_effects[effect].erase(source_id)
	_recalc_effects()

func _recalc_effects() -> void:
	player_damage_bonus = 0.0
	tower_rate_mult = 1.0
	for value in building_effects["armory_damage"].values():
		player_damage_bonus += float(value)
	var rate_bonus = 0.0
	for value in building_effects["tech_rate"].values():
		rate_bonus += float(value)
	tower_rate_mult = 1.0 + rate_bonus
	if player != null and player.has_method("apply_global_bonuses"):
		player.apply_global_bonuses(player_damage_bonus)

func get_tower_rate_mult() -> float:
	return tower_rate_mult

func get_tower_damage_bonus() -> float:
	return tower_damage_bonus

func get_tower_range_mult() -> float:
	return tower_range_mult

func _get_available_tech_ids() -> Array:
	var available: Array = []
	for id in tech_defs.keys():
		var def: Dictionary = tech_defs[id]
		var min_level = int(def.get("min_level", 1))
		if level < min_level:
			continue
		if def.has("unlock_build"):
			var build_id = str(def.get("unlock_build", ""))
			if is_build_unlocked(build_id):
				continue
		if def.has("requires_build"):
			var req = str(def.get("requires_build", ""))
			if not is_build_unlocked(req):
				continue
		var max_level = int(def.get("max", 1))
		var current = int(tech_levels.get(id, 0))
		if current < max_level:
			available.append(id)
	return available

func _update_ui() -> void:
	if ui.has_method("set_resources"):
		ui.set_resources(resources)
	if ui.has_method("set_time"):
		ui.set_time(elapsed)
	if ui.has_method("set_level"):
		ui.set_level(level, xp, xp_next)
	if player != null and ui.has_method("set_health"):
		ui.set_health(player.health, player.max_health)

func _refresh_build_palette() -> void:
	if ui == null:
		return
	var active_id = ""
	if build_manager != null and "current_id" in build_manager:
		active_id = build_manager.current_id
	if ui.has_method("update_palette"):
		ui.update_palette(unlocked_builds, active_id)

func heal_player(amount: float) -> void:
	if player == null:
		return
	if player.has_method("heal"):
		player.heal(amount)
	_update_ui()

func on_player_death() -> void:
	if game_over:
		return
	game_over = true
	Engine.time_scale = 1.0
	if ui.has_method("set_selection"):
		ui.set_selection("Game Over - Esc to exit")

func _spawn_initial_breakables() -> void:
	for i in range(breakable_target):
		spawn_breakable()

func _spawn_props() -> void:
	if props_root == null:
		return
	var textures: Array = []
	for path in PROP_PATHS:
		if ResourceLoader.exists(path):
			textures.append(load(path))
	if textures.is_empty():
		return
	for i in range(prop_count):
		var sprite = Sprite2D.new()
		sprite.texture = textures[randi_range(0, textures.size() - 1)]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -2
		var pos = Vector2.ZERO
		for attempt in range(6):
			var angle = randf() * TAU
			var distance = randf_range(prop_min_distance, prop_spawn_radius)
			pos = Vector2.RIGHT.rotated(angle) * distance
		sprite.global_position = pos
		props_root.add_child(sprite)

func _maintain_breakables() -> void:
	if breakables_root == null:
		return
	if breakables_root.get_child_count() >= breakable_target:
		return
	if randf() < 0.1:
		spawn_breakable()

func spawn_breakable() -> void:
	if player == null or breakables_root == null:
		return
	var breakable = BREAKABLE_SCENE.instantiate()
	var angle = randf() * TAU
	var distance = randf_range(breakable_spawn_min, breakable_spawn_max)
	breakable.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
	var chest = randf() < 0.18
	var value = 0
	var xp_amount = 0
	var style = "small"
	if chest:
		value = randi_range(14, 22)
		xp_amount = randi_range(6, 10)
		style = "large"
	else:
		value = randi_range(4, 8)
		xp_amount = randi_range(2, 3)
		var roll = randf()
		if roll < 0.25:
			style = "skull"
		elif roll < 0.5:
			style = "fence"
		elif roll < 0.7:
			style = "pillar"
	if breakable.has_method("setup"):
		breakable.setup(self, value, xp_amount, style, chest)
	breakables_root.add_child(breakable)

func _ensure_input_map() -> void:
	_ensure_action("start_game", [KEY_ENTER, KEY_SPACE])
	_ensure_action("move_up", [KEY_W, KEY_UP])
	_ensure_action("move_down", [KEY_S, KEY_DOWN])
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("build_toggle", [KEY_B])
	_ensure_action("build_1", [KEY_1])
	_ensure_action("build_2", [KEY_2])
	_ensure_action("build_3", [KEY_3])
	_ensure_action("build_4", [KEY_4])
	_ensure_action("build_5", [KEY_5])
	_ensure_action("build_6", [KEY_6])
	_ensure_action("build_7", [KEY_7])
	_ensure_action("build_8", [KEY_8])
	_ensure_action("build_9", [KEY_9])
	_ensure_action("build_barracks", [KEY_Q])
	_ensure_action("build_armory", [KEY_E])
	_ensure_action("build_tech_lab", [KEY_R])
	_ensure_action("build_shrine", [KEY_T])
	_ensure_action("upgrade", [KEY_U])
	_ensure_action("toggle_gate", [KEY_G])
	_ensure_action("cancel", [KEY_ESCAPE])

func _ensure_action(name: String, keys: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	for key in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(name, ev)
