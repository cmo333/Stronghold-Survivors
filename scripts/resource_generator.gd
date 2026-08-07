extends "res://scripts/building.gd"

const MAX_HP = 120.0
const LOW_HP_THRESHOLD = 0.3  # 30% health = low HP (pulse red)
const HEALTH_BAR_WIDTH = 32.0
const HEALTH_BAR_HEIGHT = 4.0
const HEALTH_BAR_OFFSET = -28.0  # Above the building

var income = 2
var interval = 2.0
var _timer = 0.0
var _game: Node = null
var _zone: Node = null
var _zone_multiplier: float = 1.0
var _health_bar: ProgressBar = null
var _health_bar_container: Node2D = null
var _is_destroyed = false
var _pulse_tween: Tween = null
var _low_hp_pulse_active = false
var _was_damaged = false
var _under_attack_warning_shown = false
var _income_text_cooldown: float = 0.0

# --- Objective beacon ---------------------------------------------------------
# The extractor is both the win condition and what the entire horde walks toward,
# yet a packed base buries it behind two rows of towers. A light column drawn
# above the buildings keeps it locatable, and brightening it with progress makes
# "nearly done" readable from across the map - exciting for the player, and fair
# warning that the pressure is about to peak.
const BEACON_COLOR = Color(0.42, 1.0, 0.70)
const BEACON_WIDTH = 26
const BEACON_HEIGHT = 132
const BEACON_Z = 60           # above buildings (0), below the player (120)
const BEACON_PULSE_SPEED = 2.6
const BEACON_MIN_SCALE = 0.55
const BEACON_MAX_SCALE = 1.0
const BEACON_MIN_ALPHA = 0.30
const BEACON_MAX_ALPHA = 0.78

static var _shared_beacon_tex: ImageTexture = null
var _beacon: Sprite2D = null
var _beacon_phase: float = 0.0

# Visual components
@onready var body: CanvasItem = get_node_or_null("Body")
@onready var base_modulate: Color = Color.WHITE

func _ready() -> void:
	super._ready()
	_game = get_tree().get_first_node_in_group("game")

	# Store base modulate color
	if body != null:
		base_modulate = body.modulate

	# Create health bar
	_create_health_bar()

	# Register with game
	if _game != null and _game.has_method("register_generator"):
		_game.register_generator(self)

	# Extraction mode: this is the run objective, not just an income building.
	if _game != null and _game.has_method("on_extractor_placed"):
		_game.on_extractor_placed(self)

	_setup_beacon()

	# Check zone membership after scene tree is ready
	call_deferred("_check_zone_membership")

func _is_the_extractor() -> bool:
	"""Only the run objective gets a beacon. Lighting up every income generator
	would recreate exactly the clutter this is meant to cut through."""
	if _game == null:
		return false
	if not ("extractor" in _game):
		return false
	return _game.extractor == self

static func _get_beacon_texture() -> ImageTexture:
	if _shared_beacon_tex != null:
		return _shared_beacon_tex
	var img := Image.create(BEACON_WIDTH, BEACON_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(BEACON_WIDTH) * 0.5
	for y in range(BEACON_HEIGHT):
		# Row 0 is the top of the image, which becomes the top of the column:
		# faint there, solid where it meets the crystal, so it reads as light
		# rather than a painted bar.
		var t := float(y) / float(BEACON_HEIGHT - 1)
		var vertical := pow(t, 1.7)
		for x in range(BEACON_WIDTH):
			var dx: float = absf(float(x) + 0.5 - cx) / cx
			var horizontal: float = clampf(1.0 - dx * dx, 0.0, 1.0)
			var a: float = vertical * horizontal
			if a <= 0.004:
				continue
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_shared_beacon_tex = ImageTexture.create_from_image(img)
	return _shared_beacon_tex

func _setup_beacon() -> void:
	if _beacon != null or not _is_the_extractor():
		return
	_beacon = Sprite2D.new()
	_beacon.name = "ObjectiveBeacon"
	_beacon.texture = _get_beacon_texture()
	_beacon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_beacon.centered = false
	_beacon.z_as_relative = false
	_beacon.z_index = BEACON_Z
	# Additive so it reads as emitted light and never hides the art behind it.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beacon.material = mat
	_beacon.position = Vector2(-float(BEACON_WIDTH) * 0.5, -float(BEACON_HEIGHT))
	_beacon.modulate = Color(BEACON_COLOR.r, BEACON_COLOR.g, BEACON_COLOR.b, BEACON_MIN_ALPHA)
	add_child(_beacon)

func _update_beacon(delta: float) -> void:
	if _beacon == null or not is_instance_valid(_beacon):
		return
	_beacon_phase += delta * BEACON_PULSE_SPEED
	var progress := 0.0
	if _game != null and "extraction_progress" in _game:
		progress = clampf(float(_game.extraction_progress), 0.0, 1.0)
	var height_scale := lerpf(BEACON_MIN_SCALE, BEACON_MAX_SCALE, progress)
	var pulse := 0.5 + 0.5 * sin(_beacon_phase)
	var alpha := lerpf(BEACON_MIN_ALPHA, BEACON_MAX_ALPHA, progress) * (0.78 + 0.22 * pulse)
	# The sprite grows from its top edge, so the base has to travel with it to
	# keep the column planted on the crystal.
	_beacon.scale.y = height_scale
	_beacon.position.y = -float(BEACON_HEIGHT) * height_scale
	_beacon.modulate = Color(BEACON_COLOR.r, BEACON_COLOR.g, BEACON_COLOR.b, alpha)

func _check_zone_membership() -> void:
	if _game == null or not _game.has_method("get_zone_at"):
		return
	_zone = _game.get_zone_at(global_position)
	if _zone != null:
		_zone_multiplier = _zone.get_multiplier()
		_zone.register_generator(self)
		if _game.has_method("show_floating_text"):
			_game.show_floating_text("IN ZONE x%.1f!" % _zone.multiplier, global_position + Vector2(0, -40), Color(1.0, 0.85, 0.2))

func _apply_tier_stats(tier_data: Dictionary) -> void:
	super._apply_tier_stats(tier_data)
	income = int(tier_data.get("income", income))
	interval = float(tier_data.get("interval", interval))

func _process(delta: float) -> void:
	if _is_destroyed or _game == null:
		return
	# Before the income gate: the objective stays lit even when it stops paying.
	_update_beacon(delta)
	# Inert generators (owner dead/left in FFA) stop producing income.
	if inert:
		return

	_income_text_cooldown = max(0.0, _income_text_cooldown - delta)
	_timer += delta
	if _timer >= interval:
		_timer -= interval
		var income_scale = 1.0
		if _game.has_method("get_generator_income_mult"):
			income_scale = float(_game.get_generator_income_mult())
		var show_income_text = true
		if _game.has_method("get_adaptive_perf_scale"):
			show_income_text = float(_game.get_adaptive_perf_scale()) >= 0.78
		if _zone != null and is_instance_valid(_zone) and not _zone._is_depleted:
			_zone_multiplier = _zone.get_multiplier()
			var actual_income = int(round(float(income) * _zone_multiplier * income_scale))
			actual_income = max(1, actual_income)
			_game.add_resources(actual_income, owner_id)
			_zone.on_generator_ticked(actual_income)
			# Show boosted income number in gold
			if show_income_text and _income_text_cooldown <= 0.0 and _game.has_method("show_floating_text"):
				_game.show_floating_text("+%d" % actual_income, global_position + Vector2(randf_range(-6, 6), -20), Color(1.0, 0.85, 0.2, 0.9))
				_income_text_cooldown = 0.75 + randf() * 0.35
		else:
			_zone_multiplier = 1.0
			var scaled_income = int(round(float(income) * income_scale))
			scaled_income = max(1, scaled_income)
			_game.add_resources(scaled_income, owner_id)
			# Show base income number in dimmer color
			if show_income_text and _income_text_cooldown <= 0.0 and _game.has_method("show_floating_text"):
				_game.show_floating_text("+%d" % scaled_income, global_position + Vector2(randf_range(-6, 6), -20), Color(0.7, 0.7, 0.5, 0.7))
				_income_text_cooldown = 0.75 + randf() * 0.35

func take_damage(amount: float) -> void:
	if _is_destroyed:
		return
	if _game != null and _game.has_method("is_damage_blocked") and _game.is_damage_blocked():
		return

	health -= amount
	_was_damaged = true

	# Audio: Building hit sound
	AudioManager.play_one_shot("building_hit", global_position, AudioManager.DEFAULT_PRIORITY)

	# Show health bar when damaged
	_update_health_bar()
	_health_bar_container.visible = true

	# Show "under attack" warning on first damage
	if not _under_attack_warning_shown and _game != null:
		_under_attack_warning_shown = true
		if _game.has_method("show_floating_text"):
			_game.show_floating_text("GENERATOR UNDER ATTACK!", global_position + Vector2(0, -50), Color(1.0, 0.5, 0.0, 1.0))

	# Check for low HP pulse effect
	var hp_ratio = health / max_health
	if hp_ratio <= LOW_HP_THRESHOLD and not _low_hp_pulse_active:
		_start_low_hp_pulse()

	# Flash red on hit
	_flash_damage()

	if health <= 0.0:
		_destroy()

func heal(amount: float) -> void:
	if _is_destroyed:
		return
	health = min(max_health, health + amount)
	_update_health_bar()

	# Stop low HP pulse if healed above threshold
	var hp_ratio = health / max_health
	if hp_ratio > LOW_HP_THRESHOLD and _low_hp_pulse_active:
		_stop_low_hp_pulse()

func _destroy() -> void:
	_is_destroyed = true

	# Unregister from zone
	if _zone != null and is_instance_valid(_zone):
		_zone.unregister_generator(self)
		_zone = null

	# Audio: Generator destroyed sound
	AudioManager.play_one_shot("generator_destroyed", global_position, AudioManager.CRITICAL_PRIORITY)

	# Screen shake
	if _game != null and _game.has_method("shake_camera"):
		_game.shake_camera(FeedbackConfig.SCREEN_SHAKE_BUILDING_DESTROY)

	# Spawn explosion FX
	if _game != null and _game.has_method("spawn_fx"):
		_game.spawn_fx("explosion", global_position)
		_spawn_glow_burst()

	# Show death message
	if _game != null and _game.has_method("show_floating_text"):
		_game.show_floating_text("GENERATOR DESTROYED!", global_position + Vector2(0, -40), Color(1.0, 0.0, 0.0, 1.0))

	# Notify game
	if _game != null and _game.has_method("on_generator_destroyed"):
		_game.on_generator_destroyed(self)

	# Losing the extractor ends the run — it is the whole objective.
	if _game != null and _game.has_method("on_extractor_destroyed") \
			and _game.has_method("has_extractor") and _game.extractor == self:
		_game.on_extractor_destroyed()

	# Track generator lost
	if _game != null and _game.has_method("track_generator_lost"):
		_game.track_generator_lost()

	queue_free()

func _spawn_glow_burst() -> void:
	if _game == null:
		return
	# Spawn orange/red glow particles for explosion
	for i in range(15):
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		var vel = dir * randf_range(80.0, 180.0)
		var color = Color(1.0, 0.4 + randf() * 0.3, 0.1, 1.0)
		if _game.has_method("spawn_glow_particle"):
			_game.spawn_glow_particle(
				global_position + dir * randf_range(0.0, 12.0),
				color,
				randf_range(8.0, 16.0),
				randf_range(0.4, 0.8),
				vel,
				2.0,
				0.7,
				1.0,
				2
			)

func _create_health_bar() -> void:
	_health_bar_container = Node2D.new()
	_health_bar_container.name = "HealthBarContainer"
	_health_bar_container.visible = false  # Hidden until damaged
	add_child(_health_bar_container)

	# Create background
	var bg = ColorRect.new()
	bg.name = "HealthBarBG"
	bg.color = Color(0.2, 0.2, 0.2, 0.9)
	bg.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	bg.position = Vector2(-HEALTH_BAR_WIDTH / 2, HEALTH_BAR_OFFSET)
	_health_bar_container.add_child(bg)

	# Create progress bar
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.min_value = 0
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_bar.show_percentage = false
	_health_bar.size = Vector2(HEALTH_BAR_WIDTH - 2, HEALTH_BAR_HEIGHT - 2)
	_health_bar.position = Vector2(-(HEALTH_BAR_WIDTH - 2) / 2, HEALTH_BAR_OFFSET + 1)

	# Style the progress bar
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.2, 0.85, 0.3, 1.0)  # Green
	_health_bar.add_theme_stylebox_override("fill", fg_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	_health_bar.add_theme_stylebox_override("background", bg_style)

	_health_bar_container.add_child(_health_bar)

func _update_health_bar() -> void:
	if _health_bar == null:
		return
	_health_bar.value = health

	# Change color based on health
	var fg_style = StyleBoxFlat.new()
	var hp_ratio = health / max_health
	if hp_ratio > 0.6:
		fg_style.bg_color = Color(0.2, 0.85, 0.3, 1.0)  # Green
	elif hp_ratio > 0.3:
		fg_style.bg_color = Color(0.95, 0.75, 0.2, 1.0)  # Yellow
	else:
		fg_style.bg_color = Color(0.95, 0.2, 0.2, 1.0)  # Red
	_health_bar.add_theme_stylebox_override("fill", fg_style)

func _flash_damage() -> void:
	if body == null:
		return
	if not is_inside_tree():
		return
	body.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Flash red
	var tween = create_tween()
	tween.tween_property(body, "modulate", base_modulate, 0.15).set_trans(Tween.TRANS_SINE)

func _start_low_hp_pulse() -> void:
	_low_hp_pulse_active = true
	if body == null:
		return

	if _pulse_tween != null:
		_pulse_tween.kill()

	if not is_inside_tree():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	# Pulse between normal and bright red
	var dim_color = base_modulate.lerp(Color(1.0, 0.2, 0.2), 0.3)
	var bright_color = base_modulate.lerp(Color(1.0, 0.1, 0.1), 0.6)
	_pulse_tween.tween_property(body, "modulate", bright_color, 0.4).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(body, "modulate", dim_color, 0.4).set_trans(Tween.TRANS_SINE)

func _stop_low_hp_pulse() -> void:
	_low_hp_pulse_active = false
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if body != null:
		if not is_inside_tree():
			return
		var tween = create_tween()
		tween.tween_property(body, "modulate", base_modulate, 0.3).set_trans(Tween.TRANS_SINE)

func sell() -> void:
	_is_destroyed = true
	if _zone != null and is_instance_valid(_zone):
		_zone.unregister_generator(self)
		_zone = null
	super.sell()

func is_destroyed() -> bool:
	return _is_destroyed

func get_health_ratio() -> float:
	return health / max_health

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _pulse_tween != null:
			_pulse_tween.kill()
