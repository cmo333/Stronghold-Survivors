extends Control

## Descent: the ~10s transition between pressing Play and the run starting.
##
## The world is not there yet, so it builds itself. A single point of light, a
## plane that weaves itself outward from it in perspective, jewels that lock
## into the lattice, then a dive down through the surface until the ground fills
## the frame and the character drops in.
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
const T_JEWELS := 6.8        # jewels lock in and the plane solidifies
const T_DIVE := 9.0          # fall through the surface
const T_END := 10.0          # hand over to the run

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
var _spawn_played := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fixed seed: the lattice assembles the same way every time, so the sequence
	# is a designed thing rather than a different accident on each launch.
	_rng.seed = 20260808
	_build_audio()

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
	_t += delta
	_tick_beat()
	if _t >= T_DIVE and not _riser_played:
		_riser_played = true
		AudioManager.play_one_shot("chest_charge", Vector2.ZERO, AudioManager.HIGH_PRIORITY)
	if _t >= T_END - 0.55 and not _spawn_played:
		_spawn_played = true
		AudioManager.play_ui_sound("level_up")
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
	if _t > T_DIVE:
		return
	var accent := idx % ACCENT_EVERY == 0
	# The kit gets louder and brighter as the world assembles.
	var build := clampf(_t / T_JEWELS, 0.0, 1.0)
	if accent:
		_play_thump(0.62, lerpf(-20.0, -8.0, build))
	else:
		_play_thump(0.9, lerpf(-26.0, -15.0, build))

# 1 on the beat, decaying to 0 before the next one.
func _beat_phase() -> float:
	var f: float = fposmod(_t, BEAT) / BEAT
	return pow(1.0 - f, 3.0)

func _snap(v: Vector2) -> Vector2:
	return Vector2(round(v.x / PIXEL) * PIXEL, round(v.y / PIXEL) * PIXEL)

# Camera height above the plane. Falls away through the dive so the surface
# rushes up and finally passes the viewer.
func _cam_height() -> float:
	if _t < T_DIVE:
		# A slow settle plus a breath on the beat.
		var settle := lerpf(3.4, 2.2, clampf(_t / T_DIVE, 0.0, 1.0))
		return settle + _beat_phase() * 0.06
	var d := clampf((_t - T_DIVE) / max(0.001, T_END - T_DIVE), 0.0, 1.0)
	return lerpf(2.2, 0.55, d * d)

func _scroll() -> float:
	# Constant drift forward, accelerating into the dive.
	var base := _t * 0.55
	if _t >= T_DIVE:
		base += pow((_t - T_DIVE) / max(0.001, T_END - T_DIVE), 2.0) * 5.0
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
	_draw_lattice(size)
	_draw_jewels(size)
	if _t >= T_DIVE:
		_draw_surface_rush(size)
	if _t >= T_END - 0.6:
		_draw_spawn(size)

func _draw_backdrop(size: Vector2) -> void:
	# Deep space that warms toward the ground colour as the world resolves.
	var warm := clampf((_t - T_JEWELS) / max(0.001, T_END - T_JEWELS), 0.0, 1.0)
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
			var p00 := _snap(_project(x0, z0, size) - Vector2(0, drop))
			var p10 := _snap(_project(x1, z0, size) - Vector2(0, drop))
			var p01 := _snap(_project(x0, z1, size) - Vector2(0, drop))
			var p11 := _snap(_project(x1, z1, size) - Vector2(0, drop))
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
			if _t >= T_JEWELS:
				var solid: float = clampf((_t - T_JEWELS) / 1.4, 0.0, 1.0) * depth_fade * 0.55
				var fill := COLOR_GROUND
				fill.a = solid * a
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
			var centre := _snap(base - Vector2(0, lift))
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

# During the dive the surface passes the camera: streaks tear upward past the
# frame to sell the speed the projection alone cannot.
func _draw_surface_rush(size: Vector2) -> void:
	var d: float = clampf((_t - T_DIVE) / max(0.001, T_END - T_DIVE), 0.0, 1.0)
	var count := int(60.0 * d)
	for i in range(count):
		var f := float(i) / 60.0
		var x: float = fposmod(_hash01(i, 1) * size.x + _t * 40.0, size.x)
		var y: float = fposmod(_hash01(i, 2) * size.y + pow(d, 2.0) * 2400.0 * (0.5 + f), size.y)
		var len_px: float = PIXEL * (2.0 + round(d * 8.0))
		var col := COLOR_LATTICE
		col.a = 0.10 + 0.35 * d
		draw_rect(Rect2(_snap(Vector2(x, y)), Vector2(PIXEL, len_px)), col, true)

# The last beat: the ground has filled the frame, light collapses to a point and
# the character's silhouette resolves out of it.
func _draw_spawn(size: Vector2) -> void:
	var f: float = clampf((_t - (T_END - 0.6)) / 0.6, 0.0, 1.0)
	var c := Vector2(size.x * 0.5, size.y * 0.66)
	# Collapsing ring.
	var r: float = lerpf(300.0, 34.0, f)
	var seg := 56
	var ring := COLOR_LATTICE
	ring.a = 0.85 * (1.0 - f * 0.4)
	for i in range(seg):
		var a0 := TAU * float(i) / float(seg)
		var p := _snap(c + Vector2(r, 0).rotated(a0))
		draw_rect(Rect2(p, Vector2(PIXEL, PIXEL)), ring, true)
	# Silhouette blocking in: a simple standing figure, pixel blocks, fading up.
	var body := Color(1.0, 0.96, 0.85, f)
	var u := PIXEL * 3.0
	var feet := c + Vector2(0, u * 3.0)
	var blocks := [
		Vector2(0, -6), Vector2(0, -5),                      # head
		Vector2(-1, -4), Vector2(0, -4), Vector2(1, -4),     # shoulders
		Vector2(-1, -3), Vector2(0, -3), Vector2(1, -3),
		Vector2(0, -2), Vector2(0, -1),                      # torso
		Vector2(-1, 0), Vector2(1, 0),                       # legs
	]
	for b in blocks:
		draw_rect(Rect2(_snap(feet + b * u), Vector2(u, u)), body, true)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().change_scene_to_file(NEXT_SCENE)
