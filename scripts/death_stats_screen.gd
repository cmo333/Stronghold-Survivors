extends CanvasLayer
class_name DeathStatsScreen

signal continue_pressed

# Chart drawing configuration
const CHART_COLOR_DAMAGE = Color(0.9, 0.3, 0.2, 0.8)
const CHART_COLOR_ENEMIES = Color(0.2, 0.7, 0.3, 0.8)
const CHART_COLOR_GOLD = Color(1.0, 0.84, 0.0, 0.8)
const CHART_BG = Color(0.1, 0.1, 0.12, 0.9)
const CHART_LINE = Color(0.3, 0.3, 0.35, 1.0)
const CHART_GRID = Color(0.2, 0.2, 0.22, 0.5)

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var subtitle_label: Label = $Panel/SubtitleLabel
@onready var new_record_container: Control = $Panel/NewRecordContainer
@onready var stats_container: VBoxContainer = $Panel/StatsContainer
@onready var charts_container: Control = $Panel/ChartsContainer
@onready var damage_chart: Control = $Panel/ChartsContainer/DamageChart
@onready var enemy_chart: Control = $Panel/ChartsContainer/EnemyChart
@onready var lost_container: VBoxContainer = $Panel/LostContainer
@onready var kept_container: VBoxContainer = $Panel/KeptContainer
@onready var continue_btn: Button = $Panel/ContinueBtn
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var confetti_root: Node2D = $ConfettiRoot

var _run_stats: Dictionary = {}
var _is_new_record: bool = false
var _confetti_particles: Array = []
var _damage_history: Array = []
var _enemy_kill_history: Array = []
var _chart_animation_progress: float = 0.0

func _ready() -> void:
	_hide_screen()
	continue_btn.pressed.connect(_on_continue)

func show_death_screen(stats: Dictionary, is_new_record: bool, damage_history: Array = [], enemy_history: Array = []) -> void:
	_run_stats = stats
	_is_new_record = is_new_record
	_damage_history = damage_history
	_enemy_kill_history = enemy_history
	
	visible = true
	
	# Setup content
	_setup_title()
	_setup_stats()
	_setup_lost_and_kept()
	_setup_charts()
	
	# Animate in
	_animate_entrance()
	
	# Start confetti if new record
	if _is_new_record:
		_start_confetti_celebration()

func _setup_title() -> void:
	var death_quotes = [
		"THE STRONGHOLD HAS FALLEN",
		"YOUR WATCH HAS ENDED",
		"DARKNESS PREVAILS",
		"THE SIEGE CLAIMS ANOTHER",
		"VALIANT BUT VANQUISHED",
		"THE WALLS CRUMBLE",
		"A HERO'S SACRIFICE"
	]
	
	var flavor_texts = [
		"The horde overran your position.",
		"Your defenses could not hold.",
		"The enemy proved too numerous.",
		"Your generators lie in ruins.",
		"The stronghold is lost... for now."
	]
	
	title_label.text = death_quotes[randi_range(0, death_quotes.size() - 1)]
	subtitle_label.text = flavor_texts[randi_range(0, flavor_texts.size() - 1)]
	
	if _is_new_record:
		new_record_container.visible = true
		title_label.text = "★ NEW RECORD! ★"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	else:
		new_record_container.visible = false
		title_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

func _setup_stats() -> void:
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()
	
	# Main stats grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	
	# Time
	_add_stat_item(grid, "⏱️ TIME SURVIVED", _format_time(_run_stats.get("time_survived", 0)), Color(0.9, 0.9, 0.9))
	
	# Kills
	var kills = _run_stats.get("enemies_killed", 0)
	_add_stat_item(grid, "⚔️ ENEMIES SLAIN", "%,d" % kills, Color(0.9, 0.3, 0.2))
	
	# Damage
	var damage = _run_stats.get("damage_dealt", 0)
	_add_stat_item(grid, "💥 DAMAGE DEALT", "%,d" % int(damage), Color(1.0, 0.6, 0.2))
	
	# Gold earned
	var gold = _run_stats.get("gold_earned", 0)
	_add_stat_item(grid, "🪙 GOLD EARNED", "%,d" % gold, Color(1.0, 0.84, 0.0))
	
	# Towers
	_add_stat_item(grid, "🏰 TOWERS BUILT", str(_run_stats.get("towers_built", 0)), Color(0.4, 0.7, 0.9))
	
	# Wave
	_add_stat_item(grid, "🌊 WAVE REACHED", "Wave %d" % _run_stats.get("wave_reached", 1), Color(0.6, 0.4, 0.9))
	
	# Best streak
	_add_stat_item(grid, "🔥 BEST STREAK", "%,d kills" % _run_stats.get("best_streak", 0), Color(1.0, 0.5, 0.0))
	
	stats_container.add_child(grid)

func _add_stat_item(parent: Control, label: String, value: String, color: Color) -> void:
	var label_node = Label.new()
	label_node.text = label
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label_node.add_theme_font_size_override("font_size", 14)
	label_node.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	parent.add_child(label_node)
	
	var value_node = Label.new()
	value_node.text = value
	value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_node.add_theme_font_size_override("font_size", 16)
	value_node.add_theme_color_override("font_color", color)
	parent.add_child(value_node)

func _setup_lost_and_kept() -> void:
	# Clear containers
	for child in lost_container.get_children():
		child.queue_free()
	for child in kept_container.get_children():
		child.queue_free()
	
	# LOST section (permadeath weight)
	var lost_title = Label.new()
	lost_title.text = "💀 LOST FOREVER"
	lost_title.add_theme_font_size_override("font_size", 14)
	lost_title.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))
	lost_container.add_child(lost_title)
	
	var lost_items = [
		"All collected gold",
		"All built towers and walls",
		"Current tech upgrades",
		"Your life"
	]
	
	for item in lost_items:
		var label = Label.new()
		label.text = "  • " + item
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lost_container.add_child(label)
	
	# KEPT section (progression)
	var kept_title = Label.new()
	kept_title.text = "✓ CARRIED FORWARD"
	kept_title.add_theme_font_size_override("font_size", 14)
	kept_title.add_theme_color_override("font_color", Color(0.2, 0.7, 0.3))
	kept_container.add_child(kept_title)
	
	var kept_items = [
		"Knowledge of enemy patterns",
		"Your skills as a defender",
		"The memory of your stand"
	]
	
	if _is_new_record:
		kept_items.append("NEW RECORD BRAGGING RIGHTS!")
	
	for item in kept_items:
		var label = Label.new()
		label.text = "  • " + item
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		kept_container.add_child(label)

func _setup_charts() -> void:
	charts_container.visible = _damage_history.size() > 5
	if charts_container.visible:
		# Trigger chart redraw
		damage_chart.queue_redraw()
		enemy_chart.queue_redraw()

func _animate_entrance() -> void:
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.9, 0.9)
	
	if not is_inside_tree():
		return
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Animate stats appearing
	tween.tween_callback(_animate_stats)
	
	# Animate charts drawing
	if charts_container.visible:
		tween.tween_property(self, "_chart_animation_progress", 1.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _animate_stats() -> void:
	var grid = stats_container.get_child(0) if stats_container.get_child_count() > 0 else null
	if grid == null:
		return
	
	if not is_inside_tree():
		return
	for i in range(grid.get_child_count()):
		var child = grid.get_child(i)
		child.modulate = Color(1, 1, 1, 0)
		
		var tween = create_tween()
		tween.tween_interval(0.05 * i)
		tween.tween_property(child, "modulate", Color(1, 1, 1, 1), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _start_confetti_celebration() -> void:
	# Spawn confetti particles
	for i in range(50):
		_spawn_confetti_piece()
	
	# Continue spawning for a few seconds
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_stop_confetti)

func _spawn_confetti_piece() -> void:
	var confetti = ColorRect.new()
	confetti.size = Vector2(randf_range(4, 10), randf_range(4, 10))
	confetti.position = Vector2(randf_range(0, 1280), -20)
	
	# Random bright color
	var colors = [
		Color(1.0, 0.2, 0.2),
		Color(1.0, 0.84, 0.0),
		Color(0.2, 0.8, 0.3),
		Color(0.2, 0.6, 1.0),
		Color(0.8, 0.2, 0.8),
		Color(0.2, 1.0, 1.0)
	]
	confetti.color = colors[randi_range(0, colors.size() - 1)]
	
	confetti_root.add_child(confetti)
	_confetti_particles.append(confetti)
	
	# Animate falling
	var duration = randf_range(2.0, 4.0)
	var target_x = confetti.position.x + randf_range(-200, 200)
	var target_y = 800
	
	if not is_inside_tree():
		confetti.queue_free()
		return
	var tween = create_tween()
	tween.tween_property(confetti, "position", Vector2(target_x, target_y), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(confetti, "rotation", randf_range(-TAU, TAU), duration)
	tween.tween_callback(confetti.queue_free)

func _stop_confetti() -> void:
	_confetti_particles.clear()

func _draw_damage_chart() -> void:
	if _damage_history.is_empty():
		return
	
	var chart_rect = damage_chart.get_rect()
	var padding = 20
	var graph_width = chart_rect.size.x - padding * 2
	var graph_height = chart_rect.size.y - padding * 2
	
	var canvas = damage_chart.get_canvas_item()
	
	# Draw background
	damage_chart.draw_rect(Rect2(Vector2.ZERO, chart_rect.size), CHART_BG, true)
	
	# Find max value
	var max_damage = 1.0
	for d in _damage_history:
		max_damage = max(max_damage, float(d))
	
	# Draw grid lines
	for i in range(5):
		var y = padding + (graph_height / 4) * i
		damage_chart.draw_line(Vector2(padding, y), Vector2(padding + graph_width, y), CHART_GRID, 1.0)
	
	# Draw line chart
	if _damage_history.size() > 1:
		var points: Array[Vector2] = []
		for i in range(_damage_history.size()):
			var x = padding + (graph_width / (_damage_history.size() - 1)) * i * _chart_animation_progress
			var y = padding + graph_height - (float(_damage_history[i]) / max_damage) * graph_height * _chart_animation_progress
			points.append(Vector2(x, y))
		
		# Draw line
		if points.size() > 1:
			for i in range(points.size() - 1):
				damage_chart.draw_line(points[i], points[i + 1], CHART_COLOR_DAMAGE, 2.0)
		
		# Draw points
		for point in points:
			damage_chart.draw_circle(point, 3.0, CHART_COLOR_DAMAGE)
	
	# Draw labels
	var title = Label.new()
	title.text = "DAMAGE OVER TIME"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title.position = Vector2(padding, 5)

func _draw_enemy_chart() -> void:
	if _enemy_kill_history.is_empty():
		return
	
	var chart_rect = enemy_chart.get_rect()
	var padding = 20
	
	# Background
	enemy_chart.draw_rect(Rect2(Vector2.ZERO, chart_rect.size), CHART_BG, true)
	
	# Simple bar chart of enemy types (would need enemy type data)
	# For now, draw placeholder
	var bar_width = (chart_rect.size.x - padding * 2) / 6
	var max_height = chart_rect.size.y - padding * 2
	
	for i in range(6):
		var height = max_height * (0.2 + randf() * 0.8) * _chart_animation_progress
		var x = padding + bar_width * i + bar_width * 0.1
		var y = chart_rect.size.y - padding - height
		
		enemy_chart.draw_rect(Rect2(x, y, bar_width * 0.8, height), CHART_COLOR_ENEMIES, true)
	
	# Label
	var title = Label.new()
	title.text = "ENEMIES BY TYPE"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	title.position = Vector2(padding, 5)

func _format_time(seconds: float) -> String:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

func _on_continue() -> void:
	continue_pressed.emit()

func _hide_screen() -> void:
	visible = false
	panel.modulate = Color(1, 1, 1, 0)
