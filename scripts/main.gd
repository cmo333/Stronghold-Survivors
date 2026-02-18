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
const GLOW_PARTICLE_SCRIPT = preload("res://scripts/glow_particle.gd")
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const ENEMY_PROJECTILE_SCENE = preload("res://scenes/enemy_projectile.tscn")
const PICKUP_SCENE = preload("res://scenes/pickup.tscn")
const BREAKABLE_SCENE = preload("res://scenes/breakable.tscn")
const TREASURE_CHEST_SCENE = preload("res://scenes/treasure_chest.tscn")
const POWER_UP_SCENE = preload("res://scenes/power_up.tscn")
const DEATH_STATS_SCENE = preload("res://scenes/death_stats_screen.tscn")
const ALLY_SCENE = preload("res://scenes/allies/ally_unit.tscn")
const GAME_OVER_SCENE = preload("res://scenes/game_over.tscn")
const FeedbackConfig = preload("res://scripts/feedback_config.gd")
const WaveManager = preload("res://scripts/wave_manager.gd")
const FXManager = preload("res://scripts/fx_manager.gd")
const Minimap = preload("res://scripts/minimap.gd")

@onready var player: CharacterBody2D = $World/Player
@onready var camera: Camera2D = $World/Player/Camera2D
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
@onready var game_over_ui: CanvasLayer = null

# FX Manager
var fx_manager: FXManager = null
var minimap: Control = null

# Game state
var resources: int = 0
var essence: int = 0
var elapsed: float = 0.0
var spawn_accumulator: float = 0.0
var game_over = false
var game_started = false
var start_timer = 0.0
var spawn_delay = 10.0
var auto_start_delay = 2.0
var _enemy_kill_count = 0
var _time_scale_tween: Tween = null
var _last_minute_announcement: int = -1
var _essence_tip_shown: bool = false

# Cached enemy list — updated once per frame, used by all towers
var cached_enemies: Array = []

# Stats tracking
var _total_damage_dealt: float = 0.0
var _towers_built: int = 0
var _generators_lost: int = 0
var _current_streak: int = 0
var _best_streak: int = 0
var _wave_reached: int = 1
var _gold_earned: int = 0

# History for charts
var _damage_history: Array = []  # Damage dealt per 10-second interval
var _enemy_kill_history: Array = []  # Kills per 10-second interval
var _history_timer: float = 0.0
var _history_interval: float = 10.0
var _interval_damage: float = 0.0
var _interval_kills: int = 0

# Record tracking
var _best_time: float = 0.0
var _best_kills: int = 0
var _is_new_record: bool = false

# Death stats screen
var death_stats_screen = null

var xp = 0
var level = 1
var xp_next = 12
var pending_picks = 0
var tech_open = false
var tech_choices: Array = []
var tech_levels: Dictionary = {}
var unlocked_builds: Dictionary = {
	"arrow_turret": true
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
var chest_damage_bonus = 0.0
var chest_speed_bonus = 0.0
var chest_max_hp_bonus = 0.0
var chest_tower_range_mult = 1.0
var build_cost_mult = 1.0

# Chest upgrade system - new stats
var reload_speed_mult = 1.0
var crit_chance_bonus = 0.0
var crit_damage_mult = 1.0
var pierce_bonus = 0
var cooldown_mult = 1.0
var pickup_range_mult = 1.0

# Epic upgrades
var has_multishot = false
var multishot_count = 0
var has_explosive = false
var explosive_radius = 0.0
var has_chain_lightning = false
var chain_lightning_targets = 0
var has_vampiric = false
var vampiric_percent = 0.0

# Diamond upgrades
var has_multishot_split = false
var multishot_split_count = 0
var has_time_dilation = false
var time_dilation_mult = 1.0
var has_phoenix = false
var phoenix_used_this_wave = false
var has_fortress = false
var tower_hp_mult = 1.0
var towers_self_repair = false

var wave_manager: Node = null
var _active_boss: Node = null
var _boss_schedule_index = 0
var _boss_cycle = 0
var _next_boss_time = 0.0
var _boss_warning_shown = false
var _final_boss_spawned = false

var spawn_radius_min = 500.0
var spawn_radius_max = 750.0
var max_enemies_cap_base = 250
var max_enemies_cap = 250
var max_projectiles = 150
var max_particles = 150  # Cap glow particles and FX to prevent memory issues
var elite_health_mult = 2.2
var max_allies = 16
var max_pickups = 60

var chest_drop_chance = 0.35
var chest_drop_cooldown = 18.0
var _next_chest_time = 0.0

var _essence_announce_count = 0
var _essence_announce_timer = 0.0
var _essence_announce_position = Vector2.ZERO

# Generator tracking
var active_generators: Array = []
var generators_destroyed = 0
var total_generator_income = 0

# Resource zone system
var resource_zones: Array = []
const ZONE_COUNT = 5
const ZONE_MIN_DIST = 400.0
const ZONE_MAX_DIST = 2200.0
const ZONE_MIN_SPACING = 500.0
const ResourceZone = preload("res://scripts/resource_zone.gd")

# Power-up spawn system
var powerup_spawn_timer: float = 0.0
var powerup_spawn_interval: float = randf_range(60.0, 90.0)  # 60-90 seconds
var powerup_spawn_min_radius: float = 400.0  # Minimum distance from center
var max_powerups: int = 3

# Data-driven pacing curve (interpolated between points).
const SPAWN_CURVE = [
	{"time": 0.0, "interval": 1.0, "max_enemies": 15, "difficulty": 1.0, "elite": 0.01, "siege": 0.0},
	{"time": 30.0, "interval": 0.8, "max_enemies": 25, "difficulty": 1.08, "elite": 0.02, "siege": 0.0},
	{"time": 60.0, "interval": 0.65, "max_enemies": 40, "difficulty": 1.2, "elite": 0.03, "siege": 0.04},
	{"time": 120.0, "interval": 0.5, "max_enemies": 60, "difficulty": 1.4, "elite": 0.04, "siege": 0.08},
	{"time": 180.0, "interval": 0.42, "max_enemies": 85, "difficulty": 1.6, "elite": 0.055, "siege": 0.14},
	{"time": 240.0, "interval": 0.36, "max_enemies": 110, "difficulty": 1.85, "elite": 0.07, "siege": 0.2},
	{"time": 300.0, "interval": 0.32, "max_enemies": 140, "difficulty": 2.1, "elite": 0.085, "siege": 0.26},
	{"time": 420.0, "interval": 0.28, "max_enemies": 180, "difficulty": 2.45, "elite": 0.1, "siege": 0.32},
	{"time": 540.0, "interval": 0.25, "max_enemies": 220, "difficulty": 2.8, "elite": 0.13, "siege": 0.36},
	{"time": 660.0, "interval": 0.23, "max_enemies": 260, "difficulty": 3.1, "elite": 0.14, "siege": 0.38},
	{"time": 900.0, "interval": 0.2, "max_enemies": 300, "difficulty": 3.45, "elite": 0.15, "siege": 0.4},
	{"time": 1200.0, "interval": 0.18, "max_enemies": 350, "difficulty": 3.9, "elite": 0.16, "siege": 0.42},
	{"time": 1500.0, "interval": 0.16, "max_enemies": 380, "difficulty": 4.4, "elite": 0.17, "siege": 0.44},
	{"time": 1800.0, "interval": 0.15, "max_enemies": 400, "difficulty": 4.9, "elite": 0.18, "siege": 0.46},
	{"time": 2100.0, "interval": 0.14, "max_enemies": 420, "difficulty": 5.4, "elite": 0.18, "siege": 0.48},
	{"time": 2400.0, "interval": 0.13, "max_enemies": 440, "difficulty": 5.9, "elite": 0.19, "siege": 0.5}
]

const BOSS_SCHEDULE = [
	{"time": 300.0, "script": "res://scripts/boss_bone_colossus.gd"},
	{"time": 600.0, "script": "res://scripts/boss_plague_bringer.gd"},
	{"time": 900.0, "script": "res://scripts/boss_siegebreaker.gd"},
	{"time": 1200.0, "script": "res://scripts/boss_lich.gd"},
	{
		"time": 1800.0,
		"script": "res://scripts/boss_siegebreaker.gd",
		"final": true,
		"health_mult": 3.0,
		"speed_mult": 2.4,
		"damage_mult": 1.7,
		"title": "The Endbringer"
	}
]
const BOSS_CYCLE_LENGTH = 1200.0
const BOSS_WARNING_LEAD = 12.0

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
	"upgrade_burst": {
		"paths": [
			"res://assets/fx/fx_shockwave_ring_64_f001_v002.png",
			"res://assets/fx/fx_shockwave_ring_64_f002_v002.png",
			"res://assets/fx/fx_shockwave_ring_64_f003_v002.png",
			"res://assets/fx/fx_shockwave_ring_64_f004_v002.png"
		],
		"fps": 20.0,
		"lifetime": 0.35,
		"scale": 2.0,
		"alpha": 0.8,
		"z": 5,
		"tint": Color(1.0, 0.9, 0.5)
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
	"fire_burst": {
		"paths": [
			"res://assets/fx/fx_hit_spark_16_f001_v001.png",
			"res://assets/fx/fx_hit_spark_16_f002_v001.png",
			"res://assets/fx/fx_hit_spark_16_f003_v001.png"
		],
		"fps": 18.0,
		"lifetime": 0.2,
		"scale": 1.0,
		"alpha": 0.9,
		"z": 1,
		"tint": Color(1.0, 0.4, 0.1, 1.0)
	},
	"shockwave": {
		"paths": [
			"res://assets/fx/fx_shockwave_ring_64_f001_v002.png",
			"res://assets/fx/fx_shockwave_ring_64_f002_v002.png",
			"res://assets/fx/fx_shockwave_ring_64_f003_v002.png",
			"res://assets/fx/fx_shockwave_ring_64_f004_v002.png"
		],
		"fps": 14.0,
		"lifetime": 0.35,
		"scale": 0.7,
		"scale_to": 2.2,
		"alpha": 0.75,
		"fade_out": true,
		"z": -2
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

func _validate_fx_defs() -> void:
	var invalid_kinds: Array[String] = []
	for kind in fx_defs:
		var def = fx_defs[kind]
		var paths = def.get("paths", [])
		var has_valid = false
		for path in paths:
			if ResourceLoader.exists(path):
				has_valid = true
				break
		if not has_valid:
			invalid_kinds.append(kind)
	for kind in invalid_kinds:
		fx_defs.erase(kind)

func _ready() -> void:
	randomize()
	add_to_group("game")
	_ensure_input_map()
	_load_damage_font()
	
	# Initialize audio system
	if camera != null:
		AudioManager.set_camera(camera)
		# Setup dynamic camera controller
		if camera.has_method("setup"):
			camera.setup(player, self)
	
	# Initialize FX Manager
	fx_manager = FXManager.new()
	fx_manager.name = "FXManager"
	add_child(fx_manager)
	fx_manager.setup(self, fx_root)
	_validate_fx_defs()
	if allies_root == null:
		allies_root = Node2D.new()
		allies_root.name = "Allies"
		$World.add_child(allies_root)
	resources = 40
	
	# Initialize game over UI (hidden initially)
	_instantiate_game_over_ui()
	
	_update_ui()
	if ui != null and ui.has_method("show_start"):
		if ui.has_method("set_start_text"):
			ui.set_start_text("Stronghold Survivors", "Choose your hero\n1: Hunter  |  2: Pyromancer\nEnter to begin")
		if ui.has_method("set_start_options"):
			ui.set_start_options(characters, selected_character)
		ui.show_start(true)
	_setup_minimap()
	_apply_base_time_scale()
	if build_manager.has_method("setup"):
		build_manager.setup(self, buildings_root, ui)
	wave_manager = WaveManager.new()
	add_child(wave_manager)
	if wave_manager.has_method("setup"):
		wave_manager.setup(self, ui)
	_spawn_props()
	_spawn_initial_breakables()
	_spawn_environmental_particles()
	_spawn_resource_zones()
	_reset_run_stats()

func _process(delta: float) -> void:
	if game_over:
		_handle_game_over_input()
		return
	if not game_started:
		_handle_start_input(delta)
		return
	if tech_open:
		_handle_tech_input()
	# Camera zoom controls
	_handle_zoom_input()
	start_timer += delta
	if start_timer < spawn_delay:
		return
	elapsed += delta
	_maybe_minute_announcement()
	_update_dynamic_caps()
	# Update cached enemy list once per frame (used by all towers)
	cached_enemies = get_tree().get_nodes_in_group("enemies")
	if wave_manager != null and wave_manager.has_method("update"):
		wave_manager.update(delta, elapsed)
	_handle_boss_spawning(delta)
	_handle_spawning(delta)
	_maintain_breakables()
	_handle_powerup_spawning(delta)  # Power-up spawn logic
	_update_essence_announcement(delta)
	_update_ui()

func _handle_start_input(delta: float) -> void:
	if Input.is_action_just_pressed("build_1"):
		_set_selected_character(0)
	if Input.is_action_just_pressed("build_2"):
		_set_selected_character(1)
	if Input.is_action_just_pressed("start_game"):
		_start_game()

func _handle_zoom_input() -> void:
	if camera == null:
		return
	if Input.is_action_just_pressed("zoom_out"):
		_cycle_zoom(1)  # Zoom out (lower zoom = see more)
	elif Input.is_action_just_pressed("zoom_in"):
		_cycle_zoom(-1)  # Zoom in (higher zoom = see less)

func _cycle_zoom(direction: int) -> void:
	_current_zoom_index = clampi(_current_zoom_index + direction, 0, ZOOM_LEVELS.size() - 1)
	var target_zoom = ZOOM_LEVELS[_current_zoom_index]

	# Kill existing tween if any
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()

	# Smooth zoom transition
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "zoom", target_zoom, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_game() -> void:
	game_started = true
	start_timer = 0.0
	_apply_base_time_scale()
	_apply_selected_character()
	if ui != null and ui.has_method("show_start"):
		ui.show_start(false)
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("SURVIVE", Color(1.0, 1.0, 1.0), 48, 2.4)
	_refresh_build_palette()
	# Audio: Wave/Game start sound
	AudioManager.play_ui_sound("wave_start")

func _setup_minimap() -> void:
	if minimap != null and is_instance_valid(minimap):
		return
	if ui == null:
		return
	minimap = Minimap.new()
	ui.add_child(minimap)
	if minimap.has_method("setup"):
		minimap.setup(self)

func _maybe_minute_announcement() -> void:
	if ui == null or not ui.has_method("show_announcement"):
		return
	var minute = int(floor(elapsed / 60.0))
	if minute <= 0:
		return
	if minute == _last_minute_announcement:
		return
	_last_minute_announcement = minute
	var text = "%d:00" % minute
	ui.show_announcement(text, Color(1.0, 1.0, 1.0, 0.5), 32, 2.0)

func _get_base_time_scale() -> float:
	if not game_started:
		return 0.0
	if game_over:
		return 1.0
	if tech_open:
		return FeedbackConfig.TECH_SLOW_TIME_SCALE
	return 1.0

func _apply_base_time_scale() -> void:
	if _time_scale_tween != null:
		_time_scale_tween.kill()
		_time_scale_tween = null
	Engine.time_scale = _get_base_time_scale()

func _trigger_kill_slow() -> void:
	var base_scale = _get_base_time_scale()
	if base_scale <= 0.0:
		return
	if base_scale <= FeedbackConfig.KILL_SLOW_TIME_SCALE:
		return
	if _time_scale_tween != null:
		_time_scale_tween.kill()
	Engine.time_scale = FeedbackConfig.KILL_SLOW_TIME_SCALE
	_time_scale_tween = create_tween()
	_time_scale_tween.tween_property(Engine, "time_scale", base_scale, FeedbackConfig.KILL_SLOW_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func trigger_time_accent(slow_scale: float, duration: float) -> void:
	"""Generic time dilation for gameplay accents (upgrades, critical hits, etc.)"""
	var base_scale = _get_base_time_scale()
	if base_scale <= 0.0 or base_scale <= slow_scale:
		return
	if _time_scale_tween != null:
		_time_scale_tween.kill()
	Engine.time_scale = slow_scale
	_time_scale_tween = create_tween()
	_time_scale_tween.tween_property(Engine, "time_scale", base_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
		var diff = float(prev.get("difficulty", 1.0)) * _get_threat_multiplier(time_sec)
		return {
			"interval": float(prev.get("interval", 1.2)),
			"max_enemies": int(prev.get("max_enemies", 12)),
			"difficulty": diff,
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
			var diff = lerp(float(prev.get("difficulty", 1.0)), float(next.get("difficulty", 1.0)), t)
			diff *= _get_threat_multiplier(time_sec)
			return {
				"interval": lerp(float(prev.get("interval", 1.2)), float(next.get("interval", 1.2)), t),
				"max_enemies": int(round(lerp(float(prev.get("max_enemies", 12)), float(next.get("max_enemies", 12)), t))),
				"difficulty": diff,
				"elite": lerp(float(prev.get("elite", 0.02)), float(next.get("elite", 0.02)), t),
				"siege": lerp(float(prev.get("siege", 0.0)), float(next.get("siege", 0.0)), t)
			}
		prev = next
		prev_time = next_time
	var last = SPAWN_CURVE[SPAWN_CURVE.size() - 1]
	var diff = float(last.get("difficulty", 1.0)) * _get_threat_multiplier(time_sec)
	return {
		"interval": float(last.get("interval", 1.2)),
		"max_enemies": int(last.get("max_enemies", 12)),
		"difficulty": diff,
		"elite": float(last.get("elite", 0.02)),
		"siege": float(last.get("siege", 0.0))
	}

func _get_threat_multiplier(time_sec: float) -> float:
	if time_sec <= 600.0:
		return 1.0
	var t = clamp((time_sec - 600.0) / 900.0, 0.0, 1.0)
	return 1.0 + t * 0.6

func _update_dynamic_caps() -> void:
	var extra = 0
	if elapsed > 300.0:
		extra = int(clamp((elapsed - 300.0) / 60.0, 0.0, 20.0)) * 8
	max_enemies_cap = max_enemies_cap_base + extra

func _count_elites() -> int:
	var count = 0
	for enemy in cached_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if "is_elite" in enemy and enemy.is_elite:
			count += 1
	return count

func _handle_spawning(delta: float) -> void:
	var settings = _get_spawn_settings(elapsed)
	var interval = max(0.26, float(settings.get("interval", 1.2)))
	spawn_accumulator += delta
	while spawn_accumulator >= interval:
		spawn_accumulator -= interval
		var max_enemies = min(max_enemies_cap, int(settings.get("max_enemies", max_enemies_cap)))
		if enemies_root.get_child_count() >= max_enemies:
			break
		spawn_enemy(settings)

func _handle_boss_spawning(_delta: float) -> void:
	if BOSS_SCHEDULE.is_empty():
		return
	if _final_boss_spawned:
		return
	if _active_boss != null:
		if is_instance_valid(_active_boss) and _active_boss.is_inside_tree():
			return
		_active_boss = null
	if not _boss_warning_shown and elapsed >= _next_boss_time - BOSS_WARNING_LEAD:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("BOSS INCOMING", Color(1.0, 0.2, 0.2), 48, 2.4)
		_boss_warning_shown = true
	if elapsed < _next_boss_time:
		return
	_spawn_next_boss()

func _spawn_next_boss() -> void:
	if BOSS_SCHEDULE.is_empty():
		return
	var entry = BOSS_SCHEDULE[_boss_schedule_index]
	var script_path = str(entry.get("script", ""))
	var boss = _spawn_boss(script_path)
	if boss != null:
		_active_boss = boss
		if entry.get("final", false):
			_final_boss_spawned = true
			call_deferred("_apply_final_boss_tuning", boss, entry)
			if ui != null and ui.has_method("show_announcement"):
				ui.show_announcement("FINAL BOSS", Color(1.0, 0.2, 0.2), 52, 3.2)
		if boss.has_signal("boss_died"):
			boss.boss_died.connect(_on_boss_died)
		boss.tree_exited.connect(_on_boss_tree_exited)
	_boss_schedule_index += 1
	if _boss_schedule_index >= BOSS_SCHEDULE.size():
		_boss_schedule_index = 0
		_boss_cycle += 1
	_next_boss_time = float(BOSS_SCHEDULE[_boss_schedule_index].get("time", _next_boss_time)) + BOSS_CYCLE_LENGTH * _boss_cycle
	_boss_warning_shown = false

func _spawn_boss(script_path: String) -> Node:
	if enemies_root == null or player == null:
		return null
	if script_path == "" or not ResourceLoader.exists(script_path):
		push_warning("Boss script missing: %s" % script_path)
		return null
	var boss = ENEMY_SCENE.instantiate()
	var boss_script = load(script_path)
	if boss_script == null:
		push_warning("Failed to load boss script: %s" % script_path)
		return null
	boss.set_script(boss_script)
	var angle = randf() * TAU
	var distance = spawn_radius_max + randf_range(80.0, 140.0)
	boss.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
	var difficulty = float(_get_spawn_settings(elapsed).get("difficulty", 1.0))
	if boss.has_method("setup"):
		boss.setup(self, difficulty)
	enemies_root.add_child(boss)
	return boss

func _on_boss_died(_boss: Node = null) -> void:
	_active_boss = null
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("BOSS DEFEATED", Color(1.0, 0.85, 0.3), 36, 2.4)

func _on_boss_tree_exited() -> void:
	_active_boss = null

func _apply_final_boss_tuning(boss: Node, entry: Dictionary) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var health_mult = float(entry.get("health_mult", 2.5))
	var speed_mult = float(entry.get("speed_mult", 2.0))
	var damage_mult = float(entry.get("damage_mult", 1.5))
	if "max_health" in boss:
		boss.max_health = float(boss.max_health) * health_mult
	if "health" in boss:
		boss.health = boss.max_health
	if "speed" in boss:
		boss.speed = float(boss.speed) * speed_mult
	if "attack_damage" in boss:
		boss.attack_damage = float(boss.attack_damage) * damage_mult
	if "attack_rate" in boss:
		boss.attack_rate = float(boss.attack_rate) * 1.25
	if "boss_title" in boss:
		boss.boss_title = str(entry.get("title", boss.boss_title))
	if boss.has_method("flash"):
		boss.flash()

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
	var base_elite_chance = clamp(float(spawn_settings.get("elite", 0.0)), 0.0, 0.14)
	var time_scalar = 1.0 + min(elapsed / 360.0, 1.0) * 0.25
	var elite_chance = clamp(base_elite_chance * time_scalar, 0.0, 0.12)
	var elite_cap = clampi(int(6 + elapsed / 150.0), 6, 18)
	if _count_elites() < elite_cap and randf() < elite_chance and enemy.has_method("set_elite"):
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

func spawn_split_minions(position: Vector2, count: int) -> void:
	if enemies_root == null:
		return
	var difficulty = float(_get_spawn_settings(elapsed).get("difficulty", 1.0))
	for i in range(count):
		if enemies_root.get_child_count() >= max_enemies_cap:
			break
		var enemy = ENEMY_SCENE.instantiate()
		enemy.global_position = position + Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		if enemy.has_method("setup"):
			enemy.setup(self, difficulty)
		if enemy.has_method("apply_split_child"):
			enemy.apply_split_child()
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
			var raw_paths = config.get("frame_paths", [])
			var typed_paths: Array[String] = []
			for path in raw_paths:
				typed_paths.append(str(path))
			body.frame_paths = typed_paths
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

func spawn_generator_smoke(generator_position: Vector2) -> void:
	"""Spawn smoke trail from resource generator - call periodically"""
	if fx_manager != null:
		fx_manager.spawn_generator_smoke(generator_position)

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

func spawn_cannonball(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, explosion_radius: float, cluster_bombs: bool = false, burn_effect: bool = false) -> Node:
	if projectiles_root.get_child_count() >= max_projectiles:
		return null
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = origin
	var damage_type = "fire" if burn_effect else "normal"
	if projectile.has_method("setup"):
		projectile.setup(self, direction, speed, damage, max_range, explosion_radius, 0, 1.0, 0.0, damage_type)
	# Store cluster bomb and burn data on the projectile
	projectile.set_meta("cluster_bombs", cluster_bombs)
	projectile.set_meta("burn_effect", burn_effect)
	projectiles_root.add_child(projectile)
	return projectile

func spawn_enemy_projectile(origin: Vector2, direction: Vector2, proj_speed: float, damage: float, proj_range: float) -> void:
	if projectiles_root.get_child_count() >= max_projectiles:
		return
	var proj = ENEMY_PROJECTILE_SCENE.instantiate()
	proj.global_position = origin
	if proj.has_method("setup"):
		proj.setup(self, direction, proj_speed, damage, proj_range)
	projectiles_root.add_child(proj)

func spawn_pickup(position: Vector2, value: int, kind: String = "gold") -> void:
	if pickups_root == null:
		return
	if pickups_root.get_child_count() >= max_pickups:
		# Prevent soft-locking resource drops when the ground is saturated.
		if kind == "gold":
			add_resources(value)
			if has_method("show_floating_text"):
				show_floating_text("+%d" % value, position, Color(1.0, 0.84, 0.2, 1.0))
		return
	var pickup = PICKUP_SCENE.instantiate()
	pickup.global_position = position
	if pickup.has_method("setup"):
		pickup.setup(self, value, kind)
	# Defer add_child to avoid "flushing queries" errors during physics callbacks.
	pickups_root.call_deferred("add_child", pickup)
	if kind == "essence":
		_queue_essence_announcement(position, value)

func spawn_treasure_chest(position: Vector2) -> void:
	if pickups_root == null:
		return
	if pickups_root.get_child_count() >= max_pickups:
		return
	if elapsed < _next_chest_time:
		return
	if randf() > chest_drop_chance:
		return
	_next_chest_time = elapsed + chest_drop_cooldown
	var chest = TREASURE_CHEST_SCENE.instantiate()
	chest.global_position = position
	if chest.has_method("setup"):
		chest.setup(self)
	# Defer add_child to avoid "flushing queries" errors during physics callbacks.
	pickups_root.call_deferred("add_child", chest)

func _queue_essence_announcement(position: Vector2, value: int) -> void:
	if value <= 0:
		return
	_essence_announce_count += value
	if _essence_announce_count == value:
		_essence_announce_position = position
	else:
		_essence_announce_position = _essence_announce_position.lerp(position, 0.35)
	_essence_announce_timer = 0.35

func _update_essence_announcement(delta: float) -> void:
	if _essence_announce_count <= 0:
		return
	_essence_announce_timer -= delta
	if _essence_announce_timer > 0.0:
		return
	if ui != null and ui.has_method("show_announcement"):
		var amount = _essence_announce_count
		var text = "+%d ESSENCE" % amount
		ui.show_announcement(text, Color(0.8, 0.4, 1.0), 28, 2.0, _essence_announce_position)
	_essence_announce_count = 0
	_essence_announce_timer = 0.0

func spawn_fx(kind: String, position: Vector2) -> void:
	if fx_root == null or not fx_defs.has(kind):
		return
	# Cap FX nodes to prevent runaway memory/crash
	if fx_root.get_child_count() >= max_particles:
		return
	var fx = FX_SCENE.instantiate()
	fx.global_position = position
	# Add to tree FIRST so @onready vars initialize before setup()
	fx_root.add_child(fx)
	var def = fx_defs[kind]
	if fx.has_method("setup"):
		var tint = def.get("tint", Color.WHITE)
		var base_scale = float(def.get("scale", 1.0))
		var base_alpha = float(def.get("alpha", 1.0))
		fx.setup(
			def.get("paths", []),
			float(def.get("fps", 10.0)),
			float(def.get("lifetime", 0.35)),
			false,
			base_scale,
			base_alpha,
			int(def.get("z", 0)),
			tint
		)
	if kind == "explosion":
		_spawn_glow_burst(position, Color(1.0, 0.55, 0.2), 10, 10.0, 0.5, 220.0, 1.9)
	elif kind == "elite_kill":
		_spawn_glow_burst(position, Color(1.0, 0.85, 0.35), 12, 12.0, 0.55, 250.0, 2.1)

func spawn_glow_particle(position: Vector2, color: Color, size: float = 8.0, lifetime: float = 0.45, velocity: Vector2 = Vector2.ZERO, bloom: float = 1.6, trail_strength: float = 0.7, trail_length: float = 0.9, z: int = 1) -> Node:
	if fx_root == null:
		return null
	# Cap particles to prevent memory issues in long games
	if fx_root.get_child_count() >= max_particles:
		return null
	var glow = GLOW_PARTICLE_SCRIPT.new()
	glow.global_position = position
	if glow.has_method("setup"):
		glow.setup(color, size, lifetime, velocity, bloom, trail_strength, trail_length, z)
	fx_root.add_child(glow)
	return glow

func _spawn_glow_burst(position: Vector2, base_color: Color, count: int, size: float, lifetime: float, speed: float, bloom: float) -> void:
	if fx_root == null:
		return
	for i in count:
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		var vel = dir * randf_range(speed * 0.4, speed)
		var tint = base_color.lerp(Color.WHITE, randf_range(0.05, 0.35))
		spawn_glow_particle(
			position + dir * randf_range(0.0, size * 0.4),
			tint,
			size * randf_range(0.6, 1.1),
			lifetime * randf_range(0.7, 1.1),
			vel,
			bloom,
			0.85,
			1.05,
			2
		)

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
	_apply_damage_label_style(label, is_crit, is_kill, is_elite, damage_type)
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
	if is_elite and is_kill:
		base_scale += FeedbackConfig.DAMAGE_NUMBER_ELITE_KILL_SCALE_BONUS
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
		push_warning("Damage font path is empty")
		return
	if not ResourceLoader.exists(path):
		push_warning("Damage font resource not found: " + path)
		return
	var font = load(path)
	if font is Font:
		_damage_font = font
		print("Damage font loaded successfully: " + path)
	else:
		push_warning("Loaded resource is not a Font: " + path + " (type: " + str(typeof(font)) + ")")

func _apply_damage_label_style(label: Label, is_crit: bool, is_kill: bool, is_elite: bool, damage_type: String) -> void:
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
	if is_elite and is_kill:
		color = FeedbackConfig.DAMAGE_COLOR_ELITE_KILL
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

func add_essence(amount: int) -> void:
	essence += amount
	_update_ui()
	if not _essence_tip_shown and ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("ESSENCE fuels tower evolutions (U)", Color(0.8, 0.4, 1.0), 24, 3.2)
		_essence_tip_shown = true

func add_xp(amount: int) -> void:
	xp += amount
	var leveled_up = false
	while xp >= xp_next:
		xp -= xp_next
		xp_next = int(xp_next * 1.35 + 6)
		level += 1
		pending_picks += 1
		leveled_up = true
		_check_level_unlocks()
	if leveled_up:
		# Audio: Level up sound
		AudioManager.play_ui_sound("level_up")
	if pending_picks > 0 and not tech_open:
		_open_tech_menu()
	_update_ui()

func _check_level_unlocks() -> void:
	if level >= 5 and not is_build_unlocked("resource_generator"):
		unlock_build("resource_generator")
		if build_manager != null and build_manager.has_method("refresh_controls"):
			build_manager.refresh_controls()
		_refresh_build_palette()
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("RESOURCE GENERATOR UNLOCKED", Color(0.9, 0.8, 0.3), 32, 2.6)

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
			"rarity": def.get("rarity", "common"),
			"level": int(tech_levels.get(id, 0))
		})
	tech_open = true
	if ui.has_method("show_tech"):
		ui.show_tech(tech_choices)
	_apply_base_time_scale()

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
	# Tween time_scale back to 1.0 smoothly instead of instant
	if _time_scale_tween != null:
		_time_scale_tween.kill()
	_time_scale_tween = create_tween()
	_time_scale_tween.tween_property(Engine, "time_scale", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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
	if ui != null and ui.has_method("update_tech_ledger"):
		ui.update_tech_ledger(tech_levels, tech_defs)

func apply_chest_upgrade(id: String, upgrade: Dictionary = {}) -> void:
	var rarity = upgrade.get("rarity", "common") if not upgrade.is_empty() else "common"
	
	match id:
		# Common upgrades
		"gun_damage":
			chest_damage_bonus += 2.0 if rarity == "common" else (3.0 if rarity == "rare" else 4.0)
			_apply_player_damage_bonuses()
		"tower_range":
			var mult = 1.06 if rarity == "common" else (1.09 if rarity == "rare" else 1.12)
			chest_tower_range_mult = min(1.8, chest_tower_range_mult * mult)
		"speed":
			chest_speed_bonus += 12.0 if rarity == "common" else (18.0 if rarity == "rare" else 25.0)
			if player != null and player.has_method("apply_speed_bonus"):
				player.apply_speed_bonus(chest_speed_bonus)
		"max_hp":
			chest_max_hp_bonus += 12.0 if rarity == "common" else (20.0 if rarity == "rare" else 30.0)
			if player != null and player.has_method("apply_max_health_bonus"):
				player.apply_max_health_bonus(chest_max_hp_bonus)
		"build_cost":
			var cost_mult = 0.92 if rarity == "common" else (0.88 if rarity == "rare" else 0.83)
			build_cost_mult = max(0.55, build_cost_mult * cost_mult)
		"reload_speed":
			reload_speed_mult *= 0.90 if rarity == "common" else (0.85 if rarity == "rare" else 0.80)
		
		# Rare upgrades
		"crit_chance":
			crit_chance_bonus += 0.08
		"crit_damage":
			crit_damage_mult += 0.25
		"pierce":
			pierce_bonus += 1
		"cooldown":
			cooldown_mult *= 0.88 if rarity == "rare" else 0.82
		"pickup_range":
			pickup_range_mult *= 1.30
		
		# Epic upgrades
		"multishot":
			if not has_multishot:
				has_multishot = true
			multishot_count += 1
			if player != null:
				player.burst_level = multishot_count
				player.burst_every = 3
				player.burst_spread = 0.15
		"explosive":
			has_explosive = true
			explosive_radius = max(explosive_radius, 60.0)
			if player != null:
				player.explosive_radius = explosive_radius
		"chain":
			has_chain_lightning = true
			chain_lightning_targets = max(chain_lightning_targets, 3)
		"vampiric":
			has_vampiric = true
			vampiric_percent = max(vampiric_percent, 0.08)
		
		# DIAMOND upgrades - game changers
		"multishot_split":
			has_multishot_split = true
			multishot_split_count = 2
		"vampiric_heart":
			has_vampiric = true
			vampiric_percent = max(vampiric_percent, 0.15)
		"chain_master":
			has_chain_lightning = true
			chain_lightning_targets = max(chain_lightning_targets, 5)
		"time_dilation":
			has_time_dilation = true
			time_dilation_mult = 2.0
		"phoenix":
			has_phoenix = true
			phoenix_used_this_wave = false
		"fortress":
			has_fortress = true
			tower_hp_mult = 1.5
			towers_self_repair = true
	
	_update_ui()
	if ui != null and ui.has_method("show_upgrade_popup"):
		ui.show_upgrade_popup(id, rarity)

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
	_apply_player_damage_bonuses()

func _apply_player_damage_bonuses() -> void:
	if player != null and player.has_method("apply_global_bonuses"):
		player.apply_global_bonuses(player_damage_bonus + chest_damage_bonus)

func get_tower_rate_mult() -> float:
	return tower_rate_mult

func get_tower_damage_bonus() -> float:
	return tower_damage_bonus

func get_tower_range_mult() -> float:
	return tower_range_mult * chest_tower_range_mult

func get_build_cost_mult() -> float:
	return build_cost_mult

func get_pickup_range_mult() -> float:
	return pickup_range_mult

func get_enemy_health_mult() -> float:
	if elapsed <= 600.0:
		return 1.0
	if elapsed <= 1200.0:
		var t = clamp((elapsed - 600.0) / 600.0, 0.0, 1.0)
		return lerp(1.0, 1.6, t)
	if elapsed <= 2100.0:
		var t = clamp((elapsed - 1200.0) / 900.0, 0.0, 1.0)
		return lerp(1.6, 2.6, t)
	var t = clamp((elapsed - 2100.0) / 900.0, 0.0, 1.0)
	return lerp(2.6, 3.2, t)

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
	if ui.has_method("set_essence"):
		ui.set_essence(essence)
	if ui.has_method("set_time"):
		ui.set_time(elapsed)
	if ui.has_method("set_level"):
		ui.set_level(level, xp, xp_next)
	if player != null and ui.has_method("set_health"):
		ui.set_health(player.health, player.max_health)

func shake_camera(strength: float, duration: float = FeedbackConfig.SCREEN_SHAKE_DURATION) -> void:
	if camera == null:
		return
	# Use dynamic camera controller shake
	if camera.has_method("shake"):
		camera.shake(strength, duration)

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

# ============================================
# DEATH SEQUENCE & GAME OVER
# ============================================

func on_player_death() -> void:
	"""Called when player health reaches 0 - starts death animation"""
	if game_over:
		return
	# Don't set game_over yet - wait for animation
	# game_over = true  # Set in on_death_animation_complete instead
	
	# Player.gd will handle its own death animation
	# We just need to track that death is in progress

func start_death_camera_zoom(player_position: Vector2) -> void:
	"""Called by player.gd to start camera zoom effect"""
	if camera == null:
		return
	
	# Store original camera settings
	_original_camera_zoom = camera.zoom
	_original_camera_position = camera.global_position
	
	# Smoothly zoom in and move to player
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera, "zoom", Vector2(1.5, 1.5), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", player_position, 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func on_death_animation_complete() -> void:
	"""Called by player.gd when death animation finishes"""
	game_over = true
	Engine.time_scale = 1.0
	
	# Audio: Game over sound
	AudioManager.play_one_shot("game_over", player.global_position, AudioManager.CRITICAL_PRIORITY)
	AudioManager.stop_music(2.0)
	
	# Screen fade to black over 2 seconds
	_fade_to_black()
	
	# Wait for fade then show game over screen
	if not is_inside_tree():
		return
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	
	_show_game_over_screen()

func _fade_to_black() -> void:
	"""Create a black overlay that fades in"""
	var fade = ColorRect.new()
	fade.name = "DeathFade"
	fade.color = Color.BLACK
	fade.anchors_preset = Control.PRESET_FULL_RECT
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 100
	fade.modulate = Color(1, 1, 1, 0)
	add_child(fade)
	if not is_inside_tree():
		return
	if not fade.is_inside_tree():
		fade.queue_free()
		return
	var tween = fade.create_tween()
	tween.tween_property(fade, "modulate", Color(1, 1, 1, 1), 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _show_game_over_screen() -> void:
	"""Display the game over stats screen"""
	if game_over_ui == null:
		return
	
	# Update wave reached from wave_manager
	if wave_manager != null and wave_manager.has_method("get_current_wave"):
		_wave_reached = wave_manager.get_current_wave()
	
	# Compile stats
	var stats = {
		"time_survived": elapsed,
		"enemies_killed": _enemy_kill_count,
		"damage_dealt": _total_damage_dealt,
		"towers_built": _towers_built,
		"generators_lost": _generators_lost,
		"best_streak": _best_streak,
		"wave_reached": _wave_reached
	}
	
	# Check for new records
	var is_new_record = _check_and_save_record(stats)
	
	# Show the game over UI
	if game_over_ui.has_method("show_game_over"):
		game_over_ui.show_game_over(stats, is_new_record)

func _instantiate_game_over_ui() -> void:
	"""Create and setup the game over UI"""
	if GAME_OVER_SCENE == null:
		push_warning("Game over scene not loaded")
		return
	
	game_over_ui = GAME_OVER_SCENE.instantiate()
	add_child(game_over_ui)
	game_over_ui.visible = false
	
	# Connect signals
	if game_over_ui.has_signal("try_again_pressed"):
		game_over_ui.try_again_pressed.connect(_on_try_again)
	if game_over_ui.has_signal("main_menu_pressed"):
		game_over_ui.main_menu_pressed.connect(_on_main_menu_pressed)
	if game_over_ui.has_signal("stats_pressed"):
		game_over_ui.stats_pressed.connect(_on_stats_pressed)

func _on_try_again() -> void:
	"""Restart the current run"""
	_restart_game()

func _on_main_menu_pressed() -> void:
	"""Return to main menu"""
	# Hide game over UI
	if game_over_ui != null:
		game_over_ui.hide_game_over()
	
	# Reset game state
	_reset_game_state()
	
	# Show start screen
	if ui != null and ui.has_method("show_start"):
		ui.show_start(true)

func _on_stats_pressed() -> void:
	"""Show detailed stats (could expand to show charts)"""
	# For now, just toggle the detailed view
	# This could be expanded to show damage over time charts, etc.
	print("Stats button pressed - detailed view coming soon!")

func _handle_game_over_input() -> void:
	"""Handle input during game over screen"""
	# Allow quick restart with Enter/R keys
	if Input.is_action_just_pressed("start_game"):
		_on_try_again()
	if Input.is_action_just_pressed("cancel"):
		_on_main_menu_pressed()

func _restart_game() -> void:
	"""Restart the game while keeping meta-progress"""
	# Hide game over UI
	if game_over_ui != null:
		game_over_ui.hide_game_over()
	
	# Remove fade overlay if exists
	var fade = get_node_or_null("DeathFade")
	if fade != null:
		fade.queue_free()
	
	# Reset game state
	_reset_game_state()
	
	# Reset player
	if player != null and player.has_method("reset"):
		player.reset()
	
	# Reset camera
	if camera != null:
		if _original_camera_zoom != Vector2.ZERO:
			camera.zoom = _original_camera_zoom
		camera.offset = _shake_base_offset
	
	# Start the game
	_start_game()

func _reset_game_state() -> void:
	"""Reset all game state for a new run"""
	game_over = false
	game_started = false
	elapsed = 0.0
	spawn_accumulator = 0.0
	start_timer = 0.0
	resources = 40
	
	# Clear enemies
	for enemy in enemies_root.get_children():
		enemy.queue_free()
	
	# Clear projectiles
	for proj in projectiles_root.get_children():
		proj.queue_free()
	
	# Clear pickups
	for pickup in pickups_root.get_children():
		pickup.queue_free()
	
	# Clear allies
	if allies_root != null:
		for ally in allies_root.get_children():
			ally.queue_free()
	
	# Reset stats
	_reset_run_stats()
	
	# Reset wave manager
	if wave_manager != null and wave_manager.has_method("reset"):
		wave_manager.reset()
	
	Engine.time_scale = 1.0

func _reset_run_stats() -> void:
	"""Reset stats for a new run"""
	_enemy_kill_count = 0
	_total_damage_dealt = 0.0
	_towers_built = 0
	_generators_lost = 0
	_current_streak = 0
	_best_streak = 0
	_wave_reached = 1
	_next_chest_time = 0.0
	_essence_announce_count = 0
	_essence_announce_timer = 0.0
	_essence_announce_position = Vector2.ZERO
	_last_minute_announcement = -1
	_essence_tip_shown = false
	_final_boss_spawned = false
	if ui != null and ui.has_method("clear_tech_ledger"):
		ui.clear_tech_ledger()
	_reset_boss_schedule()

func _reset_boss_schedule() -> void:
	_boss_schedule_index = 0
	_boss_cycle = 0
	if BOSS_SCHEDULE.is_empty():
		_next_boss_time = INF
	else:
		_next_boss_time = float(BOSS_SCHEDULE[0].get("time", 300.0))
	_boss_warning_shown = false
	_active_boss = null

# ============================================
# STATS TRACKING & PERSISTENCE
# ============================================

func track_damage_dealt(amount: float) -> void:
	"""Track damage dealt by player/towers"""
	_total_damage_dealt += amount

func track_tower_built() -> void:
	"""Track tower construction"""
	_towers_built += 1

func track_generator_lost() -> void:
	"""Track generator destruction"""
	_generators_lost += 1

func on_enemy_killed(is_elite: bool = false, is_siege: bool = false) -> void:
	_enemy_kill_count += 1
	_current_streak += 1
	if _current_streak > _best_streak:
		_best_streak = _current_streak
	if _enemy_kill_count % 10 == 0:
		_trigger_kill_slow()

func reset_kill_streak() -> void:
	"""Call when player takes damage to reset streak"""
	_current_streak = 0

func _check_and_save_record(stats: Dictionary) -> bool:
	"""Check if this run is a new record and save to history"""
	var run_history = _load_run_history()
	var is_new_record = false
	
	# Check against best runs
	var best_kills = run_history.get("best_kills", 0)
	var best_time = run_history.get("best_time", 0.0)
	var best_wave = run_history.get("best_wave", 0)
	
	if stats["enemies_killed"] > best_kills:
		run_history["best_kills"] = stats["enemies_killed"]
		is_new_record = true
	if stats["time_survived"] > best_time:
		run_history["best_time"] = stats["time_survived"]
		is_new_record = true
	if stats["wave_reached"] > best_wave:
		run_history["best_wave"] = stats["wave_reached"]
		is_new_record = true
	
	# Add to run history
	var run_entry = {
		"date": Time.get_datetime_string_from_system(),
		"time_survived": stats["time_survived"],
		"enemies_killed": stats["enemies_killed"],
		"damage_dealt": stats["damage_dealt"],
		"towers_built": stats["towers_built"],
		"generators_lost": stats["generators_lost"],
		"best_streak": stats["best_streak"],
		"wave_reached": stats["wave_reached"]
	}
	
	if not run_history.has("runs"):
		run_history["runs"] = []
	
	run_history["runs"].append(run_entry)
	
	# Keep only last 50 runs
	if run_history["runs"].size() > 50:
		run_history["runs"].pop_front()
	
	_save_run_history(run_history)
	
	return is_new_record

func _load_run_history() -> Dictionary:
	"""Load run history from JSON file"""
	var path = "user://run_history.json"
	if not FileAccess.file_exists(path):
		return {
			"best_kills": 0,
			"best_time": 0.0,
			"best_wave": 0,
			"runs": []
		}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"best_kills": 0,
			"best_time": 0.0,
			"best_wave": 0,
			"runs": []
		}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		return json.get_data()
	
	return {
		"best_kills": 0,
		"best_time": 0.0,
		"best_wave": 0,
		"runs": []
	}

func _save_run_history(data: Dictionary) -> void:
	"""Save run history to JSON file"""
	var path = "user://run_history.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open run history file for writing")
		return
	
	var json_text = JSON.stringify(data, "\t")
	file.store_string(json_text)
	file.close()

# Camera zoom storage for death animation
var _original_camera_zoom: Vector2 = Vector2.ONE
var _original_camera_position: Vector2 = Vector2.ZERO
var _shake_base_offset: Vector2 = Vector2.ZERO

# Camera zoom levels for gameplay toggle
const ZOOM_LEVELS: Array[Vector2] = [Vector2(2.0, 2.0), Vector2(1.5, 1.5), Vector2(1.0, 1.0)]
var _current_zoom_index: int = 0
var _zoom_tween: Tween = null

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

func _spawn_environmental_particles() -> void:
	"""Spawn ambient environmental particles based on zone type"""
	if fx_manager == null:
		return
	
	# Determine zone type based on level/stage - currently using grass zone
	var zone_type = "grass"
	fx_manager.spawn_environmental_particles(zone_type)

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

func spawn_powerup() -> void:
	if player == null or pickups_root == null:
		return
	
	# Get random power-up type
	var type = PowerUp.get_random_type()
	
	# Get spawn distance for this type
	var distance_config = PowerUp.get_spawn_distance(type)
	var min_dist = distance_config.min
	var max_dist = distance_config.max
	
	# Try to find valid spawn position
	var spawn_pos: Vector2 = Vector2.ZERO
	var valid_spawn = false
	
	for attempt in range(20):
		var angle = randf() * TAU
		var distance = randf_range(min_dist, max_dist)
		var test_pos = player.global_position + Vector2.RIGHT.rotated(angle) * distance
		
		valid_spawn = _is_valid_powerup_position(test_pos)
		
		if valid_spawn:
			spawn_pos = test_pos
			break
	
	if not valid_spawn:
		return
	
	# Spawn the power-up
	var powerup = POWER_UP_SCENE.instantiate()
	powerup.global_position = spawn_pos
	
	# Audio: Powerup spawn sound
	AudioManager.play_one_shot("powerup_spawn", spawn_pos, AudioManager.HIGH_PRIORITY)
	
	if powerup.has_method("setup"):
		powerup.setup(self, type, spawn_pos)
	pickups_root.add_child(powerup)

func _handle_powerup_spawning(delta: float) -> void:
	if player == null or pickups_root == null:
		return
	
	# Count existing power-ups
	var current_powerups = 0
	for child in pickups_root.get_children():
		if child is PowerUp:
			current_powerups += 1
	
	# Don't spawn if at max
	if current_powerups >= max_powerups:
		return
	
	# Update timer
	powerup_spawn_timer += delta
	if powerup_spawn_timer < powerup_spawn_interval:
		return
	
	# Reset timer with random interval
	powerup_spawn_timer = 0.0
	powerup_spawn_interval = randf_range(60.0, 90.0)
	
	# Roll for spawn chance (75% chance to spawn when timer expires)
	if randf() > 0.75:
		return
	
	spawn_powerup()

func _is_valid_powerup_position(pos: Vector2) -> bool:
	# Check if position is too close to any building
	if buildings_root != null:
		for building in buildings_root.get_children():
			if building.has_method("get_footprint_radius"):
				var footprint = building.get_footprint_radius()
				if pos.distance_to(building.global_position) < footprint + 30.0:
					return false
	
	# Check if position is too close to any enemy
	if enemies_root != null:
		for enemy in enemies_root.get_children():
			if pos.distance_to(enemy.global_position) < 40.0:
				return false
	
	return true

func show_floating_text(text: String, position: Vector2, color: Color = Color.WHITE) -> void:
	if fx_root == null or not is_instance_valid(fx_root) or not fx_root.is_inside_tree():
		return
	if fx_root.get_child_count() >= max_particles:
		return
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = Vector2.ZERO
	label.global_position = position
	# Defer add/animate to avoid physics "flushing queries" crashes.
	fx_root.call_deferred("add_child", label)
	call_deferred("_animate_floating_text", label)

func _animate_floating_text(label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	if not label.is_inside_tree():
		return
	# Animate up and fade
	var tween = label.create_tween()
	tween.tween_property(label, "position", Vector2(0, -40), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

func flash_screen(color: Color, duration: float = 0.3) -> void:
	if not is_inside_tree():
		return
	var flash = ColorRect.new()
	flash.color = color
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	if not flash.is_inside_tree():
		flash.queue_free()
		return
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration).from(color.a).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)

func set_death_vignette(intensity: float) -> void:
	"""Set vignette intensity during death sequence"""
	if camera != null and camera.has_method("set_vignette_intensity"):
		camera.set_vignette_intensity(intensity)

func spawn_soul_fragment(position: Vector2) -> Node2D:
	"""Spawn a soul fragment particle during death animation"""
	if fx_root == null:
		return null
	var color = Color(0.6, 0.7, 1.0, 0.8)  # Ghostly blue
	spawn_glow_particle(position, color, 8.0, 2.0, Vector2(0, -30), 1.0, 0.5, 0.98, 2)
	return null  # We don't track individual particles

# Generator management functions
func register_generator(generator: Node) -> void:
	if generator == null or not is_instance_valid(generator):
		return
	active_generators.append(generator)
	print("Generator registered. Total active: ", active_generators.size())

func on_generator_destroyed(generator: Node) -> void:
	generators_destroyed += 1
	
	# Remove from active list
	if generator in active_generators:
		active_generators.erase(generator)
	
	# Flash red screen for emphasis
	flash_screen(Color(1.0, 0.0, 0.0, 0.3), 0.4)
	
	# Camera shake
	shake_camera(FeedbackConfig.SCREEN_SHAKE_BUILDING_DESTROY * 1.5, 0.5)
	
	print("Generator destroyed! Active: ", active_generators.size(), " | Destroyed: ", generators_destroyed)
	
	# Check if all generators are destroyed
	if active_generators.size() == 0 and generators_destroyed > 0:
		show_floating_text("WARNING: No resource generators!", player.global_position + Vector2(0, -60), Color(1.0, 0.3, 0.3, 1.0))

func get_active_generator_count() -> int:
	# Clean up destroyed generators from list
	var valid_generators: Array = []
	for gen in active_generators:
		if gen != null and is_instance_valid(gen) and not gen.is_destroyed():
			valid_generators.append(gen)
	active_generators = valid_generators
	return active_generators.size()

# Resource zone management
func _spawn_resource_zones() -> void:
	var placed: Array = []
	var attempts = 0
	while placed.size() < ZONE_COUNT and attempts < 200:
		attempts += 1
		var angle = randf() * TAU
		var dist = randf_range(ZONE_MIN_DIST, ZONE_MAX_DIST)
		var pos = Vector2(cos(angle), sin(angle)) * dist
		var too_close = false
		for p in placed:
			if pos.distance_to(p) < ZONE_MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue
		placed.append(pos)
		var zone = ResourceZone.new()
		zone.global_position = pos
		zone.multiplier = randf_range(2.0, 3.0)
		zone.zone_id = placed.size()
		zone._game = self
		$World.add_child(zone)
		resource_zones.append(zone)
	print("Spawned %d resource zones" % resource_zones.size())

func get_zone_at(world_pos: Vector2):
	for zone in resource_zones:
		if zone != null and is_instance_valid(zone) and not zone._is_depleted:
			if zone.is_point_inside(world_pos):
				return zone
	return null

func on_zone_depleted(zone: Node) -> void:
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("ZONE DEPLETED - RELOCATE!", Color(1.0, 0.5, 0.0), 22, 4.0)
	var active = 0
	for z in resource_zones:
		if z != null and is_instance_valid(z) and not z._is_depleted:
			active += 1
	if active == 0:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("ALL ZONES EXHAUSTED!", Color(1.0, 0.2, 0.2), 26, 5.0)

# Hitstop - freeze frame effect for critical hits
func trigger_hitstop() -> void:
	if _time_scale_tween != null:
		_time_scale_tween.kill()
	Engine.time_scale = FeedbackConfig.HITSTOP_TIME_SCALE
	_time_scale_tween = create_tween()
	_time_scale_tween.tween_property(Engine, "time_scale", 1.0, FeedbackConfig.HITSTOP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Damage flash - chromatic aberration effect
func trigger_damage_flash() -> void:
	# Flash screen red briefly
	flash_screen(Color(1.0, 0.0, 0.0, 0.3), FeedbackConfig.CHROMATIC_ABERRATION_DURATION)

# Muzzle flash effect
func spawn_muzzle_flash(position: Vector2, direction: Vector2) -> void:
	if fx_root == null:
		return
	# Create a quick flash sprite
	var flash = Sprite2D.new()
	flash.texture = _get_muzzle_flash_texture()
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.global_position = position
	flash.rotation = direction.angle()
	flash.z_index = 5
	fx_root.add_child(flash)
	
	# Animate flash
	var tween = flash.create_tween()
	flash.scale = Vector2.ONE * 0.8
	tween.tween_property(flash, "scale", Vector2.ONE * 1.2, FeedbackConfig.MUZZLE_FLASH_DURATION * 0.3)
	tween.tween_property(flash, "modulate:a", 0.0, FeedbackConfig.MUZZLE_FLASH_DURATION * 0.7)
	tween.tween_callback(flash.queue_free)
	
	# Also spawn a quick glow particle
	spawn_glow_particle(position, Color(1.0, 0.9, 0.5, 0.8), 10.0, 0.08, Vector2.ZERO, 2.5, 0.0, 0.5, 4)

func _get_muzzle_flash_texture() -> Texture2D:
	var path = "res://assets/fx/fx_hit_spark_16_f001_v001.png"
	if ResourceLoader.exists(path):
		return load(path)
	return null

# Shell casing ejection effect
func spawn_shell_casing(position: Vector2, eject_direction: Vector2) -> void:
	if fx_root == null:
		return
	var casing = _create_shell_casing()
	if casing == null:
		return
	casing.global_position = position
	fx_root.add_child(casing)
	
	# Animate casing ejection
	var tween = casing.create_tween()
	var end_pos = position + eject_direction * randf_range(30.0, 50.0)
	end_pos += Vector2(0, randf_range(10.0, 25.0))  # Gravity arc
	tween.tween_property(casing, "global_position", end_pos, FeedbackConfig.SHELL_CASING_LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(casing, "rotation", randf_range(-PI, PI), FeedbackConfig.SHELL_CASING_LIFETIME)
	tween.parallel().tween_property(casing, "modulate:a", 0.0, FeedbackConfig.SHELL_CASING_LIFETIME * 0.5).set_delay(FeedbackConfig.SHELL_CASING_LIFETIME * 0.5)
	tween.tween_callback(casing.queue_free)

var _cached_shell_casing_tex: ImageTexture = null

func _create_shell_casing() -> Sprite2D:
	var casing = Sprite2D.new()
	if _cached_shell_casing_tex == null:
		var img = Image.create(3, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8, 0.7, 0.3, 1.0))
		_cached_shell_casing_tex = ImageTexture.create_from_image(img)
	casing.texture = _cached_shell_casing_tex
	casing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	casing.z_index = 1
	return casing

# Glow burst for death effects
func spawn_glow_burst_death(position: Vector2, base_color: Color) -> void:
	if fx_root == null:
		return
	# Spawn multiple glow particles in burst pattern
	for i in range(8):
		var angle = (TAU / 8.0) * i + randf_range(-0.2, 0.2)
		var speed = randf_range(60.0, 120.0)
		var vel = Vector2.RIGHT.rotated(angle) * speed
		var size = randf_range(4.0, 8.0)
		var color = base_color.lerp(Color.WHITE, randf_range(0.0, 0.4))
		color.a = 0.8
		spawn_glow_particle(position, color, size, 0.4, vel, 1.5, 0.7, 0.9, 2)

# Death particle for player death sequence
func spawn_death_particle(position: Vector2, velocity: Vector2, color: Color = Color(0.7, 0.1, 0.1), size: float = -1.0) -> void:
	"""Spawn a blood/death particle for player death animation"""
	if fx_root == null:
		return

	var final_color = color.lerp(Color(0.5, 0.05, 0.05), randf() * 0.3)
	var final_size = size if size > 0 else randf_range(3.0, 7.0)
	var lifetime = randf_range(0.5, 1.2)

	spawn_glow_particle(position, final_color, final_size, lifetime, velocity, 1.2, 0.8, 0.95, 1)

# Heartbeat sound effect for death sequence
func play_heartbeat_sound() -> void:
	"""Play slowing heartbeat sound during death sequence"""
	# This is a placeholder - you would integrate with your audio system
	# For now, we just print to indicate where sound would play
	print("*THUMP*... *thump*... *thump*...")

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
	_ensure_action("interact", [KEY_F])
	_ensure_action("cancel", [KEY_ESCAPE])

func _ensure_action(name: String, keys: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	for key in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(name, ev)
