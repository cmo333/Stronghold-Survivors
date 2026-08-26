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
const QUOTE := "Alexander wept for with the number of worlds infinite he had yet to conquer one"
const SIGNOFF := "GOOD LUCK"

# Fixed beats, in seconds from the start.
const T_STARS_IN := 0.9      # black -> stars fade up, slow drift
const T_TITLE_OUT := 3.0     # title starts dissolving
const T_QUOTE := 3.5         # first character of the quote

# The rest is derived from how long the text takes to type, so editing QUOTE
# reflows the whole cinematic instead of desyncing it from hardcoded beats.
# +3s of quote on screen, split between a slower reveal and a longer dwell:
# 34 -> 26 cps adds ~0.7s to the typing so it lands slightly slower, and the
# dwell carries the remaining ~2.3s. Everything downstream is derived in
# _build_timeline(), so the sign-off, warp, white and hand-off all shift with
# it rather than needing to be re-timed by hand.
const QUOTE_CPS := 26.0      # characters per second
const QUOTE_HOLD := 3.2      # dwell on the finished line before it clears
const SIGNOFF_GAP := 0.4     # dark beat between the quote and the sign-off
const SIGNOFF_CPS := 8.0     # slower: two words landing one at a time
const SIGNOFF_HOLD := 0.8
const TEXT_FADE := 0.35
const WARP_TIME := 0.9       # sign-off gone -> full white
const WHITE_TO_DESCENT := 2.3
const HANDOFF := 0.4

# Typewriter ticks, kept quiet and slightly detuned so a line of them reads as
# texture rather than a machine gun.
const TICK_VOLUME_DB := -22.0
const TICK_VOICES := 4

const STAR_COUNT := 520
const STAR_FIELD_DEPTH := 900.0
const FOCAL := 420.0

# Matches the menu's palette so the cinematic hands over to it cleanly.
const COLOR_TITLE := Color(1.0, 0.85, 0.35)
const COLOR_SUBTITLE := Color(0.45, 0.95, 1.0)
const COLOR_HINT := Color(0.62, 0.60, 0.70)
# Cooler and dimmer than the title: the quote is meant to be read, not shouted.
const COLOR_QUOTE := Color(0.86, 0.88, 0.94)

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
var _quote: Label = null
var _signoff: Label = null

# Derived beat boundaries, filled in by _build_timeline().
var _quote_end := 0.0
var _quote_gone := 0.0
var _signoff_start := 0.0
var _signoff_end := 0.0
var _signoff_gone := 0.0
var _t_warp := 0.0
var _t_white := 0.0
var _t_descent := 0.0
var _t_end := 0.0

var _ticks: Array[AudioStreamPlayer] = []
var _tick_voice := 0
var _quote_shown := 0
var _signoff_shown := 0
var _title_stung := false
var _quote_stung := false
var _signoff_stung := false
var _warp_stung := false

func _ready() -> void:
	# The DPS harness lives in main.tscn, but the boot scene is this cinematic
	# and the only way past it is an input a headless run can never supply.
	# Without this, `--dps-test` would sit on the star field forever.
	if OS.get_cmdline_user_args().has("--dps-test"):
		call_deferred("_skip_to_game")
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# No Rift roll here. The boot cinematic is the game's one fixed text -- the
	# roll happens when PLAY is pressed (RunManifest.deal) and is narrated by
	# the descent, so the story you are told is the story of the run you are
	# about to play, not of a boot that might sit on the menu for an hour.
	_build_timeline()
	_build_ticks()
	_seed_stars()
	_build_planet()
	_build_text()
	_build_white()
	AudioManager.play_one_shot("chest_charge", Vector2.ZERO, AudioManager.HIGH_PRIORITY)

func _build_timeline() -> void:
	_quote_end = T_QUOTE + float(QUOTE.length()) / QUOTE_CPS
	_quote_gone = _quote_end + QUOTE_HOLD + TEXT_FADE
	_signoff_start = _quote_gone + SIGNOFF_GAP
	_signoff_end = _signoff_start + float(SIGNOFF.length()) / SIGNOFF_CPS
	_signoff_gone = _signoff_end + SIGNOFF_HOLD + TEXT_FADE
	_t_warp = _signoff_gone
	_t_white = _t_warp + WARP_TIME
	_t_descent = _t_white + WHITE_TO_DESCENT
	_t_end = _t_descent + HANDOFF

# A small pool of players rather than one shot per character: at 34 characters a
# second the per-call node churn is real, and a pool lets ticks overlap without
# cutting each other off.
func _build_ticks() -> void:
	var stream = load("res://assets/audio/ui/hover.wav") if ResourceLoader.exists("res://assets/audio/ui/hover.wav") else null
	if stream == null:
		return
	for i in range(TICK_VOICES):
		var pl := AudioStreamPlayer.new()
		pl.stream = stream
		pl.bus = "UI" if AudioServer.get_bus_index("UI") >= 0 else "Master"
		pl.volume_db = TICK_VOLUME_DB
		add_child(pl)
		_ticks.append(pl)

func _tick(pitch: float) -> void:
	if _ticks.is_empty():
		return
	var pl: AudioStreamPlayer = _ticks[_tick_voice]
	_tick_voice = (_tick_voice + 1) % _ticks.size()
	pl.pitch_scale = pitch * randf_range(0.94, 1.06)
	pl.play()

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

	# The quote is mixed-case and wraps; the sign-off is a single short sting.
	_quote = Label.new()
	_quote.text = QUOTE
	_quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.add_theme_font_size_override("font_size", 20)
	_quote.add_theme_color_override("font_color", COLOR_QUOTE)
	_quote.add_theme_constant_override("outline_size", 6)
	_quote.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 1.0))
	_quote.add_theme_constant_override("line_spacing", 10)
	_quote.visible_characters = 0
	_quote.modulate.a = 0.0
	if font != null:
		_quote.add_theme_font_override("font", font)
	add_child(_quote)

	_signoff = Label.new()
	_signoff.text = SIGNOFF
	_signoff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_signoff.add_theme_font_size_override("font_size", 34)
	_signoff.add_theme_color_override("font_color", COLOR_TITLE)
	_signoff.add_theme_constant_override("outline_size", 7)
	_signoff.add_theme_color_override("font_outline_color", Color(0.16, 0.03, 0.06, 1.0))
	_signoff.visible_characters = 0
	_signoff.modulate.a = 0.0
	if font != null:
		_signoff.add_theme_font_override("font", font)
	add_child(_signoff)

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
	_update_typed_lines()
	_update_white()
	_update_planet(center)

	if _t >= _t_end:
		_finish()
		return
	queue_redraw()

func _layout_text(size: Vector2) -> void:
	_title.size.x = size.x
	_title.position = Vector2(0, size.y * 0.5 - 96)
	_subtitle.size.x = size.x
	_subtitle.position = Vector2(0, size.y * 0.5 - 8)
	# Give the quote a measured column instead of the full width, so it breaks
	# into a couple of lines rather than one long stripe on a wide window.
	var quote_w: float = clampf(size.x * 0.62, 420.0, 900.0)
	_quote.size.x = quote_w
	_quote.position = Vector2((size.x - quote_w) * 0.5, size.y * 0.5 - 34)
	_signoff.size.x = size.x
	_signoff.position = Vector2(0, size.y * 0.5 - 24)
	_hint.size.x = size.x
	_hint.position = Vector2(0, size.y - 54)

# Star speed ramps gently through the title, then hard through the warp. z is
# distance from the viewer, so subtracting it pulls stars past the camera.
func _advance_stars(delta: float) -> void:
	# Creep during the title and the text, then ramp hard once the sign-off
	# clears - the quote should be read against a near-still field.
	var target := 60.0
	var ramp_from: float = _signoff_start
	if _t >= ramp_from:
		var w := clampf((_t - ramp_from) / max(0.001, _t_warp - ramp_from), 0.0, 1.0)
		target = lerpf(60.0, 2400.0, w * w)
	if _t >= _t_warp:
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
	if _t >= T_TITLE_OUT:
		a *= clampf(1.0 - (_t - T_TITLE_OUT) / 0.5, 0.0, 1.0)
	if a > 0.9 and not _title_stung:
		_title_stung = true
		AudioManager.play_ui_sound("wave_start")
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
	if _t >= T_TITLE_OUT:
		hint_a *= clampf(1.0 - (_t - T_TITLE_OUT) / 0.4, 0.0, 1.0)
	_hint.modulate.a = hint_a

# Reveal characters on a clock rather than per frame, so the cadence is the same
# at 30fps and 240fps, and tick a sound on each newly revealed non-space glyph.
func _update_typed_lines() -> void:
	# --- the quote ---
	var q_a := 0.0
	if _t >= T_QUOTE:
		q_a = clampf((_t - T_QUOTE) / 0.25, 0.0, 1.0)
		var want: int = int(floor((_t - T_QUOTE) * QUOTE_CPS))
		want = clampi(want, 0, QUOTE.length())
		if want > _quote_shown:
			# One tick for the batch, not per character: a long frame must not
			# fire six clicks at once.
			var voiced := false
			for i in range(_quote_shown, want):
				if QUOTE[i] != " ":
					voiced = true
			if voiced:
				_tick(1.0)
			_quote_shown = want
			_quote.visible_characters = want
		if not _quote_stung:
			_quote_stung = true
			AudioManager.play_ui_sound("hover")
	if _t >= _quote_end + QUOTE_HOLD:
		q_a *= clampf(1.0 - (_t - _quote_end - QUOTE_HOLD) / TEXT_FADE, 0.0, 1.0)
	_quote.modulate.a = q_a

	# --- the sign-off ---
	var s_a := 0.0
	if _t >= _signoff_start:
		s_a = clampf((_t - _signoff_start) / 0.2, 0.0, 1.0)
		var want2: int = int(floor((_t - _signoff_start) * SIGNOFF_CPS))
		want2 = clampi(want2, 0, SIGNOFF.length())
		if want2 > _signoff_shown:
			var voiced2 := false
			for i in range(_signoff_shown, want2):
				if SIGNOFF[i] != " ":
					voiced2 = true
			if voiced2:
				# Deeper than the quote: this line is the one that lands.
				_tick(0.72)
			_signoff_shown = want2
			_signoff.visible_characters = want2
		if _signoff_shown >= SIGNOFF.length() and not _signoff_stung:
			_signoff_stung = true
			AudioManager.play_ui_sound("upgrade")
	if _t >= _signoff_end + SIGNOFF_HOLD:
		s_a *= clampf(1.0 - (_t - _signoff_end - SIGNOFF_HOLD) / TEXT_FADE, 0.0, 1.0)
	_signoff.modulate.a = s_a
	# A slow swell on the sign-off so it grows into the warp.
	var grow := 1.0 + 0.06 * clampf((_t - _signoff_start) / 1.6, 0.0, 1.0)
	_signoff.pivot_offset = _signoff.size * 0.5
	_signoff.scale = Vector2(grow, grow)

	# --- the riser under the warp ---
	if _t >= _t_warp and not _warp_stung:
		_warp_stung = true
		AudioManager.play_one_shot("chest_charge", Vector2.ZERO, AudioManager.HIGH_PRIORITY)

func _update_white() -> void:
	var a := 0.0
	if _t >= _t_warp:
		# Slam to white...
		a = clampf((_t - _t_warp) / max(0.001, _t_white - _t_warp), 0.0, 1.0)
	if _t >= _t_white:
		# ...then bleed off to reveal what you arrived at.
		a = clampf(1.0 - (_t - _t_white) / 0.7, 0.0, 1.0)
	if _t >= _t_descent:
		# Final wash as the planet swallows the frame, covering the hand-off.
		a = maxf(a, clampf((_t - _t_descent) / max(0.001, _t_end - _t_descent), 0.0, 1.0))
	_white.color.a = a

func _update_planet(center: Vector2) -> void:
	if _t < _t_white:
		_planet.visible = false
		return
	if not _planet.visible:
		_planet.visible = true
		AudioManager.play_one_shot("jackpot_fanfare", Vector2.ZERO, AudioManager.CRITICAL_PRIORITY)
	var p := clampf((_t - _t_white) / max(0.001, _t_descent - _t_white), 0.0, 1.0)
	# Ease in: the fall accelerates, which is what selling "falling" needs.
	var eased := p * p * p
	_planet.position = center + Vector2(0.0, lerpf(-10.0, 90.0, eased))
	var s := lerpf(1.2, 26.0, eased)
	_planet.scale = Vector2(s, s)

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 1.0), true)
	if _t >= _t_white:
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

const GAME_SCENE := "res://scenes/main.tscn"

# Straight into the run, skipping the cinematic and the menu. Only reachable
# from the --dps-test switch; see the note in _ready.
func _skip_to_game() -> void:
	_finished = true
	get_tree().change_scene_to_file(GAME_SCENE)

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
