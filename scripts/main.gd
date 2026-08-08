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
const ZOMBIE_SHAMBLER_SCENE = preload("res://scenes/enemies/zombie_shambler.tscn")
const WRAITH_SCENE = preload("res://scenes/enemies/wraith.tscn")
const IMP_SKIRMISHER_SCENE = preload("res://scenes/enemies/imp_skirmisher.tscn")
const FX_SCENE = preload("res://scenes/fx/fx.tscn")
const GLOW_PARTICLE_SCRIPT = preload("res://scripts/glow_particle.gd")
const PROJECTILE_SCENE = preload("res://scenes/projectile.tscn")
const ENEMY_PROJECTILE_SCENE = preload("res://scenes/enemy_projectile.tscn")
const PICKUP_SCENE = preload("res://scenes/pickup.tscn")
const BREAKABLE_SCENE = preload("res://scenes/breakable.tscn")
const TREASURE_CHEST_SCENE = preload("res://scenes/treasure_chest.tscn")
const COMPANION_COCO_SCENE = preload("res://scenes/companion_coco.tscn")
const POWER_UP_SCENE = preload("res://scenes/power_up.tscn")
const DEATH_STATS_SCENE = preload("res://scenes/death_stats_screen.tscn")
const ALLY_SCENE = preload("res://scenes/allies/ally_unit.tscn")
const GAME_OVER_SCENE = preload("res://scenes/game_over.tscn")
const PAUSE_MENU_SCENE = preload("res://scenes/pause_menu.tscn")
const SETTINGS_MENU_SCENE = preload("res://scenes/settings_menu.tscn")
const FeedbackConfig = preload("res://scripts/feedback_config.gd")
const WaveManager = preload("res://scripts/wave_manager.gd")
const FXManager = preload("res://scripts/fx_manager.gd")
const Minimap = preload("res://scripts/minimap.gd")

# The five buildings the player actually places. All are unlocked from the start
# via _unlock_core_builds(). Removed buildings (mine_trap, ice_trap, acid_trap,
# spike_trap, spike_burst_tower, flamethrower_tower, barracks, armory, tech_lab)
# are documented in docs/REMOVED_BUILDINGS.md for future re-add.
const CORE_BUILD_IDS = [
	"arrow_turret",
	"cannon_tower",
	"tesla_tower",
	"resource_generator",
	"shrine"
]
const TECH_RARITY_ORDER = ["common", "rare", "epic", "legendary", "mythic", "diamond"]
const TECH_REROLL_ACTION = "tech_reroll"
const TECH_REROLL_BASE_COST = 2
const TECH_REROLL_COST_STEP = 1
const TECH_REROLL_MAX_COST = 9
const TECH_LOCK_COST = 2
const TECH_FORCE_CATEGORY_COST = 2
const TECH_INFUSE_COST = 3
const TECH_INFUSE_1_ACTION = "tech_infuse_1"
const TECH_INFUSE_2_ACTION = "tech_infuse_2"
const TECH_INFUSE_3_ACTION = "tech_infuse_3"
const TECH_LOCK_1_ACTION = "tech_lock_1"
const TECH_LOCK_2_ACTION = "tech_lock_2"
const TECH_LOCK_3_ACTION = "tech_lock_3"
const TECH_FORCE_TOWER_ACTION = "tech_force_tower"
const TECH_FORCE_ENGINEER_ACTION = "tech_force_engineer"
const TECH_FORCE_ECONOMY_ACTION = "tech_force_economy"
const TECH_CATEGORY_ORDER = ["tower", "engineer", "economy"]
const START_RESOURCES = 220
const RESOURCE_GAIN_MULT = 0.85
const XP_GAIN_MULT = 1.5
const ENEMY_HEALTH_BASE_MULT = 2.0
const ENEMY_HEALTH_GROWTH_PER_30S = 0.25
const ENGINEER_VITALITY_HP_PER_LEVEL = 20.0
const EARLY_GAME_HORDE_RAMP_TIME = 300.0
const EARLY_GAME_ENEMY_HEALTH_GRACE_MIN = 0.60
const BUILD_FOCUS_TIME_SCALE = 0.78
# Master switch for gameplay slow-motion (kill slow, streak accents, crit
# hitstop). _trigger_kill_slow fired every 10th kill, so during a real fight the
# world was dipping into slow-mo almost continuously — players read it as the
# game slowing down or lagging rather than as punctuation. Off by default.
const ENABLE_TIME_DILATION := false
const CHEST_MODAL_TIME_SCALE = 0.0
const BUILD_COST_TIME_PRESSURE_START = 480.0
const BUILD_COST_TIME_PRESSURE_END = 1500.0
const BUILD_COST_TIME_PRESSURE_MAX = 1.3
const GENERATOR_INCOME_SOFT_CAP = 8
const GENERATOR_INCOME_MIN_MULT = 0.28
const GENERATOR_INCOME_DECAY_START = 480.0
const GENERATOR_INCOME_DECAY_END = 1500.0
const GENERATOR_INCOME_LATE_MIN = 0.80
const RESOURCE_DUMP_COST = 1200
const RESOURCE_DUMP_ESSENCE_GAIN = 1
const DEFAULT_RENDER_FPS_CAP = 30
const SIMULATION_TICKS_PER_SECOND = 60

# In solo this is the hardcoded scene player. In FFA it aliases the LOCAL
# player so the ~50 existing `player`/`camera` references keep working.
@onready var player: CharacterBody2D = $World/Player
@onready var camera: Camera2D = $World/Player/Camera2D
const PLAYER_SCENE := preload("res://scenes/player.tscn")
# peer_id -> player node (FFA). In solo, { 1: $World/Player }.
var players: Dictionary = {}
var local_player: CharacterBody2D = null
# --- Enemy replication (FFA) ---
# Host: monotonically increasing net id assigned to each spawned enemy; the enemy
# carries it as `net_id`. Client: net_id -> proxy enemy node it renders.
var _enemy_net_seq: int = 0
var _net_enemy_proxies: Dictionary = {}      # net_id -> proxy Node2D (client side)
var _net_enemy_targets: Dictionary = {}      # net_id -> Vector2 last synced pos (client side)
var _enemy_sync_accum: float = 0.0
const ENEMY_SYNC_HZ := 15.0
const ENEMY_SYNC_BATCH := 60                  # max enemies per RPC packet
# --- FFA match (host-authoritative clock + results) ---
const FFA_MATCH_SECONDS := 1200.0             # 20-minute match
const FFA_START_RESOURCES := 400              # every FFA player begins with this gold
const FFA_START_ESSENCE := 2                  # ...and this much essence
var _ffa_time_left: float = FFA_MATCH_SECONDS
var _ffa_match_over: bool = false
var _ffa_clock_accum: float = 0.0             # host broadcasts countdown at 1 Hz
var _ffa_dead_players: Dictionary = {}        # peer_id -> true once eliminated
# Last-player-standing: once only one real player remains alive, the host runs a
# short grace countdown (so the survivor can keep gathering) and then ends.
const FFA_LASTMAN_SECONDS := 60.0
var _ffa_lastman_active: bool = false
var _ffa_lastman_left: float = FFA_LASTMAN_SECONDS
var _ffa_lastman_accum: float = 0.0
var _ffa_started_real_count: int = 0          # real (human) players when the match began
@onready var enemies_root: Node2D = $World/Enemies
@onready var allies_root: Node2D = get_node_or_null("World/Allies")
@onready var projectiles_root: Node2D = $World/Projectiles
@onready var fx_root: Node2D = $World/FX
@onready var buildings_root: Node2D = $World/Buildings
@onready var props_root: Node2D = $World/Props
@onready var pickups_root: Node2D = $World/Pickups
@onready var breakables_root: Node2D = $World/Breakables
@onready var ground: TileMap = $World/Ground
@onready var ui: CanvasLayer = $UI
@onready var build_manager: Node = $BuildManager
@onready var game_over_ui: CanvasLayer = null
var ffa_results_ui: CanvasLayer = null
var ffa_death_ui: CanvasLayer = null
@onready var pause_menu: CanvasLayer = null
@onready var settings_menu: CanvasLayer = null

var _settings_manager: Node = null

# FX Manager
var fx_manager: FXManager = null
var minimap: Control = null
var _world_environment: WorldEnvironment = null

# Game state
var resources: int = 0
var essence: int = 0
# Per-player economy ledger (FFA). Keyed by peer_id. In solo, econ[1] mirrors the
# global `resources`/`essence`/`_currency_earned`/`_treasures_opened` vars so the
# ~50 existing references keep working unchanged. The host owns this ledger for
# scoring; the global vars always reflect the LOCAL player's pool for the UI.
var econ: Dictionary = {}
# Meta-progression run-start bonuses (applied from MetaProgression at run start).
var meta_essence_mult: float = 1.0
var meta_start_resources: int = 0
var meta_max_hp_bonus: float = 0.0
var meta_move_speed_mult: float = 1.0
var elapsed: float = 0.0
var spawn_accumulator: float = 0.0
var game_over = false
var game_started = false
var start_timer = 0.0
var spawn_delay = 10.0
var auto_start_delay = 2.0
var _enemy_kill_count = 0
var _time_scale_tween: Tween = null
var _build_focus_active: bool = false
var _build_focus_name: String = ""
var _last_minute_announcement: int = -1
var _essence_tip_shown: bool = false

# Play area bounds (derived from Ground radius)
var play_radius: float = 2200.0

# Flow-field pathing (lightweight maze navigation)
const FLOW_CELL_SIZE = 16.0
const FLOW_MIN_RADIUS_CELLS = 56
const FLOW_MAX_RADIUS_CELLS = 120
const FLOW_RADIUS_PADDING = 320.0
const FLOW_REBUILD_INTERVAL = 0.35
const FLOW_BLOCK_MARGIN = 0.0
const FLOW_AGENT_RADIUS = 7.0
const FLOW_CLEARANCE_MARGIN = 1.0
const DEBUG_FLOW_ACTION = "debug_flow"
const DEBUG_FLOW_DRAW_RADIUS = 60
const DEBUG_FLOW_STRIDE = 2
const DEBUG_FLOW_LINE_LEN = 8.0
const DEBUG_FLOW_DIR_COLOR = Color(0.2, 1.0, 0.5, 0.55)
const DEBUG_FLOW_BLOCK_COLOR = Color(1.0, 0.2, 0.2, 0.2)
const DEBUG_FLOW_PLAYER_COLOR = Color(1.0, 1.0, 0.2, 0.6)

const CLEARANCE_DIRS = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]
const FLOW_DIRS = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
var _flow_dist: PackedInt32Array = PackedInt32Array()
var _flow_blocked: PackedByteArray = PackedByteArray()
var _flow_clearance: PackedInt32Array = PackedInt32Array()
var _flow_radius_cells: int = FLOW_MAX_RADIUS_CELLS
var _flow_size: Vector2i = Vector2i.ZERO
var _flow_origin_cell: Vector2i = Vector2i.ZERO
var _flow_player_cell: Vector2i = Vector2i(999999, 999999)
var _flow_dirty: bool = true
var _flow_timer: float = 0.0
var _flow_rebuild_interval_runtime: float = FLOW_REBUILD_INTERVAL
var _flow_required_cells: int = 1
var debug_flow_enabled: bool = false
var _debug_flow_timer: float = 0.0
var _debug_toggle_cooldown: float = 0.0

# Cached enemy list — updated once per frame, used by all towers
var cached_enemies: Array = []
# Buildings and allies change rarely but were being re-scanned by every enemy
# every frame inside _find_target(). Cached here and refreshed on a slow timer.
var cached_buildings: Array = []
var cached_allies: Array = []
var _target_cache_timer: float = 0.0
const TARGET_CACHE_INTERVAL := 0.25

# Stats tracking
var _total_damage_dealt: float = 0.0
var _towers_built: int = 0
var _generators_lost: int = 0
var _current_streak: int = 0
var _best_streak: int = 0
var _wave_reached: int = 1
var _gold_earned: int = 0
var _treasures_opened: int = 0
var _currency_earned: int = 0  # lifetime gold/resources gained this run

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
# Gamepad cursor over the tech draft (0..2). -1 = no gamepad highlight yet (mouse/kbd).
var _tech_cursor: int = -1
var _tech_nav_cooldown: float = 0.0
var chest_modal_open = false
var _chest_modal_depth = 0
var tech_choices: Array = []
var tech_levels: Dictionary = {}
var unlocked_builds: Dictionary = {}
var _tech_rerolls_this_pick: int = 0
var _tech_rerolls_this_run: int = 0
var _tech_base_rate_mult: float = 1.0
var _tech_dead_screen_threshold_index: int = 0
var _tech_locked_id: String = ""
var _tech_locked_name: String = ""
var _tech_forced_category_once: String = ""
var _draft_pity: Dictionary = {
	"rare_miss": 0,
	"epic_miss": 0,
	"legendary_miss": 0
}
var _draft_telemetry: Dictionary = {}
var characters = [
	{
		"id": "warlock",
		"name": "Tech Warlock",
		"desc": "Arcane-circuit caster",
		"base_path": "res://assets/level1/level1_player_anim_warlock",
		"prefix": "player_warlock_32",
		"icon": "res://assets/level1/level1_player_anim_warlock/player_warlock_32_S_move_f001_v001.png"
	},
	{
		"id": "hunter",
		"name": "OG Hunter",
		"desc": "The one who came first",
		"base_path": "res://assets/level1/level1_player_anim_hunterv2",
		"prefix": "player_hunterv2_32",
		"icon": "res://assets/level1/level1_player_anim_hunterv2/player_hunterv2_32_S_move_f001_v001.png"
	},
	{
		"id": "hunter_classic",
		"name": "Hunter (Classic)",
		"desc": "The original ranger look",
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
var tower_chain_bonus = 0
var tower_aoe_mult = 1.0
var chest_damage_bonus = 0.0
var chest_speed_bonus = 0.0
var chest_max_hp_bonus = 0.0
var tech_max_hp_bonus = 0.0
var chest_tower_range_mult = 1.0
var chest_tower_damage_bonus = 0.0
var chest_tower_rate_mult = 1.0
var chest_tower_chain_bonus = 0
var chest_tower_aoe_mult = 1.0
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
var _final_boss_active = false
var _run_won = false

# ============================================
# EXTRACTION MODE
# The run is a defend-the-objective mission:
#   SCOUT    0:00-2:00  light pressure, find a defensible spot for the extractor
#   SIEGE    on placement  difficulty ramps from the moment it lands; enemies
#                          converge on the extractor and the bar fills
#   OVERRUN  after the bar fills  endless escalation past what is survivable
# Difficulty is keyed to time-since-placement, not run time, so placing early
# costs you pressure instead of buying free safety by stalling.
# ============================================
enum ExtractionPhase { SCOUT, SIEGE, OVERRUN }

const EXTRACTION_PLACEMENT_WINDOW := 120.0   # 2:00 to choose a spot
const EXTRACTION_DURATION := 600.0           # 10:00 of holding to fill the bar
const EXTRACTION_OVERRUN_PEAK := 1200.0      # 20:00 run time = near-invincible
const EXTRACTOR_STRUCTURE_ID := "resource_generator"

# --- Extraction milestones ----------------------------------------------------
# Fractions of the extraction bar that hand the horde a flat step up in both
# health and speed, on top of the time and phase curves already running.
#
# The steps COMPOUND, so the back of the bar is a different fight rather than
# more of the same one: x1.10 from halfway, x1.375 from three quarters, x1.65
# for the last tenth. Chest upgrades stack multiplicatively and uncapped, so a
# smooth curve always loses the endgame to a lucky run -- these are deliberate
# cliffs the player's power has to be re-earned against.
#
# Keyed on extraction progress rather than run time because that is the bar the
# player is actually watching, so the difficulty spike lands on a beat they can
# see coming.
const EXTRACTION_MILESTONES := [
	{"at": 0.50, "step": 1.10, "banner": "THE HORDE HARDENS"},
	{"at": 0.75, "step": 1.25, "banner": "THE HORDE SURGES"},
	{"at": 0.90, "step": 1.20, "banner": "THE HORDE IS UPON YOU"},
]

var extraction_phase: int = ExtractionPhase.SCOUT
var extractor: Node = null                 # the one placed extractor
var extractor_placed_at: float = -1.0      # run time when it landed
var extraction_progress: float = 0.0       # 0..1
var _extraction_milestone_index: int = 0   # how many milestone banners have fired

# --- Breach mode --------------------------------------------------------------
# Walling the extractor off cannot be fully prevented by placement rules alone:
# any geometric check has to guess at enclosure shapes, and a big enough fort
# will always find a case it does not cover. So the invariant is enforced at
# runtime instead - if the horde genuinely cannot reach the objective, it stops
# pathing and tears down whatever is in the way. Turtling then defeats itself.
const BREACH_CONFIRM_TIME := 0.8      # sustained before it trips, so a flow-field
                                      # rebuild mid-frame can't false-trigger it
const BREACH_MIN_ENEMIES := 5         # need a real sample before trusting "none can reach"
const BREACH_DAMAGE_MULT := 3.0       # walls come down fast; this is a penalty, not a puzzle
var extractor_sealed: bool = false
var _breach_confirm_timer: float = 0.0
var _breach_announced: bool = false
var _extraction_auto_placed := false
var _extraction_warned_30s := false
var _extraction_warned_10s := false

func extraction_time_remaining() -> float:
	"""Seconds left in the placement window (SCOUT phase only)."""
	if extraction_phase != ExtractionPhase.SCOUT:
		return 0.0
	return maxf(0.0, EXTRACTION_PLACEMENT_WINDOW - elapsed)

func siege_elapsed() -> float:
	"""Seconds since the extractor was placed; 0 during SCOUT."""
	if extractor_placed_at < 0.0:
		return 0.0
	return maxf(0.0, elapsed - extractor_placed_at)

func has_extractor() -> bool:
	return extractor != null and is_instance_valid(extractor)

# Run modifier multipliers (applied at run start from MetaProgression.pending_modifier).
var run_threat_mult = 1.0
var run_player_damage_taken_mult = 1.0
var run_ramp_speed_mult = 1.0

# Meta permanent-upgrade multipliers (applied at run start).
var meta_tower_damage_mult = 1.0
var meta_pickup_radius_mult = 1.0

# Keystone tech bonuses: build-defining picks (single-rank) that trade one
# tower stat for another. Folded into the get_tower_* accessors so every tower
# inherits them. Recomputed from tech_levels in _refresh_keystone_bonuses().
var keystone_damage_mult = 1.0
var keystone_rate_mult = 1.0
var keystone_range_mult = 1.0
var keystone_aoe_mult = 1.0
var keystone_chain_bonus = 0

# Income-decay telegraph: 0 = none, 1 = waning notice shown, 2 = low notice shown.
var _income_decay_notice_stage = 0

# Contextual controls hint: full hint shows early / in build mode, then fades once.
# Long enough to read once at the start of a run, short enough that it is not
# part of the permanent HUD. Full reference lives in the pause menu.
const CONTROLS_HINT_FADE_TIME = 25.0
var _controls_hint_faded = false

var spawn_radius_min = 500.0
var spawn_radius_max = 750.0
var max_enemies_cap_base = 210
var max_enemies_cap = 210
const HORDE_MINUTE_MULT_STEP = 0.22
const HORDE_MULT_MAX = 3.0
const HORDE_CAP_HARD_LIMIT = 520
# FFA spawns more aggressively than solo so every player faces a denser horde.
# These are the *base* (2-player) multipliers; the live values scale further with
# the live player count via _ffa_participant_count() so a full lobby (lots of
# players + towers) faces a far bigger, harder horde than a duel.
const FFA_SPAWN_RATE_MULT = 1.6
const FFA_MAX_ENEMY_MULT = 1.5
# Per *extra* participant beyond the first: +55% spawn rate, +60% enemy cap,
# +14% enemy difficulty (HP/damage). Tuned so 4 players is a real onslaught.
const FFA_RATE_PER_PLAYER = 0.55
const FFA_CAP_PER_PLAYER = 0.60
const FFA_DIFFICULTY_PER_PLAYER = 0.14

# Global balance knob. Effective pressure is roughly (enemy strength x body
# count), so the tuning is split evenly across both axes - raising each by
# sqrt(1.10) lands the product at exactly +10% rather than the +21% you'd get
# applying the full multiplier to each. Set to 1.0 to disable.
const DIFFICULTY_TUNING_MULT = 1.10
var max_projectiles = 150
var max_particles = 150  # Cap glow particles and FX to prevent memory issues
var elite_health_mult = 2.2
var max_allies = 16
var max_pickups = 60
const PERF_SAMPLE_INTERVAL = 0.45
const PERF_FX_SCALE_MIN = 0.20
const PERF_PROJECTILE_SCALE_MIN = 0.45
const PERF_FLOW_INTERVAL_MAX = 0.55
const SETPIECE_COOLDOWNS_MS = {
	"tower_evolution": 550,
	"elite_death": 120,
	"boss_death": 900,
	"cannon_impact": 110,
	"energy_impact": 95
}
const PERF_QUALITY_CAPS = {
	"low": {
		"particles": 84,
		"projectiles": 96,
		"damage_budget": 10,
		"optional_fx_cap": 0.62
	},
	"medium": {
		"particles": 124,
		"projectiles": 134,
		"damage_budget": 14,
		"optional_fx_cap": 0.82
	},
	"high": {
		"particles": 168,
		"projectiles": 176,
		"damage_budget": 20,
		"optional_fx_cap": 1.0
	},
	"ultra": {
		"particles": 220,
		"projectiles": 224,
		"damage_budget": 26,
		"optional_fx_cap": 1.18
	}
}
var _adaptive_perf_scale: float = 1.0
var _adaptive_perf_smoothed_fps: float = 60.0
var _adaptive_perf_sample_timer: float = 0.0
var _optional_fx_quality_cap: float = 1.0
var _runtime_target_fps: float = float(DEFAULT_RENDER_FPS_CAP)

var chest_drop_chance = 0.425
var chest_drop_cooldown = 12.0
var _next_chest_time = 0.0

# Dynamic sustain tuning (life pickup chance/amount).
var heal_drop_chance_enemy = 0.04
var heal_drop_chance_siege = 0.10
var heal_drop_chance_elite = 0.22
var heal_drop_chance_breakable = 0.12
var heal_drop_chance_chest = 0.25
var heal_drop_chance_missing_health_bonus = 0.30
var heal_drop_pct_enemy = 0.045
var heal_drop_pct_siege = 0.07
var heal_drop_pct_elite = 0.10
var heal_drop_pct_breakable = 0.08
var heal_drop_pct_chest = 0.12
var heal_drop_pct_missing_health_bonus = 0.06

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
			[ENEMY_SCENE, 46],
			[ZOMBIE_SHAMBLER_SCENE, 20],
			[CHARGER_SCENE, 18],
			[HELLHOUND_SCENE, 16]
		]
	},
	{
		"time": 90.0,
		"weights": [
			[ENEMY_SCENE, 28],
			[ZOMBIE_SHAMBLER_SCENE, 14],
			[CHARGER_SCENE, 14],
			[HELLHOUND_SCENE, 12],
			[SPITTER_SCENE, 13],
			[BANSHEE_SCENE, 10],
			[WRAITH_SCENE, 9]
		]
	},
	{
		"time": 150.0,
		"weights": [
			[ENEMY_SCENE, 18],
			[ZOMBIE_SHAMBLER_SCENE, 12],
			[CHARGER_SCENE, 10],
			[HELLHOUND_SCENE, 8],
			[SPITTER_SCENE, 12],
			[BANSHEE_SCENE, 8],
			[FIEND_DUELIST_SCENE, 9],
			[HEALER_SCENE, 7],
			[NECROMANCER_SCENE, 7],
			[WRAITH_SCENE, 5],
			[IMP_SKIRMISHER_SCENE, 4]
		]
	},
	{
		"time": 210.0,
		"weights": [
			[ENEMY_SCENE, 14],
			[ZOMBIE_SHAMBLER_SCENE, 10],
			[CHARGER_SCENE, 8],
			[HELLHOUND_SCENE, 7],
			[SPITTER_SCENE, 10],
			[BANSHEE_SCENE, 6],
			[FIEND_DUELIST_SCENE, 9],
			[HEALER_SCENE, 9],
			[NECROMANCER_SCENE, 9],
			[PLAGUE_ABOMINATION_SCENE, 10],
			[WRAITH_SCENE, 6],
			[IMP_SKIRMISHER_SCENE, 5]
		]
	},
	{
		"time": 300.0,
		"weights": [
			[ENEMY_SCENE, 10],
			[ZOMBIE_SHAMBLER_SCENE, 8],
			[CHARGER_SCENE, 8],
			[HELLHOUND_SCENE, 7],
			[SPITTER_SCENE, 10],
			[BANSHEE_SCENE, 6],
			[FIEND_DUELIST_SCENE, 9],
			[HEALER_SCENE, 10],
			[NECROMANCER_SCENE, 10],
			[PLAGUE_ABOMINATION_SCENE, 10],
			[WRAITH_SCENE, 8],
			[IMP_SKIRMISHER_SCENE, 7]
		]
	}
]

var breakable_target = 18
var breakable_spawn_min = 240.0
var breakable_spawn_max = 920.0

var prop_spawn_radius = 1600.0
var prop_min_distance = 120.0
var prop_count = 90
var prop_min_separation = 92.0          # rejection-sampling spacing between props
var prop_safe_spawn_radius = 180.0      # keep props out of the player start pocket
var cluster_count = 8
var cluster_min_distance = 260.0
var cluster_min_separation = 240.0      # landmarks need wide breathing room

# Props carry a weight (how often they appear) and a biome affinity so foliage
# favours the central grass and tombs/crypts favour the mid/outer wastes. The
# "size" is the source art's pixel height, used to seat the contact shadow.
const PROP_DEFS = [
	{"path": "res://assets/level1/level1_props/prop_graveyard_tombstone_small_32_v002.png", "size": 32, "weight": 10, "biomes": ["mud", "transition", "wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_tombstone_large_48_v002.png", "size": 48, "weight": 8, "biomes": ["mud", "transition", "wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_tombstone_tall_48_v001.png", "size": 48, "weight": 6, "biomes": ["transition", "wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_broken_pillar_48_v002.png", "size": 48, "weight": 5, "biomes": ["transition", "wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_ruined_pillar_48_v001.png", "size": 48, "weight": 4, "biomes": ["wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_broken_fence_32_v002.png", "size": 32, "weight": 6, "biomes": ["grass", "transition"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_dead_tree_stump_48_v002.png", "size": 48, "weight": 6, "biomes": ["grass", "transition"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_skull_cairn_32_v001.png", "size": 32, "weight": 4, "biomes": ["wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_skull_pile_32_v002.png", "size": 32, "weight": 4, "biomes": ["mud", "wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_bone_pile_32_v001.png", "size": 32, "weight": 4, "biomes": ["mud", "wasteland"]},
	{"path": "res://assets/level1/level1_props/prop_graveyard_lantern_32_v001.png", "size": 32, "weight": 3, "biomes": ["grass", "transition"]}
	# NOTE: crates + broken cart props removed — they read as "treasure chests" and
	# confused players into thinking they were openable loot. (Real chests come from
	# spawn_treasure_chest only.)
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
		"min_level": 1,
		"category": "tower"
	},
	"gun_pierce": {
		"name": "Gun: Piercing",
		"desc": "Shots pierce +1 enemy",
		"max": 2,
		"icon": "res://assets/ui/ui_icon_iron_32_v001.png",
		"rarity": "common",
		"min_level": 1,
		"category": "engineer"
	},
	"gun_burst": {
		"name": "Gun: Burst Volley",
		"desc": "Every few shots fires a 3-shot spread",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png",
		"rarity": "rare",
		"min_level": 2,
		"category": "engineer"
	},
	"gun_slow": {
		"name": "Gun: Cryo Rounds",
		"desc": "Shots slow enemies briefly",
		"max": 2,
		"icon": "res://assets/ui/ui_icon_ice_32_v001.png",
		"rarity": "rare",
		"min_level": 2,
		"category": "engineer"
	},
	# Build-unlock tech picks removed: all five buildable structures
	# (arrow_turret, cannon_tower, tesla_tower, resource_generator, shrine) are now
	# unlocked from the start via _unlock_core_builds(), and the trap/extra-building
	# unlocks (mine, ice, acid, barracks, tech_lab, armory) were dropped along with
	# those buildings. See docs/REMOVED_BUILDINGS.md to restore.
	"tesla_emp": {
		"name": "Tesla: EMP",
		"desc": "Tesla shocks slow and stun briefly",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "legendary",
		"min_level": 6,
		"requires_build": "tesla_tower",
		"category": "tower"
	},
	"tower_range": {
		"name": "Towers: Long Range",
		"desc": "+25% range to all towers",
		"max": 4,
		"icon": "res://assets/ui/ui_icon_stone_32_v001.png",
		"rarity": "common",
		"min_level": 2,
		"category": "tower"
	},
	"tower_damage": {
		"name": "Towers: Brutality",
		"desc": "+6 damage to all towers",
		"max": 4,
		"icon": "res://assets/ui/ui_icon_iron_32_v001.png",
		"rarity": "rare",
		"min_level": 2,
		"category": "tower"
	},
	"tower_overclock": {
		"name": "Towers: Overclock",
		"desc": "+22% fire rate to all towers",
		"max": 4,
		"icon": "res://assets/ui/ui_icon_crystal_32_v001.png",
		"rarity": "epic",
		"min_level": 4,
		"category": "tower"
	},
	"tower_ordnance": {
		"name": "Towers: Heavy Ordnance",
		"desc": "+9 damage to all towers",
		"max": 3,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png",
		"rarity": "epic",
		"min_level": 5,
		"category": "tower"
	},
	"tower_chain": {
		"name": "Tesla: Arc Relays",
		"desc": "Tesla bolts chain to +1 more target",
		"max": 4,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "epic",
		"min_level": 5,
		"requires_build": "tesla_tower",
		"category": "tower"
	},
	"tower_aoe": {
		"name": "Towers: Blast Radius",
		"desc": "+18% blast radius on AoE towers",
		"max": 4,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png",
		"rarity": "rare",
		"min_level": 4,
		"category": "tower"
	},
	"orbital_overdrive": {
		"name": "Relic: Orbital Overdrive",
		"desc": "+40% fire rate, +16 damage, +20% range to all towers",
		"max": 2,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "legendary",
		"min_level": 8,
		"category": "tower"
	},
	"resource_cache": {
		"name": "Supply Cache",
		"desc": "Gain a burst of resources now",
		"max": 8,
		"icon": "res://assets/ui/ui_icon_gold_32_v001.png",
		"rarity": "common",
		"min_level": 1,
		"category": "economy"
	},
	"field_repairs": {
		"name": "Field Repairs",
		"desc": "Restore health immediately",
		"max": 5,
		"icon": "res://assets/ui/ui_icon_ice_32_v001.png",
		"rarity": "common",
		"min_level": 1,
		"category": "economy"
	},
	"engineer_vitality": {
		"name": "Engineer: Vitality Frame",
		"desc": "Increase max health by +20% (up to +100%)",
		"max": 5,
		"icon": "res://assets/ui/ui_icon_ice_32_v001.png",
		"rarity": "rare",
		"min_level": 1,
		"category": "engineer"
	},
	"essence_cache": {
		"name": "Essence Cache",
		"desc": "Gain +2 Essence immediately",
		"max": 4,
		"icon": "res://assets/ui/ui_icon_crystal_32_v001.png",
		"rarity": "rare",
		"min_level": 3,
		"category": "economy"
	},
	# --- Keystones: build-defining, single-rank picks that trade one tower
	# stat for another. Effects are applied in _refresh_keystone_bonuses().
	"keystone_glass_cannon": {
		"name": "Keystone: Glass Cannon",
		"desc": "+60% tower damage, but -20% fire rate",
		"max": 1,
		"keystone": true,
		"icon": "res://assets/ui/ui_icon_fire_32_v001.png",
		"rarity": "legendary",
		"min_level": 5,
		"category": "tower"
	},
	"keystone_storm_battery": {
		"name": "Keystone: Storm Battery",
		"desc": "+55% fire rate, but -15% range",
		"max": 1,
		"keystone": true,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "legendary",
		"min_level": 5,
		"category": "tower"
	},
	"keystone_siege_doctrine": {
		"name": "Keystone: Siege Doctrine",
		"desc": "+40% damage & +30% blast radius, but -10% fire rate",
		"max": 1,
		"keystone": true,
		"icon": "res://assets/ui/ui_icon_stone_32_v001.png",
		"rarity": "epic",
		"min_level": 5,
		"category": "tower"
	},
	"keystone_overcharged_arc": {
		"name": "Keystone: Overcharged Arc",
		"desc": "Tesla chains +2 targets and all towers gain +25% damage",
		"max": 1,
		"keystone": true,
		"icon": "res://assets/ui/ui_icon_lightning_32_v001.png",
		"rarity": "legendary",
		"min_level": 6,
		"requires_build": "tesla_tower",
		"category": "tower"
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
			"res://assets/fx/fx_hit_spark_32_f001_v002.png",
			"res://assets/fx/fx_hit_spark_32_f002_v002.png",
			"res://assets/fx/fx_hit_spark_32_f003_v002.png",
			"res://assets/fx/fx_hit_spark_32_f004_v002.png"
		],
		"fps": 20.0,
		"lifetime": 0.2,
		"scale": 1.35,
		"alpha": 0.9,
		"z": 2
	},
	"crit": {
		"paths": [
			"res://assets/fx/fx_crit_impact_64_f001_v002.png",
			"res://assets/fx/fx_crit_impact_64_f002_v002.png",
			"res://assets/fx/fx_crit_impact_64_f003_v002.png",
			"res://assets/fx/fx_crit_impact_64_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.26,
		"scale": 1.8,
		"alpha": 0.95,
		"z": 3
	},
	"chain_hit": {
		"paths": [
			"res://assets/fx/fx_chain_hit_32_f001_v002.png",
			"res://assets/fx/fx_chain_hit_32_f002_v002.png",
			"res://assets/fx/fx_chain_hit_32_f003_v002.png",
			"res://assets/fx/fx_chain_hit_32_f004_v002.png"
		],
		"fps": 17.0,
		"lifetime": 0.22,
		"scale": 1.1,
		"alpha": 0.9,
		"z": 2
	},
	"kill_pop": {
		"paths": [
			"res://assets/fx/fx_kill_pop_32_f001_v002.png",
			"res://assets/fx/fx_kill_pop_32_f002_v002.png",
			"res://assets/fx/fx_kill_pop_32_f003_v002.png",
			"res://assets/fx/fx_kill_pop_32_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.28,
		"scale": 1.7,
		"alpha": 0.95,
		"z": 2
	},
	"elite_kill": {
		"paths": [
			"res://assets/fx/fx_elite_kill_impact_64_f001_v002.png",
			"res://assets/fx/fx_elite_kill_impact_64_f002_v002.png",
			"res://assets/fx/fx_elite_kill_impact_64_f003_v002.png",
			"res://assets/fx/fx_elite_kill_impact_64_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.32,
		"scale": 2.25,
		"alpha": 1.0,
		"z": 3
	},
	"build": {
		"paths": [
			"res://assets/fx/fx_holy_burst_32_f001_v002.png",
			"res://assets/fx/fx_holy_burst_32_f002_v002.png",
			"res://assets/fx/fx_holy_burst_32_f003_v002.png",
			"res://assets/fx/fx_holy_burst_32_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.25,
		"scale": 1.25,
		"alpha": 0.9,
		"z": 3,
		"tint": Color(0.92, 0.88, 0.65)
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
		"hero_evolution": {
			"paths": [
				"res://assets/fx/fx_holy_burst_64_f001_v003.png",
				"res://assets/fx/fx_holy_burst_64_f002_v003.png",
				"res://assets/fx/fx_holy_burst_64_f003_v003.png",
				"res://assets/fx/fx_holy_burst_64_f004_v003.png"
			],
			"fps": 28.0,
			"lifetime": 0.62,
			"scale": 3.5,
			"alpha": 1.0,
			"z": 10,
			"tint": Color(0.45, 0.24, 1.0, 1.0)
		},
		"hero_elite_death": {
			"paths": [
				"res://assets/fx/fx_elite_kill_impact_64_f001_v003.png",
				"res://assets/fx/fx_elite_kill_impact_64_f002_v003.png",
				"res://assets/fx/fx_elite_kill_impact_64_f003_v003.png",
				"res://assets/fx/fx_elite_kill_impact_64_f004_v003.png"
			],
			"fps": 26.0,
			"lifetime": 0.56,
			"scale": 3.8,
			"alpha": 1.0,
			"z": 10,
			"tint": Color(1.0, 0.78, 0.18, 1.0)
		},
		"hero_boss_death": {
			"paths": [
				"res://assets/fx/fx_crit_impact_64_f001_v003.png",
				"res://assets/fx/fx_crit_impact_64_f002_v003.png",
				"res://assets/fx/fx_crit_impact_64_f003_v003.png",
				"res://assets/fx/fx_crit_impact_64_f004_v003.png"
			],
			"fps": 24.0,
			"lifetime": 0.72,
			"scale": 4.6,
			"alpha": 1.0,
			"z": 11,
			"tint": Color(1.0, 0.2, 0.2, 1.0)
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
		"hero_cannon_impact": {
			"paths": [
				"res://assets/fx/fx_explosion_small_32_f001_v003.png",
				"res://assets/fx/fx_explosion_small_32_f002_v003.png",
				"res://assets/fx/fx_explosion_small_32_f003_v003.png",
				"res://assets/fx/fx_explosion_small_32_f004_v003.png"
			],
			"fps": 24.0,
			"lifetime": 0.42,
			"scale": 2.8,
			"alpha": 1.0,
			"z": 6,
			"tint": Color(1.0, 0.4, 0.08, 1.0)
		},
		"hero_energy_impact": {
			"paths": [
				"res://assets/fx/fx_chain_hit_64_f001_v003.png",
				"res://assets/fx/fx_chain_hit_64_f002_v003.png",
				"res://assets/fx/fx_chain_hit_64_f003_v003.png",
				"res://assets/fx/fx_chain_hit_64_f004_v003.png"
			],
			"fps": 24.0,
			"lifetime": 0.42,
			"scale": 2.9,
			"alpha": 1.0,
			"z": 6,
			"tint": Color(0.24, 1.0, 1.0, 1.0)
		},
		"fire_burst": {
		"paths": [
			"res://assets/fx/fx_fire_burst_32_f001_v002.png",
			"res://assets/fx/fx_fire_burst_32_f002_v002.png",
			"res://assets/fx/fx_fire_burst_32_f003_v002.png",
			"res://assets/fx/fx_fire_burst_32_f004_v002.png"
		],
		"fps": 18.0,
		"lifetime": 0.2,
		"scale": 1.1,
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
			"res://assets/fx/fx_blood_splat_64_f001_v002.png",
			"res://assets/fx/fx_blood_splat_64_f002_v002.png",
			"res://assets/fx/fx_blood_splat_64_f003_v002.png",
			"res://assets/fx/fx_blood_splat_64_f004_v002.png"
		],
		"fps": 16.0,
		"lifetime": 0.28,
		"scale": 1.45,
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
var _setpiece_fx_last_ms: Dictionary = {}
var _damage_font: Font = null
var _screen_grade: CanvasLayer = null
const DAMAGE_BADGE_PATHS = {
	"normal_small": "res://assets/ui_damage/normal_small.png",
	"normal_large": "res://assets/ui_damage/normal_large.png",
	"dot_small": "res://assets/ui_damage/dot_small.png",
	"dot_large": "res://assets/ui_damage/dot_large.png",
	"crit_small": "res://assets/ui_damage/crit_small.png",
	"crit_large": "res://assets/ui_damage/crit_large.png"
}
const DAMAGE_LABEL_SHADER_CODE = """
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.6, 0.6, 0.6, 1.0);

void fragment() {
	vec4 src = COLOR;
	// A Label draws its outline and its glyph in the same pass, distinguished only
	// by the incoming vertex colour: near-black for the outline, white for the
	// glyph. Recolouring every fragment (the old behaviour) painted the fill over
	// the outline too, so numbers lost their dark border and neighbours melted
	// into one blurry blob. Split on luminance and only touch the glyph.
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	float glyph = smoothstep(0.35, 0.62, lum);
	// Vertical gradient in local UV space: bright at the top, darker at the base.
	// Local (not screen) space keeps every number self-contained.
	vec3 fill = mix(top_color.rgb, bottom_color.rgb, clamp(UV.y, 0.0, 1.0));
	COLOR = vec4(mix(src.rgb, fill, glyph), src.a);
}
"""
var _damage_badge_cache: Dictionary = {}
var _damage_label_shader: Shader = null
# Ring buffer of recent damage-number spawn spots, used to spread out numbers
# that would otherwise land on top of each other during a swarm.
var _damage_spot_pos: PackedVector2Array = PackedVector2Array()
var _damage_spot_radius: PackedFloat32Array = PackedFloat32Array()
var _damage_spot_ms: PackedInt32Array = PackedInt32Array()
var _damage_spot_head: int = 0

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

func _new_rarity_count_dict() -> Dictionary:
	var counts: Dictionary = {}
	for rarity in TECH_RARITY_ORDER:
		counts[rarity] = 0
	return counts

func _blank_draft_telemetry() -> Dictionary:
	return {
		"draft_count": 0,
		"dead_screens": 0,
		"reroll_count": 0,
		"reroll_essence_spent": 0,
		"lock_count": 0,
		"lock_essence_spent": 0,
		"force_count": 0,
		"force_essence_spent": 0,
		"infuse_count": 0,
		"infuse_essence_spent": 0,
		"offered": _new_rarity_count_dict(),
		"chosen": _new_rarity_count_dict()
	}

func _ensure_draft_telemetry() -> void:
	if _draft_telemetry.is_empty():
		_draft_telemetry = _blank_draft_telemetry()

func _rarity_index(rarity: String) -> int:
	var index = TECH_RARITY_ORDER.find(rarity)
	if index < 0:
		return 0
	return index

func _rarity_for_tech(id: String) -> String:
	var def: Dictionary = tech_defs.get(id, {})
	return str(def.get("rarity", "common"))

func _tech_category_for(id: String) -> String:
	var def: Dictionary = tech_defs.get(id, {})
	return str(def.get("category", "engineer"))

func _category_label(category: String) -> String:
	match category:
		"tower":
			return "Tower"
		"engineer":
			return "Engineer"
		"economy":
			return "Economy"
	return category.capitalize()

func _max_rarity(a: String, b: String) -> String:
	return a if _rarity_index(a) >= _rarity_index(b) else b

func _reset_progression_state() -> void:
	_tech_rerolls_this_pick = 0
	_tech_rerolls_this_run = 0
	_tech_base_rate_mult = 1.0
	_tech_dead_screen_threshold_index = _rarity_index("rare")
	_draft_pity = {
		"rare_miss": 0,
		"epic_miss": 0,
		"legendary_miss": 0
	}
	_tech_locked_id = ""
	_tech_locked_name = ""
	_tech_forced_category_once = ""
	_draft_telemetry = _blank_draft_telemetry()

func _unlock_core_builds() -> void:
	unlocked_builds.clear()
	for id in CORE_BUILD_IDS:
		unlocked_builds[id] = true

func _target_draft_floor_rarity() -> String:
	var floor_rarity = "common"
	if level >= 10:
		floor_rarity = "rare"
	if level >= 18:
		floor_rarity = "epic"
	if level >= 24:
		floor_rarity = "legendary"
	if int(_draft_pity.get("rare_miss", 0)) >= 2:
		floor_rarity = _max_rarity(floor_rarity, "rare")
	if int(_draft_pity.get("epic_miss", 0)) >= 4:
		floor_rarity = _max_rarity(floor_rarity, "epic")
	if int(_draft_pity.get("legendary_miss", 0)) >= 7:
		floor_rarity = _max_rarity(floor_rarity, "legendary")
	return floor_rarity

func _pool_with_rarity_floor(available: Array, floor_rarity: String, option_count: int) -> Array:
	var required = min(option_count, available.size())
	var floor_index = _rarity_index(floor_rarity)
	for rarity_index in range(floor_index, -1, -1):
		var filtered: Array = []
		for raw_id in available:
			var id = str(raw_id)
			if _rarity_index(_rarity_for_tech(id)) >= rarity_index:
				filtered.append(id)
		if filtered.size() >= required:
			return filtered
	return available.duplicate()

func _roll_tech_picks(available: Array, option_count: int, floor_rarity: String) -> Array:
	var pool = _pool_with_rarity_floor(available, floor_rarity, option_count)
	var picks: Array = _pick_weighted_choices(pool, min(option_count, pool.size()))
	if picks.size() >= option_count or available.size() <= picks.size():
		return picks
	var fallback_pool: Array = available.duplicate()
	for id in picks:
		fallback_pool.erase(id)
	picks += _pick_weighted_choices(fallback_pool, option_count - picks.size())
	return picks

func _filter_ids_by_category(pool: Array, category: String) -> Array:
	var filtered: Array = []
	for raw_id in pool:
		var id = str(raw_id)
		if _tech_category_for(id) == category:
			filtered.append(id)
	return filtered

func _can_level_tech(id: String) -> bool:
	var def: Dictionary = tech_defs.get(id, {})
	var max_level = int(def.get("max", 1))
	var current = int(tech_levels.get(id, 0))
	return current < max_level

func _can_infuse_tech(id: String) -> bool:
	if not _can_level_tech(id):
		return false
	var def: Dictionary = tech_defs.get(id, {})
	var max_level = int(def.get("max", 1))
	var current = int(tech_levels.get(id, 0))
	return current + 1 < max_level

func _build_tech_pick_ids(available_ids: Array, floor_rarity: String, locked_id: String = "", forced_category: String = "") -> Array:
	var picks: Array = []
	var available: Array = available_ids.duplicate()
	if locked_id != "" and available.has(locked_id):
		picks.append(locked_id)
		available.erase(locked_id)
	if forced_category != "" and picks.size() < 3:
		var forced_pool = _pool_with_rarity_floor(_filter_ids_by_category(available, forced_category), floor_rarity, 1)
		if not forced_pool.is_empty():
			var forced_pick = _pick_weighted_id(forced_pool)
			picks.append(forced_pick)
			available.erase(forced_pick)
	var represented_categories: Array = []
	for raw_id in picks:
		var cat = _tech_category_for(str(raw_id))
		if not represented_categories.has(cat):
			represented_categories.append(cat)
	for category in TECH_CATEGORY_ORDER:
		if picks.size() >= 3:
			break
		if represented_categories.has(category):
			continue
		var category_pool = _pool_with_rarity_floor(_filter_ids_by_category(available, category), floor_rarity, 1)
		if category_pool.is_empty():
			continue
		var category_pick = _pick_weighted_id(category_pool)
		picks.append(category_pick)
		available.erase(category_pick)
		represented_categories.append(category)
	if picks.size() < 3 and not available.is_empty():
		picks += _roll_tech_picks(available, 3 - picks.size(), floor_rarity)
	return picks

func _same_choice_ids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var aa: Array = []
	var bb: Array = []
	for value in a:
		aa.append(str(value))
	for value in b:
		bb.append(str(value))
	aa.sort()
	bb.sort()
	return aa == bb

func _track_draft_offer(picks: Array, _floor_rarity: String) -> void:
	_ensure_draft_telemetry()
	_draft_telemetry["draft_count"] = int(_draft_telemetry.get("draft_count", 0)) + 1
	var offered: Dictionary = _draft_telemetry.get("offered", _new_rarity_count_dict())
	var best = "common"
	for raw_id in picks:
		var id = str(raw_id)
		var rarity = _rarity_for_tech(id)
		offered[rarity] = int(offered.get(rarity, 0)) + 1
		if _rarity_index(rarity) > _rarity_index(best):
			best = rarity
	_draft_telemetry["offered"] = offered
	if _rarity_index(best) < _tech_dead_screen_threshold_index:
		_draft_telemetry["dead_screens"] = int(_draft_telemetry.get("dead_screens", 0)) + 1
	if _rarity_index(best) >= _rarity_index("rare"):
		_draft_pity["rare_miss"] = 0
	else:
		_draft_pity["rare_miss"] = int(_draft_pity.get("rare_miss", 0)) + 1
	if _rarity_index(best) >= _rarity_index("epic"):
		_draft_pity["epic_miss"] = 0
	else:
		_draft_pity["epic_miss"] = int(_draft_pity.get("epic_miss", 0)) + 1
	if _rarity_index(best) >= _rarity_index("legendary"):
		_draft_pity["legendary_miss"] = 0
	else:
		_draft_pity["legendary_miss"] = int(_draft_pity.get("legendary_miss", 0)) + 1

func _track_draft_pick(rarity: String) -> void:
	_ensure_draft_telemetry()
	var chosen: Dictionary = _draft_telemetry.get("chosen", _new_rarity_count_dict())
	chosen[rarity] = int(chosen.get(rarity, 0)) + 1
	_draft_telemetry["chosen"] = chosen

func _build_tech_ui_meta(forced_category: String = "") -> Dictionary:
	return {
		"infuse_cost": TECH_INFUSE_COST,
		"lock_cost": TECH_LOCK_COST,
		"force_cost": TECH_FORCE_CATEGORY_COST,
		"locked_name": _tech_locked_name,
		"forced_category": forced_category
	}

func _refresh_tech_scalars() -> void:
	tower_range_mult = 1.0 + 0.25 * int(tech_levels.get("tower_range", 0)) + 0.20 * int(tech_levels.get("orbital_overdrive", 0))
	tower_damage_bonus = (
		chest_tower_damage_bonus
		+ 6.0 * int(tech_levels.get("tower_damage", 0))
		+ 9.0 * int(tech_levels.get("tower_ordnance", 0))
		+ 16.0 * int(tech_levels.get("orbital_overdrive", 0))
	)
	_tech_base_rate_mult = (
		1.0
		+ 0.22 * int(tech_levels.get("tower_overclock", 0))
		+ 0.40 * int(tech_levels.get("orbital_overdrive", 0))
	)
	tower_chain_bonus = chest_tower_chain_bonus + int(tech_levels.get("tower_chain", 0)) + int(tech_levels.get("orbital_overdrive", 0))
	tower_aoe_mult = chest_tower_aoe_mult * (1.0 + 0.18 * int(tech_levels.get("tower_aoe", 0)) + 0.15 * int(tech_levels.get("orbital_overdrive", 0)))
	_refresh_keystone_bonuses()
	_recalc_effects()

func _refresh_keystone_bonuses() -> void:
	# Keystones are single-rank; presence (level > 0) toggles the whole package.
	# Multipliers stack multiplicatively so picking several keystones still reads
	# sensibly (and is intentionally hard to assemble given their rarity).
	keystone_damage_mult = 1.0
	keystone_rate_mult = 1.0
	keystone_range_mult = 1.0
	keystone_aoe_mult = 1.0
	keystone_chain_bonus = 0
	if int(tech_levels.get("keystone_glass_cannon", 0)) > 0:
		keystone_damage_mult *= 1.60
		keystone_rate_mult *= 0.80
	if int(tech_levels.get("keystone_storm_battery", 0)) > 0:
		keystone_rate_mult *= 1.55
		keystone_range_mult *= 0.85
	if int(tech_levels.get("keystone_siege_doctrine", 0)) > 0:
		keystone_damage_mult *= 1.40
		keystone_aoe_mult *= 1.30
		keystone_rate_mult *= 0.90
	if int(tech_levels.get("keystone_overcharged_arc", 0)) > 0:
		keystone_chain_bonus += 2
		keystone_damage_mult *= 1.25

func _get_tech_reroll_cost() -> int:
	var cost = TECH_REROLL_BASE_COST + _tech_rerolls_this_pick * TECH_REROLL_COST_STEP
	return min(TECH_REROLL_MAX_COST, cost)

func _try_reroll_tech() -> void:
	if not tech_open:
		return
	var available: Array = _get_available_tech_ids()
	if available.size() <= 1:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("No alternate upgrades available", Color(0.9, 0.6, 0.3), 20, 1.5)
		return
	var cost = _get_tech_reroll_cost()
	if essence < cost:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("Need %d Essence to reroll" % cost, Color(0.9, 0.45, 1.0), 20, 1.5)
		return
	essence -= cost
	_ensure_draft_telemetry()
	_tech_rerolls_this_pick += 1
	_tech_rerolls_this_run += 1
	_draft_telemetry["reroll_count"] = int(_draft_telemetry.get("reroll_count", 0)) + 1
	_draft_telemetry["reroll_essence_spent"] = int(_draft_telemetry.get("reroll_essence_spent", 0)) + cost
	_open_tech_menu(true)
	_update_ui()

func _try_lock_tech(index: int) -> void:
	if not tech_open:
		return
	if index < 0 or index >= tech_choices.size():
		return
	if essence < TECH_LOCK_COST:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("Need %d Essence to lock" % TECH_LOCK_COST, Color(0.9, 0.45, 1.0), 20, 1.3)
		return
	var choice: Dictionary = tech_choices[index]
	var id = str(choice.get("id", ""))
	if id == "":
		return
	essence -= TECH_LOCK_COST
	_tech_locked_id = id
	_tech_locked_name = str(choice.get("name", id))
	_ensure_draft_telemetry()
	_draft_telemetry["lock_count"] = int(_draft_telemetry.get("lock_count", 0)) + 1
	_draft_telemetry["lock_essence_spent"] = int(_draft_telemetry.get("lock_essence_spent", 0)) + TECH_LOCK_COST
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("Locked next draft: %s" % _tech_locked_name, Color(0.8, 0.9, 1.0), 18, 1.5)
	if ui != null and ui.has_method("show_tech"):
		ui.show_tech(tech_choices, essence, _get_tech_reroll_cost(), _build_tech_ui_meta())
	_update_ui()

func _try_force_category(category: String) -> void:
	if not tech_open:
		return
	var available = _filter_ids_by_category(_get_available_tech_ids(), category)
	if available.is_empty():
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("No %s upgrades available" % _category_label(category), Color(0.9, 0.6, 0.35), 20, 1.4)
		return
	if essence < TECH_FORCE_CATEGORY_COST:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("Need %d Essence to force category" % TECH_FORCE_CATEGORY_COST, Color(0.9, 0.45, 1.0), 20, 1.3)
		return
	essence -= TECH_FORCE_CATEGORY_COST
	_tech_forced_category_once = category
	_ensure_draft_telemetry()
	_draft_telemetry["force_count"] = int(_draft_telemetry.get("force_count", 0)) + 1
	_draft_telemetry["force_essence_spent"] = int(_draft_telemetry.get("force_essence_spent", 0)) + TECH_FORCE_CATEGORY_COST
	_open_tech_menu(true)
	_update_ui()

func _try_choose_infused(index: int) -> void:
	if not tech_open:
		return
	_choose_tech(index, true)

func _log_draft_telemetry() -> void:
	if _draft_telemetry.is_empty():
		return
	print(
		"[DraftTelemetry] drafts=%d dead=%d rerolls=%d reroll_essence=%d lock=%d lock_essence=%d force=%d force_essence=%d infuse=%d infuse_essence=%d offered=%s chosen=%s pity=%s" % [
			int(_draft_telemetry.get("draft_count", 0)),
			int(_draft_telemetry.get("dead_screens", 0)),
			int(_draft_telemetry.get("reroll_count", 0)),
			int(_draft_telemetry.get("reroll_essence_spent", 0)),
			int(_draft_telemetry.get("lock_count", 0)),
			int(_draft_telemetry.get("lock_essence_spent", 0)),
			int(_draft_telemetry.get("force_count", 0)),
			int(_draft_telemetry.get("force_essence_spent", 0)),
			int(_draft_telemetry.get("infuse_count", 0)),
			int(_draft_telemetry.get("infuse_essence_spent", 0)),
			str(_draft_telemetry.get("offered", {})),
			str(_draft_telemetry.get("chosen", {})),
			str(_draft_pity)
		]
	)

func _ready() -> void:
	randomize()
	add_to_group("game")
	set_process_unhandled_input(true)
	_ensure_input_map()
	_settings_manager = _get_settings_manager()
	# Re-assert the custom hardware cursor for the gameplay scene (a scene change
	# can drop the boot-time cursor, so it only showed on the menu otherwise).
	if _settings_manager != null and _settings_manager.has_method("apply_custom_cursor"):
		_settings_manager.apply_custom_cursor()
	_instantiate_pause_menu()
	_instantiate_settings_menu()
	_connect_settings_manager()
	_sync_runtime_settings()
	_apply_runtime_performance_budgets()
	_load_damage_font()
	_prepare_damage_badges()
	_damage_number_budget = _get_damage_budget_per_sec()
	_setup_screen_grade()

	# Multiplayer: build the player registry. In solo this just registers the
	# existing scene player (zero behavior change); in FFA it spawns one player
	# per roster entry and re-points `player`/`camera` at the LOCAL one.
	_setup_players()
	if is_ffa() and is_host() and OS.get_cmdline_user_args().has("--ffa-econ-test"):
		call_deferred("_run_econ_selftest")

	# Initialize audio system
	if camera != null:
		AudioManager.set_camera(camera)
		# Setup dynamic camera controller
		if camera.has_method("setup"):
			camera.setup(player, self)
	
	# Punchy/neon bloom layer (quality-gated). Created in code so it can
	# re-apply live when the player cycles graphics quality.
	_setup_world_environment()

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
	resources = START_RESOURCES
	_unlock_core_builds()
	_reset_progression_state()
	_refresh_tech_scalars()
	
	# Initialize game over UI (hidden initially)
	_instantiate_game_over_ui()
	
	_update_ui()
	var meta_autostart := false
	var meta = _get_meta_progression()
	# Pick the terrain palette for the selected level before the rest of setup.
	if ground != null and ground.has_method("set_active_level"):
		var level_id := "graveyard"
		if meta != null and "pending_level" in meta:
			level_id = str(meta.pending_level)
		ground.set_active_level(level_id)
	if meta != null and bool(meta.autostart_run):
		meta_autostart = true
	# No press-Enter gate. The main menu already picks the hero (meta.pending_hero,
	# applied above) and the level, so the in-game character-select screen only
	# added a second confirmation between hitting Play and actually playing.
	if ui != null and ui.has_method("show_start"):
		ui.show_start(false)
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
	_apply_play_bounds()
	_reset_run_stats()
	_set_pause_allowed(false)
	mark_flow_field_dirty()
	# Always drop straight into the run. Clearing the flag keeps a menu-launched
	# run from re-arming autostart for a later scene load; starting is now
	# unconditional either way, including when the game scene is opened directly
	# from the editor rather than through the menu.
	if meta != null:
		meta.autostart_run = false
	_start_game()
	_print_startup_banner()
	# FFA has no character-select / press-to-start gate: the host already locked
	# the roster in the lobby, so every peer drops straight into the match.
	if is_ffa():
		_instantiate_ffa_results_ui()
		_instantiate_ffa_death_ui()
		# Remember how many real players started so the last-player-standing grace
		# timer only ever triggers in a genuine multi-human match (never solo-host
		# + bots, where there's no one left to wait for).
		_ffa_started_real_count = _count_real_players()
		# Test helper: shorten the 20-min match so the end-of-match flow can be
		# exercised headlessly.  godot ... -- --ffa-short-match
		if OS.get_cmdline_user_args().has("--ffa-short-match"):
			_ffa_time_left = 12.0
		if ui != null and ui.has_method("show_start"):
			ui.show_start(false)
		_start_game()

# ---- Multiplayer: player registry ----------------------------------------

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _net_verbose() -> bool:
	return OS.get_cmdline_user_args().has("--net-verbose")

func is_solo() -> bool:
	var n := _net()
	return n == null or not n.is_multiplayer()

func is_ffa() -> bool:
	return not is_solo()

func is_host() -> bool:
	var n := _net()
	return n != null and n.is_host

# True when this instance owns the shared simulation (enemy spawning + AI):
# solo always, or the host in FFA. Clients defer to replicated state.
func _is_sim_authority() -> bool:
	return is_solo() or is_host()

# Public alias so enemies/projectiles can gate host-only AI.
func is_sim_authority() -> bool:
	return _is_sim_authority()

# Builds `players`. Solo keeps the hardcoded $World/Player untouched. FFA hides
# it and spawns one networked player per roster entry; only the host spawns,
# clients receive them via the player spawn RPC.
func _setup_players() -> void:
	players.clear()
	_init_econ()
	if is_solo():
		players[1] = player
		local_player = player
		return
	# --- FFA ---
	var net := _net()
	# The pre-placed scene player is unused in FFA; remove it so it doesn't
	# double up with the spawned local player.
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null
	camera = null
	local_player = null
	if _net_verbose():
		print("[FFA] _setup_players host=", net.is_host, " roster=", net.match_roster.size())
	if net.is_host:
		_host_spawn_all_players()
	else:
		# Client just entered the match scene: ask the host for the full player
		# list. This avoids RPC-vs-scene-load races (host may have spawned
		# before we were ready to receive).
		_rpc_request_players.rpc_id(1)

# Host: (re)spawn every roster player locally and store their data so it can be
# replicated to any peer that asks.
func _host_spawn_all_players() -> void:
	var net := _net()
	var roster: Array = net.match_roster
	_ffa_spawn_data.clear()
	var i := 0
	for entry in roster:
		var pid := int(entry["peer_id"])
		var hero := str(entry.get("hero", "warlock"))
		var bot := bool(entry.get("is_bot", false))
		var pos := _ffa_spawn_position(i, roster.size())
		_ffa_spawn_data.append({"pid": pid, "hero": hero, "bot": bot, "pos": pos})
		_spawn_player(pid, hero, bot, pos)
		i += 1

# Cached spawn descriptors so the host can answer late client requests.
var _ffa_spawn_data: Array = []

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_players() -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	for d in _ffa_spawn_data:
		_rpc_spawn_player.rpc_id(sender, int(d["pid"]), str(d["hero"]), bool(d["bot"]), d["pos"])

@rpc("authority", "call_remote", "reliable")
func _rpc_spawn_player(pid: int, hero: String, bot: bool, pos: Vector2) -> void:
	_spawn_player(pid, hero, bot, pos)

func _spawn_player(pid: int, hero: String, bot: bool, pos: Vector2) -> void:
	if players.has(pid):
		return
	var p: CharacterBody2D = PLAYER_SCENE.instantiate()
	p.name = "Player_%d" % pid
	p.peer_id = pid
	p.is_bot = bot
	p.global_position = pos
	# Input authority: the owning peer for humans; the host for bots.
	var authority := 1 if bot else pid
	p.set_multiplayer_authority(authority)
	$World.add_child(p)
	players[pid] = p
	# Bind the LOCAL player as `player`/`camera`; activate only its camera.
	var net := _net()
	var local_id: int = net.local_peer_id
	var cam: Camera2D = p.get_node_or_null("Camera2D")
	if pid == local_id and not bot:
		local_player = p
		player = p
		camera = cam
		if cam != null:
			cam.make_current()
			AudioManager.set_camera(cam)
			if cam.has_method("setup"):
				cam.setup(p, self)
	else:
		if cam != null:
			cam.enabled = false
	# Host drives bot AI. Attach one controller per bot; clients never simulate bots.
	if bot and is_host():
		_attach_bot_controller(p)
	if _net_verbose():
		print("[FFA] spawned player pid=", pid, " bot=", bot, " authority=", authority, " local=", (pid == local_id and not bot))

const BOT_CONTROLLER_SCRIPT := preload("res://scripts/bot_controller.gd")

func _attach_bot_controller(bot_player: CharacterBody2D) -> void:
	var ctrl := BOT_CONTROLLER_SCRIPT.new()
	ctrl.name = "BotController"
	bot_player.add_child(ctrl)
	ctrl.setup(self, bot_player)

func get_nearest_player(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for pid in players.keys():
		var p = players[pid]
		if p == null or not is_instance_valid(p):
			continue
		if "inert" in p and p.inert:
			continue
		var d: float = pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	# Fallback to any player (even inert) so enemies always have a target.
	if best == null and not players.is_empty():
		for pid in players.keys():
			var p = players[pid]
			if p != null and is_instance_valid(p):
				return p
	return best

func _ffa_spawn_position(index: int, total: int) -> Vector2:
	# Spread players evenly on a ring around the arena center.
	var radius := 280.0
	var ang: float = TAU * float(index) / float(max(1, total))
	return Vector2(cos(ang), sin(ang)) * radius

# Pick a player to anchor a horde spawn on. Solo: the only player. FFA: a random
# living (non-inert) player so pressure is shared; falls back to any player.
func _spawn_anchor_player() -> Node2D:
	if is_solo():
		return player
	var living: Array = []
	for pid in players.keys():
		var p = players[pid]
		if p == null or not is_instance_valid(p):
			continue
		if "inert" in p and p.inert:
			continue
		living.append(p)
	if not living.is_empty():
		return living[randi() % living.size()]
	# Everyone dead/inert: fall back to any player so spawns still resolve.
	for pid in players.keys():
		var p = players[pid]
		if p != null and is_instance_valid(p):
			return p
	return player

# --- Per-player economy ledger -------------------------------------------------
# In solo the ledger is a single entry (peer 1) and is kept in sync with the
# global vars via _sync_local_econ_from_globals/_sync_globals_from_local_econ.
# The owner-aware economy fns below default `owner_id` to the local player, so
# every existing solo call site (which passes no owner) behaves identically.

func _local_econ_id() -> int:
	var n := _net()
	if n != null and n.is_multiplayer():
		return int(n.local_peer_id)
	return 1

# Public: the peer_id that owns the local player's economy + buildings.
func local_player_id() -> int:
	return _local_econ_id()

# Host-only self-test (cmdline: --ffa-econ-test) verifying per-player isolation:
# crediting/spending one peer's pool never touches another's. Prints PASS/FAIL.
func _run_econ_selftest() -> void:
	var ids: Array = players.keys()
	ids.sort()
	if ids.size() < 2:
		print("[ECON-TEST] FAIL: need >=2 players, have ", ids.size())
		return
	var a: int = ids[0]
	var b: int = ids[1]
	# --- Currency credit isolation (deltas; gain-mult agnostic) ---
	var a_res0: int = int(_econ_for(a)["resources"])
	var b_res0: int = int(_econ_for(b)["resources"])
	var a_cur0: int = get_score_currency(a)
	var b_cur0: int = get_score_currency(b)
	add_resources(100, a)
	var a_credited: int = int(_econ_for(a)["resources"]) - a_res0
	var ok1: bool = a_credited > 0 \
		and get_score_currency(a) == a_cur0 + a_credited \
		and int(_econ_for(b)["resources"]) == b_res0 \
		and get_score_currency(b) == b_cur0
	# --- Spend isolation ---
	var a_res1: int = int(_econ_for(a)["resources"])
	var b_res1: int = int(_econ_for(b)["resources"])
	var spent_a: bool = spend(40, a)
	var ok2: bool = spent_a \
		and int(_econ_for(a)["resources"]) == a_res1 - 40 \
		and int(_econ_for(b)["resources"]) == b_res1
	# --- Over-spend B blocked (insufficient funds) ---
	var b_res2: int = int(_econ_for(b)["resources"])
	var spent_b_fail: bool = not spend(b_res2 + 99999, b) \
		and int(_econ_for(b)["resources"]) == b_res2
	# --- Essence isolation ---
	var a_ess0: int = int(_econ_for(a)["essence"])
	var b_ess0: int = int(_econ_for(b)["essence"])
	add_essence(7, b)
	var b_ess_credited: int = int(_econ_for(b)["essence"]) - b_ess0
	var ok3: bool = b_ess_credited > 0 and int(_econ_for(a)["essence"]) == a_ess0
	# --- Treasure isolation ---
	var a_tr0: int = get_score_treasures(a)
	var b_tr0: int = get_score_treasures(b)
	on_treasure_opened(a)
	var ok4: bool = get_score_treasures(a) == a_tr0 + 1 and get_score_treasures(b) == b_tr0
	var pass_ok: bool = ok1 and ok2 and spent_b_fail and ok3 and ok4
	print("[ECON-TEST] credit_isolation=", ok1, " spend_isolation=", ok2,
		" overspend_blocked=", spent_b_fail, " essence_isolation=", ok3,
		" treasure_isolation=", ok4)
	print("[ECON-TEST] ", "PASS" if pass_ok else "FAIL")

# Read-only owner-aware score accessors used by the scoreboard (Phase 4).
func get_score_currency(owner_id: int) -> int:
	if is_solo():
		return _currency_earned
	return int(_econ_for(owner_id)["currency_earned"])

func get_score_treasures(owner_id: int) -> int:
	if is_solo():
		return _treasures_opened
	return int(_econ_for(owner_id)["treasures"])

func _init_econ() -> void:
	econ.clear()
	if is_solo():
		# Solo writes the global vars directly; the ledger is unused.
		return
	# FFA: one ledger entry per roster peer (host authoritative; clients keep
	# only their own meaningfully, but mirror the structure for safety). Every
	# player (humans and bots) starts the match with the same gold/essence stake.
	var n := _net()
	for entry in n.match_roster:
		var pid := int(entry["peer_id"])
		econ[pid] = _new_ffa_econ_entry()
	# Make sure the local pool exists even before roster (defensive).
	var lid := _local_econ_id()
	if not econ.has(lid):
		econ[lid] = _new_ffa_econ_entry()
	# The global vars become the LOCAL player's live view. FFA uses a fixed
	# starting stake (no solo meta start bonus), so mirror the seeded ledger.
	var le: Dictionary = _econ_for(lid)
	resources = int(le["resources"])
	essence = int(le["essence"])
	_currency_earned = int(le["currency_earned"])
	_treasures_opened = int(le["treasures"])
	if _net_verbose():
		print("[FFA-ECON] seeded ", econ.size(), " pools; local id=", lid, " resources=", resources, " essence=", essence)

func _new_econ_entry() -> Dictionary:
	return {"resources": 0, "essence": 0, "currency_earned": 0, "treasures": 0}

# FFA ledger entry seeded with the shared starting stake. currency_earned starts
# at 0 so the win metric only counts what players collect during the match.
func _new_ffa_econ_entry() -> Dictionary:
	return {"resources": FFA_START_RESOURCES, "essence": FFA_START_ESSENCE, "currency_earned": 0, "treasures": 0}

func _econ_for(owner_id: int) -> Dictionary:
	if not econ.has(owner_id):
		econ[owner_id] = _new_econ_entry()
	return econ[owner_id]

# Push a ledger entry back into the global vars (used when the local player's
# pool changes, so the existing UI/read sites stay correct).
func _sync_globals_from_local_econ() -> void:
	var lid := _local_econ_id()
	var e: Dictionary = _econ_for(lid)
	resources = int(e["resources"])
	essence = int(e["essence"])
	_currency_earned = int(e["currency_earned"])
	_treasures_opened = int(e["treasures"])

# If `owner_id` is the local player (or solo), refresh the global mirror + UI.
func _on_econ_changed(owner_id: int) -> void:
	if owner_id == _local_econ_id():
		_sync_globals_from_local_econ()
		_update_ui()

func _process(delta: float) -> void:
	_refresh_build_focus_ui()
	_check_debug_toggle(delta)
	if game_over:
		_handle_game_over_input()
		return
	if not game_started:
		_handle_start_input(delta)
		return
	if tech_open:
		_handle_tech_input()
		return
	if chest_modal_open:
		return
	_handle_resource_dump_input()
	# Camera zoom controls
	_handle_zoom_input()
	start_timer += delta
	if start_timer < spawn_delay:
		return
	elapsed += delta
	_maybe_minute_announcement()
	_update_controls_hint()
	_update_income_decay_telegraph()
	_update_runtime_performance(delta)
	_update_dynamic_caps()
	_update_extraction(delta)
	# Update cached enemy list once per frame (used by all towers)
	_refresh_cached_enemies()
	_rebuild_enemy_grid()
	_refresh_target_caches(delta)
	_update_flow_field(delta)
	_update_breach_state(delta)
	if wave_manager != null and wave_manager.has_method("update"):
		wave_manager.update(delta, elapsed)
	# Host owns the shared horde; clients receive enemies via replication and do
	# not run the spawn pipeline. Solo always simulates locally.
	if _is_sim_authority():
		_handle_boss_spawning(delta)
		_handle_spawning(delta)
	# Enemy replication: host streams positions; clients interpolate proxies.
	if is_ffa():
		_update_enemy_net_sync(delta)
		_update_ffa_clock(delta)
		_update_ffa_lastman(delta)
	_maintain_breakables()
	_handle_powerup_spawning(delta)  # Power-up spawn logic
	_update_essence_announcement(delta)
	_update_ui()
	_update_debug_flow(delta)

func _refresh_cached_enemies() -> void:
	cached_enemies.clear()
	if enemies_root == null:
		return
	var count = enemies_root.get_child_count()
	for i in range(count):
		var raw_enemy = enemies_root.get_child(i)
		if raw_enemy == null or not is_instance_valid(raw_enemy):
			continue
		cached_enemies.append(raw_enemy)

func get_cached_enemies() -> Array:
	return cached_enemies

# --- Enemy spatial grid -------------------------------------------------
# Every tower used to distance-check every enemy on the map, including ones far
# outside its range: cost scaled as towers x enemies. Bucketing enemies by cell
# once per frame lets a tower look at only the handful nearby, which is the
# single biggest win for late-run frame time.
const ENEMY_GRID_CELL := 160.0
var _enemy_grid: Dictionary = {}

func _grid_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / ENEMY_GRID_CELL)), int(floor(pos.y / ENEMY_GRID_CELL)))

func _rebuild_enemy_grid() -> void:
	_enemy_grid.clear()
	for e in cached_enemies:
		if e == null or not is_instance_valid(e):
			continue
		var c := _grid_cell(e.global_position)
		if not _enemy_grid.has(c):
			_enemy_grid[c] = []
		_enemy_grid[c].append(e)

func get_enemies_near(pos: Vector2, radius: float) -> Array:
	"""Enemies in cells overlapping the radius. A superset of the true circle —
	callers still distance-check, this just shrinks the candidate set."""
	if _enemy_grid.is_empty():
		return cached_enemies
	var out: Array = []
	var span := int(ceil(radius / ENEMY_GRID_CELL))
	var base := _grid_cell(pos)
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var c := base + Vector2i(dx, dy)
			var bucket = _enemy_grid.get(c)
			if bucket != null:
				out.append_array(bucket)
	return out

func _refresh_target_caches(delta: float) -> void:
	"""Refresh the building/ally lists a few times a second instead of letting
	every enemy call get_nodes_in_group() every frame. With a few hundred
	enemies that was hundreds of array allocations and tens of thousands of
	iterations per frame - the main source of horde lag."""
	_target_cache_timer -= delta
	if _target_cache_timer > 0.0:
		return
	_target_cache_timer = TARGET_CACHE_INTERVAL
	cached_buildings = get_tree().get_nodes_in_group("buildings")
	cached_allies = get_tree().get_nodes_in_group("allies")

func get_cached_buildings() -> Array:
	return cached_buildings

func get_cached_allies() -> Array:
	return cached_allies

func _update_debug_flow(delta: float) -> void:
	if not debug_flow_enabled:
		return
	_debug_flow_timer = max(0.0, _debug_flow_timer - delta)
	if _debug_flow_timer <= 0.0:
		_debug_flow_timer = 0.2
		queue_redraw()

func _handle_start_input(delta: float) -> void:
	if Input.is_action_just_pressed("build_1"):
		_set_selected_character(0)
	if Input.is_action_just_pressed("build_2"):
		_set_selected_character(1)
	if Input.is_action_just_pressed("start_game"):
		_start_game()

func _check_debug_toggle(delta: float) -> void:
	_debug_toggle_cooldown = max(0.0, _debug_toggle_cooldown - delta)
	if _debug_toggle_cooldown > 0.0:
		return
	if Input.is_action_just_pressed(DEBUG_FLOW_ACTION):
		_debug_toggle_cooldown = 0.25
		debug_flow_enabled = not debug_flow_enabled
		queue_redraw()
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("FLOW DEBUG: %s" % ("ON" if debug_flow_enabled else "OFF"), Color(0.2, 1.0, 0.6), 18, 1.2)

func _handle_zoom_input() -> void:
	if camera == null:
		return
	if Input.is_action_just_pressed("zoom_out"):
		_cycle_zoom(1)  # Zoom out (lower zoom = see more)
	elif Input.is_action_just_pressed("zoom_in"):
		_cycle_zoom(-1)  # Zoom in (higher zoom = see less)

func _handle_resource_dump_input() -> void:
	if not Input.is_action_just_pressed("resource_dump"):
		return
	if resources < RESOURCE_DUMP_COST:
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("Need %d resources for Resource Dump" % RESOURCE_DUMP_COST, Color(0.95, 0.5, 0.35), 18, 1.2)
		return
	if not spend(RESOURCE_DUMP_COST):
		return
	add_essence(RESOURCE_DUMP_ESSENCE_GAIN)
	chest_tower_rate_mult = min(5.0, chest_tower_rate_mult * 1.08)
	chest_tower_damage_bonus += 3.0
	chest_tower_aoe_mult = min(3.6, chest_tower_aoe_mult * 1.06)
	_refresh_tech_scalars()
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("RESOURCE DUMP: +1 ESSENCE | TOWER OUTPUT BOOSTED", Color(1.0, 0.9, 0.35), 20, 1.2)
	if player != null:
		spawn_fx("upgrade_burst", player.global_position)

func _cycle_zoom(direction: int) -> void:
	_current_zoom_index = clampi(_current_zoom_index + direction, 0, ZOOM_LEVELS.size() - 1)
	var target_zoom = ZOOM_LEVELS[_current_zoom_index]

	# Kill existing tween if any
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()

	# Smooth zoom transition
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(camera, "zoom", target_zoom, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Tell the camera this is the new rest position, otherwise any later zoom
	# effect snaps the view back to the value captured at scene load.
	_zoom_tween.tween_callback(func():
		if camera != null and camera.has_method("set_base_zoom"):
			camera.set_base_zoom(target_zoom)
	)

func _get_meta_progression() -> Node:
	return get_node_or_null("/root/MetaProgression")

func _apply_meta_run_start() -> void:
	# Pull persistent meta-progression selections and bonuses into this run.
	var meta = _get_meta_progression()
	if meta == null:
		meta_essence_mult = 1.0
		meta_start_resources = 0
		meta_max_hp_bonus = 0.0
		meta_move_speed_mult = 1.0
		meta_tower_damage_mult = 1.0
		meta_pickup_radius_mult = 1.0
		run_threat_mult = 1.0
		run_player_damage_taken_mult = 1.0
		run_ramp_speed_mult = 1.0
		return
	# Hero selection from the main menu.
	var hero_id = str(meta.pending_hero)
	if hero_id != "":
		for i in range(characters.size()):
			if str(characters[i].get("id", "")) == hero_id and meta.is_hero_unlocked(hero_id):
				selected_character = i
				break
	# Permanent upgrade bonuses.
	var bonuses: Dictionary = meta.get_run_start_bonuses()
	meta_start_resources = int(round(float(bonuses.get("start_resources", 0.0))))
	meta_max_hp_bonus = float(bonuses.get("max_hp", 0.0))
	meta_move_speed_mult = float(bonuses.get("move_speed_mult", 1.0))
	meta_essence_mult = float(bonuses.get("essence_mult", 1.0))
	meta_tower_damage_mult = float(bonuses.get("tower_damage_mult", 1.0))
	meta_pickup_radius_mult = float(bonuses.get("pickup_radius_mult", 1.0))
	# Top up starting gold with the meta bonus (resources was set in reset).
	if meta_start_resources > 0:
		resources += meta_start_resources
	# Pickup radius stacks multiplicatively on the base (reset to 1.0 in reset).
	if meta_pickup_radius_mult != 1.0:
		pickup_range_mult *= meta_pickup_radius_mult
	# Run modifier (challenge) effects.
	run_threat_mult = 1.0
	run_player_damage_taken_mult = 1.0
	run_ramp_speed_mult = 1.0
	if meta.has_method("get_active_modifier_effect"):
		var fx: Dictionary = meta.get_active_modifier_effect()
		run_threat_mult = float(fx.get("threat_mult", 1.0))
		run_player_damage_taken_mult = float(fx.get("player_damage_taken_mult", 1.0))
		run_ramp_speed_mult = float(fx.get("ramp_speed_mult", 1.0))

func _start_game() -> void:
	# Idempotent: solo now starts unconditionally during setup and the FFA branch
	# starts explicitly, so both can reach here in one _ready. Re-running would
	# re-apply meta bonuses and re-announce the intro.
	if game_started:
		return
	game_started = true
	start_timer = 0.0
	_apply_base_time_scale()
	_set_pause_allowed(true)
	_apply_meta_run_start()
	_apply_selected_character()
	if player != null and player.has_method("apply_meta_bonuses"):
		player.apply_meta_bonuses(meta_max_hp_bonus, meta_move_speed_mult, run_player_damage_taken_mult)
	if ui != null and ui.has_method("show_start"):
		ui.show_start(false)
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("SURVIVE", Color(1.0, 1.0, 1.0), 48, 2.4)
	_refresh_build_palette()
	# Teach the objective up front — the run is unwinnable if the player never
	# works out that the extractor is on build slot 4.
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("PRESS 4 TO PLACE YOUR EXTRACTOR", Color(1.0, 0.9, 0.4), 30, 4.0)
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
	# FFA shares one simulation across peers: no single player may slow or freeze
	# global time. Build focus / chest modal / tech become local UI only.
	if is_ffa():
		return 1.0
	if tech_open:
		return 0.0
	if chest_modal_open:
		return CHEST_MODAL_TIME_SCALE
	if is_menu_open():
		return 1.0
	# Build focus used to slow time. Playtesting said it read as the game
	# stuttering rather than as a helpful assist, so building now runs at full
	# speed. (_build_focus_active still drives the build-mode UI highlight.)
	return 1.0

func _apply_base_time_scale() -> void:
	if _time_scale_tween != null:
		_time_scale_tween.kill()
		_time_scale_tween = null
	Engine.time_scale = _get_base_time_scale()
	_refresh_build_focus_ui()

func set_build_focus(active: bool, structure_id: String = "") -> void:
	var next_active = active and not game_over
	var next_name = ""
	if next_active:
		var def = StructureDB.get_def(structure_id)
		if def.is_empty():
			next_name = structure_id
		else:
			next_name = str(def.get("name", structure_id))
	var changed = next_active != _build_focus_active or next_name != _build_focus_name
	_build_focus_active = next_active
	_build_focus_name = next_name
	if changed:
		_apply_base_time_scale()
	else:
		_refresh_build_focus_ui()

func _refresh_build_focus_ui() -> void:
	if ui == null or not ui.has_method("set_build_focus"):
		return
	var visible = _build_focus_active and game_started and not game_over and not tech_open and not is_menu_open()
	ui.set_build_focus(visible, _build_focus_name, BUILD_FOCUS_TIME_SCALE)

func _trigger_kill_slow() -> void:
	# Global slow-mo is disabled in FFA (shared sim).
	if not ENABLE_TIME_DILATION:
		return
	if is_ffa():
		return
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
	if not ENABLE_TIME_DILATION:
		return
	if is_ffa():
		return
	var base_scale = _get_base_time_scale()
	if base_scale <= 0.0 or base_scale <= slow_scale:
		return
	if _time_scale_tween != null:
		_time_scale_tween.kill()
	Engine.time_scale = slow_scale
	_time_scale_tween = create_tween()
	_time_scale_tween.tween_property(Engine, "time_scale", base_scale, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _get_settings_manager() -> Node:
	var node = get_node_or_null("/root/SettingsManager")
	if node != null:
		return node
	return _settings_manager

func _connect_settings_manager() -> void:
	var manager = _get_settings_manager()
	if manager == null:
		return
	_settings_manager = manager
	if manager.has_signal("settings_changed") and not manager.settings_changed.is_connected(_on_settings_changed):
		manager.settings_changed.connect(_on_settings_changed)
	if manager.has_signal("settings_loaded") and not manager.settings_loaded.is_connected(_sync_runtime_settings):
		manager.settings_loaded.connect(_sync_runtime_settings)

func _sync_runtime_settings(_category: String = "", _key: String = "", _value: Variant = null) -> void:
	var manager = _get_settings_manager()
	var show_tower_range = true
	var show_wave_preview = true
	if manager != null:
		show_tower_range = bool(manager.get_setting("gameplay", "show_tower_range", true))
		show_wave_preview = bool(manager.get_setting("gameplay", "wave_preview", true))
	_apply_runtime_frame_pacing()
	if build_manager != null and build_manager.has_method("set_show_tower_range"):
		build_manager.set_show_tower_range(show_tower_range)
	if ui != null and ui.has_method("set_wave_preview_enabled"):
		ui.set_wave_preview_enabled(show_wave_preview)
	if ui != null and ui.has_method("set_tech_ledger_visible"):
		ui.set_tech_ledger_visible(false)
	_apply_runtime_performance_budgets()
	_damage_number_budget = _get_damage_budget_per_sec()

func _apply_runtime_frame_pacing() -> void:
	var target_cap := DEFAULT_RENDER_FPS_CAP
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_render_fps_cap"):
		target_cap = int(manager.get_render_fps_cap())
	target_cap = clampi(target_cap, 30, 240)
	Engine.max_fps = target_cap
	Engine.physics_ticks_per_second = SIMULATION_TICKS_PER_SECOND
	_runtime_target_fps = float(target_cap)

func _setup_world_environment() -> void:
	# Enable 2D HDR so glow can bloom on bright/additive FX (projectiles, tesla, crits).
	var vp := get_viewport()
	if vp != null:
		vp.use_hdr_2d = true
	if _world_environment == null:
		_world_environment = WorldEnvironment.new()
		_world_environment.name = "GameWorldEnvironment"
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		_world_environment.environment = env
		add_child(_world_environment)
	_apply_glow_settings()

func _apply_glow_settings() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	var env := _world_environment.environment
	var settings := {
		"enabled": true, "intensity": 0.8, "strength": 1.05,
		"bloom": 0.0, "hdr_threshold": 1.0,
		"levels": [1.0, 1.0, 0.85, 0.5, 0.25, 0.0, 0.0],
	}
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_glow_settings"):
		settings = manager.get_glow_settings()
	env.glow_enabled = bool(settings.get("enabled", true))
	env.glow_intensity = float(settings.get("intensity", 0.8))
	env.glow_strength = float(settings.get("strength", 1.05))
	env.glow_bloom = float(settings.get("bloom", 0.0))
	env.glow_hdr_threshold = float(settings.get("hdr_threshold", 1.0))
	# The tier picks how many blur taps build the halo - that is what makes a
	# higher setting cost more and look better, rather than exposure.
	var levels: Array = settings.get("levels", [])
	for i in range(7):
		env.set_glow_level(i, float(levels[i]) if i < levels.size() else 0.0)

func _on_settings_changed(category: String, key: String, value: Variant) -> void:
	_sync_runtime_settings(category, key, value)
	if category == "graphics" and key == "quality":
		var quality_name = str(value).capitalize()
		_apply_glow_settings()
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("QUALITY: %s" % quality_name, Color(0.68, 0.95, 1.0), 18, 1.2)
	if category == "graphics" and key == "render_fps_cap":
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("FPS CAP: %d" % int(value), Color(0.68, 0.95, 1.0), 18, 1.1)

func _get_perf_quality_caps() -> Dictionary:
	var quality = "high"
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_quality"):
		quality = str(manager.get_quality()).to_lower()
	if not PERF_QUALITY_CAPS.has(quality):
		quality = "high"
	return PERF_QUALITY_CAPS[quality]

func _get_damage_budget_per_sec() -> int:
	var budget = FeedbackConfig.DAMAGE_NUMBER_BUDGET_PER_SEC
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_damage_budget_scale"):
		budget = int(round(float(budget) * float(manager.get_damage_budget_scale())))
	budget = int(round(float(budget) * lerpf(0.55, 1.0, _adaptive_perf_scale)))
	var caps = _get_perf_quality_caps()
	budget = min(budget, int(caps.get("damage_budget", budget)))
	return max(4, budget)

func _get_fx_density_scale() -> float:
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_fx_density_scale"):
		return clampf(float(manager.get_fx_density_scale()), 0.25, 1.5)
	return 1.0

func _get_effective_fx_density_scale() -> float:
	return clampf(_get_fx_density_scale() * _adaptive_perf_scale, PERF_FX_SCALE_MIN, _optional_fx_quality_cap)

func _should_spawn_optional_fx() -> bool:
	var density = _get_effective_fx_density_scale()
	if density >= 1.0:
		return true
	return randf() <= density

func should_spawn_optional_fx() -> bool:
	return _should_spawn_optional_fx()

func _update_runtime_performance(delta: float) -> void:
	if not game_started:
		return
	_adaptive_perf_sample_timer = max(0.0, _adaptive_perf_sample_timer - delta)
	if _adaptive_perf_sample_timer > 0.0:
		return
	_adaptive_perf_sample_timer = PERF_SAMPLE_INTERVAL
	var fps = float(Engine.get_frames_per_second())
	if fps <= 1.0:
		fps = _adaptive_perf_smoothed_fps
	_adaptive_perf_smoothed_fps = lerpf(_adaptive_perf_smoothed_fps, fps, 0.35)
	var target_scale = 1.0
	var perf_target_fps = max(30.0, _runtime_target_fps)
	var fps_ratio = _adaptive_perf_smoothed_fps / perf_target_fps
	if fps_ratio < 0.96:
		target_scale = 0.92
	if fps_ratio < 0.88:
		target_scale = 0.78
	if fps_ratio < 0.80:
		target_scale = 0.62
	if fps_ratio < 0.72:
		target_scale = 0.48
	if fps_ratio < 0.64:
		target_scale = 0.36
	if max_enemies_cap > 0 and enemies_root != null:
		var load_ratio = float(enemies_root.get_child_count()) / float(max_enemies_cap)
		if load_ratio > 0.82:
			target_scale = min(target_scale, 0.85)
		if load_ratio > 0.94:
			target_scale = min(target_scale, 0.70)
	_adaptive_perf_scale = lerpf(_adaptive_perf_scale, target_scale, 0.45)
	_apply_runtime_performance_budgets()

func _apply_runtime_performance_budgets() -> void:
	var caps = _get_perf_quality_caps()
	_optional_fx_quality_cap = clampf(float(caps.get("optional_fx_cap", 1.0)), PERF_FX_SCALE_MIN, 1.5)
	var fx_scale = _get_effective_fx_density_scale()
	var adaptive_particles = max(56, int(round(150.0 * fx_scale)))
	var quality_particles_cap = max(56, int(caps.get("particles", adaptive_particles)))
	max_particles = min(adaptive_particles, quality_particles_cap)
	var projectile_scale = lerpf(PERF_PROJECTILE_SCALE_MIN, 1.0, _adaptive_perf_scale)
	var adaptive_projectiles = max(64, int(round(150.0 * projectile_scale)))
	var quality_projectiles_cap = max(64, int(caps.get("projectiles", adaptive_projectiles)))
	max_projectiles = min(adaptive_projectiles, quality_projectiles_cap)
	_flow_rebuild_interval_runtime = lerpf(FLOW_REBUILD_INTERVAL, PERF_FLOW_INTERVAL_MAX, 1.0 - _adaptive_perf_scale)

func _instantiate_pause_menu() -> void:
	if PAUSE_MENU_SCENE == null:
		push_warning("Pause menu scene is null")
		return
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	if pause_menu == null:
		push_error("Failed to instantiate pause menu scene")
		return
	add_child(pause_menu)
	if pause_menu.has_method("setup"):
		pause_menu.setup(self)
	if pause_menu.has_signal("resumed"):
		pause_menu.resumed.connect(_on_pause_resumed)
	if pause_menu.has_signal("settings_opened"):
		pause_menu.settings_opened.connect(_on_pause_settings_opened)
	if pause_menu.has_signal("quit_to_menu"):
		pause_menu.quit_to_menu.connect(_on_main_menu_pressed)

func _instantiate_settings_menu() -> void:
	if SETTINGS_MENU_SCENE == null:
		push_warning("Settings menu scene is null")
		return
	settings_menu = SETTINGS_MENU_SCENE.instantiate()
	if settings_menu == null:
		push_error("Failed to instantiate settings menu scene")
		return
	add_child(settings_menu)
	if settings_menu.has_signal("closed"):
		settings_menu.closed.connect(_on_settings_menu_closed)
	if settings_menu.has_signal("settings_applied"):
		settings_menu.settings_applied.connect(_sync_runtime_settings)

func _on_pause_resumed() -> void:
	_set_pause_allowed(_can_pause_game())
	_apply_base_time_scale()

func _on_pause_settings_opened() -> void:
	if settings_menu == null or not is_instance_valid(settings_menu):
		return
	if pause_menu != null and pause_menu.has_method("set_can_pause"):
		pause_menu.set_can_pause(false)
	if settings_menu.has_method("show_menu"):
		settings_menu.show_menu(true)

func _on_settings_menu_closed() -> void:
	_sync_runtime_settings()
	if pause_menu == null or not is_instance_valid(pause_menu):
		return
	if pause_menu.has_method("is_paused") and pause_menu.is_paused():
		_set_pause_allowed(_can_pause_game())

func _can_pause_game() -> bool:
	if not game_started:
		return false
	if game_over:
		return false
	if tech_open:
		return false
	if chest_modal_open:
		return false
	if settings_menu != null and is_instance_valid(settings_menu) and settings_menu.visible:
		return false
	return true

func _set_pause_allowed(allowed: bool) -> void:
	if pause_menu == null or not is_instance_valid(pause_menu):
		return
	if pause_menu.has_method("set_can_pause"):
		pause_menu.set_can_pause(allowed)

func is_tech_open() -> bool:
	return tech_open

func is_menu_open() -> bool:
	if tech_open:
		return true
	if chest_modal_open:
		return true
	if pause_menu != null and is_instance_valid(pause_menu):
		if pause_menu.has_method("is_paused") and pause_menu.is_paused():
			return true
	if settings_menu != null and is_instance_valid(settings_menu) and settings_menu.visible:
		return true
	return false

func begin_chest_modal() -> void:
	if game_over:
		return
	_chest_modal_depth += 1
	chest_modal_open = true
	_set_pause_allowed(false)
	if ui != null and ui.has_method("set_chest_blackout"):
		ui.set_chest_blackout(true)
	_apply_base_time_scale()

func end_chest_modal() -> void:
	_chest_modal_depth = max(0, _chest_modal_depth - 1)
	if _chest_modal_depth > 0:
		return
	chest_modal_open = false
	if ui != null and ui.has_method("set_chest_blackout"):
		ui.set_chest_blackout(false)
	_set_pause_allowed(_can_pause_game())
	_apply_base_time_scale()

func is_damage_blocked() -> bool:
	if game_over:
		return true
	if not game_started:
		return true
	if tech_open:
		return true
	if chest_modal_open:
		return true
	return false

func show_chest_summary(gold_gain: int, upgrade_count: int) -> void:
	if ui == null or not ui.has_method("show_announcement"):
		return
	var picks = max(1, upgrade_count)
	ui.show_announcement("CHEST OPENED  +%d GOLD  |  %d AUGMENTS" % [gold_gain, picks], Color(1.0, 0.92, 0.35), 24, 1.15)

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
	# Tech draft controls: keyboard picks 1/2/3 (or R to reroll); a gamepad moves a
	# highlight with the shoulder buttons / left stick / d-pad and confirms with A.
	# Keyboard direct-pick is preserved exactly so mouse/keyboard play is unchanged.
	if Input.is_action_just_pressed("build_1"):
		_choose_tech(0)
		return
	elif Input.is_action_just_pressed("build_2"):
		_choose_tech(1)
		return
	elif Input.is_action_just_pressed("build_3"):
		_choose_tech(2)
		return
	elif Input.is_action_just_pressed(TECH_REROLL_ACTION):
		_try_reroll_tech()
		return
	_handle_tech_gamepad_input()

func _handle_tech_gamepad_input() -> void:
	var count: int = tech_choices.size()
	if count <= 0:
		return
	_tech_nav_cooldown = max(0.0, _tech_nav_cooldown - get_process_delta_time())
	# Discrete step navigation (shoulder buttons, ui_left/right, ui_up/down) with a
	# small repeat cooldown so a held stick doesn't race through the options.
	var dir: int = 0
	if Input.is_action_just_pressed("build_next") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down"):
		dir = 1
	elif Input.is_action_just_pressed("build_prev") or Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up"):
		dir = -1
	elif _tech_nav_cooldown <= 0.0:
		# Held left-stick fallback (the move_* actions are stick-bound).
		if Input.is_action_pressed("build_cursor_right") or Input.is_action_pressed("build_cursor_down"):
			dir = 1
		elif Input.is_action_pressed("build_cursor_left") or Input.is_action_pressed("build_cursor_up"):
			dir = -1
	if dir != 0:
		if _tech_cursor < 0:
			_tech_cursor = 0
		else:
			_tech_cursor = (_tech_cursor + dir + count) % count
		_tech_nav_cooldown = 0.18
		if ui != null and ui.has_method("set_tech_highlight"):
			ui.set_tech_highlight(_tech_cursor)
		var am := get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("play_ui_sound"):
			am.play_ui_sound("hover")
		return
	# Confirm with the gamepad place/accept button (only once a cursor exists).
	if _tech_cursor >= 0 and (Input.is_action_just_pressed("build_place") or Input.is_action_just_pressed("ui_accept")):
		var am2 := get_node_or_null("/root/AudioManager")
		if am2 != null and am2.has_method("play_ui_sound"):
			am2.play_ui_sound("click")
		_choose_tech(_tech_cursor)
		return
	# Reroll with the gamepad upgrade/X button as well as the keyboard R.
	if Input.is_action_just_pressed("upgrade"):
		_try_reroll_tech()

func _get_horde_count_multiplier(time_sec: float) -> float:
	time_sec = max(time_sec, 0.0) * run_ramp_speed_mult
	var minutes = int(floor(max(time_sec, 0.0) / 60.0))
	var target = clampf(1.0 + float(minutes) * HORDE_MINUTE_MULT_STEP, 1.0, HORDE_MULT_MAX)
	if time_sec < EARLY_GAME_HORDE_RAMP_TIME:
		var t = clampf(time_sec / EARLY_GAME_HORDE_RAMP_TIME, 0.0, 1.0)
		target = lerpf(1.0, target, t)
	return target * _extraction_count_multiplier() * difficulty_count_mult()

func difficulty_count_mult() -> float:
	"""Body-count half of the global balance knob. Also read by the wave manager
	so timed events (bat swarm, plague wall) scale with the same dial."""
	return sqrt(DIFFICULTY_TUNING_MULT)

func difficulty_threat_mult() -> float:
	"""Enemy-strength half of the global balance knob."""
	return sqrt(DIFFICULTY_TUNING_MULT)

func _extraction_count_multiplier() -> float:
	"""Raw body count per phase. Separate from threat (which scales enemy
	strength) so the siege reads as an actual horde, not just tankier singles."""
	match extraction_phase:
		ExtractionPhase.SCOUT:
			return 0.4
		ExtractionPhase.SIEGE:
			# Same back-loaded shape as threat: a manageable opening that builds
			# into a wall by the final minutes.
			var t := clampf(siege_elapsed() / EXTRACTION_DURATION, 0.0, 1.0)
			return 0.85 + pow(t, 1.9) * 1.6
		ExtractionPhase.OVERRUN:
			return 3.0
	return 1.0

func _scale_horde_enemy_count(base_count: int, time_sec: float) -> int:
	var scaled = int(round(float(base_count) * _get_horde_count_multiplier(time_sec)))
	return max(base_count, scaled)

func _get_spawn_settings(time_sec: float) -> Dictionary:
	var horde_mult = _get_horde_count_multiplier(time_sec)
	if SPAWN_CURVE.is_empty():
		return {
			"interval": 1.2,
			"max_enemies": _scale_horde_enemy_count(12, time_sec),
			"difficulty": 1.0,
			"elite": 0.02,
			"siege": 0.0,
			"horde_mult": horde_mult
		}
	var prev = SPAWN_CURVE[0]
	var prev_time = float(prev.get("time", 0.0))
	if time_sec <= prev_time:
		var diff = float(prev.get("difficulty", 1.0)) * _get_threat_multiplier(time_sec)
		var base_count = int(prev.get("max_enemies", 12))
		return {
			"interval": float(prev.get("interval", 1.2)),
			"max_enemies": _scale_horde_enemy_count(base_count, time_sec),
			"difficulty": diff,
			"elite": float(prev.get("elite", 0.02)),
			"siege": float(prev.get("siege", 0.0)),
			"horde_mult": horde_mult
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
			var base_count = int(round(lerp(float(prev.get("max_enemies", 12)), float(next.get("max_enemies", 12)), t)))
			return {
				"interval": lerp(float(prev.get("interval", 1.2)), float(next.get("interval", 1.2)), t),
				"max_enemies": _scale_horde_enemy_count(base_count, time_sec),
				"difficulty": diff,
				"elite": lerp(float(prev.get("elite", 0.02)), float(next.get("elite", 0.02)), t),
				"siege": lerp(float(prev.get("siege", 0.0)), float(next.get("siege", 0.0)), t),
				"horde_mult": horde_mult
			}
		prev = next
		prev_time = next_time
	var last = SPAWN_CURVE[SPAWN_CURVE.size() - 1]
	var diff = float(last.get("difficulty", 1.0)) * _get_threat_multiplier(time_sec)
	var last_count = int(last.get("max_enemies", 12))
	return {
		"interval": float(last.get("interval", 1.2)),
		"max_enemies": _scale_horde_enemy_count(last_count, time_sec),
		"difficulty": diff,
		"elite": float(last.get("elite", 0.02)),
		"siege": float(last.get("siege", 0.0)),
		"horde_mult": horde_mult
	}

# Number of active FFA participants (humans + bots). Used to scale the horde so
# a fuller lobby — which fields many more towers — faces a proportionally bigger,
# harder horde. Always >= 1; solo is handled separately so this is only meaningful
# in FFA, but it stays safe either way.
func _ffa_participant_count() -> int:
	var n := 0
	for pid in players.keys():
		var p = players[pid]
		if p != null and is_instance_valid(p):
			n += 1
	return max(1, n)

# Live FFA spawn-rate multiplier: base aggression scaled up per extra player.
func _ffa_spawn_rate_mult() -> float:
	var extra := _ffa_participant_count() - 1
	return FFA_SPAWN_RATE_MULT * (1.0 + FFA_RATE_PER_PLAYER * float(extra))

# Live FFA enemy-cap multiplier (more bodies on the field with more players).
func _ffa_max_enemy_mult() -> float:
	var extra := _ffa_participant_count() - 1
	return FFA_MAX_ENEMY_MULT * (1.0 + FFA_CAP_PER_PLAYER * float(extra))

# Live FFA difficulty (HP/damage) multiplier: enemies get tougher with more
# players so the extra towers don't trivialize the run.
func _ffa_difficulty_mult() -> float:
	var extra := _ffa_participant_count() - 1
	return 1.0 + FFA_DIFFICULTY_PER_PLAYER * float(extra)

func _get_threat_multiplier(time_sec: float) -> float:
	var base: float
	if time_sec <= 600.0:
		base = run_threat_mult
	else:
		var t = clamp((time_sec - 600.0) / 900.0, 0.0, 1.0)
		base = (1.0 + t * 1.8) * run_threat_mult
	base *= _extraction_threat_multiplier(time_sec)
	base *= _player_power_threat_multiplier()
	base *= difficulty_threat_mult()
	# FFA: fold the per-player difficulty scale into the threat multiplier so it
	# flows through every difficulty read (spawn_enemy, bosses, minions, splits).
	if is_ffa():
		base *= _ffa_difficulty_mult()
	return base

func _extraction_threat_multiplier(time_sec: float) -> float:
	"""Difficulty is driven by the extraction phase, not raw run time.

	SCOUT is deliberately quiet so the placement decision is about reading the
	map, not fighting. The moment the extractor lands the siege ramps hard, and
	once the bar fills OVERRUN escalates without limit toward the 20:00 mark."""
	match extraction_phase:
		ExtractionPhase.SCOUT:
			return 0.4
		ExtractionPhase.SIEGE:
			# Back-loaded on purpose. A linear ramp made the first quarter of the
			# extraction spike hard while the player was still building their
			# maze; the exponent keeps the opening readable and saves the real
			# pressure for the back half. Playtesting still found the early
			# siege punishing, so it now opens below parity and takes longer to
			# bite, while the finale stays at roughly the same peak.
			var t := clampf(siege_elapsed() / EXTRACTION_DURATION, 0.0, 1.0)
			return 0.75 + pow(t, 2.0) * 2.35
		ExtractionPhase.OVERRUN:
			# Past the win the gloves come off: by EXTRACTION_OVERRUN_PEAK run
			# time enemies are effectively unkillable. Survive as long as you can.
			var o := clampf(time_sec / EXTRACTION_OVERRUN_PEAK, 0.0, 1.0)
			return 3.2 + pow(o, 2.0) * 9.0
	return 1.0

func _player_power_threat_multiplier() -> float:
	"""Scale enemies against how strong the player actually got, not just how
	long they survived.

	Chest upgrades stack multiplicatively and uncapped, so a purely time-based
	curve always falls behind a lucky run. Tying a slice of the threat budget to
	measured player power keeps a hot streak exciting without trivialising the
	siege. Deliberately sub-linear so good play still feels rewarded."""
	if player == null or not is_instance_valid(player):
		return 1.0
	var power := 1.0
	if player.has_method("get_power_score"):
		power = maxf(1.0, float(player.get_power_score()))
	else:
		# Fall back to raw damage output relative to the starting baseline.
		var dmg := float(player.get("damage")) if "damage" in player else 0.0
		var base_dmg := float(player.get("base_damage")) if "base_damage" in player else 0.0
		if base_dmg > 0.0 and dmg > 0.0:
			power = maxf(1.0, dmg / base_dmg)
	# power 1x -> 1.0, 4x -> ~1.6, 16x -> ~2.4. Grows, but never runaway.
	return clampf(1.0 + log(power) / log(4.0) * 0.3, 1.0, 3.0)

func _update_dynamic_caps() -> void:
	var extra = 0
	if elapsed > 300.0:
		extra = int(clamp((elapsed - 300.0) / 60.0, 0.0, 20.0)) * 8
	var horde_mult = _get_horde_count_multiplier(elapsed)
	var cap_target = int(round(float(max_enemies_cap_base + extra) * horde_mult))
	# FFA: lift the hard cap with the player count so the per-player enemy boost in
	# _handle_spawning isn't immediately clamped back down. A full lobby can field
	# a much larger horde than a duel.
	if is_ffa():
		cap_target = int(round(float(cap_target) * _ffa_max_enemy_mult()))
	max_enemies_cap = clampi(cap_target, max_enemies_cap_base, HORDE_CAP_HARD_LIMIT)

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
	var base_interval = float(settings.get("interval", 1.2))
	var horde_mult = float(settings.get("horde_mult", 1.0))
	var ffa := is_ffa()
	if ffa:
		horde_mult *= _ffa_spawn_rate_mult()
	var interval = max(0.1, base_interval / max(1.0, horde_mult))
	spawn_accumulator += delta
	while spawn_accumulator >= interval:
		spawn_accumulator -= interval
		var max_enemies = min(max_enemies_cap, int(settings.get("max_enemies", max_enemies_cap)))
		if ffa:
			max_enemies = int(min(float(max_enemies_cap), float(max_enemies) * _ffa_max_enemy_mult()))
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
		var upcoming_final = false
		if _boss_schedule_index < BOSS_SCHEDULE.size():
			upcoming_final = bool(BOSS_SCHEDULE[_boss_schedule_index].get("final", false))
		if ui != null and ui.has_method("show_announcement"):
			if upcoming_final:
				ui.show_announcement("THE ENDBRINGER APPROACHES", Color(0.85, 0.05, 0.08), 56, 4.0)
				flash_screen(Color(0.6, 0.0, 0.0, 0.18))
			else:
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
			_final_boss_active = true
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
	var anchor := _spawn_anchor_player()
	if enemies_root == null or anchor == null:
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
	boss.global_position = anchor.global_position + Vector2.RIGHT.rotated(angle) * distance
	var difficulty = float(_get_spawn_settings(elapsed).get("difficulty", 1.0))
	if boss.has_method("setup"):
		boss.setup(self, difficulty)
	enemies_root.add_child(boss)
	_register_enemy_net(boss, ENEMY_SCENE.resource_path, script_path)
	return boss

func _on_boss_died(_boss: Node = null) -> void:
	_active_boss = null
	# Defeating the FINAL boss wins the run. Only the boss_died signal (not a despawn
	# via tree_exited) counts as a victory.
	if _final_boss_active and not _run_won:
		_final_boss_active = false
		_trigger_victory()
		return
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
	var siege_chance = clamp(float(spawn_settings.get("siege", 0.0)), 0.0, 0.5)
	var scene = _pick_enemy_scene()
	if randf() < siege_chance:
		scene = SIEGE_ENEMY_SCENE
	var enemy = scene.instantiate()
	var spawn_pos = _pick_reachable_spawn_position()
	enemy.global_position = spawn_pos
	var difficulty = float(spawn_settings.get("difficulty", 1.0))
	if enemy.has_method("setup"):
		enemy.setup(self, difficulty)
	var base_elite_chance = clamp(float(spawn_settings.get("elite", 0.0)), 0.0, 0.18)
	var time_scalar = 1.0 + min(elapsed / 300.0, 2.5) * 0.35
	var elite_chance = clamp(base_elite_chance * time_scalar, 0.0, 0.24)
	var elite_cap = clampi(int(8 + elapsed / 120.0), 8, 42)
	if _count_elites() < elite_cap and randf() < elite_chance and enemy.has_method("set_elite"):
		enemy.set_elite(elite_health_mult)
	enemies_root.add_child(enemy)
	_register_enemy_net(enemy, scene.resource_path, "")

func _pick_reachable_spawn_position() -> Vector2:
	# FFA: anchor on a random living player so the horde surrounds everyone.
	var anchor := _spawn_anchor_player()
	if anchor == null:
		return Vector2.ZERO
	var origin = anchor.global_position
	var attempts = 32
	for i in range(attempts):
		var angle = randf() * TAU
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var pos = origin + Vector2.RIGHT.rotated(angle) * distance
		if is_flow_reachable(pos):
			return pos
	# Fallback: spawn at max radius in a random direction
	var fallback_angle = randf() * TAU
	return origin + Vector2.RIGHT.rotated(fallback_angle) * spawn_radius_max

func spawn_minion(position: Vector2) -> void:
	if enemies_root.get_child_count() >= max_enemies_cap:
		return
	var enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	var difficulty = float(_get_spawn_settings(elapsed).get("difficulty", 1.0))
	if enemy.has_method("setup"):
		enemy.setup(self, difficulty)
	enemies_root.add_child(enemy)
	_register_enemy_net(enemy, ENEMY_SCENE.resource_path, "")

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
		_register_enemy_net(enemy, ENEMY_SCENE.resource_path, "")

# ---------------------------------------------------------------------------
# Enemy replication (FFA custom RPC batch sync)
#
# Host is the only simulator. It assigns each enemy a monotonic net_id, tells
# clients which scene/script to instantiate, then streams position batches at
# ENEMY_SYNC_HZ. Clients render lightweight proxies (no AI, no collisions) and
# lerp them toward the last synced position. On death the host broadcasts a
# despawn so clients free the proxy.
# ---------------------------------------------------------------------------

# Host-only: tag a freshly spawned enemy with a net id and tell clients to make
# a matching proxy. No-op in solo or on clients.
func _register_enemy_net(enemy: Node, scene_path: String, script_path: String) -> void:
	if not is_ffa() or not is_host():
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	_enemy_net_seq += 1
	var nid := _enemy_net_seq
	if "net_id" in enemy:
		enemy.net_id = nid
	if "net_scene_path" in enemy:
		enemy.net_scene_path = scene_path
	if "net_script_path" in enemy:
		enemy.net_script_path = script_path
	# Free the proxy on every other peer when this enemy leaves the tree.
	enemy.tree_exited.connect(_on_host_enemy_exited.bind(nid))
	var pos := Vector2.ZERO
	if enemy is Node2D:
		pos = (enemy as Node2D).global_position
	var is_boss := script_path != ""
	_rpc_enemy_spawn.rpc(nid, scene_path, script_path, pos, is_boss)
	if _net_verbose() and (nid <= 3 or nid % 50 == 0):
		print("[FFA-ENEMY] host register nid=", nid, " scene=", scene_path.get_file(), " boss=", is_boss)

# Host-only: an enemy left the tree (died/despawned) -> tell clients to drop it.
func _on_host_enemy_exited(nid: int) -> void:
	# tree_exited can fire during scene teardown, when this game node is itself
	# detached and absolute node paths (/root/Net) are unreachable. Bail then.
	if not is_inside_tree():
		return
	if not is_ffa() or not is_host():
		return
	_rpc_enemy_despawn.rpc(nid)

# Host streams positions; clients smooth proxies toward their last target.
var _enemy_net_heartbeat: float = 0.0
func _update_enemy_net_sync(delta: float) -> void:
	if is_host():
		_host_stream_enemy_positions(delta)
	else:
		_client_interpolate_proxies(delta)
	if _net_verbose():
		_enemy_net_heartbeat += delta
		if _enemy_net_heartbeat >= 5.0:
			_enemy_net_heartbeat = 0.0
			if is_host():
				print("[FFA-ENEMY] host live enemies=", enemies_root.get_child_count(), " next_nid=", _enemy_net_seq)
			else:
				print("[FFA-ENEMY] client proxies=", _net_enemy_proxies.size())

func _host_stream_enemy_positions(delta: float) -> void:
	if enemies_root == null:
		return
	_enemy_sync_accum += delta
	var interval := 1.0 / ENEMY_SYNC_HZ
	if _enemy_sync_accum < interval:
		return
	_enemy_sync_accum = 0.0
	# Pack (net_id, x, y) triples. Split into batches to bound packet size.
	var ids := PackedInt32Array()
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for child in enemies_root.get_children():
		if not (child is Node2D):
			continue
		var nid := 0
		if "net_id" in child:
			nid = int(child.net_id)
		if nid == 0:
			continue
		ids.append(nid)
		var gp := (child as Node2D).global_position
		xs.append(gp.x)
		ys.append(gp.y)
		if ids.size() >= ENEMY_SYNC_BATCH:
			_rpc_enemy_positions.rpc(ids, xs, ys)
			ids = PackedInt32Array()
			xs = PackedFloat32Array()
			ys = PackedFloat32Array()
	if ids.size() > 0:
		_rpc_enemy_positions.rpc(ids, xs, ys)

func _client_interpolate_proxies(delta: float) -> void:
	var lerp_factor: float = clamp(delta * 14.0, 0.0, 1.0)
	for nid in _net_enemy_proxies.keys():
		var proxy = _net_enemy_proxies[nid]
		if proxy == null or not is_instance_valid(proxy):
			continue
		if not _net_enemy_targets.has(nid):
			continue
		var target: Vector2 = _net_enemy_targets[nid]
		proxy.global_position = proxy.global_position.lerp(target, lerp_factor)

# Client: instantiate a proxy enemy from the host's scene/script path.
@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_spawn(nid: int, scene_path: String, script_path: String, pos: Vector2, _is_boss: bool) -> void:
	if is_host():
		return
	if _net_enemy_proxies.has(nid):
		return
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	var proxy = packed.instantiate()
	if script_path != "" and ResourceLoader.exists(script_path):
		var scr = load(script_path)
		if scr != null:
			proxy.set_script(scr)
	if "is_net_proxy" in proxy:
		proxy.is_net_proxy = true
	if "net_id" in proxy:
		proxy.net_id = nid
	if proxy is Node2D:
		(proxy as Node2D).global_position = pos
	if enemies_root != null:
		enemies_root.add_child(proxy)
		# Proxies must not run host AI/collisions; the visual-only guard in
		# enemy.gd keys off is_sim_authority(), which is false on clients.
		if proxy.has_method("setup"):
			proxy.setup(self, 1.0)
	_net_enemy_proxies[nid] = proxy
	_net_enemy_targets[nid] = pos
	if _net_verbose() and (nid <= 3 or _net_enemy_proxies.size() % 50 == 0):
		print("[FFA-ENEMY] client proxy nid=", nid, " total=", _net_enemy_proxies.size())

@rpc("authority", "call_remote", "reliable")
func _rpc_enemy_despawn(nid: int) -> void:
	if is_host():
		return
	if _net_enemy_proxies.has(nid):
		var proxy = _net_enemy_proxies[nid]
		if proxy != null and is_instance_valid(proxy):
			proxy.queue_free()
		_net_enemy_proxies.erase(nid)
	_net_enemy_targets.erase(nid)

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_enemy_positions(ids: PackedInt32Array, xs: PackedFloat32Array, ys: PackedFloat32Array) -> void:
	if is_host():
		return
	var n := ids.size()
	for i in range(n):
		var nid := ids[i]
		_net_enemy_targets[nid] = Vector2(xs[i], ys[i])

# ---------------------------------------------------------------------------
# FFA match: 20-minute clock + ranked results
#
# The host owns the authoritative countdown and broadcasts it once a second so
# every peer's HUD agrees. At zero the host compiles a ranked scoreboard from
# the per-player econ ledger (most resources collected wins) and pushes it to
# all peers, which each present results and award their own Cores locally.
# ---------------------------------------------------------------------------

func get_ffa_time_left() -> float:
	return _ffa_time_left

func _update_ffa_clock(delta: float) -> void:
	if _ffa_match_over:
		return
	if not is_host():
		return
	_ffa_time_left = max(0.0, _ffa_time_left - delta)
	_ffa_clock_accum += delta
	if _ffa_clock_accum >= 1.0:
		_ffa_clock_accum = 0.0
		_rpc_ffa_clock.rpc(_ffa_time_left)
		_update_ffa_clock_hud(_ffa_time_left)
		if _net_verbose():
			print("[FFA-MATCH] clock left=", int(_ffa_time_left), " ts=", Engine.time_scale)
	if _ffa_time_left <= 0.0:
		_end_ffa_match()

@rpc("authority", "call_remote", "reliable")
func _rpc_ffa_clock(time_left: float) -> void:
	_ffa_time_left = time_left
	_update_ffa_clock_hud(time_left)

func _update_ffa_clock_hud(time_left: float) -> void:
	if ui != null and ui.has_method("set_ffa_clock"):
		ui.set_ffa_clock(time_left)

# Count real (human) players in the locked match roster, regardless of alive state.
func _count_real_players() -> int:
	var n := _net()
	if n == null:
		return 0
	var c := 0
	for entry in n.match_roster:
		if not bool(entry.get("is_bot", false)):
			c += 1
	return c

# Count real (human) players who are still in the match: not a bot, not eliminated,
# and (for remote peers) still connected. A friend who crashes / force-quits drops
# off multiplayer.get_peers(), so they correctly stop counting as alive even though
# they never sent a death. Host-only meaningful (uses the host's connection view).
func _count_alive_real_players() -> int:
	var n := _net()
	if n == null:
		return 0
	var connected := {}
	for pid in multiplayer.get_peers():
		connected[int(pid)] = true
	var local_id := multiplayer.get_unique_id()
	var c := 0
	for entry in n.match_roster:
		if bool(entry.get("is_bot", false)):
			continue
		var pid := int(entry["peer_id"])
		if _ffa_dead_players.has(pid):
			continue
		# The local host (id 1) is always "present"; remote peers must still be
		# connected to count as alive.
		if pid != local_id and not connected.has(pid):
			continue
		c += 1
	return c

# Host-authoritative: once the match started with >=2 humans and only one human
# remains alive, run a short grace countdown (so the survivor can keep gathering
# resources) and then end the match. Broadcast the remaining time at 1 Hz so all
# peers show the same banner. Solo-host + bot matches never trigger this.
func _update_ffa_lastman(delta: float) -> void:
	if _ffa_match_over:
		return
	if not is_host():
		return
	if _ffa_started_real_count < 2:
		return
	if not _ffa_lastman_active:
		if _count_alive_real_players() <= 1:
			_ffa_lastman_active = true
			_ffa_lastman_left = FFA_LASTMAN_SECONDS
			_ffa_lastman_accum = 0.0
			_rpc_ffa_lastman.rpc(_ffa_lastman_left)
			_show_ffa_lastman_banner(_ffa_lastman_left)
			if _net_verbose():
				print("[FFA-MATCH] last survivor — grace countdown started (", int(FFA_LASTMAN_SECONDS), "s)")
		return
	_ffa_lastman_left = max(0.0, _ffa_lastman_left - delta)
	_ffa_lastman_accum += delta
	if _ffa_lastman_accum >= 1.0:
		_ffa_lastman_accum = 0.0
		_rpc_ffa_lastman.rpc(_ffa_lastman_left)
		_show_ffa_lastman_banner(_ffa_lastman_left)
	if _ffa_lastman_left <= 0.0:
		_end_ffa_match()

@rpc("authority", "call_remote", "reliable")
func _rpc_ffa_lastman(time_left: float) -> void:
	_ffa_lastman_active = true
	_ffa_lastman_left = time_left
	_show_ffa_lastman_banner(time_left)

func _show_ffa_lastman_banner(time_left: float) -> void:
	if ui != null and ui.has_method("show_announcement"):
		var secs := int(ceil(max(0.0, time_left)))
		ui.show_announcement("LAST SURVIVOR — match ends in %ds" % secs, Color(1.0, 0.55, 0.3), 30, 1.1)

# Host: a player's HP hit zero. Mark them eliminated and broadcast so every peer
# makes that player (and their towers) inert. Their score is already locked in
# the econ ledger and keeps counting nothing further.
func ffa_on_player_died(pid: int) -> void:
	if not is_ffa():
		return
	if not is_host():
		# Clients route the death to the host, which owns the authoritative state.
		_rpc_request_player_death.rpc_id(1, pid)
		return
	if _ffa_dead_players.has(pid):
		return
	_ffa_dead_players[pid] = true
	_rpc_player_eliminated.rpc(pid)
	_apply_player_inert(pid)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_player_death(pid: int) -> void:
	if not is_host():
		return
	ffa_on_player_died(pid)

@rpc("authority", "call_remote", "reliable")
func _rpc_player_eliminated(pid: int) -> void:
	if is_host():
		return
	_ffa_dead_players[pid] = true
	_apply_player_inert(pid)

# Make a dead/left player inert everywhere: freeze the player and stop their
# towers/generators from firing or earning.
func _apply_player_inert(pid: int) -> void:
	var p = players.get(pid)
	if p != null and is_instance_valid(p):
		if "inert" in p:
			p.inert = true
	if buildings_root != null:
		for b in buildings_root.get_children():
			if b == null or not is_instance_valid(b):
				continue
			if "owner_id" in b and int(b.owner_id) == pid:
				if "inert" in b:
					b.inert = true
	# If it's MY player that died, show the local death overlay. The match keeps
	# running for everyone (including a dead host) until the clock ends.
	if pid == _local_econ_id() and not _ffa_match_over:
		_show_ffa_death_screen()

# Local placement (1 = leading) computed from the live econ ledger, for the
# spectate overlay shown to the dead local player.
func _ffa_local_placement() -> int:
	var board := _build_ffa_scoreboard()
	var my_id := _local_econ_id()
	for i in range(board.size()):
		if int(board[i]["peer_id"]) == my_id:
			return i + 1
	return board.size()

func _show_ffa_death_screen() -> void:
	if ffa_death_ui == null or not is_instance_valid(ffa_death_ui):
		return
	var total := econ.size()
	var placement := _ffa_local_placement()
	if ffa_death_ui.has_method("show_death"):
		ffa_death_ui.show_death(placement, total)

func _end_ffa_match() -> void:
	if _ffa_match_over:
		return
	if not is_host():
		return
	_ffa_match_over = true
	var board := _build_ffa_scoreboard()
	if _net_verbose():
		print("[FFA-MATCH] host end. board size=", board.size())
		for i in range(board.size()):
			print("  #", i + 1, " pid=", board[i]["peer_id"], " currency=", board[i]["currency"], " treasures=", board[i]["treasures"], " bot=", board[i]["is_bot"])
	_rpc_ffa_results.rpc(board)
	_show_ffa_results(board)
	# Remove this game from the optional lobby browser the instant it ends, so
	# finished matches don't linger in other players' lists. Best-effort + guarded.
	var ll := get_node_or_null("/root/LobbyList")
	if ll != null and ll.has_method("end_lobby"):
		ll.end_lobby()

# Ranked board: [{peer_id, name, is_bot, currency, treasures}], best first.
func _build_ffa_scoreboard() -> Array:
	var rows: Array = []
	var n := _net()
	for pid in econ.keys():
		var e: Dictionary = econ[pid]
		var pname := "Player"
		var is_bot := false
		if n != null and n.lobby_players.has(pid):
			var lp: Dictionary = n.lobby_players[pid]
			pname = str(lp.get("name", pname))
			is_bot = bool(lp.get("is_bot", false))
		rows.append({
			"peer_id": pid,
			"name": pname,
			"is_bot": is_bot,
			"currency": int(e.get("currency_earned", 0)),
			"treasures": int(e.get("treasures", 0)),
		})
	rows.sort_custom(_ffa_score_sort)
	return rows

func _ffa_score_sort(a: Dictionary, b: Dictionary) -> bool:
	if int(a["currency"]) != int(b["currency"]):
		return int(a["currency"]) > int(b["currency"])
	return int(a["treasures"]) > int(b["treasures"])

@rpc("authority", "call_remote", "reliable")
func _rpc_ffa_results(board: Array) -> void:
	if is_host():
		return
	_ffa_match_over = true
	_show_ffa_results(board)

# Each peer presents the same ranked board and awards its own Cores based on
# this machine's placement.
func _show_ffa_results(board: Array) -> void:
	game_over = true
	Engine.time_scale = 1.0
	set_build_focus(false, "")
	_force_close_menus()
	_set_pause_allowed(false)
	# The end-of-match scoreboard supersedes the local spectate/death overlay.
	if ffa_death_ui != null and is_instance_valid(ffa_death_ui) and ffa_death_ui.has_method("hide_death"):
		ffa_death_ui.hide_death()
	var my_id := _local_econ_id()
	var placement := board.size()
	for i in range(board.size()):
		if int(board[i]["peer_id"]) == my_id:
			placement = i + 1
			break
	var won := placement == 1 and board.size() > 0
	var my_score := 0
	if placement >= 1 and placement <= board.size():
		my_score = int(board[placement - 1]["currency"])
	var cores := 0
	var meta = _get_meta_progression()
	if meta != null and meta.has_method("award_ffa_cores"):
		cores = meta.award_ffa_cores(placement, my_score, won)
	if _net_verbose():
		print("[FFA-MATCH] results my_id=", my_id, " placement=", placement, " score=", my_score, " won=", won, " cores=", cores)
	if ffa_results_ui != null and ffa_results_ui.has_method("show_results"):
		ffa_results_ui.show_results(board, my_id, placement, cores)
	elif ui != null and ui.has_method("show_announcement"):
		var msg := "VICTORY" if won else "MATCH OVER  (#%d)" % placement
		ui.show_announcement(msg, Color(1.0, 0.85, 0.3), 48, 5.0)

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

func _apply_play_bounds() -> void:
	# Derive play radius from Ground radius (tiles * tile_size)
	if ground != null:
		var tile_size = 32.0
		if "tile_size" in ground:
			var raw = ground.tile_size
			if typeof(raw) == TYPE_VECTOR2I:
				tile_size = float(raw.x)
			elif typeof(raw) == TYPE_VECTOR2:
				tile_size = float(raw.x)
		if "radius" in ground:
			var terrain_radius = float(ground.radius)
			if "fill_margin_cells" in ground:
				terrain_radius += float(ground.fill_margin_cells)
			play_radius = terrain_radius * tile_size
	# Clamp spawn distances to stay within play area
	var max_spawn = max(300.0, play_radius - 120.0)
	spawn_radius_max = min(spawn_radius_max, max_spawn)
	spawn_radius_min = min(spawn_radius_min, spawn_radius_max - 160.0)
	breakable_spawn_max = min(breakable_spawn_max, max_spawn + 200.0)
	prop_spawn_radius = min(prop_spawn_radius, play_radius + 400.0)

func get_play_radius() -> float:
	return play_radius

func clamp_to_play_area(pos: Vector2) -> Vector2:
	if play_radius <= 0.0:
		return pos
	var clamp_radius = max(0.0, play_radius - 96.0)
	var dist = pos.length()
	if dist > clamp_radius:
		return pos.normalized() * clamp_radius
	return pos

func mark_flow_field_dirty() -> void:
	_flow_dirty = true

func is_extractor_sealed() -> bool:
	return extractor_sealed

func get_breach_damage_mult() -> float:
	return BREACH_DAMAGE_MULT if extractor_sealed else 1.0

func _update_breach_state(delta: float) -> void:
	"""Ground truth, not geometry: ask the enemies that are actually on the field
	whether any of them can still path to the objective.

	Sampling live enemies rather than a ring of theoretical spawn points avoids
	depending on how far the flow field happens to extend - every enemy is inside
	it by construction."""
	if not has_extractor() or game_over:
		_breach_confirm_timer = 0.0
		if extractor_sealed:
			_set_breach(false)
		return
	var enemies = enemies_root.get_children() if enemies_root != null else []
	var sampled := 0
	var reachable := 0
	for e in enemies:
		if e == null or not is_instance_valid(e) or not (e is Node2D):
			continue
		if "_is_dying" in e and e._is_dying:
			continue
		var pos: Vector2 = (e as Node2D).global_position
		# Only enemies inside the field can testify. Outside it there is no data,
		# and counting them as unreachable would trip a breach on distance alone.
		if not is_in_flow_field(pos):
			continue
		sampled += 1
		if is_flow_reachable(pos):
			reachable += 1
			break  # one is enough to prove a route exists
	if sampled < BREACH_MIN_ENEMIES:
		# Too few bodies to conclude anything; never trip on a thin field.
		_breach_confirm_timer = 0.0
		if extractor_sealed:
			_set_breach(false)
		return
	if reachable > 0:
		_breach_confirm_timer = 0.0
		if extractor_sealed:
			_set_breach(false)
		return
	_breach_confirm_timer += delta
	if _breach_confirm_timer >= BREACH_CONFIRM_TIME and not extractor_sealed:
		_set_breach(true)

func _set_breach(active: bool) -> void:
	if extractor_sealed == active:
		return
	extractor_sealed = active
	if active:
		if not _breach_announced and ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("PATH BLOCKED - HORDE IS BREACHING!", Color(1.0, 0.35, 0.25), 30, 3.0)
			_breach_announced = true
		AudioManager.play_ui_sound("wave_start")
	else:
		_breach_announced = false
	# Enemies re-pick their target on the next refresh; nudge the field so anyone
	# already moving reacts promptly.
	mark_flow_field_dirty()

func _update_flow_field(delta: float) -> void:
	if player == null:
		return
	_flow_timer = max(0.0, _flow_timer - delta)
	# Once the extractor is down it becomes the pathing goal, so the horde
	# converges on the objective and has to chew through whatever maze the
	# player built around it.
	var goal_pos := player.global_position
	if has_extractor():
		goal_pos = (extractor as Node2D).global_position
	var goal_cell = _world_to_flow_cell(goal_pos)
	if goal_cell != _flow_player_cell:
		_flow_dirty = true
	if not _flow_dirty or _flow_timer > 0.0:
		return
	_rebuild_flow_field(goal_cell)

func _rebuild_flow_field(player_cell: Vector2i) -> void:
	_flow_timer = _flow_rebuild_interval_runtime
	_flow_dirty = false
	_flow_player_cell = player_cell

	_flow_radius_cells = _compute_flow_radius_cells()
	_flow_size = Vector2i(_flow_radius_cells * 2 + 1, _flow_radius_cells * 2 + 1)
	_flow_origin_cell = player_cell - Vector2i(_flow_radius_cells, _flow_radius_cells)

	var total = _flow_size.x * _flow_size.y
	_flow_dist = PackedInt32Array()
	_flow_dist.resize(total)
	_flow_blocked = PackedByteArray()
	_flow_blocked.resize(total)
	for i in range(total):
		_flow_dist[i] = -1
		_flow_blocked[i] = 0

	# Mark blocked cells from buildings
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building == null or not is_instance_valid(building):
			continue
		var blocks_path = true
		if "blocks_path" in building:
			blocks_path = bool(building.blocks_path)
		if not blocks_path:
			continue
		var radius = 12.0
		if building.has_method("get_footprint_radius"):
			radius = float(building.get_footprint_radius())
		var pad = radius + FLOW_AGENT_RADIUS + FLOW_BLOCK_MARGIN
		var min_cell = _world_to_flow_cell(building.global_position - Vector2(pad, pad))
		var max_cell = _world_to_flow_cell(building.global_position + Vector2(pad, pad))
		for cx in range(min_cell.x, max_cell.x + 1):
			for cy in range(min_cell.y, max_cell.y + 1):
				var cell = Vector2i(cx, cy)
				var idx = _flow_index(cell)
				if idx < 0:
					continue
				var center = _flow_cell_to_world_center(cell)
				if abs(center.x - building.global_position.x) <= pad and abs(center.y - building.global_position.y) <= pad:
					_flow_blocked[idx] = 1

	_compute_flow_clearance()
	_flow_required_cells = _get_required_clearance_cells()

	# Ensure player cell is always reachable
	var start_idx = _flow_index(player_cell)
	if start_idx >= 0:
		_flow_blocked[start_idx] = 0
		if _flow_clearance.size() > start_idx:
			_flow_clearance[start_idx] = max(_flow_clearance[start_idx], _flow_required_cells)

	# BFS from player to build distance field
	if start_idx < 0:
		return
	_flow_dist[start_idx] = 0
	var queue: Array = [start_idx]
	var head = 0
	while head < queue.size():
		var idx = queue[head]
		head += 1
		var x = idx % _flow_size.x
		var y = int(idx / _flow_size.x)
		for dir in FLOW_DIRS:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx < 0 or ny < 0 or nx >= _flow_size.x or ny >= _flow_size.y:
				continue
			var nidx = ny * _flow_size.x + nx
			if _flow_blocked[nidx] == 1:
				continue
			if _flow_clearance[nidx] < _flow_required_cells:
				continue
			if _flow_dist[nidx] >= 0:
				continue
			var cell = Vector2i(nx + _flow_origin_cell.x, ny + _flow_origin_cell.y)
			if play_radius > 0.0 and _flow_cell_to_world_center(cell).length() > play_radius:
				continue
			_flow_dist[nidx] = _flow_dist[idx] + 1
			queue.append(nidx)

func _compute_flow_clearance() -> void:
	var total = _flow_size.x * _flow_size.y
	_flow_clearance = PackedInt32Array()
	_flow_clearance.resize(total)
	for i in range(total):
		_flow_clearance[i] = -1

	var queue: Array = []
	for i in range(total):
		if _flow_blocked[i] == 1:
			_flow_clearance[i] = 0
			queue.append(i)

	if queue.is_empty():
		for i in range(total):
			_flow_clearance[i] = _flow_radius_cells
		return

	var head = 0
	while head < queue.size():
		var idx = queue[head]
		head += 1
		var x = idx % _flow_size.x
		var y = int(idx / _flow_size.x)
		for dir in CLEARANCE_DIRS:
			var nx = x + dir.x
			var ny = y + dir.y
			if nx < 0 or ny < 0 or nx >= _flow_size.x or ny >= _flow_size.y:
				continue
			var nidx = ny * _flow_size.x + nx
			if _flow_clearance[nidx] >= 0:
				continue
			_flow_clearance[nidx] = _flow_clearance[idx] + 1
			queue.append(nidx)

func _get_required_clearance_cells() -> int:
	var required = (FLOW_AGENT_RADIUS + FLOW_CLEARANCE_MARGIN + FLOW_CELL_SIZE * 0.5) / FLOW_CELL_SIZE
	return int(ceil(required))

func _compute_flow_radius_cells() -> int:
	# Keep enough radius around active spawn ring while avoiding oversized rebuilds.
	var desired_world_radius = max(spawn_radius_max + FLOW_RADIUS_PADDING, 960.0)
	if play_radius > 0.0:
		desired_world_radius = min(desired_world_radius, play_radius + FLOW_CELL_SIZE)
	var cells = int(ceil(desired_world_radius / FLOW_CELL_SIZE))
	return clampi(cells, FLOW_MIN_RADIUS_CELLS, FLOW_MAX_RADIUS_CELLS)

func get_flow_direction(world_pos: Vector2) -> Vector2:
	if _flow_dist.is_empty() or _flow_size == Vector2i.ZERO:
		return Vector2.ZERO
	var cell = _world_to_flow_cell(world_pos)
	var idx = _flow_index(cell)
	if idx < 0:
		return Vector2.ZERO
	if _flow_clearance[idx] < _flow_required_cells:
		return Vector2.ZERO
	var dist = _flow_dist[idx]
	if dist < 0:
		var fallback_cell = _find_nearest_reachable_cell(cell, 8)
		if fallback_cell != cell:
			var fallback_target = _flow_cell_to_world_center(fallback_cell)
			return (fallback_target - world_pos).normalized()
		return Vector2.ZERO
	var best_dir = Vector2i.ZERO
	var best_dist = dist
	for dir in FLOW_DIRS:
		var ncell = cell + dir
		var nidx = _flow_index(ncell)
		if nidx < 0:
			continue
		if _flow_clearance[nidx] < _flow_required_cells:
			continue
		var ndist = _flow_dist[nidx]
		if ndist >= 0 and ndist < best_dist:
			best_dist = ndist
			best_dir = dir
	if best_dir == Vector2i.ZERO:
		return Vector2.ZERO
	var target = _flow_cell_to_world_center(cell + best_dir)
	return (target - world_pos).normalized()

func _find_nearest_reachable_cell(cell: Vector2i, max_radius: int) -> Vector2i:
	var best_cell = cell
	var best_dist = INF
	for r in range(1, max_radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var candidate = Vector2i(cell.x + dx, cell.y + dy)
				var idx = _flow_index(candidate)
				if idx < 0:
					continue
				if _flow_clearance[idx] < _flow_required_cells:
					continue
				var dist = _flow_dist[idx]
				if dist >= 0 and dist < best_dist:
					best_dist = dist
					best_cell = candidate
		if best_cell != cell:
			return best_cell
	return best_cell

func is_in_flow_field(world_pos: Vector2) -> bool:
	"""Distinguishes "inside the field but cut off" from "simply outside the grid".
	is_flow_reachable() answers false for both, which is right for pathing but
	would make a far-off enemy look sealed out when it is only far away."""
	if _flow_dist.is_empty() or _flow_size == Vector2i.ZERO:
		return false
	return _flow_index(_world_to_flow_cell(world_pos)) >= 0

func is_flow_reachable(world_pos: Vector2) -> bool:
	if _flow_dist.is_empty() or _flow_size == Vector2i.ZERO:
		return true
	var cell = _world_to_flow_cell(world_pos)
	var idx = _flow_index(cell)
	if idx < 0:
		return false
	if _flow_clearance[idx] < _flow_required_cells:
		return false
	return _flow_dist[idx] >= 0

func _draw() -> void:
	if not debug_flow_enabled:
		return
	if _flow_dist.is_empty() or _flow_size == Vector2i.ZERO:
		return
	var center_cell = _flow_player_cell
	var radius = min(DEBUG_FLOW_DRAW_RADIUS, _flow_radius_cells)
	var min_cell = Vector2i(center_cell.x - radius, center_cell.y - radius)
	var max_cell = Vector2i(center_cell.x + radius, center_cell.y + radius)

	for cy in range(min_cell.y, max_cell.y + 1, DEBUG_FLOW_STRIDE):
		for cx in range(min_cell.x, max_cell.x + 1, DEBUG_FLOW_STRIDE):
			var cell = Vector2i(cx, cy)
			var idx = _flow_index(cell)
			if idx < 0:
				continue
			var center = _flow_cell_to_world_center(cell)
			if play_radius > 0.0 and center.length() > play_radius:
				continue
			if _flow_clearance.size() > idx and _flow_clearance[idx] < _flow_required_cells:
				var tight_rect = Rect2(center - Vector2(FLOW_CELL_SIZE * 0.5, FLOW_CELL_SIZE * 0.5), Vector2(FLOW_CELL_SIZE, FLOW_CELL_SIZE))
				draw_rect(tight_rect, DEBUG_FLOW_BLOCK_COLOR, true)
				continue
			if _flow_blocked[idx] == 1:
				var rect = Rect2(center - Vector2(FLOW_CELL_SIZE * 0.5, FLOW_CELL_SIZE * 0.5), Vector2(FLOW_CELL_SIZE, FLOW_CELL_SIZE))
				draw_rect(rect, DEBUG_FLOW_BLOCK_COLOR, true)
				continue
			var dist = _flow_dist[idx]
			if dist < 0:
				continue
			var dir = _get_flow_dir_for_cell(cell)
			if dir != Vector2.ZERO:
				draw_line(center, center + dir * DEBUG_FLOW_LINE_LEN, DEBUG_FLOW_DIR_COLOR, 1.0)

	# Highlight player cell
	var player_center = _flow_cell_to_world_center(center_cell)
	draw_circle(player_center, 6.0, DEBUG_FLOW_PLAYER_COLOR)

func _get_flow_dir_for_cell(cell: Vector2i) -> Vector2:
	var idx = _flow_index(cell)
	if idx < 0:
		return Vector2.ZERO
	var dist = _flow_dist[idx]
	if dist < 0:
		return Vector2.ZERO
	var best_dir = Vector2i.ZERO
	var best_dist = dist
	for dir in FLOW_DIRS:
		var ncell = cell + dir
		var nidx = _flow_index(ncell)
		if nidx < 0:
			continue
		if _flow_clearance[nidx] < _flow_required_cells:
			continue
		var ndist = _flow_dist[nidx]
		if ndist >= 0 and ndist < best_dist:
			best_dist = ndist
			best_dir = dir
	if best_dir == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(best_dir.x, best_dir.y).normalized()

func _world_to_flow_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / FLOW_CELL_SIZE)), int(floor(world_pos.y / FLOW_CELL_SIZE)))

func _flow_cell_to_world_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * FLOW_CELL_SIZE, (float(cell.y) + 0.5) * FLOW_CELL_SIZE)

func _flow_index(cell: Vector2i) -> int:
	var local = cell - _flow_origin_cell
	if local.x < 0 or local.y < 0 or local.x >= _flow_size.x or local.y >= _flow_size.y:
		return -1
	return local.y * _flow_size.x + local.x

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

func spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, explosion_radius: float, pierce: int = 0, slow_factor: float = 1.0, slow_duration: float = 0.0, damage_type: String = "normal", visual_profile: Dictionary = {}) -> void:
	if projectiles_root.get_child_count() >= max_projectiles:
		return
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = origin
	if projectile.has_method("setup"):
		projectile.setup(self, direction, speed, damage, max_range, explosion_radius, pierce, slow_factor, slow_duration, damage_type, visual_profile)
	projectiles_root.add_child(projectile)

func spawn_cannonball(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, explosion_radius: float, cluster_bombs: bool = false, burn_effect: bool = false, visual_profile: Dictionary = {}) -> Node:
	if projectiles_root.get_child_count() >= max_projectiles:
		return null
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = origin
	var damage_type = "fire" if burn_effect else "normal"
	if projectile.has_method("setup"):
		projectile.setup(self, direction, speed, damage, max_range, explosion_radius, 0, 1.0, 0.0, damage_type, visual_profile)
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

func spawn_golden_coco() -> void:
	"""Mythic chest pull: the golden coco joins the run for good.

	One only. A second mythic pull would otherwise stack auras and double the
	fetch rate, and the whole point of a mythic is that it happens once.
	"""
	for existing in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(existing):
			return
	var coco = COMPANION_COCO_SCENE.instantiate()
	var anchor: Vector2 = player.global_position if player != null and is_instance_valid(player) else Vector2.ZERO
	coco.global_position = anchor + Vector2(randf_range(-40.0, 40.0), 40.0)
	if coco.has_method("setup"):
		coco.setup(self)
	# Parented to the world, not the player: she roams the whole map and must
	# not inherit the player's transform.
	var host: Node = pickups_root if pickups_root != null else self
	host.add_child(coco)
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("GOLDEN COCO JOINS YOU!", Color(1.0, 0.84, 0.3), 44, 3.0)
	shake_camera(10.0, 0.5)
	flash_screen(Color(1.0, 0.85, 0.35, 0.30), 0.5)

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
		# Sized as a pickup, not an announcement. At 28 this covered a fifth of the
		# screen and hid live combat behind a routine notification; centre-screen
		# warnings stay large, this does not.
		ui.show_announcement(text, Color(0.8, 0.4, 1.0), 15, 1.4, _essence_announce_position)
	_essence_announce_count = 0
	_essence_announce_timer = 0.0

func spawn_fx(kind: String, position: Vector2, force_optional: bool = false) -> void:
	if fx_root == null or not fx_defs.has(kind):
		return
	if not force_optional and not _should_spawn_optional_fx():
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

func _setpiece_fx_allowed(kind: String) -> bool:
	var cooldown_ms = int(SETPIECE_COOLDOWNS_MS.get(kind, 0))
	if cooldown_ms <= 0:
		return true
	var now = Time.get_ticks_msec()
	var last = int(_setpiece_fx_last_ms.get(kind, 0))
	if now - last < cooldown_ms:
		return false
	_setpiece_fx_last_ms[kind] = now
	return true

func spawn_setpiece_fx(kind: String, position: Vector2, intensity: float = 1.0, damage_type: String = "normal") -> void:
	if not _setpiece_fx_allowed(kind):
		return
	var power = clampf(intensity, 0.65, 2.4)
	match kind:
		"tower_evolution":
			spawn_fx("hero_evolution", position, true)
			spawn_fx("hero_evolution", position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)), true)
			spawn_fx("upgrade_burst", position, true)
			spawn_fx("shockwave", position, true)
			_spawn_glow_burst(position, Color(0.6, 0.38, 1.0), int(round(20.0 * power)), 24.0 * power, 0.85, 280.0 * power, 2.9)
			flash_screen(Color(0.65, 0.48, 1.0, 0.1), 0.16)
			shake_camera(8.0 * power, 0.25)
		"elite_death":
			spawn_fx("hero_elite_death", position, true)
			spawn_fx("elite_kill", position, true)
			spawn_fx("shockwave", position, true)
			spawn_fx("blood", position, true)
			_spawn_glow_burst(position, Color(1.0, 0.76, 0.2), int(round(14.0 * power)), 16.0 * power, 0.62, 230.0 * power, 2.3)
			flash_screen(Color(1.0, 0.86, 0.3, 0.08), 0.09)
			if power >= 1.25:
				flash_screen(Color(1.0, 0.9, 0.4, 0.14), 0.13)
		"boss_death":
			spawn_fx("hero_boss_death", position, true)
			spawn_fx("hero_boss_death", position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0)), true)
			spawn_fx("hero_elite_death", position, true)
			spawn_fx("upgrade_burst", position, true)
			spawn_fx("shockwave", position, true)
			_spawn_glow_burst(position, Color(1.0, 0.35, 0.2), int(round(28.0 * power)), 28.0 * power, 1.0, 300.0 * power, 3.2)
			flash_screen(Color(1.0, 0.42, 0.26, 0.24), 0.3)
			shake_camera(13.0 * power, 0.38)
		"cannon_impact":
			spawn_fx("hero_cannon_impact", position, true)
			if damage_type == "fire":
				spawn_fx("fire_burst", position, true)
			if power >= 1.3:
				spawn_fx("shockwave", position, true)
			_spawn_glow_burst(position, Color(1.0, 0.45, 0.14), int(round(10.0 * power)), 12.0 * power, 0.44, 180.0 * power, 2.2)
		"energy_impact":
			spawn_fx("hero_energy_impact", position, true)
			spawn_fx("tesla", position, true)
			if damage_type == "lightning":
				spawn_fx("tesla", position, true)
			_spawn_glow_burst(position, Color(0.22, 0.98, 1.0), int(round(11.0 * power)), 11.0 * power, 0.4, 185.0 * power, 2.25)

func spawn_glow_particle(position: Vector2, color: Color, size: float = 8.0, lifetime: float = 0.45, velocity: Vector2 = Vector2.ZERO, bloom: float = 1.6, trail_strength: float = 0.7, trail_length: float = 0.9, z: int = 1) -> Node:
	if fx_root == null:
		return null
	if not _should_spawn_optional_fx():
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
	var density = _get_effective_fx_density_scale()
	var scaled_count = max(1, int(round(float(count) * density)))
	for i in scaled_count:
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
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("show_damage_numbers") and not manager.show_damage_numbers():
		return
	if amount < FeedbackConfig.DAMAGE_NUMBER_MIN:
		return
	if fx_root == null:
		return
	# Perf gate: keep critical/elite feedback, thin low-value spam under heavy load.
	if _adaptive_perf_scale < 0.72 and not is_crit and not is_kill and not is_elite:
		if target_max > 0.0 and amount < target_max * 0.16:
			return
		if randf() < 0.4:
			return
	if not _consume_damage_number_budget():
		return

	var health_ratio = 0.0
	if target_max > 0.0:
		health_ratio = clamp(amount / target_max, 0.0, 1.0)
	var font_px = _damage_number_font_px(health_ratio, is_crit, is_kill, is_elite)

	var label = Label.new()
	label.text = str(int(round(amount)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	var text_color = _apply_damage_label_style(label, font_px, is_crit, is_kill, is_elite, damage_type)
	label.size = label.get_minimum_size()
	label.position = -label.size * 0.5
	var badge_key = _damage_badge_key(is_crit, is_kill, is_elite, damage_type)
	_apply_damage_label_texture_style(label, text_color)

	var container = Node2D.new()
	var jitter = Vector2(
		randf_range(-FeedbackConfig.DAMAGE_NUMBER_JITTER_X, FeedbackConfig.DAMAGE_NUMBER_JITTER_X),
		randf_range(-FeedbackConfig.DAMAGE_NUMBER_JITTER_Y, FeedbackConfig.DAMAGE_NUMBER_JITTER_Y)
	)
	container.position = _declump_damage_position(position + jitter, _damage_spot_radius_for(label))
	container.z_index = 30
	fx_root.add_child(container)
	_add_damage_badge(container, label, badge_key)
	# Drop shadow behind the number for separation from neighbors + bright tiles.
	# Skipped under heavy load to respect the FX budget.
	var shadow: Label = null
	if _adaptive_perf_scale >= 0.72:
		shadow = _make_damage_shadow(label, font_px)
		if shadow != null:
			container.add_child(shadow)
	container.add_child(label)

	# Size now lives in the font size, so the container only carries the pop.
	var base_scale = 1.0

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
	if shadow != null:
		tween.parallel().tween_property(shadow, "modulate", Color(1.0, 1.0, 1.0, 0.0), lifetime)
	if is_crit:
		tween.parallel().tween_property(container, "rotation", 0.0, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(container.queue_free)

func _damage_number_font_px(health_ratio: float, is_crit: bool, is_kill: bool, is_elite: bool) -> int:
	var px = lerp(FeedbackConfig.DAMAGE_NUMBER_PX_MIN, FeedbackConfig.DAMAGE_NUMBER_PX_MAX, health_ratio)
	if is_crit:
		px += FeedbackConfig.DAMAGE_NUMBER_PX_CRIT_BONUS
	if is_kill:
		px += FeedbackConfig.DAMAGE_NUMBER_PX_KILL_BONUS
	if is_elite and is_kill:
		px += FeedbackConfig.DAMAGE_NUMBER_PX_ELITE_KILL_BONUS
	# Quantise so a handful of font sizes cover every hit instead of hundreds of
	# one-off rasterisations bloating the font atlas.
	var step = float(FeedbackConfig.DAMAGE_NUMBER_PX_STEP)
	px = round(px / step) * step
	return int(clamp(px, FeedbackConfig.DAMAGE_NUMBER_PX_CLAMP_MIN, FeedbackConfig.DAMAGE_NUMBER_PX_CLAMP_MAX))

func _make_damage_shadow(main_label: Label, font_px: int) -> Label:
	if main_label == null:
		return null
	var shadow := Label.new()
	shadow.text = main_label.text
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.z_index = 29
	if _damage_font != null:
		shadow.add_theme_font_override("font", _damage_font)
	shadow.add_theme_font_size_override("font_size", font_px)
	shadow.add_theme_color_override("font_color", FeedbackConfig.DAMAGE_NUMBER_SHADOW_COLOR)
	shadow.add_theme_color_override("font_outline_color", FeedbackConfig.DAMAGE_NUMBER_SHADOW_COLOR)
	# The shadow carries its own outline so it reads as a dilated dark backing
	# rather than a thin duplicate hiding behind the glyph.
	shadow.add_theme_constant_override("outline_size", maxi(2, int(round(float(font_px) * FeedbackConfig.DAMAGE_NUMBER_SHADOW_OUTLINE_RATIO))))
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.size = main_label.size
	var drop = maxf(2.0, float(font_px) * FeedbackConfig.DAMAGE_NUMBER_SHADOW_OFFSET_RATIO)
	shadow.position = main_label.position + Vector2(drop * 0.45, drop)
	return shadow

func _declump_damage_position(base: Vector2, own_radius: float) -> Vector2:
	# Push a new number off any number spawned in the last fraction of a second
	# nearby, so swarm damage reads as separate values instead of one smear.
	var count = _damage_spot_pos.size()
	if count == 0:
		_seed_damage_spots()
		count = _damage_spot_pos.size()
	var now_ms = Time.get_ticks_msec()
	var pos = base
	# Two relaxation passes: a single pass can push a number off one neighbour and
	# straight onto another it had already cleared.
	for _pass in range(2):
		var moved = false
		for i in range(count):
			if now_ms - _damage_spot_ms[i] > FeedbackConfig.DAMAGE_NUMBER_DECLUMP_WINDOW_MS:
				continue
			var gap = maxf(own_radius + _damage_spot_radius[i], FeedbackConfig.DAMAGE_NUMBER_DECLUMP_MIN_GAP)
			var offset = pos - _damage_spot_pos[i]
			var dist_sq = offset.length_squared()
			if dist_sq >= gap * gap:
				continue
			var dir = offset.normalized() if dist_sq > 0.01 else Vector2.from_angle(randf() * TAU)
			pos += dir * (gap - sqrt(dist_sq))
			moved = true
		if not moved:
			break
	# Cap the push so a number never drifts away from the enemy that took the hit.
	var total = pos - base
	if total.length() > FeedbackConfig.DAMAGE_NUMBER_DECLUMP_MAX_PUSH:
		pos = base + total.normalized() * FeedbackConfig.DAMAGE_NUMBER_DECLUMP_MAX_PUSH
	_damage_spot_pos[_damage_spot_head] = pos
	_damage_spot_radius[_damage_spot_head] = own_radius
	_damage_spot_ms[_damage_spot_head] = now_ms
	_damage_spot_head = (_damage_spot_head + 1) % count
	return pos

func _damage_spot_radius_for(label: Label) -> float:
	if label == null:
		return FeedbackConfig.DAMAGE_NUMBER_DECLUMP_MIN_GAP * 0.5
	return maxf(label.size.x, label.size.y) * 0.5 + FeedbackConfig.DAMAGE_NUMBER_DECLUMP_PAD

func _seed_damage_spots() -> void:
	var samples = FeedbackConfig.DAMAGE_NUMBER_DECLUMP_SAMPLES
	_damage_spot_pos.resize(samples)
	_damage_spot_radius.resize(samples)
	_damage_spot_ms.resize(samples)
	_damage_spot_head = 0
	for i in range(samples):
		_damage_spot_pos[i] = Vector2.ZERO
		_damage_spot_radius[i] = 0.0
		# Far enough in the past that a fresh buffer never repels the first spawns.
		_damage_spot_ms[i] = -FeedbackConfig.DAMAGE_NUMBER_DECLUMP_WINDOW_MS * 4

func _vary_damage_color(base: Color) -> Color:
	# Two hits for the same amount should never render the same colour - the
	# variation is what lets the eye separate stacked numbers.
	var h = base.h
	var s = base.s
	var v = base.v
	if s < 0.12:
		# Near-white (normal damage): give it a faint random tint instead of a
		# hue shift, which does nothing on an unsaturated colour.
		h = randf()
		s = randf_range(FeedbackConfig.DAMAGE_NUMBER_NEUTRAL_TINT_MIN, FeedbackConfig.DAMAGE_NUMBER_NEUTRAL_TINT_MAX)
	else:
		h = fposmod(h + randf_range(-FeedbackConfig.DAMAGE_NUMBER_HUE_JITTER, FeedbackConfig.DAMAGE_NUMBER_HUE_JITTER), 1.0)
		s = clampf(s + randf_range(-FeedbackConfig.DAMAGE_NUMBER_SAT_JITTER, FeedbackConfig.DAMAGE_NUMBER_SAT_JITTER), 0.0, 1.0)
	v = clampf(v + randf_range(-FeedbackConfig.DAMAGE_NUMBER_VAL_JITTER, FeedbackConfig.DAMAGE_NUMBER_VAL_JITTER), 0.35, 1.0)
	return Color.from_hsv(h, s, v, base.a)

func _print_startup_banner() -> void:
	"""One line stating whether the run actually began. A game that starts wrong
	looks identical to a game that started fine but is showing an old build, and
	without this there was nothing to tell them apart from a screenshot."""
	var panel_shown := false
	if ui != null:
		var panel = ui.get_node_or_null("HUD/StartPanel")
		if panel != null:
			panel_shown = (panel as CanvasItem).is_visible_in_tree()
	print("[startup] scene=%s started=%s resources=%d start_panel_visible=%s" % [
		scene_file_path, str(game_started), resources, str(panel_shown)
	])

func _setup_screen_grade() -> void:
	"""Full-screen grade, on its own canvas layer between the world and the HUD.
	Layer 1 here, UI moved to layer 2 - the grade must seat the scene without
	dimming the numbers the player reads off the interface."""
	if _screen_grade != null and is_instance_valid(_screen_grade):
		return
	_screen_grade = ScreenGrade.new()
	_screen_grade.name = "ScreenGrade"
	add_child(_screen_grade)

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

func _prepare_damage_badges() -> void:
	_damage_badge_cache.clear()
	for key in DAMAGE_BADGE_PATHS.keys():
		var path = str(DAMAGE_BADGE_PATHS[key])
		var tex = _load_damage_badge(path)
		if tex != null:
			_damage_badge_cache[key] = tex
	_seed_damage_spots()
	if _damage_label_shader == null:
		_damage_label_shader = Shader.new()
		_damage_label_shader.code = DAMAGE_LABEL_SHADER_CODE

func _load_damage_badge(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var raw = load(path)
	if not (raw is Texture2D):
		return null
	var src = raw as Texture2D
	var img = src.get_image()
	if img == null:
		return src
	img.convert(Image.FORMAT_RGBA8)
	var w = img.get_width()
	var h = img.get_height()
	for y in range(h):
		for x in range(w):
			var c = img.get_pixel(x, y)
			var max_c = max(c.r, max(c.g, c.b))
			var min_c = min(c.r, min(c.g, c.b))
			var chroma = max_c - min_c
			if chroma < 0.11 and max_c > 0.18 and max_c < 0.96:
				c.a = 0.0
			else:
				c.a = max(c.a, clampf((chroma - 0.06) / 0.45, 0.0, 1.0))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _damage_badge_key(is_crit: bool, is_kill: bool, is_elite: bool, damage_type: String) -> String:
	var large = is_crit or is_kill or (is_elite and is_kill)
	if is_crit:
		return "crit_large" if large else "crit_small"
	var lower_type = damage_type.to_lower()
	if lower_type in ["dot", "poison", "acid", "bleed"]:
		return "dot_large" if large else "dot_small"
	return "normal_large" if large else "normal_small"

func _apply_damage_label_texture_style(label: Label, base_color: Color) -> void:
	if label == null or _damage_label_shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = _damage_label_shader
	mat.set_shader_parameter("top_color", base_color.lightened(FeedbackConfig.DAMAGE_NUMBER_GRADIENT_TOP))
	mat.set_shader_parameter("bottom_color", base_color.darkened(FeedbackConfig.DAMAGE_NUMBER_GRADIENT_BOTTOM))
	label.material = mat
	label.self_modulate = Color.WHITE
	# The shader keys off the incoming vertex colour to tell glyph from outline,
	# so the glyph must be drawn white and the outline near-black.
	label.add_theme_color_override("font_color", Color.WHITE)

func _add_damage_badge(container: Node2D, label: Label, key: String) -> void:
	if container == null or label == null:
		return
	var raw_tex = _damage_badge_cache.get(key, null)
	if not (raw_tex is Texture2D):
		return
	var tex = raw_tex as Texture2D
	var sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var large = key.ends_with("_large")
	var base_width = max(label.size.x * 1.45, 58.0 if large else 42.0)
	sprite.scale = Vector2.ONE * (base_width / float(max(1, tex.get_width())))
	# Keep hook active but hide placeholder badge textures ("888" art).
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.z_index = 29
	container.add_child(sprite)

func _apply_damage_label_style(label: Label, font_px: int, is_crit: bool, is_kill: bool, is_elite: bool, damage_type: String) -> Color:
	if label == null:
		return Color.WHITE
	if _damage_font != null:
		label.add_theme_font_override("font", _damage_font)
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_outline_color", FeedbackConfig.DAMAGE_NUMBER_OUTLINE_COLOR)
	# Scale the outline with the glyph: a fixed 2px border vanishes on a 40px
	# number, which is exactly where separation matters most.
	var outline = int(round(float(font_px) * FeedbackConfig.DAMAGE_NUMBER_OUTLINE_RATIO))
	outline = clampi(outline, FeedbackConfig.DAMAGE_NUMBER_OUTLINE_MIN, FeedbackConfig.DAMAGE_NUMBER_OUTLINE_MAX)
	label.add_theme_constant_override("outline_size", outline)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var color = FeedbackConfig.DAMAGE_TYPE_COLORS.get(damage_type, FeedbackConfig.DAMAGE_COLOR_NORMAL)
	if is_kill:
		color = FeedbackConfig.DAMAGE_COLOR_KILL
	if is_crit:
		color = FeedbackConfig.DAMAGE_COLOR_CRIT
	if is_elite and is_kill:
		color = FeedbackConfig.DAMAGE_COLOR_ELITE_KILL
	color = _vary_damage_color(color)
	label.add_theme_color_override("font_color", color)
	return color

func _consume_damage_number_budget() -> bool:
	var now_ms = Time.get_ticks_msec()
	if now_ms - _damage_number_window_ms > 1000:
		_damage_number_window_ms = now_ms
		_damage_number_budget = _get_damage_budget_per_sec()
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

func add_resources(amount: int, owner_id: int = 0) ->void:
	var applied = amount
	if amount > 0:
		applied = max(1, int(round(float(amount) * RESOURCE_GAIN_MULT)))
	if is_solo():
		resources += applied
		if applied > 0:
			_currency_earned += applied
		return
	# FFA: credit the owner's ledger (default = local player).
	if owner_id == 0:
		owner_id = _local_econ_id()
	var e: Dictionary = _econ_for(owner_id)
	e["resources"] = int(e["resources"]) + applied
	if applied > 0:
		e["currency_earned"] = int(e["currency_earned"]) + applied
	_on_econ_changed(owner_id)

func on_treasure_opened(owner_id: int = 0) ->void:
	if is_solo():
		_treasures_opened += 1
		return
	if owner_id == 0:
		owner_id = _local_econ_id()
	var e: Dictionary = _econ_for(owner_id)
	e["treasures"] = int(e["treasures"]) + 1
	_on_econ_changed(owner_id)

func add_essence(amount: int, owner_id: int = 0) ->void:
	var applied = amount
	if amount > 0 and meta_essence_mult != 1.0:
		applied = max(1, int(round(float(amount) * meta_essence_mult)))
	if is_solo():
		essence += applied
	else:
		if owner_id == 0:
			owner_id = _local_econ_id()
		var e: Dictionary = _econ_for(owner_id)
		e["essence"] = int(e["essence"]) + applied
		_on_econ_changed(owner_id)
	_update_ui()
	if not _essence_tip_shown and ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("ESSENCE collected! U = tower infusion (500g + 1). T3 towers can EVOLVE.", Color(0.8, 0.4, 1.0), 18, 5.0)
		_essence_tip_shown = true

func add_xp(amount: int) -> void:
	var applied = amount
	if amount > 0:
		applied = max(1, int(round(float(amount) * XP_GAIN_MULT)))
	xp += applied
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

func can_afford(cost: int, owner_id: int = 0) ->bool:
	if is_solo():
		return resources >= cost
	if owner_id == 0:
		owner_id = _local_econ_id()
	return int(_econ_for(owner_id)["resources"]) >= cost

func spend(cost: int, owner_id: int = 0) ->bool:
	if is_solo():
		if resources < cost:
			return false
		resources -= cost
		_update_ui()
		return true
	if owner_id == 0:
		owner_id = _local_econ_id()
	var e: Dictionary = _econ_for(owner_id)
	if int(e["resources"]) < cost:
		return false
	e["resources"] = int(e["resources"]) - cost
	_on_econ_changed(owner_id)
	return true

func can_afford_essence(cost: int, owner_id: int = 0) ->bool:
	if is_solo():
		return essence >= cost
	if owner_id == 0:
		owner_id = _local_econ_id()
	return int(_econ_for(owner_id)["essence"]) >= cost

func spend_essence(cost: int, owner_id: int = 0) ->bool:
	if cost <= 0:
		return true
	if is_solo():
		if essence < cost:
			return false
		essence -= cost
		_update_ui()
		return true
	if owner_id == 0:
		owner_id = _local_econ_id()
	var e: Dictionary = _econ_for(owner_id)
	if int(e["essence"]) < cost:
		return false
	e["essence"] = int(e["essence"]) - cost
	_on_econ_changed(owner_id)
	return true

func _open_tech_menu(is_reroll: bool = false) -> void:
	var previous_ids: Array = []
	if is_reroll:
		for choice in tech_choices:
			previous_ids.append(str(choice.get("id", "")))
	else:
		_tech_rerolls_this_pick = 0
	tech_choices.clear()
	var available: Array = _get_available_tech_ids()
	if available.is_empty():
		pending_picks = 0
		tech_open = false
		if ui != null and ui.has_method("hide_tech"):
			ui.hide_tech()
		_set_pause_allowed(_can_pause_game())
		return
	var floor_rarity = _target_draft_floor_rarity()
	var forced_category_for_roll = _tech_forced_category_once
	_tech_forced_category_once = ""
	var locked_id_for_roll = ""
	if not is_reroll and _tech_locked_id != "":
		locked_id_for_roll = _tech_locked_id
		_tech_locked_id = ""
		_tech_locked_name = ""
	var picks: Array = _build_tech_pick_ids(available, floor_rarity, locked_id_for_roll, forced_category_for_roll)
	if is_reroll and available.size() > picks.size() and _same_choice_ids(previous_ids, picks):
		var attempts = 0
		while attempts < 3 and _same_choice_ids(previous_ids, picks):
			picks = _build_tech_pick_ids(available, floor_rarity, "", forced_category_for_roll)
			attempts += 1
	if picks.is_empty():
		pending_picks = 0
		tech_open = false
		if ui != null and ui.has_method("hide_tech"):
			ui.hide_tech()
		_set_pause_allowed(_can_pause_game())
		return
	_track_draft_offer(picks, floor_rarity)
	for id in picks:
		var def: Dictionary = tech_defs.get(id, {})
		tech_choices.append({
			"id": id,
			"name": def.get("name", id),
			"desc": def.get("desc", ""),
			"icon": def.get("icon", ""),
			"rarity": def.get("rarity", "common"),
			"category": def.get("category", "engineer"),
			"level": int(tech_levels.get(id, 0)),
			"max_level": int(tech_defs.get(id, {}).get("max", 1)),
			"infusable": false
		})
	tech_open = true
	_tech_cursor = -1
	_tech_nav_cooldown = 0.0
	_set_pause_allowed(false)
	if ui.has_method("show_tech"):
		ui.show_tech(tech_choices, essence, _get_tech_reroll_cost(), _build_tech_ui_meta(forced_category_for_roll))
	_apply_base_time_scale()

func _choose_tech(index: int, infused: bool = false) -> void:
	if index < 0 or index >= tech_choices.size():
		return
	var choice: Dictionary = tech_choices[index]
	var id: String = str(choice.get("id", ""))
	if id == "":
		return
	if infused:
		if not _can_infuse_tech(id):
			if ui != null and ui.has_method("show_announcement"):
				ui.show_announcement("Infuse requires a multi-rank upgrade", Color(0.9, 0.6, 0.35), 18, 1.3)
			return
		if essence < TECH_INFUSE_COST:
			if ui != null and ui.has_method("show_announcement"):
				ui.show_announcement("Need %d Essence to infuse" % TECH_INFUSE_COST, Color(0.9, 0.45, 1.0), 20, 1.3)
			return
		essence -= TECH_INFUSE_COST
		_ensure_draft_telemetry()
		_draft_telemetry["infuse_count"] = int(_draft_telemetry.get("infuse_count", 0)) + 1
		_draft_telemetry["infuse_essence_spent"] = int(_draft_telemetry.get("infuse_essence_spent", 0)) + TECH_INFUSE_COST
	_track_draft_pick(str(choice.get("rarity", "common")))
	_play_tech_pick_feedback(choice, infused)
	_apply_tech(id)
	if infused and _can_level_tech(id):
		_apply_tech(id)
	tech_open = false
	if ui.has_method("hide_tech"):
		ui.hide_tech()
	pending_picks = max(0, pending_picks - 1)
	if pending_picks > 0:
		_open_tech_menu()
		_update_ui()
		return
	_set_pause_allowed(_can_pause_game())
	_apply_base_time_scale()
	_update_ui()

func _play_tech_pick_feedback(choice: Dictionary, infused: bool) -> void:
	var rarity = str(choice.get("rarity", "common"))
	var name = str(choice.get("name", "Tech"))
	var is_infused = infused
	if ui != null and ui.has_method("show_announcement"):
		var text = ""
		var color = Color(0.85, 0.9, 1.0)
		var size = 20
		var duration = 1.25
		if _rarity_index(rarity) >= _rarity_index("legendary"):
			text = "BREAKTHROUGH: %s" % name
			color = Color(1.0, 0.85, 0.3)
			size = 30
			duration = 1.6
		elif _rarity_index(rarity) >= _rarity_index("epic"):
			text = "EPIC TECH: %s" % name
			color = Color(0.86, 0.45, 1.0)
			size = 26
			duration = 1.45
		elif _rarity_index(rarity) >= _rarity_index("rare"):
			text = "RARE TECH: %s" % name
			color = Color(0.45, 0.7, 1.0)
			size = 22
			duration = 1.25
		if text != "":
			if is_infused:
				text = "INFUSED %s" % text
			ui.show_announcement(text, color, size, duration)
	if _rarity_index(rarity) >= _rarity_index("epic"):
		shake_camera(4.5 if _rarity_index(rarity) >= _rarity_index("legendary") else 3.0, 0.18)
	if _rarity_index(rarity) >= _rarity_index("legendary"):
		trigger_time_accent(0.5, 0.16)
		flash_screen(Color(1.0, 0.85, 0.35, 0.14), 0.16)
	if player != null:
		if _rarity_index(rarity) >= _rarity_index("legendary"):
			spawn_fx("elite_kill", player.global_position)
			spawn_fx("upgrade_burst", player.global_position)
		elif _rarity_index(rarity) >= _rarity_index("epic"):
			spawn_fx("upgrade_burst", player.global_position)
		elif _rarity_index(rarity) >= _rarity_index("rare"):
			spawn_fx("build", player.global_position)

func _apply_tech(id: String) -> void:
	tech_levels[id] = int(tech_levels.get(id, 0)) + 1
	var def: Dictionary = tech_defs.get(id, {})
	if def.has("unlock_build"):
		var build_id = str(def.get("unlock_build", ""))
		unlock_build(build_id)
		if build_manager != null and build_manager.has_method("refresh_controls"):
			build_manager.refresh_controls()
		_refresh_build_palette()
	if id == "essence_cache":
		var essence_gain = 3 + int(int(tech_levels.get(id, 1)) / 2)
		add_essence(essence_gain)
	elif id == "resource_cache":
		var resource_gain = 95 + 40 * int(tech_levels.get(id, 1))
		add_resources(resource_gain)
	elif id == "field_repairs":
		var heal_amount = 14.0 + 10.0 * float(int(tech_levels.get(id, 1)))
		heal_player(heal_amount)
	elif id == "engineer_vitality":
		var level_value = int(tech_levels.get(id, 1))
		tech_max_hp_bonus = min(100.0, ENGINEER_VITALITY_HP_PER_LEVEL * float(level_value))
		_apply_player_max_health_bonuses()
	_refresh_tech_scalars()
	if player != null and player.has_method("apply_gun_tech"):
		player.apply_gun_tech(id, tech_levels[id])
	if ui != null and ui.has_method("update_tech_ledger"):
		ui.update_tech_ledger(tech_levels, tech_defs)

func apply_chest_upgrade(id: String, upgrade: Dictionary = {}) -> void:
	var rarity = upgrade.get("rarity", "common") if not upgrade.is_empty() else "common"
	
	match id:
		# Common upgrades
		"gun_damage":
			chest_damage_bonus += 3.0 if rarity == "common" else (5.0 if rarity == "rare" else 7.0)
			_apply_player_damage_bonuses()
		"tower_range":
			var mult = 1.12 if rarity == "common" else (1.18 if rarity == "rare" else 1.24)
			chest_tower_range_mult = min(3.0, chest_tower_range_mult * mult)
		"speed":
			chest_speed_bonus += 16.0 if rarity == "common" else (24.0 if rarity == "rare" else 34.0)
			if player != null and player.has_method("apply_speed_bonus"):
				player.apply_speed_bonus(chest_speed_bonus)
		"max_hp":
			chest_max_hp_bonus += 18.0 if rarity == "common" else (28.0 if rarity == "rare" else 42.0)
			_apply_player_max_health_bonuses()
		"build_cost":
			var cost_mult = 0.90 if rarity == "common" else (0.85 if rarity == "rare" else 0.78)
			build_cost_mult = max(0.45, build_cost_mult * cost_mult)
		"reload_speed":
			reload_speed_mult *= 0.86 if rarity == "common" else (0.80 if rarity == "rare" else 0.74)
		
		# Rare upgrades
		"crit_chance":
			crit_chance_bonus += 0.08
		"crit_damage":
			crit_damage_mult += 0.25
		"pierce":
			pierce_bonus += 1
		"cooldown":
			cooldown_mult *= 0.84 if rarity == "rare" else 0.76
		"pickup_range":
			pickup_range_mult *= 1.45
		"tower_core_damage":
			chest_tower_damage_bonus += 8.0 if rarity == "rare" else 12.0
		"tower_targeting":
			var rate_mult = 1.18 if rarity == "rare" else 1.25
			chest_tower_rate_mult = min(4.0, chest_tower_rate_mult * rate_mult)
			chest_tower_chain_bonus += 1
		
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
		"tower_barrage":
			chest_tower_rate_mult = min(4.4, chest_tower_rate_mult * 1.30)
			chest_tower_damage_bonus += 8.0
			chest_tower_aoe_mult = min(3.0, chest_tower_aoe_mult * 1.18)
		
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
		"orbital_matrix":
			chest_tower_rate_mult = min(5.0, chest_tower_rate_mult * 1.55)
			chest_tower_damage_bonus += 20.0
			chest_tower_range_mult = min(3.6, chest_tower_range_mult * 1.35)
			chest_tower_aoe_mult = min(3.4, chest_tower_aoe_mult * 1.25)
			chest_tower_chain_bonus += 2

		# Mythic
		"golden_coco":
			spawn_golden_coco()

	if player != null:
		match rarity:
			"diamond":
				spawn_fx("elite_kill", player.global_position)
				spawn_fx("upgrade_burst", player.global_position)
			"legendary", "mythic":
				spawn_fx("upgrade_burst", player.global_position)
				spawn_fx("fire_burst", player.global_position)
			"epic":
				spawn_fx("fire_burst", player.global_position)
			"rare":
				spawn_fx("chain_hit", player.global_position)
			_:
				spawn_fx("hit", player.global_position)
	
	_refresh_tech_scalars()
	_update_ui()
	# No stat-name popup here. The chest reveal already presents the haul as
	# named prize cards; this pushed a second list of raw upgrade ids ("+ Speed",
	# "+ Build Cost") into a panel over the base that outlived the reveal by its
	# own 2.5s timer, so the leftover was what stayed on screen.

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
	tower_rate_mult = (1.0 + rate_bonus) * _tech_base_rate_mult * chest_tower_rate_mult
	_apply_player_damage_bonuses()

func _apply_player_damage_bonuses() -> void:
	if player != null and player.has_method("apply_global_bonuses"):
		player.apply_global_bonuses(player_damage_bonus + chest_damage_bonus)

func _apply_player_max_health_bonuses() -> void:
	if player != null and player.has_method("apply_max_health_bonus"):
		player.apply_max_health_bonus(chest_max_hp_bonus + tech_max_hp_bonus)

func get_tower_rate_mult() -> float:
	return tower_rate_mult * keystone_rate_mult

func get_tower_damage_bonus() -> float:
	return tower_damage_bonus

func get_tower_damage_mult() -> float:
	return meta_tower_damage_mult * keystone_damage_mult

func get_tower_range_mult() -> float:
	return tower_range_mult * chest_tower_range_mult * keystone_range_mult

func get_tower_chain_bonus() -> int:
	return tower_chain_bonus + keystone_chain_bonus

func get_tower_aoe_mult() -> float:
	return tower_aoe_mult * keystone_aoe_mult

func get_build_cost_mult() -> float:
	var mult = build_cost_mult
	if elapsed > BUILD_COST_TIME_PRESSURE_START:
		var span = max(1.0, BUILD_COST_TIME_PRESSURE_END - BUILD_COST_TIME_PRESSURE_START)
		var t = clampf((elapsed - BUILD_COST_TIME_PRESSURE_START) / span, 0.0, 1.0)
		mult *= lerpf(1.0, BUILD_COST_TIME_PRESSURE_MAX, t)
	return mult

func _update_controls_hint() -> void:
	# Short orientation hint at the start of a run, then gone for good. It used
	# to come back every time build mode was entered, which meant it sat across
	# the screen for most of a run and competed with the objective banner. The
	# full key list now lives in the pause menu.
	if ui == null or not ui.has_method("set_controls_visible"):
		return
	if not _controls_hint_faded and elapsed >= CONTROLS_HINT_FADE_TIME:
		# Don't fade while a modal panel is open (player may be reading).
		if tech_open or chest_modal_open:
			return
		ui.set_controls_visible(false)
		_controls_hint_faded = true

func _update_income_decay_telegraph() -> void:
	# One-shot warnings as passive generator yield decays, nudging expansion.
	var mult = get_generator_income_mult()
	if _income_decay_notice_stage < 1 and mult < 0.95:
		_income_decay_notice_stage = 1
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("RESOURCE YIELD WANING", Color(1.0, 0.75, 0.25), 36, 2.6)
	elif _income_decay_notice_stage < 2 and mult < 0.85:
		_income_decay_notice_stage = 2
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("RESOURCE YIELD LOW — EXPAND", Color(1.0, 0.55, 0.2), 38, 3.0)

func get_generator_income_mult() -> float:
	var active_count = active_generators.size()
	var count_mult = 1.0
	if active_count > GENERATOR_INCOME_SOFT_CAP:
		var over = float(active_count - GENERATOR_INCOME_SOFT_CAP)
		count_mult = 1.0 / (1.0 + over * 0.2)
		count_mult = max(count_mult, GENERATOR_INCOME_MIN_MULT)
	var time_mult = 1.0
	if elapsed > GENERATOR_INCOME_DECAY_START:
		var span = max(1.0, GENERATOR_INCOME_DECAY_END - GENERATOR_INCOME_DECAY_START)
		var t = clampf((elapsed - GENERATOR_INCOME_DECAY_START) / span, 0.0, 1.0)
		time_mult = lerpf(1.0, GENERATOR_INCOME_LATE_MIN, t)
	return count_mult * time_mult

func get_adaptive_perf_scale() -> float:
	return _adaptive_perf_scale

func get_optional_fx_quality_cap() -> float:
	return _optional_fx_quality_cap

func get_runtime_target_fps() -> float:
	return _runtime_target_fps

func get_runtime_perf_snapshot() -> Dictionary:
	var quality = "high"
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_quality"):
		quality = str(manager.get_quality()).to_lower()
	return {
		"fps": int(Engine.get_frames_per_second()),
		"quality": quality,
		"adaptive_scale": _adaptive_perf_scale,
		"max_particles": max_particles,
		"max_projectiles": max_projectiles,
		"enemy_count": enemies_root.get_child_count() if enemies_root != null else 0,
		"tower_count": buildings_root.get_child_count() if buildings_root != null else 0,
	}

func get_pickup_range_mult() -> float:
	return pickup_range_mult

func get_player_missing_health_ratio() -> float:
	if player == null:
		return 0.0
	var max_hp = 0.0
	if "max_health" in player:
		max_hp = max(1.0, float(player.max_health))
	else:
		return 0.0
	var hp = max_hp
	if "health" in player:
		hp = float(player.health)
	return clampf((max_hp - hp) / max_hp, 0.0, 1.0)

func _heal_drop_urgency(missing_ratio: float) -> float:
	var t = clampf((missing_ratio - 0.10) / 0.75, 0.0, 1.0)
	# Smoothstep response: low at healthy HP, ramps quickly near danger.
	return t * t * (3.0 - 2.0 * t)

func get_heal_drop_chance(is_elite: bool = false, is_siege: bool = false, source: String = "enemy", is_chest: bool = false) -> float:
	var base_chance = heal_drop_chance_enemy
	if source == "breakable":
		base_chance = heal_drop_chance_breakable
	if is_siege:
		base_chance = heal_drop_chance_siege
	if is_elite:
		base_chance = heal_drop_chance_elite
	if is_chest:
		base_chance = heal_drop_chance_chest
	var missing_ratio = get_player_missing_health_ratio()
	var urgency = _heal_drop_urgency(missing_ratio)
	var bonus = heal_drop_chance_missing_health_bonus
	if source == "breakable":
		bonus *= 0.85
	if is_chest:
		bonus *= 1.15
	var chance = base_chance + bonus * urgency
	# Avoid excessive life drop noise when nearly full HP.
	if missing_ratio < 0.05:
		chance *= 0.55
	return clampf(chance, 0.01, 0.85)

func should_spawn_heal_drop(is_elite: bool = false, is_siege: bool = false, source: String = "enemy", is_chest: bool = false) -> bool:
	return randf() < get_heal_drop_chance(is_elite, is_siege, source, is_chest)

func get_heal_drop_amount(is_elite: bool = false, is_siege: bool = false, source: String = "enemy", is_chest: bool = false) -> int:
	var base_pct = heal_drop_pct_enemy
	var min_amount = 4
	var max_amount = 20
	if source == "breakable":
		base_pct = heal_drop_pct_breakable
		min_amount = 6
		max_amount = 28
	if is_siege:
		base_pct = heal_drop_pct_siege
		min_amount = 7
		max_amount = 26
	if is_elite:
		base_pct = heal_drop_pct_elite
		min_amount = 10
		max_amount = 34
	if is_chest:
		base_pct = heal_drop_pct_chest
		min_amount = 12
		max_amount = 40
	var target_max_hp = 100.0
	if player != null and "max_health" in player:
		target_max_hp = max(40.0, float(player.max_health))
	var urgency = _heal_drop_urgency(get_player_missing_health_ratio())
	var amount = int(round(target_max_hp * (base_pct + heal_drop_pct_missing_health_bonus * urgency)))
	return clampi(amount, min_amount, max_amount)

func get_enemy_health_mult() -> float:
	var ramp_elapsed = max(elapsed, 0.0) * run_ramp_speed_mult
	var growth = 1.0 + (ramp_elapsed / 30.0) * ENEMY_HEALTH_GROWTH_PER_30S
	var mult = ENEMY_HEALTH_BASE_MULT * growth
	if ramp_elapsed < EARLY_GAME_HORDE_RAMP_TIME:
		var t = clampf(ramp_elapsed / EARLY_GAME_HORDE_RAMP_TIME, 0.0, 1.0)
		mult *= lerpf(EARLY_GAME_ENEMY_HEALTH_GRACE_MIN, 1.0, t)
	return mult * extraction_milestone_mult()

func get_enemy_speed_mult() -> float:
	"""Movement-speed companion to get_enemy_health_mult().

	Only the extraction milestones live here for now; the rest of the speed
	curve is per-enemy in `enemy.setup()`. Kept as its own accessor so a caller
	cannot pick up the health step and miss the speed step.
	"""
	return extraction_milestone_mult()

func extraction_milestone_mult() -> float:
	"""Compounded step multiplier for how far the extraction bar has filled.

	Read at spawn, not applied retroactively: healing a live enemy because a bar
	ticked over would be indefensible, and the horde turns over fast enough that
	the field is the new tier within seconds of a crossing. OVERRUN sits at
	progress 1.0, so every step is live once the bar is full.
	"""
	if extraction_phase == ExtractionPhase.SCOUT:
		return 1.0
	var mult := 1.0
	for entry in EXTRACTION_MILESTONES:
		if extraction_progress >= float(entry["at"]):
			mult *= float(entry["step"])
	return mult

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
	var shake_strength = strength
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_screenshake_multiplier"):
		shake_strength *= float(manager.get_screenshake_multiplier())
	if shake_strength <= 0.01:
		return
	# Use dynamic camera controller shake
	if camera.has_method("shake"):
		camera.shake(shake_strength, duration)

func kick_camera_zoom(amount: float = 0.06) -> void:
	if camera != null and camera.has_method("kick_zoom"):
		camera.kick_zoom(amount)

func _refresh_build_palette() -> void:
	if ui == null:
		return
	var active_id = ""
	if build_manager != null and "current_id" in build_manager:
		active_id = build_manager.current_id
	if ui.has_method("update_palette"):
		ui.update_palette(unlocked_builds, active_id)

func heal_player(amount: float, owner_id: int = 0) -> void:
	# FFA: heal the player who actually grabbed the pickup, not always the local
	# one. owner_id == 0 means "local/solo" so every existing solo call is unchanged.
	var target: Node = player
	if not is_solo():
		if owner_id == 0:
			owner_id = _local_econ_id()
		if players.has(owner_id):
			target = players[owner_id]
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("heal"):
		target.heal(amount)
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
	set_build_focus(false, "")
	_force_close_menus()
	game_over = true
	Engine.time_scale = 1.0
	_set_pause_allowed(false)
	
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

func _compile_run_stats() -> Dictionary:
	if wave_manager != null and wave_manager.has_method("get_current_wave"):
		_wave_reached = wave_manager.get_current_wave()
	return {
		"time_survived": elapsed,
		"enemies_killed": _enemy_kill_count,
		"damage_dealt": _total_damage_dealt,
		"towers_built": _towers_built,
		"generators_lost": _generators_lost,
		"best_streak": _best_streak,
		"wave_reached": _wave_reached,
		"treasures_opened": _treasures_opened,
		"currency_earned": _currency_earned
	}

func _trigger_victory() -> void:
	"""Final boss defeated: end the run as a WIN (endless continues optionally)."""
	# FFA never wins on a boss kill — the match is decided by the 20-min clock and
	# resource score. Bosses are just shared threats. Keep playing.
	if is_ffa():
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("BOSS DEFEATED", Color(1.0, 0.85, 0.3), 36, 2.4)
		return
	if _run_won:
		return
	_run_won = true
	game_over = true
	Engine.time_scale = 1.0
	set_build_focus(false, "")
	_force_close_menus()
	_set_pause_allowed(false)
	AudioManager.play_one_shot("level_up", player.global_position if player != null else Vector2.ZERO, AudioManager.CRITICAL_PRIORITY)
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("THE ENDBRINGER FALLS", Color(1.0, 0.85, 0.3), 52, 3.5)
	# Unlock the victory milestone (space level) before presenting the screen.
	var meta = _get_meta_progression()
	if meta != null and meta.has_method("mark_victory_unlock"):
		meta.mark_victory_unlock()
	_present_run_end(true)

func _show_game_over_screen() -> void:
	"""Display the game over stats screen (player death path)."""
	_present_run_end(false)

func _present_run_end(won: bool = false) -> void:
	"""Shared run-end presentation for both death (won=false) and victory (won=true)."""
	if game_over_ui == null:
		return

	var stats = _compile_run_stats()

	# Check for new records
	var is_new_record = _check_and_save_record(stats)
	_log_draft_telemetry()

	# Award persistent meta-progression currency (Cores) for this run.
	var cores_earned = 0
	var meta = _get_meta_progression()
	if meta != null and meta.has_method("award_run_cores"):
		cores_earned = meta.award_run_cores(stats, won)

	# Show the run-end UI
	if game_over_ui.has_method("show_game_over"):
		game_over_ui.show_game_over(stats, is_new_record, cores_earned, won)

const FFA_RESULTS_UI_SCRIPT := preload("res://scripts/ffa_results_ui.gd")

func _instantiate_ffa_results_ui() -> void:
	"""Create the FFA end-of-match scoreboard overlay (hidden until match end)."""
	if ffa_results_ui != null and is_instance_valid(ffa_results_ui):
		return
	ffa_results_ui = FFA_RESULTS_UI_SCRIPT.new()
	ffa_results_ui.name = "FFAResultsUI"
	add_child(ffa_results_ui)

const FFA_DEATH_UI_SCRIPT := preload("res://scripts/ffa_death_ui.gd")

func _instantiate_ffa_death_ui() -> void:
	"""Create the local 'you died' spectate overlay (hidden until local death)."""
	if ffa_death_ui != null and is_instance_valid(ffa_death_ui):
		return
	ffa_death_ui = FFA_DEATH_UI_SCRIPT.new()
	ffa_death_ui.name = "FFADeathUI"
	add_child(ffa_death_ui)

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
	if game_over_ui.has_signal("continue_endless_pressed"):
		game_over_ui.continue_endless_pressed.connect(_on_continue_endless)

func _on_try_again() -> void:
	"""Restart the current run"""
	_restart_game()

func _on_continue_endless() -> void:
	"""After victory: resume the same run into endless boss cycling."""
	if game_over_ui != null:
		game_over_ui.hide_game_over()
	game_over = false
	_run_won = false
	# Allow the boss scheduler to resume; the schedule index/cycle and _next_boss_time
	# were already advanced when the final boss spawned, so cycling continues cleanly.
	_final_boss_spawned = false
	_final_boss_active = false
	Engine.time_scale = 1.0
	_set_pause_allowed(true)

func _on_main_menu_pressed() -> void:
	"""Return to the main menu scene"""
	_force_close_menus()
	# Restore time scale before leaving the run scene.
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _handle_game_over_input() -> void:
	"""Handle input during game over screen"""
	# Allow quick restart with Enter/R keys (continue endless after a victory).
	if Input.is_action_just_pressed("start_game"):
		if _run_won:
			_on_continue_endless()
		else:
			_on_try_again()
	if Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("pause"):
		_on_main_menu_pressed()

func _restart_game() -> void:
	"""Restart the game while keeping meta-progress"""
	_force_close_menus()
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

func _reset_run_modifiers() -> void:
	chest_damage_bonus = 0.0
	chest_speed_bonus = 0.0
	chest_max_hp_bonus = 0.0
	tech_max_hp_bonus = 0.0
	chest_tower_range_mult = 1.0
	chest_tower_damage_bonus = 0.0
	chest_tower_rate_mult = 1.0
	chest_tower_chain_bonus = 0
	chest_tower_aoe_mult = 1.0
	tower_chain_bonus = 0
	tower_aoe_mult = 1.0
	build_cost_mult = 1.0
	reload_speed_mult = 1.0
	crit_chance_bonus = 0.0
	crit_damage_mult = 1.0
	pierce_bonus = 0
	cooldown_mult = 1.0
	pickup_range_mult = 1.0
	has_multishot = false
	multishot_count = 0
	has_explosive = false
	explosive_radius = 0.0
	has_chain_lightning = false
	chain_lightning_targets = 0
	has_vampiric = false
	vampiric_percent = 0.0
	has_multishot_split = false
	multishot_split_count = 0
	has_time_dilation = false
	time_dilation_mult = 1.0
	has_phoenix = false
	phoenix_used_this_wave = false
	has_fortress = false
	tower_hp_mult = 1.0
	towers_self_repair = false
	if player != null and player.has_method("clear_run_modifiers"):
		player.clear_run_modifiers()
	elif player != null:
		if player.has_method("apply_speed_bonus"):
			player.apply_speed_bonus(0.0)
		if player.has_method("apply_max_health_bonus"):
			player.apply_max_health_bonus(0.0)

func _reset_game_state() -> void:
	"""Reset all game state for a new run"""
	set_build_focus(false, "")
	_force_close_menus()
	game_over = false
	game_started = false
	elapsed = 0.0
	spawn_accumulator = 0.0
	start_timer = 0.0
	resources = START_RESOURCES
	essence = 0
	xp = 0
	level = 1
	xp_next = 12
	pending_picks = 0
	tech_open = false
	chest_modal_open = false
	_chest_modal_depth = 0
	tech_choices.clear()
	tech_levels.clear()
	_unlock_core_builds()
	_reset_progression_state()
	_reset_run_modifiers()
	_refresh_tech_scalars()
	if ui != null and ui.has_method("hide_tech"):
		ui.hide_tech()
	if ui != null and ui.has_method("set_chest_blackout"):
		ui.set_chest_blackout(false)
	if build_manager != null and build_manager.has_method("refresh_controls"):
		build_manager.refresh_controls()
	_refresh_build_palette()
	
	# Clear enemies
	for enemy in enemies_root.get_children():
		enemy.queue_free()
	cached_enemies.clear()
	
	# Clear projectiles
	for proj in projectiles_root.get_children():
		proj.queue_free()
	
	# Clear pickups
	for pickup in pickups_root.get_children():
		pickup.queue_free()

	# Clear companions. They persist for a whole run by design, so a restart is
	# the only thing that removes them -- miss this and a fresh run starts with
	# every coco the previous runs ever pulled.
	for c in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c):
			c.queue_free()
	
	# Clear allies
	if allies_root != null:
		for ally in allies_root.get_children():
			ally.queue_free()

	# Clear buildings. Without this a replay inherited the previous run's whole
	# base - towers, walls and the extractor all still standing.
	if buildings_root != null:
		for building in buildings_root.get_children():
			building.queue_free()
	active_generators.clear()
	generators_destroyed = 0

	# Reset extraction objective back to the placement phase.
	extraction_phase = ExtractionPhase.SCOUT
	extractor = null
	extractor_placed_at = -1.0
	extraction_progress = 0.0
	_extraction_milestone_index = 0
	extractor_sealed = false
	_breach_confirm_timer = 0.0
	_breach_announced = false
	_extraction_auto_placed = false
	_extraction_warned_30s = false
	_extraction_warned_10s = false
	if ui != null and ui.has_method("update_objective"):
		ui.update_objective(ExtractionPhase.SCOUT, EXTRACTION_PLACEMENT_WINDOW, 0.0)

	# Boss cycle state
	_active_boss = null
	_final_boss_active = false

	# Buildings just vanished, so any cached pathing is stale.
	mark_flow_field_dirty()

	# Reset stats
	_reset_run_stats()
	
	# Reset wave manager
	if wave_manager != null and wave_manager.has_method("reset"):
		wave_manager.reset()

	_set_pause_allowed(false)
	Engine.time_scale = 1.0

func _force_close_menus() -> void:
	get_tree().paused = false
	chest_modal_open = false
	_chest_modal_depth = 0
	if settings_menu != null and is_instance_valid(settings_menu):
		settings_menu.visible = false
	if pause_menu != null and is_instance_valid(pause_menu):
		if pause_menu.has_method("is_paused") and pause_menu.is_paused():
			pause_menu.unpause()
		else:
			pause_menu.visible = false
	if ui != null and ui.has_method("set_chest_blackout"):
		ui.set_chest_blackout(false)

func _reset_run_stats() -> void:
	"""Reset stats for a new run"""
	_enemy_kill_count = 0
	_total_damage_dealt = 0.0
	_towers_built = 0
	_generators_lost = 0
	_current_streak = 0
	_best_streak = 0
	_wave_reached = 1
	_treasures_opened = 0
	_currency_earned = 0
	_next_chest_time = 0.0
	_essence_announce_count = 0
	_essence_announce_timer = 0.0
	_essence_announce_position = Vector2.ZERO
	_last_minute_announcement = -1
	_essence_tip_shown = false
	_final_boss_spawned = false
	_final_boss_active = false
	_run_won = false
	run_threat_mult = 1.0
	run_player_damage_taken_mult = 1.0
	run_ramp_speed_mult = 1.0
	meta_tower_damage_mult = 1.0
	meta_pickup_radius_mult = 1.0
	_income_decay_notice_stage = 0
	_controls_hint_faded = false
	if ui != null and ui.has_method("set_controls_visible"):
		ui.set_controls_visible(true)
	_reset_progression_state()
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
	# Update kill streak HUD
	if ui != null and ui.has_method("update_streak"):
		ui.update_streak(_current_streak)
	# Escalating dopamine milestones: each tier punches harder so streaks feel
	# like a building crescendo rather than a flat counter.
	if _current_streak == 5 or _current_streak == 10 or _current_streak == 25 \
			or _current_streak == 50 or _current_streak == 100:
		_celebrate_streak_milestone(_current_streak)

func _celebrate_streak_milestone(streak: int) -> void:
	"""Escalating flash/shake/slow-mo punch for streak milestones."""
	var color := Color(1.0, 1.0, 0.5, 0.11)
	var shake := 4.0
	var slow := 0.85
	if streak >= 100:
		color = Color(1.0, 0.2, 0.2, 0.22)
		shake = 12.0
		slow = 0.4
	elif streak >= 50:
		color = Color(1.0, 0.35, 0.1, 0.18)
		shake = 9.0
		slow = 0.5
	elif streak >= 25:
		color = Color(1.0, 0.55, 0.1, 0.15)
		shake = 7.0
		slow = 0.6
	elif streak >= 10:
		color = Color(1.0, 0.85, 0.2, 0.13)
		shake = 5.0
		slow = 0.7
	if has_method("flash_screen"):
		flash_screen(color, 0.18)
	if has_method("shake_camera"):
		shake_camera(shake, 0.25)
	# Bigger streaks earn a punchier slow-mo beat.
	if streak >= 25:
		trigger_time_accent(slow, 0.12)
	if ui != null and ui.has_method("update_streak"):
		ui.update_streak(streak)

func reset_kill_streak() -> void:
	"""Call when player takes damage to reset streak"""
	_current_streak = 0
	if ui != null and ui.has_method("update_streak"):
		ui.update_streak(0)

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
# The old first step (2.0) was so tight that the camera's follow/lookahead read
# as the view drifting in and out on its own. Starting at 1.5 keeps enough of
# the field visible that the framing feels stable.
const ZOOM_LEVELS: Array[Vector2] = [Vector2(1.5, 1.5), Vector2(1.25, 1.25), Vector2(1.0, 1.0)]
var _current_zoom_index: int = 0
var _zoom_tween: Tween = null

func _spawn_initial_breakables() -> void:
	for i in range(breakable_target):
		spawn_breakable()

func _spawn_props() -> void:
	if props_root == null:
		return
	# Build the weighted, biome-tagged prop pool (skip any missing assets).
	var pool: Array = []
	var weights: Array = []
	for d in PROP_DEFS:
		var path := str(d.get("path", ""))
		if path != "" and ResourceLoader.exists(path):
			pool.append({"tex": load(path), "size": int(d.get("size", 32)), "biomes": d.get("biomes", [])})
			weights.append(max(1, int(d.get("weight", 1))))
	if pool.is_empty():
		return
	var placed: Array = []  # accepted prop world positions (for spacing checks)
	for i in range(prop_count):
		var def: Dictionary = _weighted_pick_prop(pool, weights)
		var pos = _find_prop_position(placed, prop_min_distance, prop_spawn_radius, prop_min_separation, def.get("biomes", []))
		if pos == null:
			continue
		placed.append(pos)
		var node := _make_grounded_prop(def["tex"], int(def.get("size", 32)))
		node.global_position = pos
		props_root.add_child(node)
	_spawn_clusters(placed)

func _spawn_clusters(placed: Array = []) -> void:
	if props_root == null:
		return
	var textures: Array = []
	for path in CLUSTER_PATHS:
		if ResourceLoader.exists(path):
			textures.append(load(path))
	if textures.is_empty():
		return
	for i in range(cluster_count):
		var tex: Texture2D = textures[randi_range(0, textures.size() - 1)]
		var pos = _find_prop_position(placed, cluster_min_distance, prop_spawn_radius, cluster_min_separation, [])
		if pos == null:
			continue
		placed.append(pos)
		var node := _make_grounded_prop(tex, 96)
		node.global_position = pos
		props_root.add_child(node)

# Rejection sampling: try several candidate positions, accept the first that is
# far enough from already-placed props, outside the spawn pocket, and (when a
# biome filter is given) sitting on an allowed biome. Returns null on failure so
# the caller can simply skip that prop rather than stack it on another.
func _find_prop_position(placed: Array, min_dist: float, max_dist: float, separation: float, allowed_biomes: Array):
	var sep_sq := separation * separation
	for attempt in range(18):
		var angle := randf() * TAU
		# sqrt() biases distance so density is even across the disc, not clumped.
		var distance: float = min_dist + sqrt(randf()) * (max_dist - min_dist)
		var pos := Vector2.RIGHT.rotated(angle) * distance
		if pos.length() < prop_safe_spawn_radius:
			continue
		if not allowed_biomes.is_empty() and ground != null and ground.has_method("get_biome_at"):
			var biome := str(ground.get_biome_at(pos))
			if not allowed_biomes.has(biome):
				continue
		var ok := true
		for p in placed:
			if pos.distance_squared_to(p) < sep_sq:
				ok = false
				break
		if ok:
			return pos
	return null

func _weighted_pick_prop(pool: Array, weights: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	if weights.size() != pool.size():
		return pool[randi_range(0, pool.size() - 1)]
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return pool[0]
	var target := randf() * float(total)
	var acc := 0.0
	for i in range(pool.size()):
		acc += float(weights[i])
		if target <= acc:
			return pool[i]
	return pool[pool.size() - 1]

# Wrap a prop texture so its base sits at the node origin (the ground-contact
# point used by y-sort) and add a soft contact shadow underneath. This gives
# props depth and stops them reading as flat stickers.
func _make_grounded_prop(tex: Texture2D, art_size: int) -> Node2D:
	var root := Node2D.new()
	var half := float(art_size) * 0.5
	var shadow := _make_contact_shadow(float(art_size) * 0.62)
	shadow.position = Vector2(0, -2)
	root.add_child(shadow)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sprite is centered by default; lift it so its bottom edge meets the origin.
	sprite.offset = Vector2(0, -half)
	root.add_child(sprite)
	return root

# Cached soft ellipse shadow texture, scaled per prop. One radial-gradient image
# is built once and reused for every shadow (cheap, no per-prop image work).
var _shadow_tex: Texture2D = null
func _make_contact_shadow(width: float) -> Sprite2D:
	if _shadow_tex == null:
		_shadow_tex = _build_shadow_texture()
	var spr := Sprite2D.new()
	spr.texture = _shadow_tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.modulate = Color(0, 0, 0, 0.32)
	var base_w := float(_shadow_tex.get_width())
	var sx: float = width / max(1.0, base_w)
	spr.scale = Vector2(sx, sx * 0.42)  # flattened ellipse
	spr.z_index = -1
	return spr

func _build_shadow_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x - c, y - c).length() / c
			var a: float = clamp(1.0 - d, 0.0, 1.0)
			a = a * a  # softer falloff toward the edge
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

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
	var value = randi_range(4, 8)
	var xp_amount = randi_range(2, 3)
	var style = "small"
	var roll = randf()
	if roll < 0.25:
		style = "skull"
	elif roll < 0.5:
		style = "fence"
	elif roll < 0.7:
		style = "pillar"
	if breakable.has_method("setup"):
		breakable.setup(self, value, xp_amount, style, false)
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
	if _adaptive_perf_scale < 0.72:
		if text.begins_with("+") and randf() < 0.75:
			return
		if randf() < 0.35:
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
	var final_color = color
	var final_duration = duration
	var manager = _get_settings_manager()
	if manager != null and manager.has_method("get_screen_flash_reduction"):
		var reduction = clampf(float(manager.get_screen_flash_reduction()), 0.0, 1.0)
		final_color.a *= (1.0 - reduction)
		final_duration = max(0.05, duration * (1.0 - reduction * 0.5))
	if final_color.a <= 0.01:
		return
	var flash = ColorRect.new()
	flash.color = final_color
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	if not flash.is_inside_tree():
		flash.queue_free()
		return
	var tween = flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, final_duration).from(final_color.a).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
func _update_extraction(delta: float) -> void:
	"""Drive the SCOUT -> SIEGE -> OVERRUN state machine."""
	match extraction_phase:
		ExtractionPhase.SCOUT:
			_update_scout_phase()
		ExtractionPhase.SIEGE:
			_update_siege_phase(delta)
		ExtractionPhase.OVERRUN:
			pass
	if ui != null and ui.has_method("update_objective"):
		ui.update_objective(extraction_phase, extraction_time_remaining(), extraction_progress)

func _update_scout_phase() -> void:
	var remaining := extraction_time_remaining()
	# Escalating callouts so the deadline never sneaks up on the player.
	if remaining <= 30.0 and not _extraction_warned_30s:
		_extraction_warned_30s = true
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("30s TO DEPLOY", Color(1.0, 0.75, 0.2), 34, 2.0)
	if remaining <= 10.0 and not _extraction_warned_10s:
		_extraction_warned_10s = true
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement("DEPLOYING SOON", Color(1.0, 0.4, 0.2), 34, 2.0)
	if remaining <= 0.0:
		_auto_place_extractor()

func _auto_place_extractor() -> void:
	"""Placement window expired: drop the extractor at the player rather than
	ending the run on a UI timer."""
	if has_extractor() or _extraction_auto_placed:
		return
	_extraction_auto_placed = true
	var pos := player.global_position if player != null else Vector2.ZERO
	var placed := _spawn_extractor_at(pos)
	if placed == null:
		# Could not place (blocked); retry next frame from the player's new spot.
		_extraction_auto_placed = false
		return
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("AUTO-DEPLOYED", Color(1.0, 0.6, 0.2), 38, 2.2)

func _spawn_extractor_at(pos: Vector2) -> Node:
	"""Instantiate the extractor directly (used by the auto-place fallback)."""
	var def: Dictionary = StructureDB.get_def(EXTRACTOR_STRUCTURE_ID)
	if def.is_empty():
		return null
	var scene_path := str(def.get("scene", ""))
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return null
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return null
	var building: Node2D = scene.instantiate()
	building.global_position = pos
	buildings_root.add_child(building)
	if building.has_method("configure"):
		building.configure(EXTRACTOR_STRUCTURE_ID, def, 0)
	mark_flow_field_dirty()
	return building

func on_extractor_placed(node: Node) -> void:
	"""Called by resource_generator.gd when the one extractor lands. Starts the
	siege: difficulty ramps from this moment and enemies converge here."""
	if has_extractor():
		return
	extractor = node
	extractor_placed_at = elapsed
	extraction_phase = ExtractionPhase.SIEGE
	extraction_progress = 0.0
	_extraction_milestone_index = 0
	mark_flow_field_dirty()
	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("EXTRACTION BEGINS", Color(0.4, 1.0, 0.6), 44, 2.6)
	AudioManager.play_ui_sound("wave_start")
	if has_method("shake_camera"):
		shake_camera(9.0, 0.4)

func _update_siege_phase(delta: float) -> void:
	if not has_extractor():
		return
	extraction_progress = clampf(extraction_progress + delta / EXTRACTION_DURATION, 0.0, 1.0)
	_announce_extraction_milestones()
	if extraction_progress >= 1.0:
		_on_extraction_complete()

func _announce_extraction_milestones() -> void:
	"""Call out each milestone as the bar crosses it.

	The step is a cliff, not a ramp, so it has to be legible: without the
	banner the horde simply gets harder for no reason the player can point at,
	which reads as the game cheating rather than as a scheduled escalation.
	"""
	while _extraction_milestone_index < EXTRACTION_MILESTONES.size():
		var entry: Dictionary = EXTRACTION_MILESTONES[_extraction_milestone_index]
		if extraction_progress < float(entry["at"]):
			return
		_extraction_milestone_index += 1
		if ui != null and ui.has_method("show_announcement"):
			ui.show_announcement(str(entry["banner"]), Color(1.0, 0.45, 0.2), 44, 2.6)
		flash_screen(Color(0.6, 0.15, 0.0, 0.16), 0.35)
		shake_camera(6.0, 0.35)
		AudioManager.play_one_shot("chest_charge", global_position, AudioManager.HIGH_PRIORITY)

func _on_extraction_complete() -> void:
	extraction_phase = ExtractionPhase.OVERRUN
	if not _run_won:
		_trigger_victory()

func on_extractor_destroyed() -> void:
	"""The one thing you were protecting is gone: the run ends immediately.

	Mirrors the player-death sequence (announce, fade, stats screen) rather than
	killing the player, so the defeat reads as 'you lost the objective'."""
	if game_over or _run_won:
		return
	extractor = null
	set_build_focus(false, "")
	_force_close_menus()
	game_over = true
	Engine.time_scale = 1.0
	_set_pause_allowed(false)

	if ui != null and ui.has_method("show_announcement"):
		ui.show_announcement("EXTRACTOR LOST", Color(1.0, 0.2, 0.2), 48, 3.0)
	shake_camera(18.0, 0.9)
	flash_screen(Color(1.0, 0.1, 0.1, 0.35), 0.5)
	AudioManager.play_one_shot("game_over", global_position, AudioManager.CRITICAL_PRIORITY)
	AudioManager.stop_music(2.0)
	_fade_to_black()

	if not is_inside_tree():
		return
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	_show_game_over_screen()

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
	# Mark bonus zones with blight-corruption ground tiles.
	if ground != null and ground.has_method("paint_blight_zones") and not placed.is_empty():
		ground.paint_blight_zones(placed, ResourceZone.ZONE_RADIUS)

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
	if not ENABLE_TIME_DILATION:
		return
	if is_ffa():
		return
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

	# Also spawn a quick glow particle — gated by the optional-FX budget so dense
	# fire doesn't stack additive glow into a bright wash.
	if should_spawn_optional_fx():
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
	var density = _get_effective_fx_density_scale()
	var burst_count = max(2, int(round(8.0 * density)))
	# Spawn multiple glow particles in burst pattern
	for i in range(burst_count):
		var angle = (TAU / float(burst_count)) * i + randf_range(-0.2, 0.2)
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
	# --- Gamepad layout (Xbox/SDL): added alongside keyboard, never replacing it ---
	# A=confirm/place, B=cancel, X=upgrade, Y=build toggle, Start=pause, Back=sell,
	# LB/RB=cycle build, left stick=move, right stick=build cursor, triggers=zoom.
	_ensure_action("start_game", [KEY_ENTER, KEY_SPACE], [JOY_BUTTON_A, JOY_BUTTON_START])
	# Movement: left stick (analog) + d-pad fallback. Low deadzone so the stick
	# responds near center — a high deadzone is the classic "controller won't move"
	# complaint. Both axis directions are bound so the full stick range maps to
	# action strength.
	_ensure_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]], 0.2)
	_ensure_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]], 0.2)
	_ensure_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]], 0.2)
	_ensure_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]], 0.2)
	_ensure_action("build_toggle", [KEY_B], [JOY_BUTTON_Y])
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
	_ensure_action(TECH_REROLL_ACTION, [KEY_R])
	_ensure_action(TECH_INFUSE_1_ACTION, [KEY_A])
	_ensure_action(TECH_INFUSE_2_ACTION, [KEY_S])
	_ensure_action(TECH_INFUSE_3_ACTION, [KEY_D])
	_ensure_action(TECH_LOCK_1_ACTION, [KEY_Z])
	_ensure_action(TECH_LOCK_2_ACTION, [KEY_X])
	_ensure_action(TECH_LOCK_3_ACTION, [KEY_C])
	_ensure_action(TECH_FORCE_TOWER_ACTION, [KEY_Q])
	_ensure_action(TECH_FORCE_ENGINEER_ACTION, [KEY_W])
	_ensure_action(TECH_FORCE_ECONOMY_ACTION, [KEY_E])
	_ensure_action("upgrade", [KEY_U], [JOY_BUTTON_X])
	_ensure_action("resource_dump", [KEY_H])
	_ensure_action("toggle_gate", [KEY_G])
	_ensure_action("interact", [KEY_F], [JOY_BUTTON_A])
	_ensure_action("sell", [KEY_X], [JOY_BUTTON_BACK])
	_ensure_action("cancel", [KEY_ESCAPE], [JOY_BUTTON_B])
	# Escape is what players reach for to pause; P stays as a second binding.
	_ensure_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_ensure_action("ui_cancel", [KEY_ESCAPE], [JOY_BUTTON_B])
	_ensure_action("zoom_in", [KEY_EQUAL], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], 0.5)
	_ensure_action("zoom_out", [KEY_MINUS], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], 0.5)
	# Gamepad-only build placement helpers (no keyboard equivalent needed).
	_ensure_action("build_place", [], [JOY_BUTTON_A])
	_ensure_action("build_prev", [], [JOY_BUTTON_LEFT_SHOULDER])
	_ensure_action("build_next", [], [JOY_BUTTON_RIGHT_SHOULDER])
	# Build cursor: RIGHT stick only. D-pad is intentionally NOT bound here so it
	# always means "move the player" — sharing the d-pad between movement and the
	# build cursor made movement feel ambiguous/unresponsive.
	_ensure_action("build_cursor_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]], 0.2)
	_ensure_action("build_cursor_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]], 0.2)
	_ensure_action("build_cursor_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]], 0.2)
	_ensure_action("build_cursor_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]], 0.2)
	_ensure_action(DEBUG_FLOW_ACTION, [KEY_F8, KEY_F9, KEY_F10])

func _ensure_action(name: String, keys: Array, buttons: Array = [], axes: Array = [], deadzone: float = -1.0) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	if deadzone >= 0.0:
		InputMap.action_set_deadzone(name, deadzone)
	for key in keys:
		var ev = InputEventKey.new()
		ev.physical_keycode = key
		if not InputMap.action_has_event(name, ev):
			InputMap.action_add_event(name, ev)
	# Gamepad buttons (e.g. JOY_BUTTON_A).
	for button in buttons:
		var bev = InputEventJoypadButton.new()
		bev.button_index = button
		if not InputMap.action_has_event(name, bev):
			InputMap.action_add_event(name, bev)
	# Gamepad analog axes. Each entry is [axis, direction] where direction is
	# +1.0 or -1.0 (the half of the axis that triggers the action).
	for axis_entry in axes:
		var mev = InputEventJoypadMotion.new()
		mev.axis = axis_entry[0]
		mev.axis_value = axis_entry[1]
		if not InputMap.action_has_event(name, mev):
			InputMap.action_add_event(name, mev)
