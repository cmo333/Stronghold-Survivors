extends Node

# ============================================
# SettingsManager - persistent game settings
# Backs scripts/settings_menu.gd. Stores to user://settings.cfg,
# applies audio via AudioManager and window flags via DisplayServer.
# ============================================

const SETTINGS_PATH = "user://settings.cfg"

const DEFAULTS = {
	"audio": {
		"master_volume": 1.0,
		"sfx_volume": 0.8,
		"music_volume": 0.6,
		"ui_volume": 0.9,
	},
	"graphics": {
		"fullscreen": false,
		"vsync": true,
		"quality": "high",
	},
	"gameplay": {
		"screenshake_intensity": 1.0,
		"damage_numbers": true,
		"show_tower_range": true,
		"auto_collect_gold": false,
		"wave_preview": true,
	},
	"accessibility": {
		"colorblind_mode": "none",
		"font_size": 16,
		"screen_flash_reduction": 0.0,
		"reduced_motion": false,
		"high_contrast": false,
	},
}

var _settings: Dictionary = {}

func _ready() -> void:
	_load()
	_apply_all()

func _load() -> void:
	_settings = {}
	for category in DEFAULTS.keys():
		_settings[category] = DEFAULTS[category].duplicate()
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for category in cfg.get_sections():
		if not _settings.has(category):
			_settings[category] = {}
		for key in cfg.get_section_keys(category):
			_settings[category][key] = cfg.get_value(category, key)

func _save() -> void:
	var cfg = ConfigFile.new()
	for category in _settings.keys():
		for key in _settings[category].keys():
			cfg.set_value(category, key, _settings[category][key])
	cfg.save(SETTINGS_PATH)

func _apply_all() -> void:
	_apply_audio()
	_apply_graphics()

func _apply_audio() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	am.set_master_volume(float(get_setting("audio", "master_volume", 1.0)))
	am.set_sfx_volume(float(get_setting("audio", "sfx_volume", 0.8)))
	am.set_music_volume(float(get_setting("audio", "music_volume", 0.6)))
	am.set_ui_volume(float(get_setting("audio", "ui_volume", 0.9)))

func _apply_graphics() -> void:
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_setting("graphics", "fullscreen", false)) \
		else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	var vsync = DisplayServer.VSYNC_ENABLED if bool(get_setting("graphics", "vsync", true)) \
		else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)

# ---------------- generic access ----------------

func get_setting(category: String, key: String, default_value = null):
	if _settings.has(category) and _settings[category].has(key):
		return _settings[category][key]
	return default_value

func set_setting(category: String, key: String, value) -> void:
	if not _settings.has(category):
		_settings[category] = {}
	_settings[category][key] = value
	_save()
	match category:
		"audio":
			_apply_audio()
		"graphics":
			_apply_graphics()

func reset_to_defaults() -> void:
	_settings = {}
	for category in DEFAULTS.keys():
		_settings[category] = DEFAULTS[category].duplicate()
	_save()
	_apply_all()

# ---------------- typed getters used by settings_menu.gd ----------------

func get_master_volume() -> float:
	return float(get_setting("audio", "master_volume", 1.0))

func get_volume(bus: String) -> float:
	return float(get_setting("audio", "%s_volume" % bus, 0.8))

func is_fullscreen() -> bool:
	return bool(get_setting("graphics", "fullscreen", false))

func is_vsync() -> bool:
	return bool(get_setting("graphics", "vsync", true))

func get_quality() -> String:
	return str(get_setting("graphics", "quality", "high"))

func get_screenshake_intensity() -> float:
	return float(get_setting("gameplay", "screenshake_intensity", 1.0))

func show_damage_numbers() -> bool:
	return bool(get_setting("gameplay", "damage_numbers", true))

func get_colorblind_mode() -> String:
	return str(get_setting("accessibility", "colorblind_mode", "none"))

func get_font_size() -> int:
	return int(get_setting("accessibility", "font_size", 16))

func get_screen_flash_reduction() -> float:
	return float(get_setting("accessibility", "screen_flash_reduction", 0.0))

func is_reduced_motion() -> bool:
	return bool(get_setting("accessibility", "reduced_motion", false))

func is_high_contrast() -> bool:
	return bool(get_setting("accessibility", "high_contrast", false))

# ---------------- volume setters (live preview from the menu) ----------------

func set_master_volume(value: float) -> void:
	set_setting("audio", "master_volume", clampf(value, 0.0, 1.0))

func set_sfx_volume(value: float) -> void:
	set_setting("audio", "sfx_volume", clampf(value, 0.0, 1.0))

func set_music_volume(value: float) -> void:
	set_setting("audio", "music_volume", clampf(value, 0.0, 1.0))

func set_ui_volume(value: float) -> void:
	set_setting("audio", "ui_volume", clampf(value, 0.0, 1.0))
