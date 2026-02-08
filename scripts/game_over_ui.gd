extends CanvasLayer

signal try_again_pressed
signal main_menu_pressed
signal stats_pressed

@onready var title_label: Label = $Panel/TitleLabel
@onready var skull_icon: TextureRect = $Panel/SkullIcon
@onready var stats_container: VBoxContainer = $Panel/StatsContainer
@onready var new_record_label: Label = $Panel/NewRecordLabel
@onready var buttons_container: HBoxContainer = $Panel/ButtonsContainer
@onready var try_again_btn: Button = $Panel/ButtonsContainer/TryAgainBtn
@onready var main_menu_btn: Button = $Panel/ButtonsContainer/MainMenuBtn
@onready var stats_btn: Button = $Panel/ButtonsContainer/StatsBtn
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const UI_FONT_PATH = "res://assets/ui/pixel_font.ttf"
const USE_CUSTOM_FONT = true

var _ui_font: Font = null
var _run_stats: Dictionary = {}

func _ready() -> void:
	_ui_font = _load_font()
	_apply_fonts()
	_setup_visuals()
	_hide_game_over()
	
	try_again_btn.pressed.connect(_on_try_again)
	main_menu_btn.pressed.connect(_on_main_menu)
	stats_btn.pressed.connect(_on_stats)
	
	# Audio: Connect button sounds
	for btn in [try_again_btn, main_menu_btn, stats_btn]:
		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_click)

func _on_button_hover() -> void:
	AudioManager.play_ui_sound("hover")

func _on_button_click() -> void:
	AudioManager.play_ui_sound("click")

func show_game_over(stats: Dictionary, is_new_record: bool = false) -> void:
	_run_stats = stats
	
	# Update stats display
	_update_stats_display(stats)
	
	# Show new record label if applicable
	new_record_label.visible = is_new_record
	
	# Show the panel with animation
	visible = true
	$Panel.modulate = Color(1, 1, 1, 0)
	
	var tween = create_tween()
	tween.tween_property($Panel, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Animate stats appearing one by one
	_animate_stats_appear()

func hide_game_over() -> void:
	_hide_game_over()

func _hide_game_over() -> void:
	visible = false
	for child in stats_container.get_children():
		child.modulate = Color(1, 1, 1, 0)

func _update_stats_display(stats: Dictionary) -> void:
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Time Survived
	var time_str = _format_time(stats.get("time_survived", 0.0))
	_add_stat_row("Time Survived:", time_str)
	
	# Enemies Killed
	_add_stat_row("Enemies Killed:", "%,d" % stats.get("enemies_killed", 0))
	
	# Damage Dealt
	_add_stat_row("Damage Dealt:", "%,d" % int(stats.get("damage_dealt", 0)))
	
	# Towers Built
	_add_stat_row("Towers Built:", str(stats.get("towers_built", 0)))
	
	# Generators Lost
	_add_stat_row("Generators Lost:", str(stats.get("generators_lost", 0)))
	
	# Best Streak
	_add_stat_row("Best Streak:", "%,d kills" % stats.get("best_streak", 0))
	
	# Wave Reached
	var wave = stats.get("wave_reached", 1)
	_add_stat_row("Wave Reached:", "Wave %d" % wave)

func _add_stat_row(label_text: String, value_text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	
	var label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font_to_label(label, 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font_to_label(value, 14)
	value.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold color
	hbox.add_child(value)
	
	hbox.modulate = Color(1, 1, 1, 0)
	stats_container.add_child(hbox)

func _animate_stats_appear() -> void:
	var children = stats_container.get_children()
	for i in range(children.size()):
		var child = children[i]
		var tween = create_tween()
		tween.tween_interval(0.1 * i)
		tween.tween_property(child, "modulate", Color(1, 1, 1, 1), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func _setup_visuals() -> void:
	# Dark background panel
	$Panel.get_theme_stylebox("panel").bg_color = Color(0.08, 0.08, 0.1, 0.95)
	
	# Title styling
	title_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))  # Dark red
	_apply_font_to_label(title_label, 32)
	
	# New record styling
	new_record_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold
	_apply_font_to_label(new_record_label, 16)
	
	# Button styling
	for btn in [try_again_btn, main_menu_btn, stats_btn]:
		_apply_font_to_label(btn, 12)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.0))  # Gold on hover

func _on_try_again() -> void:
	try_again_pressed.emit()

func _on_main_menu() -> void:
	main_menu_pressed.emit()

func _on_stats() -> void:
	stats_pressed.emit()

func _load_font() -> Font:
	if not ResourceLoader.exists(UI_FONT_PATH):
		return null
	var font = load(UI_FONT_PATH)
	if font is Font:
		return font
	return null

func _apply_fonts() -> void:
	if _ui_font == null:
		return
		
	_apply_font_to_label(title_label, 32)
	_apply_font_to_label(new_record_label, 16)
	
	for btn in [try_again_btn, main_menu_btn, stats_btn]:
		_apply_font_to_label(btn, 12)

func _apply_font_to_label(label: Control, size: int) -> void:
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	label.add_theme_font_size_override("font_size", size)
