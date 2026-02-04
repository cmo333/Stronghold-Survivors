extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SIEGE_ENEMY_SCENE := preload("res://scenes/siege_enemy.tscn")
const BANSHEE_SCENE := preload("res://scenes/enemies/banshee.tscn")
const NECROMANCER_SCENE := preload("res://scenes/enemies/necromancer.tscn")
const FIEND_DUELIST_SCENE := preload("res://scenes/enemies/fiend_duelist.tscn")
const HELLHOUND_SCENE := preload("res://scenes/enemies/hellhound.tscn")
const PLAGUE_ABOMINATION_SCENE := preload("res://scenes/enemies/plague_abomination.tscn")
const FX_SCENE := preload("res://scenes/fx/fx.tscn")
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const PICKUP_SCENE := preload("res://scenes/pickup.tscn")
const BREAKABLE_SCENE := preload("res://scenes/breakable.tscn")

@onready var player: CharacterBody2D = $World/Player
@onready var enemies_root: Node2D = $World/Enemies
@onready var projectiles_root: Node2D = $World/Projectiles
@onready var fx_root: Node2D = $World/FX
@onready var buildings_root: Node2D = $World/Buildings
@onready var pickups_root: Node2D = $World/Pickups
@onready var breakables_root: Node2D = $World/Breakables
@onready var ui: CanvasLayer = $UI
@onready var build_manager: Node = $BuildManager

var resources: int = 0
var elapsed: float = 0.0
var spawn_accumulator: float = 0.0
var game_over := false

var xp := 0
var level := 1
var xp_next := 12
var pending_picks := 0
var tech_open := false
var tech_choices: Array = []
var tech_levels: Dictionary = {}
var building_effects := {
    "armory_damage": {},
    "tech_rate": {}
}
var tower_rate_mult := 1.0
var player_damage_bonus := 0.0

var spawn_radius_min := 520.0
var spawn_radius_max := 720.0
var max_enemies_base := 70
var max_enemies_growth := 1.6
var max_enemies_cap := 260
var max_projectiles := 240

var breakable_target := 18
var breakable_spawn_min := 240.0
var breakable_spawn_max := 920.0

var tech_defs := {
    "gun_pierce": {
        "name": "Gun: Piercing",
        "desc": "Shots pierce +1 enemy",
        "max": 2,
        "icon": "res://assets/ui/ui_icon_iron_32_v001.png"
    },
    "gun_burst": {
        "name": "Gun: Burst Volley",
        "desc": "Every few shots fires a 3-shot spread",
        "max": 3,
        "icon": "res://assets/ui/ui_icon_fire_32_v001.png"
    },
    "gun_slow": {
        "name": "Gun: Cryo Rounds",
        "desc": "Shots slow enemies briefly",
        "max": 2,
        "icon": "res://assets/ui/ui_icon_ice_32_v001.png"
    },
    "arrow_fan": {
        "name": "Arrow: Fanfire",
        "desc": "Arrow turrets fire extra spread shots",
        "max": 3,
        "icon": "res://assets/ui/ui_icon_wood_32_v001.png"
    },
    "tesla_emp": {
        "name": "Tesla: EMP",
        "desc": "Tesla shocks slow and stun briefly",
        "max": 3,
        "icon": "res://assets/ui/ui_icon_lightning_32_v001.png"
    }
}

var fx_defs := {
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
    }
}

func _ready() -> void:
    randomize()
    add_to_group("game")
    _ensure_input_map()
    resources = 60
    _update_ui()
    if build_manager.has_method("setup"):
        build_manager.setup(self, buildings_root, ui)
    _spawn_initial_breakables()

func _process(delta: float) -> void:
    if game_over:
        return
    if tech_open:
        _handle_tech_input()
        return
    elapsed += delta
    _handle_spawning(delta)
    _maintain_breakables()

func is_tech_open() -> bool:
    return tech_open

func get_tech_level(id: String) -> int:
    return int(tech_levels.get(id, 0))

func _handle_tech_input() -> void:
    if Input.is_action_just_pressed("build_1"):
        _choose_tech(0)
    elif Input.is_action_just_pressed("build_2"):
        _choose_tech(1)
    elif Input.is_action_just_pressed("build_3"):
        _choose_tech(2)

func _handle_spawning(delta: float) -> void:
    var interval := max(0.3, 1.35 - (elapsed / 150.0))
    spawn_accumulator += delta
    while spawn_accumulator >= interval:
        spawn_accumulator -= interval
        var max_enemies := min(max_enemies_cap, max_enemies_base + int(elapsed * max_enemies_growth))
        if enemies_root.get_child_count() >= max_enemies:
            break
        spawn_enemy()

func spawn_enemy() -> void:
    if player == null:
        return
    var siege_chance := 0.0
    if elapsed > 90.0:
        siege_chance = clamp(0.05 + (elapsed - 90.0) / 300.0, 0.0, 0.35)
    var scene := _pick_enemy_scene()
    if randf() < siege_chance:
        scene = SIEGE_ENEMY_SCENE
    var enemy := scene.instantiate()
    var angle := randf() * TAU
    var distance := randf_range(spawn_radius_min, spawn_radius_max)
    enemy.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
    var difficulty := 1.0 + (elapsed / 60.0) * 0.25
    if enemy.has_method("setup"):
        enemy.setup(self, difficulty)
    enemies_root.add_child(enemy)

func spawn_minion(position: Vector2) -> void:
    if enemies_root.get_child_count() >= max_enemies_cap:
        return
    var enemy := ENEMY_SCENE.instantiate()
    enemy.global_position = position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
    var difficulty := 1.0 + (elapsed / 60.0) * 0.25
    if enemy.has_method("setup"):
        enemy.setup(self, difficulty)
    enemies_root.add_child(enemy)

func _pick_enemy_scene() -> PackedScene:
    if elapsed < 45.0:
        return ENEMY_SCENE
    if elapsed < 120.0:
        return _random_scene([ENEMY_SCENE, BANSHEE_SCENE, HELLHOUND_SCENE])
    if elapsed < 240.0:
        return _random_scene([ENEMY_SCENE, BANSHEE_SCENE, HELLHOUND_SCENE, FIEND_DUELIST_SCENE, NECROMANCER_SCENE])
    return _random_scene([ENEMY_SCENE, BANSHEE_SCENE, HELLHOUND_SCENE, FIEND_DUELIST_SCENE, NECROMANCER_SCENE, PLAGUE_ABOMINATION_SCENE])

func _random_scene(pool: Array) -> PackedScene:
    if pool.is_empty():
        return ENEMY_SCENE
    return pool[randi_range(0, pool.size() - 1)]

func spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: float, max_range: float, explosion_radius: float, pierce: int = 0, slow_factor: float = 1.0, slow_duration: float = 0.0) -> void:
    if projectiles_root.get_child_count() >= max_projectiles:
        return
    var projectile := PROJECTILE_SCENE.instantiate()
    projectile.global_position = origin
    if projectile.has_method("setup"):
        projectile.setup(self, direction, speed, damage, max_range, explosion_radius, pierce, slow_factor, slow_duration)
    projectiles_root.add_child(projectile)

func spawn_pickup(position: Vector2, value: int) -> void:
    var pickup := PICKUP_SCENE.instantiate()
    pickup.global_position = position
    if pickup.has_method("setup"):
        pickup.setup(self, value)
    pickups_root.add_child(pickup)

func spawn_fx(kind: String, position: Vector2) -> void:
    if fx_root == null or not fx_defs.has(kind):
        return
    var fx := FX_SCENE.instantiate()
    fx.global_position = position
    var def := fx_defs[kind]
    if fx.has_method("setup"):
        fx.setup(def.get("paths", []), float(def.get("fps", 10.0)), float(def.get("lifetime", 0.35)), false)
    fx_root.add_child(fx)

func damage_enemies_in_radius(position: Vector2, radius: float, damage: float, siege_bonus: float = 1.0) -> void:
    var radius_sq := radius * radius
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy == null:
            continue
        if enemy.global_position.distance_squared_to(position) <= radius_sq:
            var final_damage := damage
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
    var available := _get_available_tech_ids()
    if available.is_empty():
        pending_picks = 0
        tech_open = false
        return
    available.shuffle()
    var count := min(3, available.size())
    for i in range(count):
        var id := available[i]
        var def := tech_defs[id]
        tech_choices.append({
            "id": id,
            "name": def.get("name", id),
            "desc": def.get("desc", ""),
            "icon": def.get("icon", "")
        })
    tech_open = true
    if ui.has_method("show_tech"):
        ui.show_tech(tech_choices)
    Engine.time_scale = 0.7

func _choose_tech(index: int) -> void:
    if index < 0 or index >= tech_choices.size():
        return
    var choice := tech_choices[index]
    var id := choice.get("id", "")
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
    var rate_bonus := 0.0
    for value in building_effects["tech_rate"].values():
        rate_bonus += float(value)
    tower_rate_mult = 1.0 + rate_bonus
    if player != null and player.has_method("apply_global_bonuses"):
        player.apply_global_bonuses(player_damage_bonus)

func get_tower_rate_mult() -> float:
    return tower_rate_mult

func _get_available_tech_ids() -> Array:
    var available: Array = []
    for id in tech_defs.keys():
        var max_level := int(tech_defs[id].get("max", 1))
        var current := int(tech_levels.get(id, 0))
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
    var breakable := BREAKABLE_SCENE.instantiate()
    var angle := randf() * TAU
    var distance := randf_range(breakable_spawn_min, breakable_spawn_max)
    breakable.global_position = player.global_position + Vector2.RIGHT.rotated(angle) * distance
    var chest := randf() < 0.25
    var value := chest ? randi_range(10, 16) : randi_range(4, 8)
    var xp_amount := chest ? randi_range(4, 7) : randi_range(2, 3)
    if breakable.has_method("setup"):
        breakable.setup(self, value, xp_amount)
    breakables_root.add_child(breakable)

func _ensure_input_map() -> void:
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
        var ev := InputEventKey.new()
        ev.physical_keycode = key
        InputMap.action_add_event(name, ev)
