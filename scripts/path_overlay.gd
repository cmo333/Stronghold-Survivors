extends Node2D
class_name PathOverlay

# Build-mode overlay that makes enemy pathing legible.
#
# Mazes were being built blind: a one-tile gap in a wall is invisible, but the
# whole horde funnels through it. Rather than make the player guess, this draws
# the actual flow field they are shaping — arrows follow the exact route enemies
# will take, so a leak shows up as a bright stream pouring through the hole.
#
# Only drawn while build mode is active, so normal play stays uncluttered.

const SAMPLE_STEP := 40.0          # world units between arrows
const ARROW_LEN := 15.0
const MAX_SAMPLES := 900           # hard cap so a huge view can't tank the frame
const REFRESH_INTERVAL := 0.12

const COLOR_FLOW := Color(0.35, 0.85, 1.0, 0.5)      # open route
const COLOR_HOT := Color(1.0, 0.75, 0.2, 0.85)       # converging = a leak
const COLOR_BLOCKED := Color(1.0, 0.25, 0.25, 0.16)  # no path from here

var _game: Node = null
var _timer := 0.0
var _samples: Array = []           # [pos, dir, crowding]
var _active := false

func setup(game_ref: Node) -> void:
	_game = game_ref
	z_index = 60
	top_level = true
	visible = false

func set_active(active: bool) -> void:
	# Always assign visibility, even when _active already matches: the initial
	# set_active(false) has to actually hide the node, not early-out on the
	# default state and leave it drawn.
	_active = active
	visible = active
	if not active:
		return
	if active:
		_timer = 0.0
		_rebuild()
	queue_redraw()

func _process(delta: float) -> void:
	if not _active or _game == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_INTERVAL
		_rebuild()
		queue_redraw()

func _rebuild() -> void:
	_samples.clear()
	if _game == null or not _game.has_method("get_flow_direction"):
		return
	var cam = _game.get("camera")
	if cam == null or not is_instance_valid(cam):
		return
	var view := get_viewport_rect().size
	var zoom: Vector2 = cam.zoom
	if zoom.x <= 0.001 or zoom.y <= 0.001:
		return
	# World-space rect currently on screen, padded slightly so arrows do not
	# pop in at the edges.
	var half := view / zoom * 0.5 * 1.05
	var center: Vector2 = cam.global_position
	var origin := center - half

	# Coarse first pass: collect direction samples across the view.
	var cols := int(half.x * 2.0 / SAMPLE_STEP)
	var rows := int(half.y * 2.0 / SAMPLE_STEP)
	var budget := MAX_SAMPLES
	var dirs := {}
	for gy in range(rows + 1):
		for gx in range(cols + 1):
			if budget <= 0:
				break
			var pos := origin + Vector2(gx * SAMPLE_STEP, gy * SAMPLE_STEP)
			var dir: Vector2 = _game.get_flow_direction(pos)
			dirs[Vector2i(gx, gy)] = dir
			budget -= 1

	# Second pass: a cell is "hot" when its neighbours point into it, which is
	# exactly what a chokepoint or a gap in the wall looks like.
	for key in dirs.keys():
		var dir: Vector2 = dirs[key]
		var pos := origin + Vector2(key.x * SAMPLE_STEP, key.y * SAMPLE_STEP)
		if dir == Vector2.ZERO:
			_samples.append([pos, Vector2.ZERO, 0.0])
			continue
		# A chokepoint is where traffic is squeezed from OPPOSITE sides, not
		# merely where everything drifts the same way. Testing each neighbour
		# independently flagged ordinary laminar flow (a whole field marching
		# toward the extractor) as converging, which lit up almost every sample
		# and made the heat colour meaningless. Checking opposite pairs only
		# fires when both sides genuinely point inward — a real funnel.
		var squeeze := 0.0
		for axis in [[Vector2i(-1, 0), Vector2i(1, 0)], [Vector2i(0, -1), Vector2i(0, 1)]]:
			var a_key: Vector2i = key + axis[0]
			var b_key: Vector2i = key + axis[1]
			if not dirs.has(a_key) or not dirs.has(b_key):
				continue
			var a_dir: Vector2 = dirs[a_key]
			var b_dir: Vector2 = dirs[b_key]
			if a_dir == Vector2.ZERO or b_dir == Vector2.ZERO:
				continue
			# Inward means: the sample on the low side heads positive along the
			# axis, and the one on the high side heads negative.
			var axis_vec := Vector2(axis[1].x, axis[1].y)
			var a_in: float = a_dir.dot(axis_vec)
			var b_in: float = b_dir.dot(-axis_vec)
			if a_in > 0.4 and b_in > 0.4:
				squeeze = maxf(squeeze, minf(a_in, b_in))
		_samples.append([pos, dir, clampf(squeeze, 0.0, 1.0)])

func _draw() -> void:
	if not _active:
		return
	for s in _samples:
		var pos: Vector2 = s[0]
		var dir: Vector2 = s[1]
		var heat: float = s[2]
		if dir == Vector2.ZERO:
			# Unreachable / walled off — a faint dot reads as "nothing comes here".
			draw_circle(pos, 2.0, COLOR_BLOCKED)
			continue
		var col := COLOR_FLOW.lerp(COLOR_HOT, heat)
		var width := 1.5 + heat * 2.0
		var tip := pos + dir * ARROW_LEN
		draw_line(pos, tip, col, width)
		# Arrowhead so direction of travel is unambiguous.
		var back := -dir * 5.0
		var side := dir.orthogonal() * 3.0
		draw_line(tip, tip + back + side, col, width)
		draw_line(tip, tip + back - side, col, width)
