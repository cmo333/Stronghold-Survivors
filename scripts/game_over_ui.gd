extends CanvasLayer

signal try_again_pressed
signal main_menu_pressed
signal continue_endless_pressed

@onready var title_label: Label = $Panel/TitleLabel
@onready var skull_icon: TextureRect = $Panel/SkullIcon
@onready var stats_container: VBoxContainer = $Panel/StatsContainer
@onready var new_record_label: Label = $Panel/NewRecordLabel
@onready var buttons_container: HBoxContainer = $Panel/ButtonsContainer
@onready var try_again_btn: Button = $Panel/ButtonsContainer/TryAgainBtn
@onready var main_menu_btn: Button = $Panel/ButtonsContainer/MainMenuBtn
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const UI_FONT_PATH = "res://assets/ui/pixel_font.ttf"
const USE_CUSTOM_FONT = true

var _ui_font: Font = null
var _run_stats: Dictionary = {}
var _won_mode: bool = false

func _ready() -> void:
	_ui_font = _load_font()
	_apply_fonts()
	_setup_visuals()
	_hide_game_over()
	
	try_again_btn.pressed.connect(_on_try_again)
	main_menu_btn.pressed.connect(_on_main_menu)

	# Audio: Connect button sounds
	for btn in [try_again_btn, main_menu_btn]:
		btn.mouse_entered.connect(_on_button_hover)
		btn.pressed.connect(_on_button_click)

func _on_button_hover() -> void:
	AudioManager.play_ui_sound("hover")

func _on_button_click() -> void:
	AudioManager.play_ui_sound("click")

func show_game_over(stats: Dictionary, is_new_record: bool = false, cores_earned: int = 0, won: bool = false) -> void:
	_run_stats = stats
	_won_mode = won

	# Frame the screen for victory vs defeat.
	_apply_outcome_framing(won)

	# Update stats display
	_update_stats_display(stats, cores_earned)

	# Show new record label if applicable
	new_record_label.visible = is_new_record

	# Show the panel with animation
	visible = true
	$Panel.modulate = Color(1, 1, 1, 0)
	
	if not is_inside_tree():
		return
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

func _update_stats_display(stats: Dictionary, cores_earned: int = 0) -> void:
	# Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
	
	# Time Survived
	var time_str = _format_time(stats.get("time_survived", 0.0))
	_add_stat_row("Time Survived:", time_str)

	# Enemies Killed
	_add_stat_row("Enemies Killed:", _commas(stats.get("enemies_killed", 0)), Color(0.9, 0.4, 0.3))

	# Best Streak
	_add_stat_row("Best Streak:", "%s kills" % _commas(stats.get("best_streak", 0)))

	# Damage Dealt
	_add_stat_row("Damage Dealt:", _commas(int(stats.get("damage_dealt", 0))))

	# Building Score (towers built this run)
	_add_stat_row("Building Score:", str(stats.get("towers_built", 0)), Color(0.4, 0.7, 0.9))

	# Treasures Opened
	_add_stat_row("Treasures Opened:", str(stats.get("treasures_opened", 0)))

	# Currency Earned (in-run gold/resources)
	_add_stat_row("Currency Earned:", _commas(int(stats.get("currency_earned", 0))))

	# Wave Reached
	var wave = stats.get("wave_reached", 1)
	_add_stat_row("Wave Reached:", "Wave %d" % wave)

	# Generators Lost
	_add_stat_row("Generators Lost:", str(stats.get("generators_lost", 0)))

	# Cores earned (persistent meta-progression reward)
	if cores_earned > 0:
		_add_stat_row("Cores Earned:", "+%d" % cores_earned, Color(0.8, 0.4, 1.0))

func _add_stat_row(label_text: String, value_text: String, value_color: Color = Color(1.0, 0.84, 0.0)) -> void:
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
	value.add_theme_color_override("font_color", value_color)
	hbox.add_child(value)
	
	hbox.modulate = Color(1, 1, 1, 0)
	stats_container.add_child(hbox)

func _animate_stats_appear() -> void:
	var children = stats_container.get_children()
	if not is_inside_tree():
		return
	for i in range(children.size()):
		var child = children[i]
		if child == null or not is_instance_valid(child) or not child.is_inside_tree():
			continue
		var tween = create_tween()
		tween.tween_interval(0.1 * i)
		tween.tween_property(child, "modulate", Color(1, 1, 1, 1), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

# GDScript's `%` has no comma flag (unlike Python), so build the grouped string
# manually. Handles negatives and large ints.
func _commas(value: int) -> String:
	var neg := value < 0
	var digits := str(abs(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" + out) if neg else out

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
	for btn in [try_again_btn, main_menu_btn]:
		_apply_font_to_label(btn, 12)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.0))  # Gold on hover

func _apply_outcome_framing(won: bool) -> void:
	main_menu_btn.text = "ACCEPT"
	if won:
		title_label.text = "STRONGHOLD HELD"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Gold
		try_again_btn.text = "CONTINUE (ENDLESS)"
	else:
		title_label.text = "THE STRONGHOLD HAS FALLEN"
		title_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))  # Dark red
		try_again_btn.text = "TRY AGAIN"

func _on_try_again() -> void:
	if _won_mode:
		continue_endless_pressed.emit()
	else:
		try_again_pressed.emit()

func _on_main_menu() -> void:
	main_menu_pressed.emit()

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

	for btn in [try_again_btn, main_menu_btn]:
		_apply_font_to_label(btn, 12)

func _apply_font_to_label(label: Control, size: int) -> void:
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	label.add_theme_font_size_override("font_size", size)
