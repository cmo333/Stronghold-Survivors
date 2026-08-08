# Developer Guide

> *Architecture, patterns, and extension points for Stronghold Survivors*

---

## Architecture Overview

Stronghold Survivors follows a **component-based architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                      Main (main.gd)                      │
│              Game state, spawning, economy               │
├─────────────────────────────────────────────────────────┤
│  Player  │  Enemies  │  Buildings  │  FX  │  Pickups   │
├─────────────────────────────────────────────────────────┤
│           Managers (Audio, FX, Build, Wave)             │
├─────────────────────────────────────────────────────────┤
│              Data Layer (structures.json)               │
└─────────────────────────────────────────────────────────┘
```

### Key Design Patterns

1. **Singleton Pattern** - `AudioManager` as autoload for global access
2. **State Machine** - Enemy AI states (idle, chase, attack)
3. **Observer Pattern** - Signal-based communication between nodes
4. **Data-Driven Design** - Building stats in JSON, not hardcoded
5. **Object Pooling** - Implicit via node groups and cleanup

### Scene Tree Structure

```
Main (Node2D)
├── World
│   ├── Player (CharacterBody2D)
│   ├── Enemies (Node2D)          - Enemy instances
│   ├── Allies (Node2D)           - Friendly units
│   ├── Buildings (Node2D)        - All structures
│   ├── Projectiles (Node2D)      - Active projectiles
│   ├── FX (Node2D)               - Particle effects
│   ├── Pickups (Node2D)          - Gold, health, chests
│   ├── Breakables (Node2D)       - Pots, destructibles
│   └── Props (Node2D)            - Visual environment
├── UI (CanvasLayer)
├── BuildManager
├── FXManager
└── WaveManager
```

---

## File Structure

```
stronghold-survivors/
├── project.godot              # Godot project file
├── data/
│   └── structures.json        # Building stats database
├── scripts/
│   ├── main.gd               # Core game loop, spawning, state
│   ├── player.gd             # Player controller, auto-attack
│   ├── enemy.gd              # Base enemy class
│   ├── building.gd           # Base building class
│   ├── tower.gd              # Extends Building, adds combat
│   ├── trap.gd               # Extends Building, trap logic
│   ├── *.gd                  # Specialized classes
│   └── audio_manager.gd      # Global audio singleton
├── scenes/
│   ├── buildings/            # Building scene files (.tscn)
│   ├── enemies/              # Enemy scene files
│   ├── allies/               # Ally unit scenes
│   ├── fx/                   # Effect scenes
│   └── *.tscn                # Main scenes
├── assets/
│   ├── level1/               # Level-specific sprites
│   ├── fx/                   # Effect sprites
│   ├── ui/                   # UI elements
│   └── audio/                # Sound files
└── addons/                   # Third-party plugins
```

---

## How to Add New Towers

### Step 1: Create the Scene

1. Create a new scene in `scenes/buildings/`
2. Root node: `Area2D` (or extend from existing tower)
3. Add required children:
   - `CollisionShape2D` - Hitbox
   - `AnimatedSprite2D` (named "Body") - Visual
   - `Sprite2D` - Range indicator (optional)

### Step 2: Create the Script

Create `scripts/my_tower.gd`:

```gdscript
extends Tower
class_name MyTower

# Unique tower properties
var chain_count: int = 3
var bounce_range: float = 120.0

func _ready() -> void:
    tower_type = "my_tower"  # Must match structures.json key
    super._ready()

func _setup_tower_specific_visuals() -> void:
    # Add visual elements for T2/T3
    # Called automatically during _ready()
    pass

func _fire_at(target: Node2D) -> void:
    # Custom firing logic
    var dir = (target.global_position - global_position).normalized()
    
    # Example: Chain lightning behavior
    _fire_chain_projectile(target, chain_count)
    
    # Audio
    AudioManager.play_weapon_sound(tower_type, global_position)

func _fire_chain_projectile(target: Node2D, chains_remaining: int) -> void:
    if chains_remaining <= 0:
        return
    
    var dmg = damage + _game.get_tower_damage_bonus()
    _game.spawn_projectile(global_position, 
        (target.global_position - global_position).normalized(),
        projectile_speed, dmg, projectile_range, 0)
    
    # Find next target in chain
    if chains_remaining > 1:
        var next = _find_chain_target(target.global_position)
        if next:
            _fire_chain_projectile(next, chains_remaining - 1)

func _find_chain_target(from_pos: Vector2) -> Node2D:
    var best: Node2D = null
    var best_dist = bounce_range * bounce_range
    for enemy in get_tree().get_nodes_in_group("enemies"):
        var dist = from_pos.distance_squared_to(enemy.global_position)
        if dist <= best_dist and dist > 10:  # Not the same target
            best = enemy
            best_dist = dist
    return best
```

### Step 3: Add to Data File

Edit `data/structures.json`:

```json
{
  "my_tower": {
    "name": "My Custom Tower",
    "type": "tower",
    "scene": "res://scenes/buildings/my_tower.tscn",
    "footprint_radius": 16,
    "blocks_path": true,
    "tiers": [
      {
        "cost": 40,
        "health": 50,
        "range": 240,
        "fire_rate": 1.2,
        "damage": 15,
        "projectile_speed": 600,
        "projectile_range": 300,
        "chain_count": 3
      },
      {
        "cost": 60,
        "health": 70,
        "range": 280,
        "fire_rate": 1.4,
        "damage": 22,
        "projectile_speed": 650,
        "projectile_range": 340,
        "chain_count": 5
      },
      {
        "cost": 100,
        "health": 95,
        "range": 320,
        "fire_rate": 1.6,
        "damage": 30,
        "projectile_speed": 700,
        "projectile_range": 380,
        "chain_count": 8
      }
    ],
    "preview": "res://assets/ui_build_icons/ui_build_my_tower_32_v001.png"
  }
}
```

### Step 4: Add Unlock Tech (Optional)

In `main.gd`, add to `tech_defs`:

```gdscript
"unlock_my_tower": {
    "name": "Unlock: My Tower",
    "desc": "Custom tower description",
    "max": 1,
    "icon": "res://assets/ui/ui_icon_custom_32_v001.png",
    "rarity": "epic",
    "min_level": 4,
    "unlock_build": "my_tower"
}
```

### Step 5: Add Icons

Create 32x32 icon: `assets/ui_build_icons/ui_build_my_tower_32_v001.png`

---

## How to Add New Enemies

### Step 1: Create the Scene

Create `scenes/enemies/my_enemy.tscn`:
- Root: `CharacterBody2D`
- Add `CollisionShape2D`, `AnimatedSprite2D` ("Body")

### Step 2: Create the Script

Create `scripts/my_enemy.gd`:

```gdscript
extends "res://scripts/enemy.gd"
class_name MyEnemy

# Unique properties
var special_cooldown: float = 0.0
var special_interval: float = 5.0

func _ready() -> void:
    super._ready()
    # Override base stats
    speed = 110.0
    max_health = 35.0
    health = max_health
    attack_damage = 12.0
    attack_rate = 0.8

func _physics_process(delta: float) -> void:
    if _is_dying:
        return
    
    # Handle special ability
    special_cooldown -= delta
    if special_cooldown <= 0.0:
        _do_special_attack()
        special_cooldown = special_interval
    
    # Call parent behavior (chase/attack)
    super._physics_process(delta)

func _do_special_attack() -> void:
    # Example: Area buff to nearby enemies
    var radius_sq = 200.0 * 200.0
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy != self and global_position.distance_squared_to(enemy.global_position) <= radius_sq:
            if enemy.has_method("apply_speed_buff"):
                enemy.apply_speed_buff(1.5, 3.0)  # 50% faster for 3s
    
    # Visual effect
    if _game and _game.has_method("spawn_fx"):
        _game.spawn_fx("summon_fire", global_position)

func apply_speed_buff(multiplier: float, duration: float) -> void:
    speed *= multiplier
    await get_tree().create_timer(duration).timeout
    speed /= multiplier
```

### Step 3: Add to Spawn Pool

In `main.gd`, add to `ENEMY_POOLS`:

```gdscript
const MY_ENEMY_SCENE = preload("res://scenes/enemies/my_enemy.tscn")

# In ENEMY_POOLS array, add to appropriate time bracket:
{
    "time": 120.0,  # Spawn starting at 2 minutes
    "weights": [
        [ENEMY_SCENE, 30],
        [CHARGER_SCENE, 15],
        [MY_ENEMY_SCENE, 10]  # 10% weight
    ]
}
```

### Step 4: Add as Elite Variant (Optional)

The base `enemy.gd` already supports elite modifiers (aura, regen, splitter). Your new enemy will automatically work with these.

---

## How to Add New Power-ups

### Step 1: Add Type to Enum

In `scripts/power_up.gd`:

```gdscript
enum Type {
    ANCIENT_RELIC,
    TIME_CRYSTAL,
    RESOURCE_CACHE,
    BERSERK_ORB,
    MY_POWERUP  # Add new type
}
```

### Step 2: Add Configuration

In the `TYPE_CONFIG` dictionary:

```gdscript
Type.MY_POWERUP: {
    "name": "My Powerup",
    "color": Color(0.8, 0.2, 0.8),      # Purple
    "glow_color": Color(1.0, 0.4, 1.0),
    "spawn_min": 500.0,                 # Min spawn distance
    "spawn_max": 700.0,                 # Max spawn distance
    "duration": 30.0,                   # How long it stays on map
    "icon": "res://assets/ui/ui_icon_my_powerup_32_v001.png"
}
```

### Step 3: Add Effect Logic

In `_apply_effect()`:

```gdscript
func _apply_effect(player: Node2D) -> void:
    match power_up_type:
        # ... existing cases ...
        Type.MY_POWERUP:
            _apply_my_powerup(player)

func _apply_my_powerup(player: Node2D) -> void:
    # Example: Shield that absorbs damage
    if player.has_method("apply_shield"):
        player.apply_shield(100.0)  # 100 HP shield
    
    # Visual effects
    if _game and _game.has_method("spawn_fx"):
        _game.spawn_fx("shockwave", global_position)
    
    if _game and _game.has_method("flash_screen"):
        _game.flash_screen(Color(0.8, 0.2, 0.8, 0.4), 0.5)
```

### Step 4: Adjust Spawn Weights

In `get_random_type()`:

```gdscript
static func get_random_type() -> Type:
    var roll = randf()
    if roll < 0.30:
        return Type.RESOURCE_CACHE
    elif roll < 0.50:
        return Type.TIME_CRYSTAL
    elif roll < 0.70:
        return Type.ANCIENT_RELIC
    elif roll < 0.85:
        return Type.BERSERK_ORB
    else:
        return Type.MY_POWERUP  # 15% chance
```

---

## Data-Driven Design

### structures.json Schema

```json
{
  "building_id": {
    "name": "Display Name",
    "type": "tower|trap|wall|utility|core",
    "scene": "res://path/to/scene.tscn",
    "footprint_radius": 16,      // Collision size
    "blocks_path": true,          // Affects enemy pathfinding
    "preview": "res://path/to/icon.png",
    "tiers": [
      {
        "cost": 25,
        "health": 50,
        // Tower-specific:
        "range": 240,
        "fire_rate": 1.0,
        "damage": 10,
        "projectile_speed": 600,
        "projectile_range": 300,
        // Custom properties are passed to the script
        "custom_stat": 5
      }
    ]
  }
}
```

### How Data Flows

1. `main.gd` loads `structures.json` into memory
2. `build_manager.gd` reads data for build palette
3. When placing, `building.gd` reads tier data via `_apply_tier_stats()`
4. Tower scripts access stats as member variables

---

## Key Systems Reference

### Game Layers (Collision)

Defined in `constants.gd`:
- `ENEMY = 1` - Enemy units
- `PLAYER = 2` - Player character
- `BUILDING = 3` - All structures
- `PROJECTILE = 4` - Player projectiles
- `PICKUP = 5` - Gold, health drops
- `ALLY = 6` - Friendly units

### Global Access

```gdscript
# Get game reference
var game = get_tree().get_first_node_in_group("game")

# Get player
var player = get_tree().get_first_node_in_group("player")

# Iterate enemies
for enemy in get_tree().get_nodes_in_group("enemies"):
    pass

# Iterate buildings
for building in get_tree().get_nodes_in_group("buildings"):
    pass
```

### Audio Integration

```gdscript
# One-shot sound
AudioManager.play_one_shot("sound_name", global_position)

# Weapon sound (auto-selects based on type)
AudioManager.play_weapon_sound("gun", global_position)

# UI sound (non-spatial)
AudioManager.play_ui_sound("click")

# Impact sound
AudioManager.play_impact_sound(is_crit, is_death, global_position)
```

### FX Spawning

```gdscript
# Via game reference
var game = get_tree().get_first_node_in_group("game")
game.spawn_fx("hit", global_position)
game.spawn_fx("explosion", global_position)
game.spawn_fx("blood", global_position)

# Custom glow particle
game.spawn_glow_particle(
    position,           # Vector2
    Color.RED,          # Color
    8.0,                # Size
    0.5,                # Lifetime
    Vector2.UP * 50,    # Velocity
    1.6,                # Bloom
    0.7,                // Trail strength
    0.9,                // Trail length
    1                   // Z-index
)
```

---

## Testing & Debugging

### Debug Hotkeys (Add to main.gd)

```gdscript
func _input(event):
    if event.is_action_pressed("debug_gold"):
        add_resources(100)
    if event.is_action_pressed("debug_level"):
        add_xp(xp_next)
    if event.is_action_pressed("debug_kill_all"):
        for enemy in get_tree().get_nodes_in_group("enemies"):
            enemy.take_damage(9999)
```

### Performance Monitoring

Key metrics tracked in `main.gd`:
- Enemy count
- Projectile count
- Active effects
- Spawn intervals

Watch for:
- Enemy count > 150 (may cause slowdown)
- Projectile count > 200 (approaching limit)

---

## Best Practices

1. **Always use groups** - Don't hardcode node paths
2. **Check has_method()** - Before calling script-specific methods
3. **Clean up tweens** - In `_exit_tree()` to avoid errors
4. **Use signals** - For decoupled communication
5. **Data in JSON** - Keep balance numbers out of code
6. **Test with controller** - Keyboard + mouse isn't the only input
7. **Profile early** - Check performance with max enemies spawned

---

## Common Issues

| Issue | Solution |
|-------|----------|
| Tween errors on exit | Kill tweens in `_exit_tree()` |
| Enemies not spawning | Check `ENEMY_POOLS` time brackets |
| Towers not firing | Verify `tower_type` matches JSON key |
| Audio not playing | Ensure `AudioManager.set_camera()` called |
| Build preview stuck | Call `build_manager.cancel_build()` |

---

*For balance tuning, see `BALANCE_GUIDE.md`*
