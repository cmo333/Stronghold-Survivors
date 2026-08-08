extends Control

## Descent: the ~13s transition between pressing Play and the run starting.
##
## The world is not there yet, so it builds itself. A single point of light, a
## plane that weaves itself outward from it in perspective, jewels that lock
## into the lattice, a dive down through the surface, and a vortex that drags
## the whole plane inward. Then the signal breaks up into static and someone on
## the far side of the rift tells you to hurry.
##
## main.tscn loads on a background thread for the whole of it, so the hand-off
## at the end is a pointer swap rather than a stall.
##
## Everything is drawn, not authored - projected geometry snapped to a chunky
## virtual pixel so it reads as pixel art rather than clean vector lines, which
## is what "pixelated" has to mean when there is no art to sample.
##
## The whole thing runs on one beat clock. The pulse you see (tiles flexing,
## jewels flaring, the horizon breathing) and the pulse you hear are the same
## number, so nothing has to be hand-synced.
##
## Any input skips to the run.

const NEXT_SCENE := "res://scenes/main.tscn"

# Beats, in seconds.
const T_SPARK := 1.2         # one point of light, pulsing alone
const T_WEAVE := 4.2         # the lattice draws itself outward
const T_JEWELS := 6.0        # jewels lock in
const T_CASCADE := 7.0       # tiles flood the plane, the frame starts shaking
const T_VORTEX := 8.0        # everything spirals inward
const T_STATIC := 9.0          # signal breaks up: scrambled static wipe
const T_MESSAGE := 9.9         # the rift warning
const T_SCRAMBLE_OUT := 13.9   # 4.0s of message, then it tears apart again
const T_END := 14.4            # hand over to the run

# What used to sit between T_STATIC and T_END was a "spawn" beat: a collapsing
# ring with a twelve-block stick figure fading up inside it, meant to read as the
# character arriving. It read as a crudely drawn something-or-other, so it is
# gone. The signal tearing itself apart and a warning from whoever is on the
# other end of it does the same job -- covering the hand-off -- without asking
# twelve rectangles to look like a person.

const MESSAGE_LINES := "The time is fleeting.\nWe don't know how long the rift will stay open.\nExtract as much as you can, traveler..."
const MESSAGE_STING := "More are coming."
const T_STING_IN := 2.55     # seconds into the message beat
const MESSAGE_FADE := 0.30
const TYPE_LINES := 2.0      # seconds to type the three lines on
const TYPE_STING := 0.55     # seconds to type the sting on
const MESSAGE_MARGIN := 110.0

# The hand-off used to cut from the message screen straight to the run. Measured
# off frames of each: the message screen averages luma 0.094 and the first frame
# of a run averages 0.42, so that cut is a 4.5x jump in brightness and it lands
# like a flashbulb. The out-scramble ramps the whole field up to meet it.
#
# Cool grey rather than the map's green: matching the LUMA is what kills the
# flash, and the colour is free to stay in the black-and-space register the rest
# of the sequence lives in. 0.2126*0.40 + 0.7152*0.43 + 0.0722*0.47 = 0.427,
# against the run's measured 0.42.
const HANDOFF_WASH := Color(0.40, 0.43, 0.47)

# Dead-channel palette: cold whites and blues over black, no green.
const STATIC_TINT := Color(0.62, 0.68, 0.82)

const COLOR_MESSAGE := Color(0.72, 1.0, 0.86)
const COLOR_STING := Color(1.0, 0.42, 0.34)

# Vortex shape. Angular speed rises toward the centre, so the middle whips round
# while the rim is still turning lazily - that is what reads as a whirlpool
# rather than a record spinning.
const VORTEX_TURNS := 2.4
const VORTEX_PULL := 0.06    # how far in the rim ends up (1.0 = no pull)
const SHAKE_MAX := 14.0

const BPM := 120.0
const BEAT := 60.0 / BPM     # 0.5s
const ACCENT_EVERY := 4

# Virtual pixel size in screen pixels. Everything is snapped to this, so the
# lattice has the same chunk as the game's art instead of hairline edges.
const PIXEL := 4.0

# Perspective. The plane sits below the camera; screen y for a point at depth z
# is horizon + (height * FOCAL) / z.
const FOCAL := 300.0
const GRID_HALF := 9         # cells either side of centre
const GRID_DEPTH := 16       # cells ahead
const CELL := 1.0            # world units per cell

const COLOR_LATTICE := Color(0.42, 0.95, 1.0)     # arcane cyan, matches the menu
const COLOR_LATTICE_DIM := Color(0.16, 0.42, 0.55)
const COLOR_GROUND := Color(0.20, 0.34, 0.16)
const JEWEL_PALETTE := [
	Color(0.95, 0.32, 0.55),   # rose
	Color(0.45, 0.95, 1.00),   # cyan
	Color(1.00, 0.82, 0.30),   # gold
	Color(0.72, 0.45, 1.00),   # violet
	Color(0.40, 1.00, 0.60),   # jade
]

var _t := 0.0
var _finished := false
var _beat_index := -1
var _rng := RandomNumberGenerator.new()
var _thump: Array[AudioStreamPlayer] = []
var _thump_voice := 0
var _riser_played := false
var _static_played := false
var _out_played := false
var _cascade_played := false
var _shake := Vector2.ZERO
var _message: Label = null
var _sting: Label = null
var _preload_started := false
var _world: Node = null
var _world_layers: Array[CanvasLayer] = []
var _typewriter_chars := -1
var _skip_next_delta := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Above everything the run can draw. Tree order alone is not enough to keep
	# the world covered while it is mounted behind this scene: z_index outranks
	# it, and the run uses the range freely -- towers 0-2, the extractor beacon
	# 60, the player 120. Caught in a render, where the player and its health bar
	# were sitting on top of the transition in the top-left corner, drawn at the
	# world origin because the camera is off. 4096 is the engine's maximum.
	z_index = 4096
	z_as_relative = false
	# Fixed seed: the lattice assembles the same way every time, so the sequence
	# is a designed thing rather than a different accident on each launch.
	_rng.seed = 20260808
	_build_audio()
	_build_message()
	_begin_preload()

func _begin_preload() -> void:
	"""Load the run on a background thread while the descent plays.

	This is where the dead air came from. change_scene_to_file() loads
	main.tscn synchronously at the moment it is called, so the descent would
	finish, the frame would stop, and the player sat on a held image for as long
	as the scene took to come off disk. Nothing was animating; there was simply
	nothing else the main thread could do.

	Starting the request in _ready gives the loader the entire ~15s of the
	descent to work in, so by the time _finish runs the scene is already in
	memory and the hand-off is a pointer swap."""
	if _preload_started:
		return
	if not ResourceLoader.exists(NEXT_SCENE):
		return
	_preload_started = ResourceLoader.load_threaded_request(NEXT_SCENE) == OK

func _build_message() -> void:
	var font: FontFile = null
	if ResourceLoader.exists("res://assets/ui/pixel_font.ttf"):
		font = load("res://assets/ui/pixel_font.ttf")

	_message = Label.new()
	_message.name = "RiftMessage"
	_message.text = MESSAGE_LINES
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 22)
	_message.add_theme_color_override("font_color", COLOR_MESSAGE)
	_message.add_theme_constant_override("outline_size", 6)
	_message.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.05))
	_message.add_theme_constant_override("line_spacing", 12)
	if font != null:
		_message.add_theme_font_override("font", font)
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Side margins plus word wrap. A Label does not clip to its rect by default,
	# so a line wider than the viewport just runs off both edges -- which is what
	# the first cut did, losing "...how long the rift will stay open" past the
	# right of the frame. Wrapping inside a bounded box makes overflow
	# unrepresentable rather than something to re-check by eye at each font size.
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD
	_message.offset_left = MESSAGE_MARGIN
	_message.offset_right = -MESSAGE_MARGIN
	_message.offset_top = -70.0
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	add_child(_message)

	_sting = Label.new()
	_sting.name = "RiftSting"
	_sting.text = MESSAGE_STING
	_sting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sting.add_theme_font_size_override("font_size", 34)
	_sting.add_theme_color_override("font_color", COLOR_STING)
	_sting.add_theme_constant_override("outline_size", 7)
	_sting.add_theme_color_override("font_outline_color", Color(0.10, 0.01, 0.01))
	if font != null:
		_sting.add_theme_font_override("font", font)
	_sting.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sting.autowrap_mode = TextServer.AUTOWRAP_WORD
	_sting.offset_left = MESSAGE_MARGIN
	_sting.offset_right = -MESSAGE_MARGIN
	_sting.offset_top = 130.0
	_sting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sting.modulate.a = 0.0
	add_child(_sting)

func _update_message() -> void:
	if _message == null or _sting == null:
		return
	if _t < T_MESSAGE:
		_message.modulate.a = 0.0
		_sting.modulate.a = 0.0
		return
	var m: float = _t - T_MESSAGE
	# Cleared before the out-scramble is fully up. Text surviving into the noise
	# reads as a rendering fault rather than a transition.
	var out: float = clampf(1.0 - (_t - T_SCRAMBLE_OUT) / 0.16, 0.0, 1.0)
	_message.modulate.a = clampf(m / MESSAGE_FADE, 0.0, 1.0) * out
	_sting.modulate.a = clampf((m - T_STING_IN) / MESSAGE_FADE, 0.0, 1.0) * out
	# Typed on rather than faded in. visible_ratio counts through the string the
	# Label already laid out, so wrapping, centring and the outline all stay
	# exactly as they are and no per-character bookkeeping is needed.
	_message.visible_ratio = clampf(m / TYPE_LINES, 0.0, 1.0)
	_sting.visible_ratio = clampf((m - T_STING_IN) / TYPE_STING, 0.0, 1.0)
	_tick_typewriter()

func _tick_typewriter() -> void:
	"""One tick per character revealed, from a pool, skipping whitespace.

	Driven off the count rather than per frame, so the cadence is the same at
	30fps and at 240fps, and a long frame fires one tick instead of a burst."""
	var shown: int = _message.visible_characters + _sting.visible_characters
	if _typewriter_chars < 0:
		_typewriter_chars = shown
		return
	if shown <= _typewriter_chars:
		return
	var stepped := shown > _typewriter_chars + 1
	_typewriter_chars = shown
	if stepped:
		return
	_play_thump(2.6 + randf_range(-0.12, 0.12), -28.0)

func _try_mount_world() -> void:
	"""Build the run behind this scene, while the animation is still playing.

	Preloading the resource off-thread only ever removed part of the wait.
	main.tscn's _ready() -- where the world is actually assembled -- runs on the
	main thread the moment the node enters the tree, and no amount of background
	loading moves that. Measured before any of this: 1.0s resource load, then
	5.9s in _ready, then 0.9s on the first frame.

	So the node is added here instead of at the end, as early as the loader
	allows. It goes in behind this Control and is held completely inert:

	  * PROCESS_MODE_DISABLED stops _process, _physics_process and every input
	    callback, so the run sits at frame zero rather than playing underneath.
	  * its Camera2D is switched off, because a live Camera2D owns the canvas
	    transform for the default layer and would drag this Control off-screen
	    along with the world.
	  * its CanvasLayers are hidden -- the HUD sits on layer 2 and would
	    otherwise draw straight over the top of the descent regardless of tree
	    order.

	Everything else stays visible, hidden behind an opaque backdrop, so the
	world's textures and shaders warm up on a covered frame instead of on the
	player's first."""
	if _world != null or _finished or not _preload_started:
		return
	if ResourceLoader.load_threaded_get_status(NEXT_SCENE) != ResourceLoader.THREAD_LOAD_LOADED:
		return
	var packed = ResourceLoader.load_threaded_get(NEXT_SCENE)
	if not (packed is PackedScene):
		_preload_started = false
		return
	var started := Time.get_ticks_usec()
	var inst: Node = (packed as PackedScene).instantiate()
	inst.process_mode = Node.PROCESS_MODE_DISABLED
	var tree_root := get_tree().root
	tree_root.add_child(inst)
	tree_root.move_child(inst, 0)
	_world = inst
	if "camera" in inst and inst.camera != null:
		inst.camera.enabled = false
	# Only the ones that were actually showing, and remember exactly those. A
	# blanket hide-all / show-all restores PauseMenu, SettingsMenu and GameOverUI
	# to visible whether or not they started that way, which would put the
	# game-over screen up over a run that has not started yet.
	for child in inst.get_children():
		if child is CanvasLayer and (child as CanvasLayer).visible:
			(child as CanvasLayer).visible = false
			_world_layers.append(child as CanvasLayer)
	# Swallow the next frame's delta. Building the world stops the main thread,
	# and that time arrives as one enormous delta on the FOLLOWING frame -- left
	# alone it fast-forwards the animation by most of a second and skips a beat
	# outright. Subtracting the measured duration here instead does not work:
	# _t += delta runs at the top of _process, before this, so the correction
	# lands a frame early and the jump still arrives. Cancelling the frame the
	# stall actually shows up on is exact.
	_skip_next_delta = true
	print("[descent] world built behind the transition in %.0f ms" % (
		float(Time.get_ticks_usec() - started) / 1000.0))

func _reveal_world() -> bool:
	if _world == null or not is_instance_valid(_world):
		return false
	if "camera" in _world and _world.camera != null:
		_world.camera.enabled = true
	for layer in _world_layers:
		if is_instance_valid(layer):
			layer.visible = true
	_world.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = _world
	_world = null
	queue_free()
	return true

func _build_audio() -> void:
	for path in ["res://assets/audio/sfx/building_hit.wav", "res://assets/audio/sfx/shield_hit.wav"]:
		if not ResourceLoader.exists(path):
			continue
		for i in range(3):
			var pl := AudioStreamPlayer.new()
			pl.stream = load(path)
			pl.bus = "UI" if AudioServer.get_bus_index("UI") >= 0 else "Master"
			add_child(pl)
			_thump.append(pl)

func _play_thump(pitch: float, volume_db: float) -> void:
	if _thump.is_empty():
		return
	var pl: AudioStreamPlayer = _thump[_thump_voice]
	_thump_voice = (_thump_voice + 1) % _thump.size()
	pl.pitch_scale = pitch
	pl.volume_db = volume_db
	pl.play()

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_finish()

func _process(delta: float) -> void:
	if _finished:
		return
	if _skip_next_delta:
		_skip_next_delta = false
		delta = 0.0
	_t += delta
	_tick_beat()
	_update_shake(delta)
	if _t >= T_CASCADE and not _cascade_played:
		_cascade_played = true
		AudioManager.play_ui_sound("wave_start")
	if _t >= T_VORTEX and not _riser_played:
		_riser_played = true
		AudioManager.play_one_shot("chest_charge", Vector2.ZERO, AudioManager.HIGH_PRIORITY)
	if _t >= T_STATIC and not _static_played:
		_static_played = true
		AudioManager.play_one_shot("lightning_crack", Vector2.ZERO, AudioManager.HIGH_PRIORITY)
	if _t >= T_SCRAMBLE_OUT and not _out_played:
		_out_played = true
		AudioManager.play_one_shot("lightning_crack", Vector2.ZERO, AudioManager.HIGH_PRIORITY)
	_try_mount_world()
	_update_message()
	if _t >= T_END:
		_finish()
		return
	queue_redraw()

# The audible half of the pulse. The visual half reads the same clock in _beat_phase().
func _tick_beat() -> void:
	var idx := int(floor(_t / BEAT))
	if idx == _beat_index:
		return
	_beat_index = idx
	# Silent until the first light appears, and it drops out during the dive so
	# the riser owns the last stretch.
	if _t > T_VORTEX:
		return
	var accent := idx % ACCENT_EVERY == 0
	# The kit gets louder and brighter as the world assembles.
	var build := clampf(_t / T_CASCADE, 0.0, 1.0)
	# The cascade doubles the kit into eighths, so the run-up to the vortex
	# accelerates audibly as well as visually.
	if _t >= T_CASCADE:
		_play_thump(1.15, -16.0)
	if accent:
		_play_thump(0.62, lerpf(-20.0, -6.0, build))
	else:
		_play_thump(0.9, lerpf(-26.0, -13.0, build))

# 1 on the beat, decaying to 0 before the next one.
func _beat_phase() -> float:
	var f: float = fposmod(_t, BEAT) / BEAT
	return pow(1.0 - f, 3.0)

func _snap(v: Vector2) -> Vector2:
	return Vector2(round(v.x / PIXEL) * PIXEL, round(v.y / PIXEL) * PIXEL)

# Builds through the cascade, peaks in the vortex, gone by the spawn. Re-rolled
# per frame rather than smoothed: a vibration wants to be jittery.
func _update_shake(_delta: float) -> void:
	var amount := 0.0
	if _t >= T_CASCADE:
		amount = clampf((_t - T_CASCADE) / max(0.001, T_VORTEX - T_CASCADE), 0.0, 1.0) * 0.55
	if _t >= T_VORTEX:
		amount = lerpf(0.55, 1.0, clampf((_t - T_VORTEX) / max(0.001, T_STATIC - T_VORTEX), 0.0, 1.0))
	if _t >= T_STATIC:
		amount *= clampf(1.0 - (_t - T_STATIC) / 0.35, 0.0, 1.0)
	if amount <= 0.0:
		_shake = Vector2.ZERO
		return
	var mag := SHAKE_MAX * amount
	# Snapped, so the whole frame jumps by whole virtual pixels instead of
	# smearing sub-pixel - it reads as a hard vibration, not a wobble.
	_shake = _snap(Vector2(randf_range(-mag, mag), randf_range(-mag, mag)))

func _vortex_amount() -> float:
	if _t < T_VORTEX:
		return 0.0
	return clampf((_t - T_VORTEX) / max(0.001, T_STATIC - T_VORTEX), 0.0, 1.0)

# Every drawn point goes through here: shake, then the spiral. Angular speed
# scales with how close the point already is to the centre, and the whole field
# is pulled inward, so the plane winds itself into the drain.
func _warp(p: Vector2, size: Vector2) -> Vector2:
	var q := p + _shake
	var v := _vortex_amount()
	if v <= 0.0:
		return _snap(q)
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	var d := q - c
	var r := d.length()
	var max_r: float = size.length() * 0.5
	var closeness: float = clampf(1.0 - r / max_r, 0.0, 1.0)
	var swirl: float = v * VORTEX_TURNS * TAU * (0.25 + 0.75 * closeness)
	var pull: float = lerpf(1.0, VORTEX_PULL, v * v)
	return _snap(c + d.rotated(swirl) * pull)

# Camera height above the plane. Falls away through the dive so the surface
# rushes up and finally passes the viewer.
func _cam_height() -> float:
	# Settles toward the plane and holds. The old version dived to 0.06, which
	# collapses the plane to a stripe; the vortex does the travelling now.
	var settle := lerpf(3.4, 1.9, clampf(_t / T_VORTEX, 0.0, 1.0))
	return settle + _beat_phase() * 0.06

func _scroll() -> float:
	# Constant drift forward, accelerating into the dive.
	var base := _t * 0.55
	if _t >= T_CASCADE:
		# A shove forward as the tiles flood in.
		base += pow((_t - T_CASCADE) / max(0.001, T_VORTEX - T_CASCADE), 2.0) * 1.6
	return base

# Project a point on the plane (x across, z ahead) to the screen.
func _project(x: float, z: float, size: Vector2) -> Vector2:
	var h := _cam_height()
	var zz: float = maxf(z, 0.05)
	return Vector2(size.x * 0.5 + (x * FOCAL) / zz, size.y * 0.42 + (h * FOCAL) / zz)

# When a cell joins the lattice: centre first, rippling outward, with a little
# per-cell jitter so the edge of the ripple is ragged rather than a clean disc.
func _cell_arrival(gx: int, gz: int) -> float:
	var d := sqrt(float(gx * gx) + float(gz * gz))
	var jitter := _hash01(gx, gz) * 0.5
	return T_SPARK + (d / 12.0) * (T_WEAVE - T_SPARK) + jitter

func _hash01(a: int, b: int) -> float:
	var n := int(a * 73856093) ^ int(b * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	# Fold to 0..1 without pulling on the RNG per frame.
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0

func _draw() -> void:
	var size := get_viewport_rect().size
	_draw_backdrop(size)
	if _t < T_SPARK * 0.35:
		_draw_spark(size)
		return
	if _t < T_STATIC:
		_draw_lattice(size)
		_draw_jewels(size)
		if _t >= T_VORTEX:
			_draw_vortex_streaks(size)
	elif _t < T_MESSAGE:
		_draw_static(size)
	elif _t >= T_SCRAMBLE_OUT:
		_draw_scramble_out(size)

func _draw_backdrop(size: Vector2) -> void:
	# Deep space that warms toward the ground colour as the world resolves.
	# Keyed to T_STATIC, not T_END: the warm-up belongs to the lattice assembling,
	# and T_END now sits five seconds later on the far side of the message.
	var warm := clampf((_t - T_JEWELS) / max(0.001, T_STATIC - T_JEWELS), 0.0, 1.0)
	var top := Color(0.02, 0.02, 0.05).lerp(Color(0.05, 0.09, 0.06), warm)
	draw_rect(Rect2(Vector2.ZERO, size), top, true)

func _draw_spark(size: Vector2) -> void:
	var c := size * 0.5
	var pulse := 0.5 + 0.5 * _beat_phase()
	var r: float = PIXEL * (1.0 + round(pulse * 3.0))
	draw_rect(Rect2(_snap(c - Vector2(r, r) * 0.5), Vector2(r, r)), COLOR_LATTICE, true)

func _draw_lattice(size: Vector2) -> void:
	var scroll := _scroll()
	var pulse := _beat_phase()
	var w: float = PIXEL
	for gz in range(GRID_DEPTH):
		for gx in range(-GRID_HALF, GRID_HALF):
			var arrive := _cell_arrival(absi(gx), gz)
			var age := _t - arrive
			if age <= 0.0:
				continue
			# Cells snap in: they fade up and slide down onto the plane.
			var settle: float = clampf(age / 0.45, 0.0, 1.0)
			var drop: float = (1.0 - settle) * 60.0
			var a: float = settle * 0.9

			var z0: float = float(gz) * CELL + 1.0 - fposmod(scroll, CELL)
			var z1: float = z0 + CELL
			if z1 <= 0.1:
				continue
			var x0: float = float(gx) * CELL
			var x1: float = x0 + CELL
			var p00 := _warp(_project(x0, z0, size) - Vector2(0, drop), size)
			var p10 := _warp(_project(x1, z0, size) - Vector2(0, drop), size)
			var p01 := _warp(_project(x0, z1, size) - Vector2(0, drop), size)
			var p11 := _warp(_project(x1, z1, size) - Vector2(0, drop), size)
			# Far cells dim out so the lattice fades into the distance instead of
			# ending on a hard line.
			var depth_fade: float = clampf(1.0 - float(gz) / float(GRID_DEPTH), 0.0, 1.0)
			var line_a: float = a * (0.25 + 0.75 * depth_fade)
			var col := COLOR_LATTICE_DIM.lerp(COLOR_LATTICE, 0.2 + 0.8 * pulse)
			col.a = line_a
			# Two edges per cell is enough to draw the whole grid once.
			var lw: float = w * (1.0 + 0.5 * pulse * depth_fade)
			draw_line(p00, p10, col, lw)
			draw_line(p00, p01, col, lw)
			# Once the plane is solid, fill it so it reads as ground rather than
			# a wireframe hanging in space.
			# Tiles flood the plane on the cascade: a fast wave outward from the
			# centre, each cell snapping to full ground in a fraction of a second
			# rather than the slow global fade it used to be.
			if _t >= T_CASCADE:
				var cell_d := sqrt(float(gx * gx) + float(gz * gz))
				var flood_at: float = T_CASCADE + (cell_d / 18.0) * (T_VORTEX - T_CASCADE)
				var flood: float = clampf((_t - flood_at) / 0.18, 0.0, 1.0)
				var fill := COLOR_GROUND.lerp(COLOR_GROUND.lightened(0.35), _beat_phase() * 0.5)
				fill.a = flood * a * (0.35 + 0.65 * depth_fade)
				draw_colored_polygon(PackedVector2Array([p00, p10, p11, p01]), fill)

func _draw_jewels(size: Vector2) -> void:
	if _t < T_WEAVE - 0.6:
		return
	var scroll := _scroll()
	var pulse := _beat_phase()
	for gz in range(GRID_DEPTH):
		for gx in range(-GRID_HALF, GRID_HALF):
			if gz > 7:
				continue   # far rows render sub-pixel; nothing to see there
			var h := _hash01(gx * 7 + 3, gz * 11 + 5)
			if h > 0.20:
				continue   # sparse: jewels are an accent, not a texture
			var arrive: float = _cell_arrival(absi(gx), gz) + 0.8
			var age := _t - arrive
			if age <= 0.0:
				continue
			var z: float = float(gz) * CELL + 1.5 - fposmod(scroll, CELL)
			if z <= 0.15:
				continue
			var base := _project(float(gx) * CELL + 0.5, z, size)
			# Hover above the plane, bobbing on the beat.
			var lift: float = 40.0 / z * (1.0 + 0.35 * pulse)
			var centre := _warp(base - Vector2(0, lift), size)
			var grow: float = clampf(age / 0.5, 0.0, 1.0)
			var scale: float = (46.0 / z) * grow * (1.0 + 0.30 * pulse)
			if scale < PIXEL:
				continue
			var col: Color = JEWEL_PALETTE[int(h * 1000.0) % JEWEL_PALETTE.size()]
			_draw_jewel(centre, scale, col, clampf(grow, 0.0, 1.0))

# A faceted gem built from four blocky triangles: a bright crown, two mid
# flanks and a dark pavilion. Drawn from snapped points so the facets keep hard
# pixel edges at any size.
func _draw_jewel(c: Vector2, s: float, col: Color, a: float) -> void:
	var top := _snap(c + Vector2(0, -s))
	var bottom := _snap(c + Vector2(0, s * 1.15))
	var left := _snap(c + Vector2(-s * 0.8, -s * 0.15))
	var right := _snap(c + Vector2(s * 0.8, -s * 0.15))
	var crown_l := _snap(c + Vector2(-s * 0.4, -s * 0.55))
	var crown_r := _snap(c + Vector2(s * 0.4, -s * 0.55))

	var bright := col.lerp(Color.WHITE, 0.55)
	bright.a = a
	var mid := col
	mid.a = a
	var dark := col.darkened(0.45)
	dark.a = a

	draw_colored_polygon(PackedVector2Array([top, crown_r, crown_l]), bright)
	draw_colored_polygon(PackedVector2Array([crown_l, crown_r, right, left]), mid)
	draw_colored_polygon(PackedVector2Array([left, right, bottom]), dark)
	# One flat highlight block: at this size a gradient would just blur, and a
	# single lit facet is what sells "cut stone" in pixel art.
	var spec := Color(1, 1, 1, a * 0.9)
	var sp: float = maxf(PIXEL, s * 0.28)
	draw_rect(Rect2(_snap(c + Vector2(-s * 0.34, -s * 0.5)), Vector2(sp, sp)), spec, true)

# Spiral arms: sparks dragged around the drain, drawn as short blocks along the
# same warp the plane is using, so they sit in the vortex rather than over it.
func _draw_vortex_streaks(size: Vector2) -> void:
	var v := _vortex_amount()
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	for i in range(90):
		var h0 := _hash01(i, 31)
		var h1 := _hash01(i, 57)
		var ang: float = h0 * TAU
		var rad: float = (0.15 + 0.85 * h1) * size.length() * 0.42
		# Sparks fall inward faster than the plane, and lead it round.
		var fall: float = pow(clampf(v * (0.7 + 0.6 * h0), 0.0, 1.0), 1.6)
		var r: float = lerpf(rad, 8.0, fall)
		var a: float = ang + fall * TAU * 2.2
		var p := c + Vector2(r, 0).rotated(a)
		var col := COLOR_LATTICE.lerp(Color(1, 1, 1), 0.35)
		col.a = (0.25 + 0.55 * v) * clampf(1.0 - fall, 0.0, 1.0)
		var l: float = PIXEL * (1.0 + round(3.0 * v))
		draw_rect(Rect2(_snap(p + _shake), Vector2(l, PIXEL)), col, true)

# The vortex hands off to a dead channel: the signal tears itself apart, floods
# the frame, and clears to leave the warning on black.
#
# Rows, not a pixel grid. Filling 1280x720 with 4px cells is ~57,000 draw_rect
# calls a frame, which is a real cost for a full-second effect; ragged horizontal
# bands with the occasional one slid sideways is what actually reads as a broken
# signal anyway, and it lands in a few hundred rects.
#
# The scramble comes free from _rng advancing across frames -- no reseeding. The
# scene's seed is fixed so the lattice assembles identically every launch, and
# the static inherits that: it is different every frame but the same every run.
func _draw_static(size: Vector2) -> void:
	var f: float = clampf((_t - T_STATIC) / max(0.001, T_MESSAGE - T_STATIC), 0.0, 1.0)
	# Floods down the frame, holds, then thins out to nothing.
	var flood: float = clampf(f / 0.40, 0.0, 1.0)
	var density: float = 1.0 - clampf((f - 0.62) / 0.38, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.02), true)
	if density <= 0.0:
		return
	var limit: float = size.y * flood

	var y := 0.0
	while y < limit:
		var h: float = PIXEL * float(_rng.randi_range(1, 4))
		# Tear: roughly one band in five slides sideways.
		var dx := 0.0
		if _rng.randf() < 0.22:
			dx = float(_rng.randi_range(-30, 30))
		var v: float = _rng.randf()
		# Tinted toward the rift's own cyan-green rather than grey, so the dead
		# channel still belongs to this game.
		var col := Color(STATIC_TINT.r + v * 0.38, STATIC_TINT.g + v * 0.32, STATIC_TINT.b + v * 0.18,
			density * (0.08 + v * 0.55))
		draw_rect(Rect2(_snap(Vector2(dx - 32.0, y)), Vector2(size.x + 64.0, h)), col, true)
		y += h

	# A couple of blown-out sync lines per frame.
	for i in range(3):
		if _rng.randf() > 0.55 * density:
			continue
		var sy: float = _rng.randf() * limit
		draw_rect(Rect2(_snap(Vector2(0.0, sy)), Vector2(size.x, PIXEL)),
			Color(1, 1, 1, 0.45 * density), true)

	# Block noise scattered over the bands.
	for i in range(int(240.0 * density)):
		var p := Vector2(_rng.randf() * size.x, _rng.randf() * limit)
		var g: float = 0.40 + _rng.randf() * 0.60
		draw_rect(Rect2(_snap(p), Vector2(PIXEL * 2.0, PIXEL)),
			Color(g, g, g, 0.5 * density), true)

# The way out. No wipe this time -- it snaps on at full density across the whole
# frame, which is what makes it read as a cut rather than another effect -- and
# then bleaches toward HANDOFF_WASH so the last frame before the run is already
# about as bright as the run is.
func _draw_scramble_out(size: Vector2) -> void:
	var f: float = clampf((_t - T_SCRAMBLE_OUT) / maxf(0.001, T_END - T_SCRAMBLE_OUT), 0.0, 1.0)
	var lift: float = smoothstep(0.0, 1.0, f)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.01, 0.02).lerp(HANDOFF_WASH, lift), true)
	var y := 0.0
	while y < size.y:
		var h: float = PIXEL * float(_rng.randi_range(1, 4))
		# Tears harder than the way in: this is the channel giving up, not
		# breaking up.
		var dx := 0.0
		if _rng.randf() < 0.30:
			dx = float(_rng.randi_range(-44, 44))
		var v: float = _rng.randf()
		var col := Color(STATIC_TINT.r + v * 0.38, STATIC_TINT.g + v * 0.32, STATIC_TINT.b + v * 0.18, 0.10 + v * 0.55)
		col = col.lerp(Color(HANDOFF_WASH.r, HANDOFF_WASH.g, HANDOFF_WASH.b, col.a), lift)
		draw_rect(Rect2(_snap(Vector2(dx - 46.0, y)), Vector2(size.x + 92.0, h)), col, true)
		y += h
	for i in range(3):
		if _rng.randf() > 0.6:
			continue
		var sy: float = _rng.randf() * size.y
		draw_rect(Rect2(_snap(Vector2(0.0, sy)), Vector2(size.x, PIXEL)),
			Color(1, 1, 1, 0.45 * (1.0 - lift * 0.6)), true)
	for i in range(280):
		var p2 := Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
		var g2: float = 0.40 + _rng.randf() * 0.60
		draw_rect(Rect2(_snap(p2), Vector2(PIXEL * 2.0, PIXEL)),
			Color(g2, g2, g2, 0.45 * (1.0 - lift * 0.5)), true)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	# The world is normally already built and sitting behind this scene, in which
	# case handing over is switching a camera on and freeing this node.
	if _reveal_world():
		return
	# Only reached if the mount never happened -- a skip in the first second, or
	# a load that failed. Falls back to the plain path.
	if _preload_started:
		var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var packed := ResourceLoader.load_threaded_get(NEXT_SCENE)
			if packed is PackedScene:
				get_tree().change_scene_to_packed(packed)
				return
	get_tree().change_scene_to_file(NEXT_SCENE)
