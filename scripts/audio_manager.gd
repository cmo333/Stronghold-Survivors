extends Node

# ============================================
# AudioManager - Singleton for all game audio
# Handles SFX, Music, UI sounds with spatial audio
# ============================================

const MAX_SFX_CHANNELS = 32
const DEFAULT_PRIORITY = 0
const HIGH_PRIORITY = 10
const CRITICAL_PRIORITY = 20

# Audio bus indices
var master_bus: int = 0
var sfx_bus: int = 1
var music_bus: int = 2
var ui_bus: int = 3

# Volume settings (0.0 to 1.0)
var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.6
var ui_volume: float = 0.9

# SFX categories with sound arrays
var sfx_categories = {
	"weapon": [],
	"impact": [],
	"ui": [],
	"ambient": [],
	"special": []
}

# Currently playing sounds for priority management
var _active_sfx: Array[Dictionary] = []

# Music players for crossfading
var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _current_music_player: AudioStreamPlayer = null
var _is_crossfading: bool = false

# Camera reference for spatial audio
var _camera: Camera2D = null
var _viewport_size: Vector2 = Vector2(1280, 720)

# Preloaded sounds cache
var _sound_cache: Dictionary = {}

# SFX pool for one-shot sounds
var _sfx_pool: Array[AudioStreamPlayer2D] = []

func _ready() -> void:
	_setup_audio_buses()
	_create_music_players()
	_create_sfx_pool()
	_cache_sounds()
	_update_bus_volumes()

func _setup_audio_buses() -> void:
	"""Ensure audio buses are configured properly"""
	# Get bus indices (Master always exists as 0)
	master_bus = AudioServer.get_bus_index("Master")
	
	# Create SFX bus if doesn't exist
	if AudioServer.get_bus_count() < 2:
		AudioServer.add_bus()
	AudioServer.set_bus_name(1, "SFX")
	sfx_bus = 1
	
	# Create Music bus if doesn't exist
	if AudioServer.get_bus_count() < 3:
		AudioServer.add_bus()
	AudioServer.set_bus_name(2, "Music")
	music_bus = 2
	
	# Create UI bus if doesn't exist
	if AudioServer.get_bus_count() < 4:
		AudioServer.add_bus()
	AudioServer.set_bus_name(3, "UI")
	ui_bus = 3
	
	# Route buses to Master
	AudioServer.set_bus_send(sfx_bus, "Master")
	AudioServer.set_bus_send(music_bus, "Master")
	AudioServer.set_bus_send(ui_bus, "Master")

func _create_music_players() -> void:
	"""Create two music players for crossfading"""
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	_music_player_a.name = "MusicPlayerA"
	add_child(_music_player_a)
	
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	_music_player_b.name = "MusicPlayerB"
	add_child(_music_player_b)
	
	_current_music_player = _music_player_a

func _create_sfx_pool() -> void:
	"""Create a pool of 2D audio players for spatial SFX"""
	for i in range(MAX_SFX_CHANNELS):
		var player = AudioStreamPlayer2D.new()
		player.name = "SFXPool_%d" % i
		player.bus = "SFX"
		player.max_distance = 800.0
		player.attenuation = 1.5
		player.max_polyphony = 1
		add_child(player)
		_sfx_pool.append(player)

func _cache_sounds() -> void:
	"""Preload and categorize all sound effects"""
	# Weapon sounds
	_cache_sound("gun_fire_01", "res://assets/audio/sfx/gun_fire_01.wav", "weapon")
	_cache_sound("gun_fire_02", "res://assets/audio/sfx/gun_fire_02.wav", "weapon")
	_cache_sound("gun_fire_03", "res://assets/audio/sfx/gun_fire_03.wav", "weapon")
	_cache_sound("cannon_boom", "res://assets/audio/sfx/cannon_boom.wav", "weapon")
	_cache_sound("lightning_crack", "res://assets/audio/sfx/lightning_crack.wav", "weapon")
	_cache_sound("arrow_shoot", "res://assets/audio/sfx/arrow_shoot.wav", "weapon")
	
	# Impact sounds
	_cache_sound("enemy_hit_01", "res://assets/audio/sfx/enemy_hit_01.wav", "impact")
	_cache_sound("enemy_hit_02", "res://assets/audio/sfx/enemy_hit_02.wav", "impact")
	_cache_sound("enemy_hit_03", "res://assets/audio/sfx/enemy_hit_03.wav", "impact")
	_cache_sound("crit_hit", "res://assets/audio/sfx/crit_hit.wav", "impact")
	_cache_sound("enemy_death_01", "res://assets/audio/sfx/enemy_death_01.wav", "impact")
	_cache_sound("enemy_death_02", "res://assets/audio/sfx/enemy_death_02.wav", "impact")
	_cache_sound("enemy_death_03", "res://assets/audio/sfx/enemy_death_03.wav", "impact")
	_cache_sound("building_hit", "res://assets/audio/sfx/building_hit.wav", "impact")
	_cache_sound("shield_hit", "res://assets/audio/sfx/shield_hit.wav", "impact")
	
	# UI sounds
	_cache_sound("click", "res://assets/audio/ui/click.wav", "ui")
	_cache_sound("hover", "res://assets/audio/ui/hover.wav", "ui")
	_cache_sound("upgrade", "res://assets/audio/ui/upgrade.wav", "ui")
	_cache_sound("error", "res://assets/audio/ui/error.wav", "ui")
	_cache_sound("wave_start", "res://assets/audio/ui/wave_start.wav", "ui")
	_cache_sound("level_up", "res://assets/audio/ui/level_up.wav", "ui")
	
	# Ambient sounds
	_cache_sound("generator_hum", "res://assets/audio/ambient/generator_hum.wav", "ambient")
	_cache_sound("wind", "res://assets/audio/ambient/wind.wav", "ambient")
	_cache_sound("distant_battle", "res://assets/audio/ambient/distant_battle.wav", "ambient")
	
	# Special sounds
	_cache_sound("chest_open", "res://assets/audio/special/chest_open.wav", "special")
	_cache_sound("powerup_spawn", "res://assets/audio/special/powerup_spawn.wav", "special")
	_cache_sound("powerup_pickup", "res://assets/audio/special/powerup_pickup.wav", "special")
	_cache_sound("generator_destroyed", "res://assets/audio/special/generator_destroyed.wav", "special")
	_cache_sound("heartbeat", "res://assets/audio/special/heartbeat.wav", "special")
	_cache_sound("game_over", "res://assets/audio/special/game_over.wav", "special")
	_cache_sound("victory", "res://assets/audio/special/victory.wav", "special")
	_cache_sound("berserk_activate", "res://assets/audio/special/berserk_activate.wav", "special")

func _cache_sound(name: String, path: String, category: String) -> void:
	"""Load a sound and add to category"""
	var stream = load(path)
	if stream != null:
		_sound_cache[name] = stream
		if sfx_categories.has(category):
			sfx_categories[category].append(name)
	else:
		# Sound not found - will use placeholder in play function
		pass

# ============================================
# PUBLIC API
# ============================================

func play_one_shot(sound_name: String, position: Vector2 = Vector2.ZERO, priority: int = DEFAULT_PRIORITY) -> void:
	"""
	Play a single sound effect
	- sound_name: Name of the cached sound
	- position: World position for spatial audio (Vector2.ZERO for non-spatial)
	- priority: Higher priority sounds can interrupt lower priority ones
	"""
	if not _sound_cache.has(sound_name):
		# Try to load on-the-fly or use placeholder
		push_warning("Sound not cached: %s" % sound_name)
		return
	
	var stream = _sound_cache[sound_name]
	
	# Calculate volume based on screen position for spatial audio
	var volume_db = 0.0
	if position != Vector2.ZERO and _camera != null:
		volume_db = _calculate_spatial_volume(position)
		if volume_db < -60.0:  # Too far to hear
			return
	
	# Get available player from pool
	var player = _get_available_sfx_player(priority)
	if player == null:
		return
	
	player.stream = stream
	player.volume_db = volume_db
	
	if position != Vector2.ZERO:
		player.global_position = position
		player.attenuation = 1.5
	
	player.play()
	
	# Track active SFX
	_active_sfx.append({
		"player": player,
		"priority": priority,
		"time": Time.get_ticks_msec()
	})

func play_random_from_category(category: String, position: Vector2 = Vector2.ZERO, priority: int = DEFAULT_PRIORITY) -> void:
	"""Play a random sound from a category"""
	if not sfx_categories.has(category):
		push_warning("Unknown category: %s" % category)
		return
	
	var sounds = sfx_categories[category]
	if sounds.is_empty():
		return
	
	var random_sound = sounds[randi() % sounds.size()]
	play_one_shot(random_sound, position, priority)

func play_weapon_sound(weapon_type: String, position: Vector2) -> void:
	"""Play appropriate weapon sound"""
	match weapon_type:
		"gun":
			play_random_from_category("weapon", position, DEFAULT_PRIORITY)
		"cannon":
			play_one_shot("cannon_boom", position, HIGH_PRIORITY)
		"lightning":
			play_one_shot("lightning_crack", position, HIGH_PRIORITY)
		"arrow":
			play_one_shot("arrow_shoot", position, DEFAULT_PRIORITY)

func play_impact_sound(is_crit: bool = false, is_death: bool = false, position: Vector2 = Vector2.ZERO) -> void:
	"""Play impact sound based on hit type"""
	if is_death:
		play_random_from_category("impact", position, DEFAULT_PRIORITY)
	elif is_crit:
		play_one_shot("crit_hit", position, HIGH_PRIORITY)
	else:
		play_random_from_category("impact", position, DEFAULT_PRIORITY)

func play_ui_sound(sound_name: String) -> void:
	"""Play UI sound (non-spatial)"""
	if _sound_cache.has(sound_name):
		var player = AudioStreamPlayer.new()
		player.bus = "UI"
		player.stream = _sound_cache[sound_name]
		player.finished.connect(func(): player.queue_free())
		add_child(player)
		player.play()

func play_music(music_name: String, crossfade_duration: float = 2.0) -> void:
	"""
	Play music track with crossfade
	- music_name: Name of the music track
	- crossfade_duration: Duration of crossfade in seconds
	"""
	var music_path = "res://assets/audio/music/%s.ogg" % music_name
	var stream = load(music_path)
	if stream == null:
		push_warning("Music not found: %s" % music_path)
		return
	
	if _is_crossfading:
		return
	
	var next_player = _music_player_a if _current_music_player == _music_player_b else _music_player_b
	next_player.stream = stream
	next_player.volume_db = -80.0  # Start silent
	next_player.play()
	
	_is_crossfading = true
	
	# Create crossfade tween
	var tween = create_tween()
	tween.set_parallel()
	
	# Fade out current
	if _current_music_player.playing:
		tween.tween_property(_current_music_player, "volume_db", -80.0, crossfade_duration)
	
	# Fade in next
	tween.tween_property(next_player, "volume_db", 0.0, crossfade_duration)
	
	tween.chain().tween_callback(func():
		if _current_music_player.playing:
			_current_music_player.stop()
		_current_music_player = next_player
		_is_crossfading = false
	)

func stop_music(fade_duration: float = 1.0) -> void:
	"""Stop music with optional fade out"""
	if not _current_music_player.playing:
		return
	
	var tween = create_tween()
	tween.tween_property(_current_music_player, "volume_db", -80.0, fade_duration)
	tween.tween_callback(func():
		_current_music_player.stop()
		_current_music_player.volume_db = 0.0
	)

func play_ambient(ambient_name: String, fade_in: float = 3.0) -> void:
	"""Start ambient sound loop"""
	var ambient_path = "res://assets/audio/ambient/%s.ogg" % ambient_name
	var stream = load(ambient_path)
	if stream == null:
		return
	
	# Use a dedicated ambient player
	var ambient_player = get_node_or_null("AmbientPlayer")
	if ambient_player == null:
		ambient_player = AudioStreamPlayer.new()
		ambient_player.name = "AmbientPlayer"
		ambient_player.bus = "Ambient"
		add_child(ambient_player)
	
	ambient_player.stream = stream
	ambient_player.volume_db = -80.0
	ambient_player.play()
	
	var tween = create_tween()
	tween.tween_property(ambient_player, "volume_db", 0.0, fade_in)

# ============================================
# VOLUME CONTROLS
# ============================================

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	_update_bus_volumes()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	_update_bus_volumes()

func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	_update_bus_volumes()

func set_ui_volume(volume: float) -> void:
	ui_volume = clamp(volume, 0.0, 1.0)
	_update_bus_volumes()

func _update_bus_volumes() -> void:
	"""Update all audio bus volumes"""
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(ui_bus, linear_to_db(ui_volume))

func mute_all(muted: bool) -> void:
	"""Mute or unmute all audio"""
	AudioServer.set_bus_mute(master_bus, muted)

func mute_sfx(muted: bool) -> void:
	"""Mute or unmute SFX bus"""
	AudioServer.set_bus_mute(sfx_bus, muted)

func mute_music(muted: bool) -> void:
	"""Mute or unmute Music bus"""
	AudioServer.set_bus_mute(music_bus, muted)

# ============================================
# SPATIAL AUDIO
# ============================================

func set_camera(camera: Camera2D) -> void:
	"""Set reference camera for spatial audio calculations"""
	_camera = camera
	if camera != null:
		_viewport_size = camera.get_viewport_rect().size

func _calculate_spatial_volume(position: Vector2) -> float:
	"""
	Calculate volume attenuation based on screen position
	Returns volume in dB (0 = full volume, -80 = silent)
	"""
	if _camera == null:
		return 0.0
	
	var camera_pos = _camera.global_position
	var distance = position.distance_to(camera_pos)
	var screen_edge_dist = _viewport_size.x * 0.6  # Distance at which sound starts fading
	
	# Full volume within screen bounds
	if distance < _viewport_size.x * 0.5:
		return 0.0
	
	# Fade out beyond screen edge
	var fade_dist = screen_edge_dist - (_viewport_size.x * 0.5)
	var fade_ratio = (distance - _viewport_size.x * 0.5) / fade_dist
	fade_ratio = clamp(fade_ratio, 0.0, 1.0)
	
	# Convert to dB (smooth fade from 0 to -40dB)
	return lerp(0.0, -40.0, fade_ratio)

func _get_available_sfx_player(priority: int) -> AudioStreamPlayer2D:
	"""
	Get an available SFX player from the pool
	If all busy, may interrupt a lower priority sound
	"""
	# First, try to find a free player
	for player in _sfx_pool:
		if not player.playing:
			return player
	
	# All busy - check if we can interrupt a lower priority sound
	if priority > DEFAULT_PRIORITY:
		var lowest_priority = CRITICAL_PRIORITY
		var candidate = null
		
		for sfx in _active_sfx:
			if sfx["priority"] < lowest_priority and sfx["priority"] < priority:
				lowest_priority = sfx["priority"]
				candidate = sfx["player"]
		
		if candidate != null:
			candidate.stop()
			return candidate
	
	return null

# ============================================
# CLEANUP
# ============================================

func _process(_delta: float) -> void:
	"""Clean up finished SFX from tracking"""
	_active_sfx = _active_sfx.filter(func(sfx):
		var player = sfx["player"] as AudioStreamPlayer2D
		return player != null and player.playing
	)

func stop_all_sfx() -> void:
	"""Stop all playing SFX immediately"""
	for player in _sfx_pool:
		player.stop()
	_active_sfx.clear()

# ============================================
# HELPER FUNCTIONS
# ============================================

func is_sound_loaded(sound_name: String) -> bool:
	return _sound_cache.has(sound_name)

func get_category_sounds(category: String) -> Array:
	if sfx_categories.has(category):
		return sfx_categories[category].duplicate()
	return []

func preload_sound(sound_name: String, path: String) -> bool:
	"""Dynamically preload a sound at runtime"""
	var stream = load(path)
	if stream != null:
		_sound_cache[sound_name] = stream
		return true
	return false
