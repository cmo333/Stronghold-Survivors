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
const ALLY_SCENE = preload("res://scenes/allies/ally_unit.tscn")
const FeedbackConfig = preload("res://scripts/feedback_config.gd")

@onready var player: CharacterBody2D = $World/Player
@onready var enemies_root: Node2D = $World/Enemies
@onready var allies_root: Node2D = get_node_or_null("World/Allies")
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
var max_enemies_cap = 180
var max_projectiles = 240
var elite_health_mult = 2.2
var max_allies = 16

# Data-driven pacing curve (interpolated between points).
const SPAWN_CURVE = [
	{"time": 0.0, "interval": 1.6, "max_enemies": 8, "difficulty": 1.0, "elite": 0.01, "siege": 0.0},
	{"time": 30.0, "interval": 1.35, "max_enemies": 12, "difficulty": 1.08, "elite": 0.015, "siege": 0.0},
	{"time": 60.0, "interval": 1.15, "max_enemies": 18, "difficulty": 1.2, "elite": 0.02, "siege": 0.03},
	{"time": 120.0, "interval": 0.9, "max_enemies": 28, "difficulty": 1.4, "elite": 0.03, "siege": 0.07},
	{"time": 180.0, "interval": 0.74, "max_enemies": 42, "difficulty": 1.6, "elite": 0.045, "siege": 0.12},
	{"time": 240.0, "interval": 0.62, "max_enemies": 58, "difficulty": 1.85, "elite": 0.06, "siege": 0.18},
	{"time": 300.0, "interval": 0.54, "max_enemies": 78, "difficulty": 2.1, "elite": 0.075, "siege": 0.24},
	{"time": 420.0, "interval": 0.48, "max_enemies": 110, "difficulty": 2.45, "elite": 0.095, "siege": 0.3},
	{"time": 540.0, "interval": 0.44, "max_enemies": 145, "difficulty": 2.8, "elite": 0.12, "siege": 0.34},
	{"time": 660.0, "interval": 0.41, "max_enemies": 170, "difficulty": 3.1, "elite": 0.14, "siege": 0.35}
]

const ENEMY_POOLS = [
	{
		"time": 0.0,
		"weights": [
			[ENEMY_SCENE, 100]
		]
	},
	{
		"time": 45.0,
		"weights": [
			[ENEMY_SCENE, 60],
			[CHARGER_SCENE, 22],
			[HELLHOUND_SCENE, 18]
		]
	},
	{
		"time": 90.0,
		"weights": [
			[ENEMY_SCENE, 40],
			[CHARGER_SCENE, 16],
			[HELLHOUND_SCENE, 14],
			[SPITTER_SCENE, 16],
			[BANSHEE_SCENE, 14]
		]
	},
	{
		"time": 150.0,
		"weights": [
			[ENEMY_SCENE, 28],
			[CHARGER_SCENE, 12],
			[HELLHOUND_SCENE, 10],
			[SPITTER_SCENE, 14],
			[BANSHEE_SCENE, 10],
			[FIEND_DUELIST_SCENE, 10],
			[HEALER_SCENE, 8],
			[NECROMANCER_SCENE, 8]
		]
	},
	{
		"time": 210.0,
		"weights": [
			[ENEMY_SCENE, 20],
			[CHARGER_SCENE, 10],
			[HELLHOUND_SCENE, 8],
			[SPITTER_SCENE, 12],
			[BANSHEE_SCENE, 8],
			[FIEND_DUELIST_SCENE, 10],
			[HEALER_SCENE, 10],
			[NECROMANCER_SCENE, 10],
			[PLAGUE_ABOMINATION_SCENE, 12]
		]
	},
	{
		"time": 300.0,
		"weights": [
			[ENEMY_SCENE, 16],
			[CHARGER_SCENE, 10],
			[HELLHOUND_SCENE, 8],
			[SPITTER_SCENE, 12],
			[BANSHEE_SCENE, 8],
			[FIEND_DUELIST_SCENE, 10],
			[HEALER_SCENE, 12],
			[NECROMANCER_SCENE, 12],
			[PLAGUE_ABOMINATION_SCENE, 12]
		]
	}
]

var breakable_target = 18
var breakable_spawn_min = 240.0
var breakable_spawn_max = 920.0

var prop_spawn_radius = 1600.0
var prop_min_distance = 120.0
var prop_count = 90
var cluster_count = 8
var cluster_min_distance = 260.0

const PROP_PATHS = [
	"res://assets/level1/level1_props/prop_graveyard_broken_fence_32_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_bone_pile_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_broken_cart_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_broken_pillar_48_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_crates_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_dead_tree_stump_48_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_lantern_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_ruined_pillar_48_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_skull_cairn_32_v001.png",
	"res://assets/level1/level1_props/prop_graveyard_skull_pile_32_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_tombstone_large_48_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_tombstone_small_32_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_tombstone_tall_48_v001.png"
]

const CLUSTER_PATHS = [
	"res://assets/level1/level1_props/prop_graveyard_cluster_collapsed_crypt_96_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_cluster_fallen_angel_memorial_96_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_cluster_gravedigger_camp_96_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_cluster_ritual_circle_96_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_cluster_family_plot_96_v002.png",
	"res://assets/level1/level1_props/prop_graveyard_cluster_mass_grave_96_v002.png"
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
		"fps": 18.0,
		"lifetime": 0.2,
		"scale": 1.25,
		"alpha": 0.9,
		"z": 2
	},
	"crit": {
		"paths": [
			"res://assets/fx/fx_explosion_small_32_f001_v002.png",
			"res://assets/fx/fx_explosion_small_32_f002_v002.png",
			"res://assets/fx/fx_explosion_small_32_f003_v002.png",
			"res://assets/fx/fx_explosion_small_32_f004_v002.png"
		],
		"fps": 20.0,
		"lifetime": 0.24,
		"scale": 1.6,
		"alpha": 0.95,
		"z": 3
	},
	"chain_hit": {
		"paths": [
			"res://assets/fx/fx_shock_ring_32_f001_v001.png",
			"res://assets/fx/fx_shock_ring_32_f002_v001.png",
			"res://assets/fx/fx_shock_ring_32_f003_v001.png",
			"res://assets/fx/fx_shock_ring_32_f004_v001.png"
		],
		"fps": 16.0,
		"lifetime": 0.22,
		"scale": 1.1,
		"alpha": 0.9,
		"z": 2
	},
	"kill_pop": {
		"paths": [
			"res://assets/fx/fx_blood_splash_32_f001_v001.png",
			"res://assets/fx/fx_blood_splash_32_f002_v001.png",
			"res://assets/fx/fx_blood_splash_32_f003_v001.png",
			"res://assets/fx/fx_blood_splash_32_f004_v001.png"
		],
		"fps": 16.0,
		"lifetime": 0.28,
		"scale": 1.7,
		"alpha": 0.95,
		"z": 2
	},
	"elite_kill": {
		"paths": [
			"res://assets/fx/fx_explosion_small_32_f001_v002.png",
			"res://assets/fx/fx_explosion_small_32_f002_v002.png",
			"res://assets/fx/fx_explosion_small_32_f003_v002.png",
			"res://assets/fx/fx_explosion_small_32_f004_v002.png"
		],
		"fps": 16.0,
		"lifetime": 0.3,
		"scale": 2.1,
		"alpha": 1.0,
		"z": 3
	},
	"build": {
		"paths": [
			"res://assets/fx/fx_hit_spark_16_f001_v001.png",
			"res://assets/fx/fx_hit_spark_16_f002_v001.png",
			"res://assets/fx/fx_hit_spark_16_f003_v001.png",
			"res://assets/fx/fx_hit_spark_16_f004_v001.png"
		],
		"fps": 16.0,
		"lifetime": 0.25,
		"scale": 1.4,
		"alpha": 0.9,
		"z": 3,
		"tint": Color(1.0, 0.85, 0.4)
	},
	"explosion": {
		"paths": [
			"res://assets/fx/fx_explosion_small_32_f001_v002.png",
			"res://assets/fx/fx_explosion_small_32_f002_v002.png",
			"res://assets/fx/fx_explosion_small_32_f003_v002.png",
			"res://assets/fx/fx_explosion_small_32_f004_v002.png"
		],
		"fps": 16.0,
		"lifetime": 0.28,
		"scale": 1.35,
		"alpha": 0.85,
		"z": -1
	},
	"acid": {
		"paths": [
			"res://assets/fx/fx_acid_burst_64_f001_v001.png",
			"res://assets/fx/fx_acid_burst_64_f002_v001.png",
			"res://assets/fx/fx_acid_burst_64_f003_v001.png",
			"res://assets/fx/fx_acid_burst_64_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.4,
		"scale": 1.05,
		"alpha": 0.55,
		"z": -2
	},
	"ice": {
		"paths": [
			"res://assets/fx/fx_ice_field_64_f001_v001.png",
			"res://assets/fx/fx_ice_field_64_f002_v001.png",
			"res://assets/fx/fx_ice_field_64_f003_v001.png",
			"res://assets/fx/fx_ice_field_64_f004_v001.png"
		],
		"fps": 8.0,
		"lifetime": 0.6,
		"scale": 1.0,
		"alpha": 0.5,
		"z": -2
	},
	"stun": {
		"paths": [
			"res://assets/fx/fx_stun_star_16_f001_v001.png",
			"res://assets/fx/fx_stun_star_16_f002_v001.png",
			"res://assets/fx/fx_stun_star_16_f003_v001.png",
			"res://assets/fx/fx_stun_star_16_f004_v001.png"
		],
		"fps": 14.0,
		"lifetime": 0.25,
		"scale": 1.2,
		"alpha": 0.9,
		"z": 3
	},
	"tesla": {
		"paths": [
			"res://assets/fx/fx_tesla_arc_32_f001_v002.png",
			"res://assets/fx/fx_tesla_arc_32_f002_v002.png",
			"res://assets/fx/fx_tesla_arc_32_f003_v002.png",
			"res://assets/fx/fx_tesla_arc_32_f004_v002.png"
		],
		"fps": 16.0,
		"lifetime": 0.2,
		"scale": 1.15,
		"alpha": 0.85,
		"z": 2
	},
	"summon_shadow": {
		"paths": [
			"res://assets/fx/fx_shadow_puff_64_f001_v002.png",
			"res://assets/fx/fx_shadow_puff_64_f002_v002.png",
			"res://assets/fx/fx_shadow_puff_64_f003_v002.png",
			"res://assets/fx/fx_shadow_puff_64_f004_v002.png"
		],
		"fps": 12.0,
		"lifetime": 0.35,
		"scale": 1.35,
		"alpha": 0.9,
		"z": 1
	},
	"summon_fire": {
		"paths": [
			"res://assets/fx/fx_fire_burst_64_f001_v002.png",
			"res://assets/fx/fx_fire_burst_64_f002_v002.png",
			"res://assets/fx/fx_fire_burst_64_f003_v002.png",
			"res://assets/fx/fx_fire_burst_64_f004_v002.png"
		],
		"fps": 12.0,
		"lifetime": 0.35,
		"scale": 1.45,
		"alpha": 0.95,
		"z": 1
	},
	"ally_slash": {
		"paths": [
			"res://assets/fx/fx_slash_arc_32_f001_v002.png",
			"res://assets/fx/fx_slash_arc_32_f002_v002.png",
			"res://assets/fx/fx_slash_arc_32_f003_v002.png",
			"res://assets/fx/fx_slash_arc_32_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.22,
		"scale": 1.2,
		"alpha": 0.9,
		"z": 2
	},
	"ally_lightning": {
		"paths": [
			"res://assets/fx/fx_lightning_zap_32_f001_v002.png",
			"res://assets/fx/fx_lightning_zap_32_f002_v002.png",
			"res://assets/fx/fx_lightning_zap_32_f003_v002.png",
			"res://assets/fx/fx_lightning_zap_32_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.22,
		"scale": 1.2,
		"alpha": 0.95,
		"z": 2
	},
	"poison": {
		"paths": [
			"res://assets/fx/fx_poison_cloud_64_f001_v001.png",
			"res://assets/fx/fx_poison_cloud_64_f002_v001.png",
			"res://assets/fx/fx_poison_cloud_64_f003_v001.png",
			"res://assets/fx/fx_poison_cloud_64_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.5,
		"scale": 1.05,
		"alpha": 0.55,
		"z": -2
	},
	"necrotic": {
		"paths": [
			"res://assets/fx/fx_necrotic_pulse_64_f001_v001.png",
			"res://assets/fx/fx_necrotic_pulse_64_f002_v001.png",
			"res://assets/fx/fx_necrotic_pulse_64_f003_v001.png",
			"res://assets/fx/fx_necrotic_pulse_64_f004_v001.png"
		],
		"fps": 10.0,
		"lifetime": 0.5,
		"scale": 1.05,
		"alpha": 0.55,
		"z": -2
	},
	"blood": {
		"paths": [
			"res://assets/fx/fx_blood_splat_32_f001_v002.png",
			"res://assets/fx/fx_blood_splat_32_f002_v002.png",
			"res://assets/fx/fx_blood_splat_32_f003_v002.png",
			"res://assets/fx/fx_blood_splat_32_f004_v002.png"
		],
		"fps": 16.0,
		"lifetime": 0.28,
		"scale": 1.6,
		"alpha": 0.95,
		"z": 1
	},
	"fire": {
		"paths": [
			"res://assets/fx/fx_fire_burst_32_f001_v002.png",
			"res://assets/fx/fx_fire_burst_32_f002_v002.png",
			"res://assets/fx/fx_fire_burst_32_f003_v002.png",
			"res://assets/fx/fx_fire_burst_32_f004_v002.png"
		],
		"fps": 14.0,
		"lifetime": 0.3,
		"scale": 1.2,
		"alpha": 0.8,
		"z": 1
	},
	"ghost": {
		"paths": [
			"res://assets/fx/fx_ghost_trail_32_f001_v001.png",
			"res://assets/fx/fx_ghost_trail_32_f002_v001.png",
			"res://assets/fx/fx_ghost_trail_32_f003_v001.png",
			"res://assets/fx/fx_ghost_trail_32_f004_v001.png"
		],
		"fps": 12.0,
		"lifetime": 0.4,
		"scale": 1.1,
		"alpha": 0.65,
		"z": -1
	}
}

var _damage_number_window_ms = 0
var _damage_number_budget = FeedbackConfig.DAMAGE_NUMBER_BUDGET_PER_SEC
var _damage_font: Font = null

func _ready() -> void:
	randomize()
	add_to_group("game")
	_ensure_input_map()
	_load_damage_font()
	if allies_root == null:
		allies_root = Node2D.new()
		allies_root.name = "Allies"
		$World.add_child(allies_root)
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

func _get_spawn_settings(time_sec: float) -> Dictionary:
	if SPAWN_CURVE.is_empty():
		return {
			"interval": 1.2,
			"max_enemies": 12,
			"difficulty": 1.0,
			"elite": 0.02,
			"siege": 0.0
		}
	var prev = SPAWN_CURVE[0]
	var prev_time = float(prev.get("time", 0.0))
	if time_sec <= prev_time:
		return {
			"interval": float(prev.get("interval", 1.2)),
			"max_enemies": int(prev.get("max_enemies", 12)),
			"difficulty": float(prev.get("difficulty", 1.0)),
			"elite": float(prev.get("elite", 0.02)),
			"siege": float(prev.get("siege", 0.0))
		}
	for i in range(1, SPAWN_CURVE.size()):
		var next = SPAWN_CURVE[i]
		var next_time = float(next.get("time", 0.0))
		if time_sec <= next_time:
			var t = 0.0
			if next_time > prev_time:
				t = clamp((time_sec - prev_time) / (next_time - prev_time), 0.0, 1.0)
			return {
				"interval": lerp(float(prev.get("interval", 1.2)), float(next.get("interval", 1.2)), t),
				"max_enemies": int(round(lerp(float(prev.get("max_enemies", 12)), float(next.get("max_enemies", 12)), t))),
				"difficulty": lerp(float(prev.get("difficulty", 1.0)), float(next.get("difficulty", 1.0)), t),
				"elite": lerp(float(prev.get("elite", 0.02)), float(next.get("elite", 0.02)), t),
				"siege": lerp(float(prev.get("siege", 0.0)), float(next.get("siege", 0.0)), t)
			}
		prev = next
		prev_time = next_time
	var last = SPAWN_CURVE[SPAWN_CURVE.size() - 1]
	return {
		"interval": float(last.get("interval", 1.2)),
		"max_enemies": int(last.get("max_enemies", 12)),
		"difficulty": float(last.get("difficulty", 1.0)),
		"elite": float(last.get("elite", 0.02)),
		"siege": float(last.get("siege", 0.0))
	}

func _handle_spawning(delta: float) -> void:
	var settings = _get_spawn_settings(elapsed)
	var interval = max(0.35, float(settings.get("interval", 1.2)))
	spawn_accumulator += delta
	while spawn_accumulator >= interval:
		spawn_accumulator -= interval
		var max_enemies = min(max_enemies_cap, int(settings.get("max_enemies", max_enemies_cap)))
		if enemies_root.get_child_count() >= max_enemies:
			break
		spawn_enemy(settings)

func spawn_enemy(settings: Dictionary = {}) -> void:
	if player == null:
		return
	var spawn_settings = settings
	if spawn_settings.is_empty():
		spawn_settings = _get_spawn_settings(elapsed)
	var siege_chance = clamp(float(spawn_settings.get("siege", 0.0)), 0.0, 0.35)
	var scene = _pick_enemy_scene()
	if randf() < siege_chance:
		scene = SIEGE_ENEMY_SCENE
	var enemy = scene.instantiate()
	var angle = randf() * TAU
	var distance = randf_range(spawn_radius_min, spawn_radius_max)
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
	var difficulty = float(spawn_settings.get("difficulty", 1.0))
	if enemy.has_method("setup"):
		enemy.setup(self, difficulty)
	var elite_chance = clamp(float(spawn_settings.get("elite", 0.0)), 0.0, 0.2)
	if randf() < elite_chance and enemy.has_method("set_elite"):
		enemy.set_elite(elite_health_mult)
	enemies_root.add_child(enemy)

func spawn_minion(position: Vector2) -> void:
	if enemies_root.get_child_count() >= max_enemies_cap:
		return
	var enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	var difficulty = float(_get_spawn_settings(elapsed).get("difficulty", 1.0))
	if enemy.has_method("setup"):
		enemy.setup(self, difficulty)
	enemies_root.add_child(enemy)

func spawn_ally(config: Dictionary, position: Vector2) -> void:
	if allies_root == null:
		return
	if allies_root.get_child_count() >= max_allies:
		return
	var ally = ALLY_SCENE.instantiate()
	ally.global_position = position
	var body = ally.get_node_or_null("Body")
	if body != null:
		if config.has("frame_paths"):
			body.frame_paths = config.get("frame_paths", [])
		if config.has("fps"):
			body.fps = float(config.get("fps", 8.0))
		body.loop = true
		body.auto_play = true
	allies_root.add_child(ally)
	if ally.has_method("setup"):
		ally.setup(self, config)
	var fx_kind = str(config.get("spawn_fx", ""))
	if fx_kind != "" and has_method("spawn_fx"):
		spawn_fx(fx_kind, position)

func _pick_enemy_scene() -> PackedScene:
	var pool: Array = []
	for entry in ENEMY_POOLS:
		if elapsed >= float(entry.get("time", 0.0)):
			pool = entry.get("weights", pool)
		else:
			break
	if pool.is_empty():
		return ENEMY_SCENE
	return _weighted_pick(pool)

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

func spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, explosion_radius: float, pierce: int = 0, slow_factor: float = 1.0, slow_duration: float = 0.0, damage_type: String = "normal") -> void:
	if projectiles_root.get_child_count() >= max_projectiles:
		return
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = origin
	if projectile.has_method("setup"):
		projectile.setup(self, direction, speed, damage, max_range, explosion_radius, pierce, slow_factor, slow_duration, damage_type)
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
		var tint = def.get("tint", Color.WHITE)
		fx.setup(
			def.get("paths", []),
			float(def.get("fps", 10.0)),
			float(def.get("lifetime", 0.35)),
			false,
			float(def.get("scale", 1.0)),
			float(def.get("alpha", 1.0)),
			int(def.get("z", 0)),
			tint
		)
	fx_root.add_child(fx)

func spawn_damage_number(amount: float, position: Vector2, target_max: float = 0.0, is_crit: bool = false, is_kill: bool = false, is_elite: bool = false, damage_type: String = "normal") -> void:
	if not FeedbackConfig.ENABLE_DAMAGE_NUMBERS:
		return
	if amount < FeedbackConfig.DAMAGE_NUMBER_MIN:
		return
	if fx_root == null:
		return
	if not _consume_damage_number_budget():
		return

	var label = Label.new()
	label.text = str(int(round(amount)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	_apply_damage_label_style(label, is_crit, is_kill, damage_type)
	label.size = label.get_minimum_size()
	label.position = -label.size * 0.5

	var container = Node2D.new()
	var jitter = Vector2(
		randf_range(-FeedbackConfig.DAMAGE_NUMBER_JITTER_X, FeedbackConfig.DAMAGE_NUMBER_JITTER_X),
		randf_range(-FeedbackConfig.DAMAGE_NUMBER_JITTER_Y, FeedbackConfig.DAMAGE_NUMBER_JITTER_Y)
	)
	container.position = position + jitter
	container.z_index = 30
	fx_root.add_child(container)
	container.add_child(label)

	var health_ratio = 0.0
	if target_max > 0.0:
		health_ratio = clamp(amount / target_max, 0.0, 1.0)
	var base_scale = lerp(FeedbackConfig.DAMAGE_NUMBER_SCALE_MIN, FeedbackConfig.DAMAGE_NUMBER_SCALE_MAX, health_ratio)
	if is_elite:
		base_scale += FeedbackConfig.DAMAGE_NUMBER_ELITE_SCALE_BONUS
	if is_crit:
		base_scale += FeedbackConfig.DAMAGE_NUMBER_CRIT_SCALE_BONUS
	if is_kill:
		base_scale += FeedbackConfig.DAMAGE_NUMBER_KILL_SCALE_BONUS

	var rise = FeedbackConfig.DAMAGE_NUMBER_RISE
	var lifetime = FeedbackConfig.DAMAGE_NUMBER_LIFETIME
	var pop_start = FeedbackConfig.DAMAGE_NUMBER_POP_START
	var pop_time = FeedbackConfig.DAMAGE_NUMBER_POP_TIME
	if damage_type == "dot":
		rise = FeedbackConfig.DAMAGE_NUMBER_DOT_RISE
		lifetime = FeedbackConfig.DAMAGE_NUMBER_DOT_LIFETIME
		pop_start = FeedbackConfig.DAMAGE_NUMBER_DOT_POP_START
		pop_time = FeedbackConfig.DAMAGE_NUMBER_DOT_POP_TIME
	if is_crit:
		rise = FeedbackConfig.DAMAGE_NUMBER_CRIT_RISE
		lifetime = FeedbackConfig.DAMAGE_NUMBER_CRIT_LIFETIME
		pop_start = FeedbackConfig.DAMAGE_NUMBER_CRIT_POP_START
		pop_time = FeedbackConfig.DAMAGE_NUMBER_CRIT_POP_TIME
	container.scale = Vector2.ONE * base_scale * pop_start
	if is_crit:
		container.rotation = randf_range(-FeedbackConfig.DAMAGE_NUMBER_ROTATION_MAX, FeedbackConfig.DAMAGE_NUMBER_ROTATION_MAX)

	var tween = container.create_tween()
	tween.tween_property(container, "scale", Vector2.ONE * base_scale, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "position", container.position + Vector2(0, -rise), lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", Color(1.0, 1.0, 1.0, 0.0), lifetime)
	if is_crit:
		tween.parallel().tween_property(container, "rotation", 0.0, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(container.queue_free)

func _load_damage_font() -> void:
	var path = FeedbackConfig.DAMAGE_NUMBER_FONT_PATH
	if path == "":
		return
	if not ResourceLoader.exists(path):
		return
	var font = load(path)
	if font is Font:
		_damage_font = font

func _apply_damage_label_style(label: Label, is_crit: bool, is_kill: bool, damage_type: String) -> void:
	if label == null:
		return
	if _damage_font != null:
		label.add_theme_font_override("font", _damage_font)
	label.add_theme_font_size_override("font_size", FeedbackConfig.DAMAGE_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", FeedbackConfig.DAMAGE_NUMBER_OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", FeedbackConfig.DAMAGE_NUMBER_OUTLINE_SIZE)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var color = FeedbackConfig.DAMAGE_TYPE_COLORS.get(damage_type, FeedbackConfig.DAMAGE_COLOR_NORMAL)
	if is_kill:
		color = FeedbackConfig.DAMAGE_COLOR_KILL
	if is_crit:
		color = FeedbackConfig.DAMAGE_COLOR_CRIT
		label.add_theme_font_size_override("font_size", FeedbackConfig.DAMAGE_NUMBER_CRIT_FONT_SIZE)
	label.add_theme_color_override("font_color", color)

func _consume_damage_number_budget() -> bool:
	var now_ms = Time.get_ticks_msec()
	if now_ms - _damage_number_window_ms > 1000:
		_damage_number_window_ms = now_ms
		_damage_number_budget = FeedbackConfig.DAMAGE_NUMBER_BUDGET_PER_SEC
	if _damage_number_budget <= 0:
		return false
	_damage_number_budget -= 1
	return true

func damage_enemies_in_radius(position: Vector2, radius: float, damage: float, siege_bonus: float = 1.0, damage_type: String = "normal") -> void:
	var radius_sq = radius * radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_squared_to(position) <= radius_sq:
			var final_damage = damage
			if siege_bonus != 1.0 and enemy.has_method("is_siege_unit") and enemy.is_siege_unit():
				final_damage = damage * siege_bonus
			if enemy.has_method("take_damage"):
				enemy.take_damage(final_damage, enemy.global_position, false, true, damage_type)

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
	if FeedbackConfig.ENABLE_DEATH_FEEDBACK and player != null and has_method("spawn_fx"):
		spawn_fx("ghost", player.global_position)
		spawn_fx("blood", player.global_position)
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
	_spawn_clusters()

func _spawn_clusters() -> void:
	if props_root == null:
		return
	var textures: Array = []
	for path in CLUSTER_PATHS:
		if ResourceLoader.exists(path):
			textures.append(load(path))
	if textures.is_empty():
		return
	for i in range(cluster_count):
		var sprite = Sprite2D.new()
		sprite.texture = textures[randi_range(0, textures.size() - 1)]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = -2
		var pos = Vector2.ZERO
		for attempt in range(8):
			var angle = randf() * TAU
			var distance = randf_range(cluster_min_distance, prop_spawn_radius)
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
	var chest = randf() < 0.28
	var value = 0
	var xp_amount = 0
	var style = "small"
	if chest:
		value = randi_range(18, 28)
		xp_amount = randi_range(8, 12)
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
