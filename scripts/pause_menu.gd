extends CanvasLayer
class_name PauseMenu

signal resumed
signal settings_opened
signal quit_to_menu
signal quit_to_desktop

@onready var panel: Panel = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var quit_menu_button: Button = $Panel/VBoxContainer/QuitMenuButton
@onready var quit_desktop_button: Button = $Panel/VBoxContainer/QuitDesktopButton
@onready var stats_container: VBoxContainer = $Panel/StatsContainer
@onready var time_label: Label = $Panel/StatsContainer/TimeLabel
@onready var kills_label: Label = $Panel/StatsContainer/KillsLabel
@onready var gold_label: Label = $Panel/StatsContainer/GoldLabel
@onready var level_label: Label = $Panel/StatsContainer/LevelLabel
@onready var wave_label: Label = $Panel/StatsContainer/WaveLabel
@onready var health_label: Label = $Panel/StatsContainer/HealthLabel
@onready var powerups_container: VBoxContainer = $Panel/PowerupsContainer
@onready var powerups_list: Label = $Panel/PowerupsContainer/PowerupsList

var game: Node = null

var _is_paused: bool = false
var _can_pause: bool = true

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if resume_button:
		resume_button.pressed.connect(_on_resume)
	if settings_button:
		settings_button.pressed.connect(_on_settings)
	if quit_menu_button:
		quit_menu_button.pressed.connect(_on_quit_menu)
	if quit_desktop_button:
		quit_desktop_button.pressed.connect(_on_quit_desktop)

	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		if settings_manager.has_signal("settings_changed") and not settings_manager.settings_changed.is_connected(_on_settings_changed):
			settings_manager.settings_changed.connect(_on_settings_changed)
	_apply_stats_visibility()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
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
