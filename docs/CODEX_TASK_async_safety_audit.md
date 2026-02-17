# Codex Task: Async Safety Audit & Audio Warning Cleanup

## Context
Stronghold Survivors is a Godot 4.2 tower defense game. We've been fixing crashes caused by:
1. `create_tween()` called on nodes removed from the scene tree
2. `await get_tree().create_timer()` on freed/orphaned nodes
3. Tween callbacks referencing freed nodes
4. Audio manager spamming "Sound not cached" warnings (28 missing .wav files)

We've already fixed the tower scripts (`tower.gd`, `arrow_turret.gd`, `cannon_tower.gd`, `tesla_tower.gd`). This task covers **all remaining scripts**.

## Task 1: Audit ALL scripts for unsafe async patterns

Search every `.gd` file in `scripts/` for these crash patterns and fix them:

### Pattern A: `create_tween()` without tree check
```gdscript
# BEFORE (crashes if node removed from tree)
var tween = create_tween()

# AFTER
if not is_inside_tree():
    return
var tween = create_tween()
```

### Pattern B: `node.create_tween()` on child/spawned node
```gdscript
# BEFORE (crashes if node is freed)
var tween = some_child.create_tween()

# AFTER
if not is_instance_valid(some_child) or not some_child.is_inside_tree():
    return
var tween = some_child.create_tween()
```

### Pattern C: `await get_tree().create_timer()` without guard
```gdscript
# BEFORE (crashes if node freed during await)
await get_tree().create_timer(0.5).timeout
do_stuff()

# AFTER
if not is_inside_tree():
    return
await get_tree().create_timer(0.5).timeout
if not is_inside_tree():
    return
do_stuff()
```

### Pattern D: Tween callback referencing potentially freed nodes
```gdscript
# BEFORE
tween.tween_callback(some_node.queue_free)

# AFTER (queue_free is safe, but method calls aren't)
tween.tween_callback(func(): if is_instance_valid(some_node): some_node.queue_free())
```

### Files to audit (NOT already fixed):
- `scripts/enemy.gd` — has create_tween in take_damage and elite glow
- `scripts/boss_siegebreaker.gd` — has create_tween
- `scripts/boss_lich.gd` — has 5+ create_tween calls
- `scripts/boss_plague_bringer.gd` — has create_tween
- `scripts/boss_bone_colossus.gd` — has create_tween
- `scripts/resource_generator.gd` — has create_tween in pulse effect
- `scripts/player.gd` — has create_tween for berserk glow
- `scripts/pickup.gd` — has create_tween
- `scripts/power_up.gd` — has create_tween
- `scripts/treasure_chest.gd` — has create_tween
- `scripts/projectile_trail.gd` — has create_tween
- `scripts/corpse_fade.gd` — has create_tween
- `scripts/shockwave_ring.gd` — has create_tween
- `scripts/multishot_indicator.gd` — has create_tween on child nodes
- `scripts/game_over_ui.gd` — has create_tween
- `scripts/death_stats_screen.gd` — has create_tween
- `scripts/audio_manager.gd` — has create_tween for fade effects
- `scripts/fx/projectile_trail.gd` — has create_tween
- `scripts/fx/corpse_fade.gd` — has create_tween
- `scripts/fx/shockwave_ring.gd` — has create_tween
- `scripts/fx/multishot_indicator.gd` — has create_tween on child lines

### Already fixed (DO NOT MODIFY):
- `scripts/tower.gd`
- `scripts/arrow_turret.gd`
- `scripts/cannon_tower.gd`
- `scripts/tesla_tower.gd`
- `scripts/fx_manager.gd`
- `scripts/main.gd`
- `scripts/fx.gd`

## Task 2: Silence audio warnings for missing files

The audio manager tries to load 28 .wav files that don't exist yet, spamming the log with "Sound not cached" warnings every time a sound is requested.

In `scripts/audio_manager.gd`:
- Add a Set/Dictionary that tracks which sound names have already warned
- Only print the warning ONCE per sound name, not every call
- Example:
```gdscript
var _warned_sounds: Dictionary = {}

func play_sound(sound_name: String) -> void:
    if not _sound_cache.has(sound_name):
        if not _warned_sounds.has(sound_name):
            push_warning("Sound not cached: %s" % sound_name)
            _warned_sounds[sound_name] = true
        return
    # ... play the sound ...
```

## Acceptance Criteria
- [ ] Every `create_tween()` call in non-fixed scripts has an `is_inside_tree()` guard
- [ ] Every `await get_tree()` has a pre-check and post-check guard
- [ ] Every `node.create_tween()` on a child has `is_instance_valid()` check
- [ ] Audio warnings only print once per missing sound name
- [ ] No functional changes — only safety guards added
- [ ] Commit message: `fix: async safety audit + audio warning dedup`
