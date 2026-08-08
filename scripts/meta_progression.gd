extends Node

# Persistent meta-progression: banked "Cores" currency earned across runs, hero
# unlocks, permanent upgrades, and level availability. Survives scene changes as
# an autoload. Mirrors the SettingsManager persistence pattern.

signal cores_changed(amount: int)
signal meta_loaded

const SAVE_PATH := "user://meta_progress.json"

# --- Prototype testing grant (remove before release) ---
const PROTOTYPE_GRANT_ID := "proto_grant_v1"   # bump suffix to re-trigger
const PROTOTYPE_MIN_CORES := 1000

# ---- Content definitions (kept in-script this pass; can externalize to JSON later) ----

const HERO_DEFS := [
	{
		"id": "warlock",
		"name": "Tech Warlock",
		"desc": "Arcane-circuit caster. The standard issue.",
		"core_cost": 0,
		"unlocked_by_default": true
	},
	{
		"id": "reaper",
		"name": "Reaper",
		"desc": "Raises the dead instead of firing. They fight for you.",
		"core_cost": 1000,
		"unlocked_by_default": false
	},
	{
		"id": "hunter",
		"name": "OG Hunter",
		"desc": "The one who came first. Prestige unlock.",
		"core_cost": 10000,
		"unlocked_by_default": false
	},
	{
		"id": "hunter_classic",
		"name": "Hunter (Classic)",
		"desc": "The original ranger look.",
		"core_cost": 10,
		"unlocked_by_default": false
	},
	{
		"id": "pyromancer",
		"name": "Pyromancer",
		"desc": "Aggressive fire caster.",
		"core_cost": 30,
		"unlocked_by_default": false
	}
]

# Permanent upgrades bought with Cores, applied at run start.
const UPGRADE_DEFS := [
	{
		"id": "start_gold",
		"name": "War Chest",
		"desc": "+40 starting gold per level.",
		"max_level": 5,
		"cost_per_level": [10, 18, 28, 42, 60],
		"effect_key": "start_resources",
		"effect_per_level": 40.0
	},
	{
		"id": "max_hp",
		"name": "Fortitude",
		"desc": "+15 max HP per level.",
		"max_level": 5,
		"cost_per_level": [12, 20, 32, 48, 70],
		"effect_key": "max_hp",
		"effect_per_level": 15.0
	},
	{
		"id": "move_speed",
		"name": "Fleet Footed",
		"desc": "+5% move speed per level.",
		"max_level": 4,
		"cost_per_level": [12, 22, 36, 54],
		"effect_key": "move_speed_mult",
		"effect_per_level": 0.05
	},
	{
		"id": "essence_gain",
		"name": "Attunement",
		"desc": "+10% essence gain per level.",
		"max_level": 4,
		"cost_per_level": [15, 26, 42, 64],
		"effect_key": "essence_mult",
		"effect_per_level": 0.10
	},
	{
		"id": "tower_damage_pct",
		"name": "Siege Doctrine",
		"desc": "+4% tower damage per level.",
		"max_level": 5,
		"cost_per_level": [14, 24, 38, 56, 80],
		"effect_key": "tower_damage_mult",
		"effect_per_level": 0.04
	},
	{
		"id": "pickup_radius_pct",
		"name": "Lodestone",
		"desc": "+8% pickup radius per level.",
		"max_level": 4,
		"cost_per_level": [12, 22, 36, 54],
		"effect_key": "pickup_radius_mult",
		"effect_per_level": 0.08
	}
]

# Optional run modifiers (challenges) chosen on the main menu before a run.
# Each trades a difficulty effect for a Cores reward multiplier.
const MODIFIER_DEFS := [
	{
		"id": "none",
		"name": "Standard",
		"desc": "No modifiers.",
		"effect": {},
		"cores_reward_mult": 1.0
	},
	{
		"id": "hardened",
		"name": "Hardened Horde",
		"desc": "Enemies hit harder and ramp faster. +30% Cores.",
		"effect": {"threat_mult": 1.30},
		"cores_reward_mult": 1.30
	},
	{
		"id": "glass",
		"name": "Glass Stronghold",
		"desc": "You take +50% damage. +40% Cores.",
		"effect": {"player_damage_taken_mult": 1.50},
		"cores_reward_mult": 1.40
	},
	{
		"id": "speedrun",
		"name": "Onslaught",
		"desc": "The horde escalates 40% faster. +25% Cores.",
		"effect": {"ramp_speed_mult": 1.40},
		"cores_reward_mult": 1.25
	}
]

const LEVEL_DEFS := [
	{
		"id": "graveyard",
		"name": "The Graveyard",
		"desc": "Cursed burial grounds.",
		"unlocked_by_default": true,
		"coming_soon": false
	},
	{
		"id": "space",
		"name": "Orbital Station",
		"desc": "Coming soon.",
		"unlocked_by_default": false,
		"coming_soon": true
	}
]

const DEFAULT_STATE := {
	"cores": 0,
	"lifetime_cores_earned": 0,
	# Fresh saves start on the warlock. An existing save keeps whatever it
	# already unlocked -- repricing a hero must not confiscate one a player has.
	"unlocked_heroes": {"warlock": true, "hunter": false, "pyromancer": false},
	"permanent_upgrades": {},
	"unlocked_levels": {"graveyard": true},
	"first_victory": false
}

const VICTORY_CORES_BONUS := 50

var _state: Dictionary = {}

# Transient selections chosen in the main menu (not persisted).
var pending_hero: String = "warlock"
var pending_level: String = "graveyard"
var pending_modifier: String = "none"
# Set true by the menu when launching a run so the game scene auto-starts
# instead of showing its legacy in-HUD start panel.
var autostart_run: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_state = _deep_copy(DEFAULT_STATE)
	_load_from_disk()
	_apply_prototype_grant()
	meta_loaded.emit()

func _apply_prototype_grant() -> void:
	# One-time dev convenience: top cores up to a floor and unlock the space
	# level so prototype features are testable. Guarded by a saved flag so it
	# runs once and never re-grants (lets the user actually spend cores).
	var grants: Dictionary = _state.get("_dev_grants", {})
	if bool(grants.get(PROTOTYPE_GRANT_ID, false)):
		return
	var changed := false
	if get_cores() < PROTOTYPE_MIN_CORES:
		_state["cores"] = PROTOTYPE_MIN_CORES
		changed = true
	var levels: Dictionary = _state.get("unlocked_levels", {})
	if not bool(levels.get("space", false)):
		levels["space"] = true
		_state["unlocked_levels"] = levels
		changed = true
	grants[PROTOTYPE_GRANT_ID] = true
	_state["_dev_grants"] = grants
	_save_to_disk()
	if changed:
		cores_changed.emit(get_cores())

# ---- Persistence (mirrors settings_manager.gd) ----

func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value.keys():
			result[key] = _deep_copy(value[key])
		return result
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_deep_copy(item))
		return arr
	return value

func _merge_defaults(target: Dictionary, defaults: Dictionary) -> Dictionary:
	var merged: Dictionary = _deep_copy(defaults)
	for key in target.keys():
		var src = target[key]
		if src is Dictionary and merged.has(key) and merged[key] is Dictionary:
			for sub in src.keys():
				merged[key][sub] = src[sub]
		else:
			merged[key] = src
	return merged

func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text = file.get_as_text()
	file.close()
	if text == "":
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	if json.data is Dictionary:
		_state = _merge_defaults(json.data, DEFAULT_STATE)

func _save_to_disk() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("MetaProgression: failed to open save file")
		return
	file.store_string(JSON.stringify(_state, "\t"))
	file.close()

# ---- Currency ----

func get_cores() -> int:
	return int(_state.get("cores", 0))

func add_cores(n: int) -> void:
	if n == 0:
		return
	_state["cores"] = max(0, get_cores() + n)
	if n > 0:
		_state["lifetime_cores_earned"] = int(_state.get("lifetime_cores_earned", 0)) + n
	_save_to_disk()
	cores_changed.emit(get_cores())

func can_afford(n: int) -> bool:
	return get_cores() >= n

func spend_cores(n: int) -> bool:
	if n <= 0:
		return true
	if get_cores() < n:
		return false
	_state["cores"] = get_cores() - n
	_save_to_disk()
	cores_changed.emit(get_cores())
	return true

# ---- Heroes ----

func get_hero_def(id: String) -> Dictionary:
	for h in HERO_DEFS:
		if str(h.get("id", "")) == id:
			return h
	return {}

func is_hero_unlocked(id: String) -> bool:
	var heroes: Dictionary = _state.get("unlocked_heroes", {})
	return bool(heroes.get(id, false))

func unlock_hero(id: String) -> bool:
	var def := get_hero_def(id)
	if def.is_empty():
		return false
	if is_hero_unlocked(id):
		return true
	var cost := int(def.get("core_cost", 0))
	if not spend_cores(cost):
		return false
	var heroes: Dictionary = _state.get("unlocked_heroes", {})
	heroes[id] = true
	_state["unlocked_heroes"] = heroes
	_save_to_disk()
	return true

# ---- Levels ----

func is_level_unlocked(id: String) -> bool:
	var levels: Dictionary = _state.get("unlocked_levels", {})
	return bool(levels.get(id, false))

# ---- Permanent upgrades ----

func get_upgrade_def(id: String) -> Dictionary:
	for u in UPGRADE_DEFS:
		if str(u.get("id", "")) == id:
			return u
	return {}

func get_upgrade_level(id: String) -> int:
	var ups: Dictionary = _state.get("permanent_upgrades", {})
	return int(ups.get(id, 0))

func get_upgrade_next_cost(id: String) -> int:
	var def := get_upgrade_def(id)
	if def.is_empty():
		return -1
	var lvl := get_upgrade_level(id)
	var max_lvl := int(def.get("max_level", 0))
	if lvl >= max_lvl:
		return -1
	var costs: Array = def.get("cost_per_level", [])
	if lvl < costs.size():
		return int(costs[lvl])
	return -1

func buy_upgrade(id: String) -> bool:
	var cost := get_upgrade_next_cost(id)
	if cost < 0:
		return false
	if not spend_cores(cost):
		return false
	var ups: Dictionary = _state.get("permanent_upgrades", {})
	ups[id] = get_upgrade_level(id) + 1
	_state["permanent_upgrades"] = ups
	_save_to_disk()
	return true

# Aggregate permanent-upgrade effects into a flat dictionary for main.gd.
func get_run_start_bonuses() -> Dictionary:
	var bonuses := {
		"start_resources": 0.0,
		"max_hp": 0.0,
		"move_speed_mult": 1.0,
		"essence_mult": 1.0,
		"tower_damage_mult": 1.0,
		"pickup_radius_mult": 1.0
	}
	for def in UPGRADE_DEFS:
		var id := str(def.get("id", ""))
		var lvl := get_upgrade_level(id)
		if lvl <= 0:
			continue
		var key := str(def.get("effect_key", ""))
		var per := float(def.get("effect_per_level", 0.0))
		match key:
			"start_resources", "max_hp":
				bonuses[key] = float(bonuses.get(key, 0.0)) + per * lvl
			"move_speed_mult", "essence_mult", "tower_damage_mult", "pickup_radius_mult":
				bonuses[key] = float(bonuses.get(key, 1.0)) + per * lvl
	return bonuses

# ---- Run modifiers (challenges) ----

func get_modifier_def(id: String) -> Dictionary:
	for m in MODIFIER_DEFS:
		if str(m.get("id", "")) == id:
			return m
	return MODIFIER_DEFS[0]

func get_active_modifier_effect() -> Dictionary:
	return get_modifier_def(pending_modifier).get("effect", {})

func get_modifier_cores_mult() -> float:
	return float(get_modifier_def(pending_modifier).get("cores_reward_mult", 1.0))

# ---- Milestone unlocks ----

func mark_victory_unlock() -> void:
	var levels: Dictionary = _state.get("unlocked_levels", {})
	levels["space"] = true
	_state["unlocked_levels"] = levels
	_state["first_victory"] = true
	_save_to_disk()

func has_won() -> bool:
	return bool(_state.get("first_victory", false))

# ---- Run reward ----

func award_run_cores(stats: Dictionary, won: bool = false) -> int:
	var time_survived := float(stats.get("time_survived", 0.0))
	var kills := int(stats.get("enemies_killed", 0))
	var wave := int(stats.get("wave_reached", 0))
	var base := int(floor(time_survived / 30.0)) + int(kills / 25) + wave * 2
	var earned := int(round(float(base) * get_modifier_cores_mult()))
	if won:
		earned += VICTORY_CORES_BONUS
	earned = max(earned, 1)
	add_cores(earned)
	return earned

# FFA payout: a participation floor plus a score bonus, with a winner bonus on
# top. Placement is 1-based (1 = winner). Awarded locally on each machine from
# the replicated final scoreboard.
func award_ffa_cores(placement: int, score: int, won: bool = false) -> int:
	var earned := 2 + int(score / 200)
	if won:
		earned += VICTORY_CORES_BONUS
	elif placement == 2:
		earned += 10
	elif placement == 3:
		earned += 5
	earned = int(round(float(earned) * get_modifier_cores_mult()))
	earned = max(earned, 1)
	add_cores(earned)
	return earned
