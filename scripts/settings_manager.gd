extends Node

signal settings_changed(category: String, key: String, value: Variant)
signal settings_loaded

const SAVE_PATH := "user://settings.json"

const DEFAULT_SETTINGS := {
	"audio": {
		"master_volume": 1.0,
		"sfx_volume": 0.8,
		"music_volume": 0.6,
		"ui_volume": 0.9
	},
	"graphics": {
		"fullscreen": false,
		"vsync": true,
		"quality": "high",
		"render_fps_cap": 30
	},
	"gameplay": {
		"screenshake_intensity": 1.0,
		"damage_numbers": true,
		"show_tower_range": true,
		"auto_collect_gold": false,
		"wave_preview": true,
		"show_stats_in_pause": true
	},
	"accessibility": {
		"colorblind_mode": "none",
		"font_size": 16,
		"screen_flash_reduction": 0.0,
		"reduced_motion": false,
		"high_contrast": false
	}
}

var _settings: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_settings = _deep_copy(DEFAULT_SETTINGS)
	_load_from_disk()
	_apply_all_settings()
	apply_custom_cursor()
	settings_loaded.emit()

const CURSOR_TEXTURE_PATH := "res://assets/ui/cursor_arrowhead_48_v001.png"
# Hotspot sits on the arrowhead tip (near the top of the emblem).
const CURSOR_HOTSPOT := Vector2(8, 2)

func apply_custom_cursor() -> void:
	if not ResourceLoader.exists(CURSOR_TEXTURE_PATH):
		return
	var tex = load(CURSOR_TEXTURE_PATH)
	if not (tex is Texture2D):
		return
	# Apply to every cursor shape so the emblem stays consistent over buttons,
	# the play area, etc. (a Control hovering with a non-ARROW shape would
	# otherwise fall back to the OS cursor in-game).
	for shape in [
		Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_IBEAM,
		Input.CURSOR_CROSS, Input.CURSOR_BUSY, Input.CURSOR_DRAG,
		Input.CURSOR_CAN_DROP, Input.CURSOR_MOVE, Input.CURSOR_HELP,
	]:
		Input.set_custom_mouse_cursor(tex, shape, CURSOR_HOTSPOT)

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
	for category in target.keys():
		var src = target[category]
		if src is Dictionary and merged.has(category) and merged[category] is Dictionary:
			for key in src.keys():
				merged[category][key] = src[key]
		else:
			merged[category] = src
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
		_settings = _merge_defaults(json.data, DEFAULT_SETTINGS)

func _save_to_disk() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SettingsManager: failed to open save file")
		return
	file.store_string(JSON.stringify(_settings, "\t"))
	file.close()

func _apply_all_settings() -> void:
	for category in _settings.keys():
		var bucket = _settings[category]
		if bucket is Dictionary:
			for key in bucket.keys():
				_apply_setting(category, key, bucket[key])

func _apply_setting(category: String, key: String, value: Variant) -> void:
	if category == "audio":
		_apply_audio_setting(key, value)
		return
		if category == "graphics":
			if key == "fullscreen":
				_apply_fullscreen(bool(value))
			elif key == "vsync":
				_apply_vsync(bool(value))
			elif key == "render_fps_cap":
				_apply_render_fps_cap(int(value))

func _apply_audio_setting(key: String, value: Variant) -> void:
	if AudioManager == null:
		return
	match key:
		"master_volume":
			AudioManager.set_master_volume(float(value))
		"sfx_volume":
			AudioManager.set_sfx_volume(float(value))
		"music_volume":
			AudioManager.set_music_volume(float(value))
		"ui_volume":
			AudioManager.set_ui_volume(float(value))

func _apply_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _apply_vsync(enabled: bool) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _apply_render_fps_cap(cap: int) -> void:
	var clamped_cap := clampi(cap, 30, 240)
	Engine.max_fps = clamped_cap

func get_setting(category: String, key: String, default_value: Variant = null) -> Variant:
	if not _settings.has(category):
		return default_value
	var bucket = _settings[category]
	if not (bucket is Dictionary):
		return default_value
	return bucket.get(key, default_value)

func set_setting(category: String, key: String, value: Variant) -> void:
	if not _settings.has(category) or not (_settings[category] is Dictionary):
		_settings[category] = {}
	_settings[category][key] = value
	_apply_setting(category, key, value)
	_save_to_disk()
	settings_changed.emit(category, key, value)

func reset_to_defaults() -> void:
	_settings = _deep_copy(DEFAULT_SETTINGS)
	_apply_all_settings()
	_save_to_disk()
	for category in _settings.keys():
		var bucket = _settings[category]
		if bucket is Dictionary:
			for key in bucket.keys():
				settings_changed.emit(category, key, bucket[key])

func get_master_volume() -> float:
	return float(get_setting("audio", "master_volume", 1.0))

func get_volume(bus: String) -> float:
	match bus:
		"master":
			return get_master_volume()
		"sfx":
			return float(get_setting("audio", "sfx_volume", 0.8))
		"music":
			return float(get_setting("audio", "music_volume", 0.6))
		"ui":
			return float(get_setting("audio", "ui_volume", 0.9))
	return 1.0

func set_master_volume(volume: float) -> void:
	set_setting("audio", "master_volume", clampf(volume, 0.0, 1.0))

func set_sfx_volume(volume: float) -> void:
	set_setting("audio", "sfx_volume", clampf(volume, 0.0, 1.0))

func set_music_volume(volume: float) -> void:
	set_setting("audio", "music_volume", clampf(volume, 0.0, 1.0))

func set_ui_volume(volume: float) -> void:
	set_setting("audio", "ui_volume", clampf(volume, 0.0, 1.0))

func is_fullscreen() -> bool:
	return bool(get_setting("graphics", "fullscreen", false))

func is_vsync() -> bool:
	return bool(get_setting("graphics", "vsync", true))

func get_quality() -> String:
	return str(get_setting("graphics", "quality", "high"))

func get_render_fps_cap() -> int:
	return clampi(int(get_setting("graphics", "render_fps_cap", 30)), 30, 240)

func set_render_fps_cap(cap: int) -> void:
	set_setting("graphics", "render_fps_cap", clampi(cap, 30, 240))

func get_quality_levels() -> Array[String]:
	return ["low", "medium", "high", "ultra"]

func cycle_quality(step: int = 1) -> String:
	var levels = get_quality_levels()
	var current = get_quality().to_lower()
	var idx = levels.find(current)
	if idx < 0:
		idx = levels.find("high")
	var next_idx = posmod(idx + step, levels.size())
	var next_quality = levels[next_idx]
	set_setting("graphics", "quality", next_quality)
	return next_quality

func get_screenshake_intensity() -> float:
	return clampf(float(get_setting("gameplay", "screenshake_intensity", 1.0)), 0.0, 2.0)

func show_damage_numbers() -> bool:
	return bool(get_setting("gameplay", "damage_numbers", true))

func get_colorblind_mode() -> String:
	return str(get_setting("accessibility", "colorblind_mode", "none"))

func get_font_size() -> int:
	return int(get_setting("accessibility", "font_size", 16))

func get_screen_flash_reduction() -> float:
	return clampf(float(get_setting("accessibility", "screen_flash_reduction", 0.0)), 0.0, 1.0)

func is_reduced_motion() -> bool:
	return bool(get_setting("accessibility", "reduced_motion", false))

func is_high_contrast() -> bool:
	return bool(get_setting("accessibility", "high_contrast", false))

func get_fx_density_scale() -> float:
	var quality := get_quality()
	var scale := 1.0
	match quality:
		"low":
			scale = 0.55
		"medium":
			scale = 0.75
		"high":
			scale = 1.0
		"ultra":
			scale = 1.2
		_:
			scale = 1.0
	if is_reduced_motion():
		scale *= 0.75
	return clampf(scale, 0.25, 1.5)

func get_trail_interval_scale() -> float:
	var quality := get_quality()
	var scale := 1.0
	match quality:
		"low":
			scale = 2.4
		"medium":
			scale = 1.6
		"high":
			scale = 1.0
		"ultra":
			scale = 0.85
		_:
			scale = 1.0
	if is_reduced_motion():
		scale = max(scale, 1.8)
	return clampf(scale, 0.7, 3.0)

func get_damage_budget_scale() -> float:
	var quality := get_quality()
	var scale := 1.0
	match quality:
		"low":
			scale = 0.6
		"medium":
			scale = 0.8
		"high":
			scale = 1.0
		"ultra":
			scale = 1.2
		_:
			scale = 1.0
	if is_reduced_motion():
		scale *= 0.8
	return clampf(scale, 0.4, 1.5)

func get_glow_settings() -> Dictionary:
	# Punchy / neon bloom, gated by quality tier for perf safety.
	# Low tier disables glow entirely; higher tiers ramp intensity/bloom.
	var quality := get_quality()
	match quality:
		"low":
			return {"enabled": false, "intensity": 0.0, "strength": 0.0, "bloom": 0.0, "hdr_threshold": 1.0}
		"medium":
			return {"enabled": true, "intensity": 0.55, "strength": 0.9, "bloom": 0.10, "hdr_threshold": 0.95}
		"high":
			return {"enabled": true, "intensity": 0.8, "strength": 1.1, "bloom": 0.18, "hdr_threshold": 0.85}
		"ultra":
			return {"enabled": true, "intensity": 1.0, "strength": 1.25, "bloom": 0.25, "hdr_threshold": 0.75}
		_:
			return {"enabled": true, "intensity": 0.8, "strength": 1.1, "bloom": 0.18, "hdr_threshold": 0.85}

func get_screenshake_multiplier() -> float:
	var mult = get_screenshake_intensity()
	if is_reduced_motion():
		mult *= 0.4
	return clampf(mult, 0.0, 2.0)
