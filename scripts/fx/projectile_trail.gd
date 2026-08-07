extends Line2D

## Tracer streak behind a projectile: a hot core with a softer glow around it.
##
## The old trail was a single flat Line2D - one solid colour, no gradient, and a
## width curve that ran widest at the *tail* and pinched to nothing at the head.
## That draws a blunt stick that looks like it is being sucked backwards out of
## the shot, which is most of why shots read as scratch marks rather than fire.
##
## What a streak needs to read as a shot:
##   - widest and brightest where the projectile is, tapering to a point behind
##   - a white-hot head cooling into the damage colour along its length
##   - additive blending, so overlapping shots build light instead of stacking
##     flat colour, and so the head passes the glow threshold and blooms
##   - a length set by time (a streak is motion blur - faster shot, longer
##     streak) with a hard ceiling so nothing draws a laser across the screen

# A streak, not a beam. 0.3s at typical projectile speeds drew a ~250px bar.
const TRAIL_SECONDS := 0.12
# Hard ceiling in world units, for projectiles fast enough that even 0.12s is
# a stripe across the play area.
const MAX_TRAIL_LENGTH := 96.0
const MAX_POINTS := 16
# The glow sits behind the core and carries the damage colour; the core is the
# near-white centre that survives the bloom threshold.
const GLOW_WIDTH_MULT := 1.9
const GLOW_ALPHA := 0.30
const CORE_WIDTH_MULT := 0.5
# How far toward white the head runs. The tail keeps the damage colour so the
# streak still reads as fire/ice/lightning at a glance.
const HEAD_HEAT := 0.55

var _target: Node2D
var _fade_time: float = TRAIL_SECONDS
var _points_data: Array[Dictionary] = []
var _is_dying: bool = false
var _color: Color = Color.WHITE
var _base_width: float = 3.0
var _glow: Line2D = null
static var _shared_width_curve: Curve = null
static var _shared_additive: CanvasItemMaterial = null

func setup(target: Node2D, color: Color, width: float = 3.0, fade_time: float = TRAIL_SECONDS) -> void:
	# CRITICAL: pooled trails are reused. Clear any stale points/state from the
	# previous projectile, otherwise the Line2D draws a long streak from the old
	# (faraway) position to the new one -- the "random white line" bug.
	clear_points()
	_points_data.clear()
	_is_dying = false
	modulate.a = 1.0

	_target = target
	_color = color
	_base_width = width
	_fade_time = maxf(0.02, fade_time)

	_style(self, width * CORE_WIDTH_MULT, _core_gradient(color))
	_ensure_glow()
	_glow.clear_points()
	_style(_glow, width * GLOW_WIDTH_MULT, _glow_gradient(color))
	# Above the ground (which sits at -10) but below the projectile sprite, so the
	# bolt reads as the solid thing and the streak as its wake. Anything positive
	# here would also draw the streak over the towers it flies past.
	z_index = -1
	# Relative to the core, so the glow lands just behind it.
	_glow.z_index = -1

	if target != null and is_instance_valid(target):
		_push_point(target.global_position)

func _style(line: Line2D, w: float, grad: Gradient) -> void:
	line.width = w
	line.width_curve = _width_curve()
	line.gradient = grad
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Round joints and caps turn the taper into a bullet shape instead of a
	# chisel, and hide the segment corners on a turning shot.
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.material = _additive()

func _additive() -> CanvasItemMaterial:
	if _shared_additive == null:
		_shared_additive = CanvasItemMaterial.new()
		_shared_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_additive

func _ensure_glow() -> void:
	if _glow != null and is_instance_valid(_glow):
		return
	_glow = Line2D.new()
	_glow.name = "Glow"
	add_child(_glow)

# Point 0 is the oldest point (the tail) and the last point sits on the
# projectile, so the curve has to run thin -> thick, not the reverse.
func _width_curve() -> Curve:
	if _shared_width_curve != null:
		return _shared_width_curve
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 0.5))
	curve.add_point(Vector2(0.85, 1.0))
	curve.add_point(Vector2(1.0, 0.72))
	_shared_width_curve = curve
	return _shared_width_curve

func _core_gradient(base: Color) -> Gradient:
	var grad := Gradient.new()
	var tail := base
	tail.a = 0.0
	var mid := base
	mid.a = 0.55
	# Scale the white-hot lift by how saturated the shot colour is. A saturated
	# orange or cyan gains heat from running toward white; a near-white cream has
	# nowhere to go and just clips into a featureless blob.
	var head := base.lerp(Color(1, 1, 1, 1), HEAD_HEAT * base.s)
	head.a = 0.8
	# Ease off over the last stretch. The hottest part of the streak sitting
	# exactly on the projectile drowns the bolt art in white; backing it off just
	# behind the tip lets the sprite read as the solid thing being thrown.
	var tip := head
	tip.a = 0.5
	grad.offsets = PackedFloat32Array([0.0, 0.5, 0.88, 1.0])
	grad.colors = PackedColorArray([tail, mid, head, tip])
	return grad

func _glow_gradient(base: Color) -> Gradient:
	var grad := Gradient.new()
	var tail := base
	tail.a = 0.0
	var head := base
	head.a = GLOW_ALPHA
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([tail, head])
	return grad

func _push_point(pos: Vector2) -> void:
	add_point(pos)
	_points_data.append({"pos": pos, "age": 0.0})
	if _glow != null and is_instance_valid(_glow):
		_glow.add_point(pos)

func _pop_oldest() -> void:
	remove_point(0)
	_points_data.pop_front()
	if _glow != null and is_instance_valid(_glow) and _glow.get_point_count() > 0:
		_glow.remove_point(0)

func _process(delta: float) -> void:
	if _is_dying:
		_update_fade(delta)
		return

	if _target == null or not is_instance_valid(_target):
		_start_fade_out()
		return

	var current_pos: Vector2 = _target.global_position
	if points.size() == 0 or current_pos.distance_squared_to(points[points.size() - 1]) > 4.0:
		_push_point(current_pos)
		if points.size() > MAX_POINTS:
			_pop_oldest()

	for i in range(_points_data.size()):
		_points_data[i]["age"] += delta

	# Drop the tail on age first, then on length. Age keeps the streak reading as
	# motion blur; the length clamp stops a very fast shot drawing a laser.
	while _points_data.size() > 1 and _points_data[0]["age"] > _fade_time:
		_pop_oldest()
	while _points_data.size() > 2 and points[0].distance_to(current_pos) > MAX_TRAIL_LENGTH:
		_pop_oldest()

func _start_fade_out() -> void:
	_is_dying = true
	if not is_inside_tree():
		queue_free()
		return
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func _update_fade(delta: float) -> void:
	# Trail is fading out, shrink width
	var t := clampf(delta * 7.0, 0.0, 1.0)
	self.width = lerpf(self.width, 0.0, t)
	if _glow != null and is_instance_valid(_glow):
		_glow.width = lerpf(_glow.width, 0.0, t)
	if self.width < 0.1:
		queue_free()
