# ============================================
# Audio Integration Helper
# 
# This file documents how to integrate audio into existing game scripts.
# Copy these snippets into the relevant scripts.
# ============================================

# ============================================
# PLAYER.GD - Add these audio calls
# ============================================

# In _physics_process, when shooting:
# After: _game.spawn_projectile(...)
# Add:
#   AudioManager.play_weapon_sound("gun", global_position)

# In take_damage:
# After: _game.trigger_damage_flash()
# Add:
#   AudioManager.play_one_shot("shield_hit", global_position)

# In start_death_animation:
# Add at the start:
#   AudioManager.play_one_shot("heartbeat", global_position, AudioManager.HIGH_PRIORITY)

# In apply_berserk_buff:
# Add:
#   AudioManager.play_one_shot("berserk_activate", global_position, AudioManager.HIGH_PRIORITY)

# ============================================
# ENEMY.GD - Add these audio calls
# ============================================

# In take_damage function (add if not present, or modify existing):
# When enemy takes damage:
#   AudioManager.play_impact_sound(false, false, global_position)

# When enemy dies (wherever death is handled):
#   AudioManager.play_impact_sound(false, true, global_position)

# In elite glow/visual effects:
#   AudioManager.play_one_shot("powerup_spawn", global_position)

# ============================================
# MAIN.GD - Add these audio calls
# ============================================

# In _ready:
#   AudioManager.set_camera(camera)
#   AudioManager.play_music("battle_theme")

# When spawning enemies (spawn_enemy function):
#   if randf() < 0.1:  # Don't play for every spawn
#       AudioManager.play_one_shot("distant_battle", spawn_position, AudioManager.DEFAULT_PRIORITY)

# When wave starts:
#   AudioManager.play_ui_sound("wave_start")

# When player levels up:
#   AudioManager.play_ui_sound("level_up")

# When generator is destroyed:
#   AudioManager.play_one_shot("generator_destroyed", position, AudioManager.HIGH_PRIORITY)

# When chest is opened:
#   AudioManager.play_one_shot("chest_open", chest_position)

# When powerup is picked up:
#   AudioManager.play_one_shot("powerup_pickup", pickup_position)

# On game over:
#   AudioManager.play_one_shot("game_over", player.global_position, AudioManager.CRITICAL_PRIORITY)
#   AudioManager.stop_music(2.0)

# On victory:
#   AudioManager.play_one_shot("victory", player.global_position, AudioManager.CRITICAL_PRIORITY)

# ============================================
# TOWER.GD - Add these audio calls
# ============================================

# When tower fires:
#   AudioManager.play_weapon_sound("arrow", global_position)  # or "cannon", "lightning"

# When tower is hit:
#   AudioManager.play_one_shot("building_hit", global_position)

# ============================================
# UI.GD - Add these audio calls
# ============================================

# On button hover:
#   AudioManager.play_ui_sound("hover")

# On button click:
#   AudioManager.play_ui_sound("click")

# On upgrade selected:
#   AudioManager.play_ui_sound("upgrade")

# On error (can't build, etc.):
#   AudioManager.play_ui_sound("error")

# ============================================
# TREASURE_CHEST.GD - Add these audio calls
# ============================================

# When chest opens:
#   AudioManager.play_one_shot("chest_open", global_position)

# ============================================
# BUILDING.GD / RESOURCE_GENERATOR.GD
# ============================================

# When building takes damage:
#   AudioManager.play_one_shot("building_hit", global_position)

# When generator is destroyed:
#   AudioManager.play_one_shot("generator_destroyed", global_position, AudioManager.HIGH_PRIORITY)

# For ambient generator hum (optional, add loop):
#   Could add an Area2D that plays generator_hum when player is near

# ============================================
# PROJECTILE.GD
# ============================================

# When projectile hits target:
#   AudioManager.play_impact_sound(false, false, collision_position)

# When critical hit:
#   AudioManager.play_impact_sound(true, false, collision_position)

# ============================================
# VOLUME CONTROL UI (Add to settings menu)
# ============================================

# Master volume slider:
#   AudioManager.set_master_volume(slider_value)

# SFX volume slider:
#   AudioManager.set_sfx_volume(slider_value)

# Music volume slider:
#   AudioManager.set_music_volume(slider_value)

# UI volume slider:
#   AudioManager.set_ui_volume(slider_value)

# Mute toggle:
#   AudioManager.mute_all(is_muted)
