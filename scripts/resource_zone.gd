extends Node2D

const ZONE_RADIUS = 256.0
const DRAIN_PER_TICK = 0.002
const PULSE_MIN_ALPHA = 0.08
const PULSE_MAX_ALPHA = 0.18
const LOW_CHARGE_THRESHOLD = 0.3

var zone_id: int = 0
var multiplier: float = 2.5
var charge: float = 1.0
var _is_depleted: bool = false
var _registered_generators: Array = []
var _game: Node = null
var _pulse_alpha: float = 0.12
var _pulse_tween: Tween = null
var _label: Label = null
var _label_update_timer: float = 0.0

func _ready() -> void:
	add_to_group("resource_zones")
	z_index = -1
	_game = get_tree().get_first_node_in_group("game")
	_create_label()
	_start_pulse()

func _process(delta: float) -> void:
	if _is_depleted:
		return
	queue_redraw()
	_label_update_timer += delta
	if _label_update_timer >= 1.0:
		_label_update_timer = 0.0
		_update_label()

func _draw() -> void:
	if _is_depleted:
		# Dim grey outline only
		draw_arc(Vector2.ZERO, ZONE_RADIUS, 0, TAU, 48, Color(0.4, 0.4, 0.4, 0.15), 1.5)
		return

	# Fill color shifts from gold to red as charge drops
	var fill_color: Color
	if charge > LOW_CHARGE_THRESHOLD:
		fill_color = Color(1.0, 0.8, 0.1, _pulse_alpha)
	else:
		var t = charge / LOW_CHARGE_THRESHOLD
		fill_color = Color(1.0, 0.8 * t, 0.1 * t, _pulse_alpha)

	# Draw filled circle
	draw_circle(Vector2.ZERO, ZONE_RADIUS, fill_color)

	# Draw border
	var border_alpha = 0.4 * charge + 0.1
	var border_color: Color
	if charge > LOW_CHARGE_THRESHOLD:
		border_color = Color(1.0, 0.8, 0.1, border_alpha)
	else:
		var t = charge / LOW_CHARGE_THRESHOLD
		border_color = Color(1.0, 0.8 * t, 0.1 * t, border_alpha)
	draw_arc(Vector2.ZERO, ZONE_RADIUS, 0, TAU, 48, border_color, 2.0)

	# Draw inner dashed ring at 80% radius for visual depth
	var inner_r = ZONE_RADIUS * 0.8
	var segments = 16
	var gap = TAU / (segments * 2)
	for i in range(segments):
		var start_angle = i * (TAU / segments)
		draw_arc(Vector2.ZERO, inner_r, start_angle, start_angle + gap, 6, Color(1.0, 0.85, 0.2, border_alpha * 0.5), 1.0)

func register_generator(gen: Node) -> void:
	if gen not in _registered_generators:
		_registered_generators.append(gen)

func unregister_generator(gen: Node) -> void:
	_registered_generators.erase(gen)

func get_multiplier() -> float:
	if _is_depleted:
		return 1.0
	return multiplier * charge

func is_point_inside(world_pos: Vector2) -> bool:
	return world_pos.distance_to(global_position) <= ZONE_RADIUS

func on_generator_ticked(income_amount: int) -> void:
	if _is_depleted:
		return
	charge -= DRAIN_PER_TICK * income_amount
	charge = max(0.0, charge)
	if charge <= 0.0:
		_deplete()

func _deplete() -> void:
	_is_depleted = true
	charge = 0.0

	# Stop pulse
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null

	# Update label
	if _label != null:
		_label.text = "DEPLETED"
		_label.modulate = Color(0.5, 0.5, 0.5, 0.6)

	# Notify game
	if _game != null and _game.has_method("on_zone_depleted"):
		_game.on_zone_depleted(self)

	# Glow burst FX
	if _game != null and _game.has_method("spawn_glow_particle"):
		for i in range(12):
			var dir = Vector2.RIGHT.rotated(randf() * TAU)
			var vel = dir * randf_range(60.0, 140.0)
			var color = Color(1.0, 0.6, 0.1, 1.0)
			_game.spawn_glow_particle(
				global_position + dir * randf_range(0.0, ZONE_RADIUS * 0.3),
				color,
				randf_range(6.0, 12.0),
				randf_range(0.3, 0.7),
				vel,
				2.0,
				0.7,
				1.0,
				2
			)

	queue_redraw()

func _create_label() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-60, -ZONE_RADIUS - 20)
	_label.size = Vector2(120, 20)
	_label.add_theme_font_size_override("font_size", 12)
	_label.modulate = Color(1.0, 0.9, 0.3, 0.9)
	add_child(_label)
	_update_label()

func _update_label() -> void:
	if _label == null or _is_depleted:
		return
	var charge_pct = int(charge * 100)
	_label.text = "ZONE x%.1f (%d%%)" % [multiplier, charge_pct]

func _start_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	if not is_inside_tree():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "_pulse_alpha", PULSE_MAX_ALPHA, 1.2).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(self, "_pulse_alpha", PULSE_MIN_ALPHA, 1.2).set_trans(Tween.TRANS_SINE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _pulse_tween != null:
			_pulse_tween.kill()
