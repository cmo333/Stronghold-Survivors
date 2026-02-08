# Audio Design System

## Overview
The audio system for Stronghold Survivors provides spatial 2D audio, categorized SFX, music crossfading, and volume controls. Even placeholder audio makes the game feel 10x better!

## Architecture

### AudioManager (Singleton)
Located at `scripts/audio_manager.gd` - automatically loaded as an autoload singleton.

### Audio Buses
1. **Master** - Overall volume control
2. **SFX** - All gameplay sound effects
3. **Music** - Background music
4. **UI** - Interface sounds

## Usage

### Playing Sounds

```gdscript
# Play a single sound effect
AudioManager.play_one_shot("gun_fire_01", global_position)

# Play random sound from category
AudioManager.play_random_from_category("weapon", global_position)

# Play weapon-specific sound
AudioManager.play_weapon_sound("gun", global_position)

# Play impact sound (supports crit and death variants)
AudioManager.play_impact_sound(is_crit, is_death, global_position)

# Play UI sound (non-spatial)
AudioManager.play_ui_sound("click")
```

### Volume Control

```gdscript
# Set individual bus volumes (0.0 to 1.0)
AudioManager.set_master_volume(0.8)
AudioManager.set_sfx_volume(0.9)
AudioManager.set_music_volume(0.6)
AudioManager.set_ui_volume(0.9)

# Mute controls
AudioManager.mute_all(true)
AudioManager.mute_sfx(true)
AudioManager.mute_music(true)
```

### Music

```gdscript
# Play music with crossfade
AudioManager.play_music("battle_theme", 2.0)

# Stop music with fade out
AudioManager.stop_music(1.0)
```

### Spatial Audio Setup

```gdscript
# In your main scene _ready()
AudioManager.set_camera($Player/Camera2D)
```

## SFX Categories

### Weapon
- `gun_fire_01`, `gun_fire_02`, `gun_fire_03`
- `cannon_boom`
- `lightning_crack`
- `arrow_shoot`

### Impact
- `enemy_hit_01`, `enemy_hit_02`, `enemy_hit_03`
- `crit_hit`
- `enemy_death_01`, `enemy_death_02`, `enemy_death_03`
- `building_hit`
- `shield_hit`

### UI
- `click`
- `hover`
- `upgrade`
- `error`
- `wave_start`
- `level_up`

### Ambient
- `generator_hum`
- `wind`
- `distant_battle`

### Special
- `chest_open`
- `powerup_spawn`
- `powerup_pickup`
- `generator_destroyed`
- `heartbeat`
- `game_over`
- `victory`
- `berserk_activate`

## Priority System

```gdscript
AudioManager.DEFAULT_PRIORITY   # 0 - Normal sounds
AudioManager.HIGH_PRIORITY      # 10 - Important sounds
AudioManager.CRITICAL_PRIORITY  # 20 - Must-play sounds
```

Higher priority sounds can interrupt lower priority sounds when the SFX pool is full.

## Spatial Audio Features

- **Screen-edge attenuation**: Sounds fade as they move off-screen
- **Distance-based volume**: Closer sounds are louder
- **Priority management**: Important sounds always play

## Integration Points

The following scripts have audio integrated:

| Script | Audio Events |
|--------|--------------|
| `player.gd` | Gun fire, shield hit (damage), heartbeat (death), berserk activation |
| `enemy.gd` | Hit sounds, death sounds |
| `tower.gd` | Tower firing sounds (arrow/cannon/lightning) |
| `main.gd` | Wave start, level up, game over, victory |
| `treasure_chest.gd` | Chest opening |
| `power_up.gd` | Powerup spawn and pickup |
| `resource_generator.gd` | Building hit, generator destroyed |
| `game_over_ui.gd` | Button hover and click |

## Placeholder Audio Generation

Run the audio placeholder generator from Godot Editor:

1. Open the script: `scripts/audio_placeholder_generator.gd`
2. Select File > Run > AudioPlaceholderGenerator
3. This will generate synthesized WAV files in `assets/audio/`

## Adding New Sounds

1. Add the sound file to the appropriate folder in `assets/audio/`
2. Add to `_cache_sounds()` in `audio_manager.gd`:

```gdscript
_cache_sound("my_new_sound", "res://assets/audio/sfx/my_new_sound.wav", "weapon")
```

3. Play it in your code:

```gdscript
AudioManager.play_one_shot("my_new_sound", global_position)
```

## Performance Notes

- SFX pool limited to 32 concurrent sounds
- Sounds too far off-screen are not played
- Automatic cleanup of finished sounds
- Sound cache prevents repeated disk loads

## Future Enhancements

- Dynamic music system based on intensity
- Reverb zones for indoor areas
- Footstep sounds based on terrain
- Environmental audio (wind, rain)
