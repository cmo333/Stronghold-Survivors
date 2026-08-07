extends Control

## Arrival cinematic. Plays on every launch; any input skips it.
##
## Beats: black, then the title alone in pixel space among the stars; the stars
## stretch into a warp; a white-out; and out of the white a planet, which you
## fall into until it swallows the screen and the menu takes over.
##
## Everything here is generated - the stars are projected points and the planet
## is a texture built at load. That keeps the whole thing one script with no new
## art to ship, and lets it render at any window size.
##
## It runs on every launch rather than only the first. Gating it on a saved flag
## meant the only way to see it again was a command-line argument, which is not
## a thing anyone reaches for - and a skip that works from the first frame makes
## the gate unnecessary anyway.

const NEXT_SCENE := "res://scenes/main_menu.tscn"
const FONT_PIXEL := "res://assets/ui/pixel_font.ttf"
const TITLE := "AVARICE"
const SUBTITLE := "AGE OF AETHER"

# Beat boundaries, in seconds from the start. Each phase runs until the next.
const T_STARS_IN := 0.9      # black -> stars fade up, slow drift
const T_TITLE := 3.8         # title holds, stars drift
const T_WARP := 4.9          # stars stretch into streaks, title dissolves
const T_WHITE := 5.35        # white-out
const T_DESCENT := 7.9       # out of the white, falling into the planet
const T_END := 8.3           # fade off and hand over

const STAR_COUNT := 520
const STAR_FIELD_DEPTH := 900.0
const FOCAL := 420.0

# Matches the menu's palette so the cinematic hands over to it cleanly.
const COLOR_TITLE := Color(1.0, 0.85, 0.35)
const COLOR_SUBTITLE := Color(0.45, 0.95, 1.0)
const COLOR_HINT := Color(0.62, 0.60, 0.70)

var _t := 0.0
var _stars: Array[Vector3] = []
var _star_prev: PackedVector2Array = PackedVector2Array()
var _speed := 0.0
var _finished := false

var _planet: Sprite2D = null
var _white: ColorRect = null
var _title: Label = null
var _subtitle: Label = null
var _hint: Label = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_seed_stars()
	_build_planet()
	_build_text()
	_build_white()
	AudioManager.play_one_shot("chest_charge", Vector2.ZERO, AudioManager.HIGH_PRIORITY)

func _seed_stars() -> void:
	_stars.clear()
	for i in range(STAR_COUNT):
		_stars.append(_new_star(randf_range(1.0, STAR_FIELD_DEPTH)))
	_star_prev.resize(STAR_COUNT)

func _new_star(z: float) -> Vector3:
	# Spread across a box wider than the screen so stars keep arriving from
	# off-frame instead of all streaming out of a hole in the middle.
	return Vector3(randf_range(-1400.0, 1400.0), randf_range(-900.0, 900.0), z)

func _build_planet() -> void:
	_planet = Sprite2D.new()
	_planet.name = "Planet"
	_planet.texture = _make_planet_texture(96)
	_planet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_planet.visible = false
	add_child(_planet)

func _build_text() -> void:
	var font: FontFile = null
	if ResourceLoader.exists(FONT_PIXEL):
		font = load(FONT_PIXEL)

	_title = Label.new()
	_title.text = TITLE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", COLOR_TITLE)
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0.16, 0.03, 0.06, 1.0))
	_title.modulate.a = 0.0
	if font != null:
		_title.add_theme_font_override("font", font)
	add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.12, 1.0))
	_subtitle.modulate.a = 0.0
	if font != null:
		_subtitle.add_theme_font_override("font", font)
	add_child(_subtitle)

	_hint = Label.new()
	_hint.text = "PRESS ANY KEY TO SKIP"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", COLOR_HINT)
	_hint.modulate.a = 0.0
	if font != null:
		_hint.add_theme_font_override("font", font)
	add_child(_hint)

func _build_white() -> void:
	_white = ColorRect.new()
	_white.name = "Whiteout"
	_white.color = Color(1, 1, 1, 0)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_white)

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_finish()

func _process(delta: float) -> void:
	if _finished or _title == null:
		return
	_t += delta
	var size := get_viewport_rect().size
	var center := size * 0.5

	_layout_text(size)
	_advance_stars(delta)
	_update_title()
	_update_white()
	_update_planet(center)

	if _t >= T_END:
		_finish()
		return
	queue_redraw()

func _layout_text(size: Vector2) -> void:
	_title.size.x = size.x
	_title.position = Vector2(0, size.y * 0.5 - 96)
	_subtitle.size.x = size.x
	_subtitle.position = Vector2(0, size.y * 0.5 - 8)
	_hint.size.x = size.x
	_hint.position = Vector2(0, size.y - 54)

# Star speed ramps gently through the title, then hard through the warp. z is
# distance from the viewer, so subtracting it pulls stars past the camera.
func _advance_stars(delta: float) -> void:
	var target := 60.0
	if _t >= T_TITLE:
		var w := clampf((_t - T_TITLE) / max(0.001, T_WARP - T_TITLE), 0.0, 1.0)
		target = lerpf(60.0, 2400.0, w * w)
	if _t >= T_WARP:
		target = 2400.0
	_speed = lerpf(_speed, target, clampf(delta * 3.0, 0.0, 1.0))
	for i in range(_stars.size()):
		var s := _stars[i]
		s.z -= _speed * delta
		if s.z <= 1.0:
			s = _new_star(STAR_FIELD_DEPTH)
		_stars[i] = s

func _update_title() -> void:
	# Fade in over the first beat, hold, then dissolve into the warp.
	var a := 0.0
	if _t >= T_STARS_IN:
		a = clampf((_t - T_STARS_IN) / 0.9, 0.0, 1.0)
	if _t >= T_TITLE:
		a *= clampf(1.0 - (_t - T_TITLE) / 0.6, 0.0, 1.0)
	_title.modulate.a = a
	_subtitle.modulate.a = a * clampf((_t - T_STARS_IN - 0.5) / 0.8, 0.0, 1.0)
	# A slow drift toward the viewer, so the title sits in the field rather than
	# on top of it.
	var drift := 1.0 + 0.04 * clampf((_t - T_STARS_IN) / 3.0, 0.0, 1.0)
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2(drift, drift)
	# Only offer the skip while there is something to skip; it has no business
	# sitting over the white-out or the descent.
	var hint_a := 0.0
	if _t >= 1.6:
		hint_a = 0.55 * (0.6 + 0.4 * sin(_t * 3.0))
	if _t >= T_TITLE:
		hint_a *= clampf(1.0 - (_t - T_TITLE) / 0.4, 0.0, 1.0)
	_hint.modulate.a = hint_a

func _update_white() -> void:
	var a := 0.0
	if _t >= T_WARP:
		# Slam to white...
		a = clampf((_t - T_WARP) / max(0.001, T_WHITE - T_WARP), 0.0, 1.0)
	if _t >= T_WHITE:
		# ...then bleed off to reveal what you arrived at.
		a = clampf(1.0 - (_t - T_WHITE) / 0.7, 0.0, 1.0)
	if _t >= T_DESCENT:
		# Final wash as the planet swallows the frame, covering the hand-off.
		a = maxf(a, clampf((_t - T_DESCENT) / max(0.001, T_END - T_DESCENT), 0.0, 1.0))
	_white.color.a = a

func _update_planet(center: Vector2) -> void:
	if _t < T_WHITE:
		_planet.visible = false
		return
	if not _planet.visible:
		_planet.visible = true
		AudioManager.play_one_shot("jackpot_fanfare", Vector2.ZERO, AudioManager.CRITICAL_PRIORITY)
	var p := clampf((_t - T_WHITE) / max(0.001, T_DESCENT - T_WHITE), 0.0, 1.0)
	# Ease in: the fall accelerates, which is what selling "falling" needs.
	var eased := p * p * p
	_planet.position = center + Vector2(0.0, lerpf(-10.0, 90.0, eased))
	var s := lerpf(1.2, 26.0, eased)
	_planet.scale = Vector2(s, s)

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 1.0), true)
	if _t >= T_WHITE:
		return  # past the white-out the planet owns the frame
	var center := size * 0.5
	var fade := clampf(_t / T_STARS_IN, 0.0, 1.0)
	# Warp streaks: draw from where the star was one step ago to where it is now.
	var streak := clampf((_speed - 200.0) / 1600.0, 0.0, 1.0)
	for i in range(_stars.size()):
		var s := _stars[i]
		var sp := center + Vector2(s.x, s.y) * (FOCAL / s.z)
		if sp.x < -80.0 or sp.y < -80.0 or sp.x > size.x + 80.0 or sp.y > size.y + 80.0:
			_star_prev[i] = sp
			continue
		# Nearer stars are bigger and brighter - that is the only depth cue a
		# field of identical dots gets.
		var near := clampf(1.0 - s.z / STAR_FIELD_DEPTH, 0.0, 1.0)
		var px: float = 1.0 + round(near * 2.0)
		var a := (0.42 + 0.58 * near) * fade
		var col := Color(1.0, 0.97, 0.9, a)
		if streak > 0.02:
			var prev: Vector2 = _star_prev[i]
			if prev != Vector2.ZERO and prev.distance_squared_to(sp) < 400000.0:
				draw_line(prev, sp, col, px)
			else:
				draw_rect(Rect2(sp, Vector2(px, px)), col, true)
		else:
			draw_rect(Rect2(sp, Vector2(px, px)), col, true)
		_star_prev[i] = sp

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_go_to_menu()

func _go_to_menu() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)

# ---- Planet ----

# A small shaded disc, built once and drawn with nearest filtering so blowing it
# up to fill the screen reads as chunky pixel art rather than a blurry circle.
static func _make_planet_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := float(size) * 0.5
	var center := Vector2(r, r)
	# Light from the upper left, which is where the star we just flew past is.
	var light := Vector3(-0.55, -0.6, 0.58).normalized()
	var sea := Color(0.09, 0.24, 0.34)
	var land := Color(0.30, 0.42, 0.20)
	var sand := Color(0.52, 0.45, 0.26)
	var ice := Color(0.80, 0.86, 0.90)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5) - center
			var dist := d.length() / r
			if dist > 1.0:
				continue
			# Sphere normal from the disc position.
			var nz := sqrt(maxf(0.0, 1.0 - dist * dist))
			var n := Vector3(d.x / r, d.y / r, nz)
			# Cheap banded continents: two out-of-phase waves over the surface,
			# biased by latitude so the poles ice over.
			var lat: float = n.y
			var lon: float = atan2(n.x, n.z)
			var h: float = sin(lon * 3.1 + lat * 4.0) * 0.5 + sin(lon * 7.3 - lat * 2.0) * 0.3
			var base := sea
			if h > 0.12:
				base = land
			if h > 0.44:
				base = sand
			if absf(lat) > 0.74:
				base = ice
			var diffuse: float = clampf(n.dot(light), 0.0, 1.0)
			# Ambient floor keeps the night side readable instead of black.
			var shade: float = 0.22 + 0.95 * diffuse
			var col := Color(base.r * shade, base.g * shade, base.b * shade, 1.0)
			# Atmosphere: a cool rim that brightens toward the edge of the disc.
			var rim: float = pow(clampf(dist, 0.0, 1.0), 6.0)
			col = col.lerp(Color(0.55, 0.78, 1.0), rim * 0.65)
			# Quantise so the surface reads as a limited palette when magnified.
			col = Color(_step(col.r), _step(col.g), _step(col.b), 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

static func _step(v: float) -> float:
	return round(clampf(v, 0.0, 1.0) * 7.0) / 7.0
