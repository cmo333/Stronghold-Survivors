extends "res://scripts/building.gd"

const MAX_HP = 120.0
const LOW_HP_THRESHOLD = 0.3  # 30% health = low HP (pulse red)
const HEALTH_BAR_WIDTH = 32.0
const HEALTH_BAR_HEIGHT = 4.0
# Above the building, and "the building" is now 112px tall rather than 64: the
# v002 art is a fountain whose jet reaches ~53px above the sprite's centre. At
# the old -28 the bar sat halfway up the plume.
const HEALTH_BAR_OFFSET = -62.0

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
# yet a packed base buries it behind two rows of towers.
#
# The first version of this was a 26px column, 132px tall, at 0.30 alpha until
# extraction was well underway. That is narrower than the tower it sits on and
# barely clears its own roof, and it blends ADDITIVELY in the same green as the
# extractor's own plume -- so on a real screenshot of a built-up base it was
# simply not there. Nothing was broken; it was just too small and too dim to
# survive its own background.
#
# So it is now an actual sky beam: wide enough at the base to wrap the whole
# tower, running far enough up to leave the top of the screen at every zoom the
# game uses, with a shimmer shader so it reads as a live column of light rather
# than a painted stripe. A separate radial glow sits on the building itself so
# the tower is lit, not just the air above it. Progress drives brightness and
# width rather than height -- "goes to the sky" should be true from the moment
# it lands, and "nearly done" still has to be readable from across the map.
const BEACON_COLOR = Color(0.60, 1.0, 0.82)
const BEACON_Z = 60           # above buildings (0-2), below the player (120)
const BEACON_PULSE_SPEED = 2.2

# 1024 world px of beam. The viewport is 720 tall and the camera runs at roughly
# 1.9-2.4 zoom, so about 300-380 world px are on screen above the tower: this
# leaves the frame with a wide margin at any zoom anyone is likely to set.
const BEAM_WIDTH = 96
const BEAM_HEIGHT = 1024
const BEAM_BASE_Y = 8.0       # bottom of the beam, just above the stone footing

# The building spans roughly -53..+23 around the node origin, so the glow is
# centred slightly high to cover the machinery and the base of the jet.
const GLOW_SIZE = 168
const GLOW_CENTRE_Y = -14.0
const GLOW_Z = 1              # over the tower art, under the health bar (2)

const BEACON_MIN_ALPHA = 0.55
const BEACON_MAX_ALPHA = 1.0
const BEAM_MIN_WIDTH_SCALE = 0.82
const BEAM_MAX_WIDTH_SCALE = 1.15
# Deliberately modest. This is a halo that picks the tower out of a packed base,
# and additive light over 48x112 of detailed pixel art turns into a green smear
# very quickly -- measured by eye at 0.62, where the stonework stopped reading.
const GLOW_MIN_ALPHA = 0.22
const GLOW_MAX_ALPHA = 0.45

# Shimmer. Two counter-scrolling band sets at unrelated frequencies so the
# pattern never visibly loops, modulated into the sprite's existing COLOR rather
# than replacing it -- COLOR arrives already multiplied by the node's modulate,
# which is what carries the beacon's colour and its progress-driven alpha, and
# overwriting it would throw both away. (MODULATE itself is not exposed in this
# renderer; see the readability pass.)
const BEAM_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

uniform float shimmer_speed = 1.0;
uniform float shimmer_depth = 0.34;

void fragment() {
	float fast = sin(UV.y * 34.0 - TIME * 5.2 * shimmer_speed);
	float slow = sin(UV.y * 11.3 + TIME * 1.7 * shimmer_speed + UV.x * 4.0);
	float bands = 0.5 + 0.5 * (fast * 0.58 + slow * 0.42);
	COLOR.a *= (1.0 - shimmer_depth) + shimmer_depth * bands;
	COLOR.rgb *= 0.86 + 0.28 * bands;
}
"""

static var _shared_beam_tex: ImageTexture = null
static var _shared_glow_tex: ImageTexture = null
static var _shared_beam_shader: Shader = null
var _beacon: Sprite2D = null
var _beacon_glow: Sprite2D = null
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

static func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / maxf(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func _get_beam_texture() -> ImageTexture:
	"""A column that flares out over the tower and narrows as it climbs.

	Drawn white; the sprite's modulate supplies the colour, so one texture is
	shared by every extractor that ever exists in the process."""
	if _shared_beam_tex != null:
		return _shared_beam_tex
	var img := Image.create(BEAM_WIDTH, BEAM_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(BEAM_WIDTH) * 0.5
	for y in range(BEAM_HEIGHT):
		# u: 0 at the tower, 1 at the far top. Row 0 of the image is the top.
		var u: float = float(BEAM_HEIGHT - 1 - y) / float(BEAM_HEIGHT - 1)
		# The flare is what makes the beam belong to the building instead of
		# hovering over it: 34px half-width at the footing, pinched to a 9px
		# shaft within the first fifth of the climb.
		var flare: float = 1.0 - _smoothstep(0.0, 0.20, u)
		var half_w: float = 9.0 + 25.0 * flare
		var core_w: float = 3.0 + 3.0 * flare
		# Dims with height but is still strong where it leaves the screen, so it
		# reads as continuing upward rather than stopping just out of frame.
		var vertical: float = pow(1.0 - u, 0.8)
		# ...and fades back out over the bottom ~85px, which is exactly the part
		# that overlaps the building. At full strength the flare capped the tower
		# in flat green and erased both the stonework and the extractor's own
		# jet; the point is to light the tower, not to paint over it. Faded, the
		# beam looks like it is being emitted by the crystal instead.
		# The floor matters: at 0.16 a dim gap opened between the top of the
		# extractor's own jet and the point where the beam takes over, and the
		# two read as separate effects. 0.26 keeps them joined.
		vertical *= 0.26 + 0.74 * _smoothstep(0.0, 0.085, u)
		for x in range(BEAM_WIDTH):
			var dx: float = absf(float(x) + 0.5 - cx)
			var body: float = clampf(1.0 - pow(dx / half_w, 2.0), 0.0, 1.0)
			body = pow(body, 1.4)
			var core: float = exp(-pow(dx / core_w, 2.0) * 1.6)
			var a: float = vertical * clampf(body * 0.68 + core * 0.90, 0.0, 1.0)
			if a <= 0.004:
				continue
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_shared_beam_tex = ImageTexture.create_from_image(img)
	return _shared_beam_tex

static func _get_glow_texture() -> ImageTexture:
	"""Soft radial pool that lights the tower itself."""
	if _shared_glow_tex != null:
		return _shared_glow_tex
	var img := Image.create(GLOW_SIZE, GLOW_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(GLOW_SIZE) * 0.5
	for y in range(GLOW_SIZE):
		for x in range(GLOW_SIZE):
			var dx: float = (float(x) + 0.5 - c) / c
			var dy: float = (float(y) + 0.5 - c) / c
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 2.2)
			if a <= 0.004:
				continue
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_shared_glow_tex = ImageTexture.create_from_image(img)
	return _shared_glow_tex

static func _get_beam_shader() -> Shader:
	if _shared_beam_shader != null:
		return _shared_beam_shader
	_shared_beam_shader = Shader.new()
	_shared_beam_shader.code = BEAM_SHADER_CODE
	return _shared_beam_shader

func _setup_beacon() -> void:
	if _beacon != null or not _is_the_extractor():
		return

	_beacon_glow = Sprite2D.new()
	_beacon_glow.name = "ObjectiveGlow"
	_beacon_glow.texture = _get_glow_texture()
	_beacon_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_beacon_glow.z_as_relative = false
	_beacon_glow.z_index = GLOW_Z
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beacon_glow.material = glow_mat
	_beacon_glow.position = Vector2(0.0, GLOW_CENTRE_Y)
	_beacon_glow.modulate = Color(BEACON_COLOR.r, BEACON_COLOR.g, BEACON_COLOR.b, GLOW_MIN_ALPHA)
	add_child(_beacon_glow)

	_beacon = Sprite2D.new()
	_beacon.name = "ObjectiveBeacon"
	_beacon.texture = _get_beam_texture()
	_beacon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_beacon.centered = false
	_beacon.z_as_relative = false
	_beacon.z_index = BEACON_Z
	# The shader declares blend_add itself; a ShaderMaterial replaces the
	# CanvasItemMaterial that used to carry the blend mode.
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = _get_beam_shader()
	_beacon.material = beam_mat
	_beacon.position = Vector2(-float(BEAM_WIDTH) * 0.5, BEAM_BASE_Y - float(BEAM_HEIGHT))
	_beacon.modulate = Color(BEACON_COLOR.r, BEACON_COLOR.g, BEACON_COLOR.b, BEACON_MIN_ALPHA)
	add_child(_beacon)

func _update_beacon(delta: float) -> void:
	if _beacon == null or not is_instance_valid(_beacon):
		return
	_beacon_phase += delta * BEACON_PULSE_SPEED
	var progress := 0.0
	if _game != null and "extraction_progress" in _game:
		progress = clampf(float(_game.extraction_progress), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_beacon_phase)

	# Height is fixed. Progress widens and brightens instead, so the beam reaches
	# the sky from the moment the extractor lands while "nearly done" still reads
	# from across the map.
	var alpha := lerpf(BEACON_MIN_ALPHA, BEACON_MAX_ALPHA, progress) * (0.86 + 0.14 * pulse)
	var width_scale := lerpf(BEAM_MIN_WIDTH_SCALE, BEAM_MAX_WIDTH_SCALE, progress)
	_beacon.scale.x = width_scale
	# centered = false, so widening from the left edge would walk the beam
	# sideways off the tower. Re-anchor the left edge on every change.
	_beacon.position.x = -float(BEAM_WIDTH) * 0.5 * width_scale
	_beacon.modulate = Color(BEACON_COLOR.r, BEACON_COLOR.g, BEACON_COLOR.b, alpha)
	var beam_mat := _beacon.material as ShaderMaterial
	if beam_mat != null:
		# The shimmer quickens as extraction closes out.
		beam_mat.set_shader_parameter("shimmer_speed", 1.0 + progress * 1.1)

	if _beacon_glow != null and is_instance_valid(_beacon_glow):
		var glow_alpha := lerpf(GLOW_MIN_ALPHA, GLOW_MAX_ALPHA, progress) * (0.80 + 0.20 * pulse)
		_beacon_glow.modulate = Color(BEACON_COLOR.r, BEACON_COLOR.g, BEACON_COLOR.b, glow_alpha)
		_beacon_glow.scale = Vector2.ONE * (0.96 + 0.06 * pulse)

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
	# Above the building's own sprite (z 1), for the same reason that has: with
	# World/Buildings unsorted, a neighbour placed later simply paints over this.
	# A health bar you cannot see when the thing is being attacked is the one
	# moment it exists for.
	_health_bar_container.z_index = 2
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
