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
@onready var game: Node = null

var _is_paused: bool = false
var _can_pause: bool = true

func _ready() -> void:
	layer = 100  # Ensure pause menu is on top
	visible = false
	
	if resume_button:
		resume_button.pressed.connect(_on_resume)
	if settings_button:
		settings_button.pressed.connect(_on_settings)
	if quit_menu_button:
		quit_menu_button.pressed.connect(_on_quit_menu)
	if quit_desktop_button:
		quit_desktop_button.pressed.connect(_on_quit_desktop)
	
	# Connect to settings manager signals if available
	var settings_manager = get_node_or_null("/root/SettingsManager")
	if settings_manager:
		settings_manager.settings_changed.connect(_on_settings_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _can_pause:
		if _is_paused:
			unpause()
		else:
			pause()

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
	
	# Center the panel
	if panel:
		var viewport_size = get_viewport().get_visible_rect().size
		panel.position = (viewport_size - panel.size) / 2
	
	_update_stats()
	
	# Pause audio (optional - reduce volume)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	
	# Focus resume button
	if resume_button:
		resume_button.grab_focus()

func unpause() -> void:
	if not _is_paused:
		return
	
	_is_paused = false
	visible = false
	get_tree().paused = false
	
	# Unmute audio
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
	
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
	
	# Get stats from game
	var time = _format_time(game.get("elapsed") if game.get("elapsed") != null else 0.0)
	var kills = game.get("_enemy_kill_count") if game.get("_enemy_kill_count") != null else 0
	var resources = game.get("resources") if game.get("resources") != null else 0
	var level = game.get("level") if game.get("level") != null else 1
	var wave = 1
	if game.has_method("wave_manager") and game.wave_manager != null:
		wave = game.wave_manager.get("current_wave") if game.wave_manager.get("current_wave") != null else 1
	
	# Get player health
	var player_health = 0
	var player_max_health = 100
	var player = game.get("player")
	if player != null:
		player_health = int(player.get("health")) if player.get("health") != null else 0
		player_max_health = int(player.get("max_health")) if player.get("max_health") != null else 100
	
	# Update stat labels
	var stat_labels = stats_container.get_children()
	if stat_labels.size() >= 6:
		stat_labels[0].text = "⏱ Time: %s" % time
		stat_labels[1].text = "💀 Kills: %d" % kills
		stat_labels[2].text = "💰 Gold: %d" % resources
		stat_labels[3].text = "⭐ Level: %d" % level
		stat_labels[4].text = "🌊 Wave: %d" % wave
		stat_labels[5].text = "❤ Health: %d/%d" % [player_health, player_max_health]

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%d:%02d" % [mins, secs]

func _on_resume() -> void:
	unpause()

func _on_settings() -> void:
	settings_opened.emit()

func _on_quit_menu() -> void:
	# Save before quitting
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and game:
		save_manager.update_run_data(game)
		save_manager.save_recovery_data()
	
	unpause()
	quit_to_menu.emit()

func _on_quit_desktop() -> void:
	# Save before quitting
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and game:
		save_manager.update_run_data(game)
		save_manager.save_recovery_data()
	
	get_tree().quit()

func _on_settings_changed(category: String, key: String, value: Variant) -> void:
	# Handle settings changes that affect pause menu
	if category == "gameplay" and key == "show_stats_in_pause":
		if stats_container:
			stats_container.visible = value