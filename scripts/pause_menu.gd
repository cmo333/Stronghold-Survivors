extends CanvasLayer
class_name PauseMenu

signal resumed
signal settings_opened
signal quit_to_menu
signal quit_to_desktop

@onready var panel: Panel = $Panel
@onready var background: ColorRect = $Background
@onready var title_label: Label = $Panel/Title
@onready var hint_label: Label = $Panel/Hint
@onready var stats_title: Label = $Panel/StatsContainer/StatsTitle
@onready var powerups_title: Label = $Panel/PowerupsContainer/PowerupsTitle
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var quality_button: Button = $Panel/VBoxContainer/QualityButton
@onready var quit_menu_button: Button = $Panel/VBoxContainer/QuitMenuButton
@onready var quit_desktop_button: Button = $Panel/VBoxContainer/QuitDesktopButton
@onready var stats_container: VBoxContainer = $Panel/StatsContainer
@onready var time_label: Label = $Panel/StatsContainer/TimeLabel
@onready var kills_label: Label = $Panel/StatsContainer/KillsLabel
@onready var gold_label: Label = $Panel/StatsContainer/GoldLabel
@onready var level_label: Label = $Panel/StatsContainer/LevelLabel
@onready var wave_label: Label = $Panel/StatsContainer/WaveLabel
@onready var health_label: Label = $Panel/StatsContainer/HealthLabel
@onready var quality_label: Label = $Panel/StatsContainer/QualityLabel
@onready var perf_label: Label = $Panel/StatsContainer/PerfLabel
@onready var powerups_container: VBoxContainer = $Panel/PowerupsContainer
@onready var powerups_list: Label = $Panel/PowerupsContainer/PowerupsList

var game: Node = null
const QUALITY_ORDER = ["low", "medium", "high", "ultra"]

# ---- Gothic-arcade styling (matches main_menu.gd) ----
const FONT_PIXEL := "res://assets/ui/pixel_font.ttf"
const PANEL_FRAME := "res://assets/ui/ui_panel_frame_large_512x256_v001.png"
const BTN_NORMAL := "res://assets/ui/ui_button_primary_normal_128x32_v001.png"
const BTN_HOVER := "res://assets/ui/ui_button_primary_hover_128x32_v001.png"
const BTN_PRESSED := "res://assets/ui/ui_button_primary_pressed_128x32_v001.png"

const COLOR_TITLE := Color(1.0, 0.85, 0.35)       # molten gold
const COLOR_ACCENT := Color(0.45, 0.95, 1.0)      # arcane cyan
const COLOR_TEXT := Color(0.88, 0.86, 0.92)
const COLOR_DIM := Color(0.62, 0.60, 0.70)

var _font: FontFile = null

var _is_paused: bool = false
var _can_pause: bool = true

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_font = _load_font()
	_apply_gothic_style()

	if resume_button:
		resume_button.pressed.connect(_on_resume)
	if settings_button:
		settings_button.pressed.connect(_on_settings)
	if quality_button:
		quality_button.pressed.connect(_on_quality_cycle)
	if quit_menu_button:
		quit_menu_button.pressed.connect(_on_quit_menu)
	if quit_desktop_button:
		quit_desktop_button.pressed.connect(_on_quit_desktop)

	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		if settings_manager.has_signal("settings_changed") and not settings_manager.settings_changed.is_connected(_on_settings_changed):
			settings_manager.settings_changed.connect(_on_settings_changed)
		_refresh_quality_ui(str(settings_manager.get_setting("graphics", "quality", "high")))
	_apply_stats_visibility()

# ---- Gothic-arcade theming -------------------------------------------------
# Reskins the scene's existing nodes to match the main menu: pixel font, molten
# gold title with a blood-red outline, ornate metal panel frame, arcane-cyan
# section headings, and themed button textures.

func _apply_gothic_style() -> void:
	if background != null:
		background.color = Color(0.02, 0.02, 0.05, 0.78)
	if panel != null:
		panel.add_theme_stylebox_override("panel", _make_frame_stylebox())
	if title_label != null:
		_apply_font(title_label, 30, COLOR_TITLE)
		title_label.add_theme_constant_override("outline_size", 6)
		title_label.add_theme_color_override("font_outline_color", Color(0.5, 0.05, 0.1))
	if hint_label != null:
		_apply_font(hint_label, 11, COLOR_DIM)
	if stats_title != null:
		_apply_font(stats_title, 16, COLOR_ACCENT)
	if powerups_title != null:
		_apply_font(powerups_title, 16, COLOR_ACCENT)
	for lbl in [time_label, kills_label, gold_label, level_label, wave_label, health_label, quality_label, perf_label, powerups_list]:
		if lbl != null:
			_apply_font(lbl, 12, COLOR_TEXT)
	for btn in [resume_button, settings_button, quality_button, quit_menu_button, quit_desktop_button]:
		if btn != null:
			_apply_font(btn, 14, COLOR_TEXT)
			_style_button(btn)

func _load_font() -> FontFile:
	if not ResourceLoader.exists(FONT_PIXEL):
		return null
	var f = load(FONT_PIXEL)
	return f if f is FontFile else null

func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var t = load(path)
	return t if t is Texture2D else null

func _apply_font(ctrl: Control, size: int, color: Color) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)
	ctrl.add_theme_font_size_override("font_size", size)
	ctrl.add_theme_color_override("font_color", color)

func _make_frame_stylebox() -> StyleBox:
	var tex := _tex(PANEL_FRAME)
	if tex != null:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = 48
		sb.texture_margin_right = 48
		sb.texture_margin_top = 56
		sb.texture_margin_bottom = 48
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.10, 0.08, 0.14, 0.96)
	flat.border_color = COLOR_ACCENT
	flat.set_border_width_all(2)
	flat.set_corner_radius_all(8)
	return flat

func _style_button(btn: Button) -> void:
	var n := _tex(BTN_NORMAL)
	var h := _tex(BTN_HOVER)
	var p := _tex(BTN_PRESSED)
	if n != null:
		btn.add_theme_stylebox_override("normal", _btn_box(n))
		btn.add_theme_stylebox_override("hover", _btn_box(h if h != null else n))
		btn.add_theme_stylebox_override("pressed", _btn_box(p if p != null else n))
		btn.add_theme_stylebox_override("focus", _btn_box(h if h != null else n))
		btn.add_theme_color_override("font_hover_color", COLOR_TITLE)
		btn.add_theme_color_override("font_pressed_color", COLOR_ACCENT)
		btn.add_theme_color_override("font_focus_color", COLOR_TITLE)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.12, 0.20, 0.95)
		sb.border_color = COLOR_ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)

func _btn_box(tex: Texture2D) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 16
	sb.texture_margin_right = 16
	sb.texture_margin_top = 6
	sb.texture_margin_bottom = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _build_interaction_active() -> bool:
	"""True when the build system has something Escape should dismiss first."""
	var game = get_tree().get_first_node_in_group("game")
	if game == null:
		return false
	var bm = game.get("build_manager")
	if bm == null or not is_instance_valid(bm):
		return false
	if bool(bm.get("build_mode")):
		return true
	var sel = bm.get("selected_building")
	return sel != null and is_instance_valid(sel)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# Escape now pauses, but it is also the build-mode cancel key. build_manager
	# polls that action in _process, so it ignores set_input_as_handled() and
	# both would fire off one press. While the player is mid-placement, let
	# Escape mean "cancel this" — pausing is the fallback when nothing is
	# waiting to be dismissed.
	if not _is_paused and event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		if _build_interaction_active():
			return
	if _is_paused:
		if _can_pause:
			unpause()
		get_viewport().set_input_as_handled()
		return
	if _can_pause:
		pause()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _is_paused:
		_update_stats()

func setup(game_ref: Node) -> void:
	game = game_ref

func pause() -> void:
	if _is_paused or not _can_pause:
		return

	_is_paused = true
	visible = true
	get_tree().paused = true

	if panel:
		var viewport_size = get_viewport().get_visible_rect().size
		panel.position = (viewport_size - panel.size) / 2

	_update_stats()
	_set_bus_muted("SFX", true)

	if resume_button:
		resume_button.grab_focus()

func unpause() -> void:
	if not _is_paused:
		return

	_is_paused = false
	visible = false
	get_tree().paused = false
	_set_bus_muted("SFX", false)
	resumed.emit()

func toggle() -> void:
	if _is_paused:
		unpause()
	else:
		pause()

func is_paused() -> bool:
	return _is_paused

func set_can_pause(can_pause: bool) -> void:
	_can_pause = can_pause

func _update_stats() -> void:
	if game == null or stats_container == null:
		return

	var run_time = _format_time(float(game.get("elapsed")) if game.get("elapsed") != null else 0.0)
	var kills = int(game.get("_enemy_kill_count")) if game.get("_enemy_kill_count") != null else 0
	var resources = int(game.get("resources")) if game.get("resources") != null else 0
	var level = int(game.get("level")) if game.get("level") != null else 1
	var wave = 1
	var wave_manager = game.get("wave_manager")
	if wave_manager != null and wave_manager.has_method("get_current_wave"):
		wave = int(wave_manager.get_current_wave())

	var player_health = 0
	var player_max_health = 100
	var player = game.get("player")
	if player != null:
		player_health = int(player.get("health")) if player.get("health") != null else 0
		player_max_health = int(player.get("max_health")) if player.get("max_health") != null else 100

	if time_label:
		time_label.text = "Time: %s" % run_time
	if kills_label:
		kills_label.text = "Kills: %d" % kills
	if gold_label:
		gold_label.text = "Gold: %d" % resources
	if level_label:
		level_label.text = "Level: %d" % level
	if wave_label:
		wave_label.text = "Wave: %d" % wave
	if health_label:
		health_label.text = "Health: %d/%d" % [player_health, player_max_health]
	if game != null and game.has_method("get_runtime_perf_snapshot"):
		var perf = game.get_runtime_perf_snapshot()
		if perf is Dictionary:
			var quality = str(perf.get("quality", "high"))
			var fps = int(perf.get("fps", 0))
			var adaptive_pct = int(round(float(perf.get("adaptive_scale", 1.0)) * 100.0))
			if quality_label:
				quality_label.text = "Quality: %s | FX %d | Proj %d" % [quality.capitalize(), int(perf.get("max_particles", 0)), int(perf.get("max_projectiles", 0))]
			if perf_label:
				perf_label.text = "Perf: %d FPS | %d%% | Enemies %d | Towers %d" % [fps, adaptive_pct, int(perf.get("enemy_count", 0)), int(perf.get("tower_count", 0))]
			_refresh_quality_ui(quality)

	_update_powerups()

func _update_powerups() -> void:
	if powerups_list == null:
		return
	if game == null:
		powerups_list.text = "No upgrades selected yet."
		return
	var levels_raw = game.get("tech_levels")
	if not (levels_raw is Dictionary):
		powerups_list.text = "No upgrades selected yet."
		return
	var defs_raw = game.get("tech_defs")
	var defs: Dictionary = defs_raw if defs_raw is Dictionary else {}
	var entries: Array = []
	for id in levels_raw.keys():
		var lvl = int(levels_raw.get(id, 0))
		if lvl <= 0:
			continue
		var name = str(id)
		var def = defs.get(id, {})
		if def is Dictionary:
			name = str(def.get("name", id))
		entries.append({
			"name": name,
			"lvl": lvl
		})
	if entries.is_empty():
		powerups_list.text = "No upgrades selected yet."
		return
	entries.sort_custom(func(a, b):
		if int(a["lvl"]) == int(b["lvl"]):
			return str(a["name"]) < str(b["name"])
		return int(a["lvl"]) > int(b["lvl"])
	)
	var lines: Array[String] = []
	var max_lines = 10
	for i in range(min(entries.size(), max_lines)):
		var entry = entries[i]
		lines.append("- %s Lv %d" % [entry["name"], entry["lvl"]])
	if entries.size() > max_lines:
		lines.append("+%d more" % (entries.size() - max_lines))
	powerups_list.text = "\n".join(lines)

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_resume() -> void:
	unpause()

func _on_settings() -> void:
	settings_opened.emit()

func _on_quality_cycle() -> void:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager == null:
		return
	var next_quality = "high"
	if settings_manager.has_method("cycle_quality"):
		next_quality = str(settings_manager.cycle_quality(1))
	else:
		var current = str(settings_manager.get_setting("graphics", "quality", "high")).to_lower()
		var idx = QUALITY_ORDER.find(current)
		if idx < 0:
			idx = QUALITY_ORDER.find("high")
		next_quality = QUALITY_ORDER[(idx + 1) % QUALITY_ORDER.size()]
		settings_manager.set_setting("graphics", "quality", next_quality)
	_refresh_quality_ui(next_quality)

func _on_quit_menu() -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and game:
		save_manager.update_run_data(game)
		save_manager.save_recovery_data()

	unpause()
	quit_to_menu.emit()

func _on_quit_desktop() -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and game:
		save_manager.update_run_data(game)
		save_manager.save_recovery_data()

	get_tree().quit()

func _on_settings_changed(category: String, key: String, value: Variant) -> void:
	if category == "gameplay" and key == "show_stats_in_pause":
		_apply_stats_visibility()
	elif category == "graphics" and key == "quality":
		_refresh_quality_ui(str(value))

func _apply_stats_visibility() -> void:
	var settings_manager = get_node_or_null("/root/SettingsManager")
	var show_stats = true
	if settings_manager != null:
		show_stats = bool(settings_manager.get_setting("gameplay", "show_stats_in_pause", true))
	if stats_container:
		stats_container.visible = show_stats
	if powerups_container:
		powerups_container.visible = show_stats

func _set_bus_muted(bus_name: String, muted: bool) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, muted)

func _refresh_quality_ui(quality: String) -> void:
	var normalized = quality.to_lower()
	if not QUALITY_ORDER.has(normalized):
		normalized = "high"
	if quality_button:
		quality_button.text = "Quality: %s" % normalized.capitalize()
