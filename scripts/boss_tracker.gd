extends Control

# Keeps a live boss findable.
#
# Bosses were reported as hard to notice at all. Size and colour were raised for
# that, but neither helps in the two cases that actually lose the player: the
# boss is off-screen, or it is standing inside a hundred other enemies. A boss
# that cannot be located is not a fight, it is chip damage arriving from
# somewhere.
#
# So: a health bar pinned to the top of the screen for as long as any boss is
# alive, and - while that boss is outside the view - an arrow riding the screen
# edge pointing at it, in the boss's own colour, with the distance in metres.
#
# The arrow is drawn rather than textured because it has to rotate to any angle
# and tint per boss, and one triangle plus a ring is cheaper than an atlas entry
# that would need both.

const EDGE_MARGIN := 46.0
# How far outside the view the boss must be before the arrow appears. Without a
# dead zone the arrow flickers on and off while a boss walks the screen edge.
const OFFSCREEN_SLACK := 24.0
const BAR_SIZE := Vector2(360.0, 14.0)
const BAR_TOP := 96.0
const ARROW_LENGTH := 22.0
const ARROW_HALF_WIDTH := 11.0
const RING_RADIUS := 19.0
# World px per "m" in the readout. Purely a scale for the number; the point is a
# quantity that shrinks as the player closes in, not a real unit.
const PIXELS_PER_METRE := 32.0

var _boss: Node2D = null
var _refresh_timer: float = 0.0
var _arrow_pos: Vector2 = Vector2.ZERO
var _arrow_angle: float = 0.0
var _arrow_visible: bool = false
var _arrow_color: Color = Color(1.0, 0.3, 0.3, 1.0)
var _distance_text: String = ""
var _bar: TextureProgressBar = null
var _bar_fill: ColorRect = null
var _bar_back: ColorRect = null
var _name_label: Label = null
var _font: Font = null

func setup(font: Font) -> void:
	_font = font
	if _name_label != null and is_instance_valid(_name_label) and _font != null:
		_name_label.add_theme_font_override("font", _font)

func _ready() -> void:
	name = "BossTracker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	_build_bar()
	set_process(true)

func _build_bar() -> void:
	_bar_back = ColorRect.new()
	_bar_back.name = "BossBarBack"
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.color = Color(0.05, 0.02, 0.04, 0.82)
	_bar_back.size = BAR_SIZE + Vector2(4.0, 4.0)
	add_child(_bar_back)

	_bar_fill = ColorRect.new()
	_bar_fill.name = "BossBarFill"
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.color = Color(1.0, 0.3, 0.3, 0.95)
	_bar_fill.size = BAR_SIZE
	add_child(_bar_fill)

	_name_label = Label.new()
	_name_label.name = "BossName"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	if _font != null:
		_name_label.add_theme_font_override("font", _font)
	add_child(_name_label)

	_set_bar_visible(false)

func _set_bar_visible(v: bool) -> void:
	if _bar_back != null:
		_bar_back.visible = v
	if _bar_fill != null:
		_bar_fill.visible = v
	if _name_label != null:
		_name_label.visible = v

func _process(delta: float) -> void:
	# The group walk is cheap but pointless every frame; the boss only changes
	# when one spawns or dies.
	_refresh_timer -= delta
	if _boss == null or not is_instance_valid(_boss) or _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_boss = _pick_boss()
	if _boss == null:
		if _arrow_visible:
			_arrow_visible = false
			queue_redraw()
		_set_bar_visible(false)
		return
	_update_bar()
	_update_arrow()

func _pick_boss() -> Node2D:
	"""The boss with the most health left. With several alive that is the one the
	player still has to deal with, and it stays put rather than flicking between
	targets as their bars move."""
	var best: Node2D = null
	var best_health := -1.0
	for raw in get_tree().get_nodes_in_group("bosses"):
		if raw == null or not is_instance_valid(raw) or not (raw is Node2D):
			continue
		if "is_boss_active" in raw and not bool(raw.is_boss_active):
			continue
		var hp := 1.0
		if "health" in raw:
			hp = float(raw.health)
		if hp <= 0.0:
			continue
		if hp > best_health:
			best_health = hp
			best = raw as Node2D
	return best

func _boss_colour() -> Color:
	if _boss != null and "boss_color" in _boss:
		var c: Color = _boss.boss_color
		return Color(c.r, c.g, c.b, 1.0)
	return Color(1.0, 0.3, 0.3, 1.0)

func _update_bar() -> void:
	var vp := get_viewport_rect().size
	var frac := 1.0
	if "max_health" in _boss and float(_boss.max_health) > 0.0:
		frac = clampf(float(_boss.health) / float(_boss.max_health), 0.0, 1.0)
	var col := _boss_colour()
	var origin := Vector2(round((vp.x - BAR_SIZE.x) * 0.5), BAR_TOP)
	if _bar_back != null:
		_bar_back.position = origin - Vector2(2.0, 2.0)
		_bar_back.size = BAR_SIZE + Vector2(4.0, 4.0)
	if _bar_fill != null:
		_bar_fill.position = origin
		_bar_fill.size = Vector2(BAR_SIZE.x * frac, BAR_SIZE.y)
		# Lift the tint: several boss colours are dark enough that a thin bar of
		# them over the backdrop reads as empty.
		_bar_fill.color = Color(col.r, col.g, col.b, 1.0).lerp(Color.WHITE, 0.18)
	if _name_label != null:
		var title := "BOSS"
		if "boss_name" in _boss:
			title = str(_boss.boss_name).to_upper()
		_name_label.text = title
		_name_label.size = Vector2(BAR_SIZE.x, 20.0)
		_name_label.position = Vector2(origin.x, origin.y - 20.0)
		_name_label.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 1.0).lerp(Color.WHITE, 0.45))
	_set_bar_visible(true)

func _update_arrow() -> void:
	var vp := get_viewport_rect().size
	# World -> screen exactly once. Composing the canvas transform twice is how an
	# earlier probe ended up sampling pixels off the side of the framebuffer.
	var xform := get_viewport().get_canvas_transform()
	var screen: Vector2 = xform * _boss.global_position
	var rect := Rect2(Vector2(OFFSCREEN_SLACK, OFFSCREEN_SLACK), vp - Vector2(OFFSCREEN_SLACK, OFFSCREEN_SLACK) * 2.0)
	var was_visible := _arrow_visible
	_arrow_visible = not rect.has_point(screen)
	if not _arrow_visible:
		if was_visible:
			queue_redraw()
		return
	var centre := vp * 0.5
	var dir := screen - centre
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	_arrow_angle = dir.angle()
	# Push the marker out to the edge box along the same bearing, so it sits where
	# the boss would appear if the view were wide enough.
	var half := vp * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var scale_x: float = half.x / absf(dir.x) if absf(dir.x) > 0.001 else INF
	var scale_y: float = half.y / absf(dir.y) if absf(dir.y) > 0.001 else INF
	_arrow_pos = centre + dir * minf(scale_x, scale_y)
	_arrow_color = _boss_colour()
	var metres := int(round(_boss.global_position.distance_to(_camera_centre()) / PIXELS_PER_METRE))
	_distance_text = "%dm" % metres
	queue_redraw()

func _camera_centre() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam != null and is_instance_valid(cam):
		return cam.global_position
	return Vector2.ZERO

func _draw() -> void:
	if not _arrow_visible:
		return
	var pulse := 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) * 0.006)
	var body := Color(_arrow_color.r, _arrow_color.g, _arrow_color.b, pulse)
	draw_circle(_arrow_pos, RING_RADIUS, Color(0.0, 0.0, 0.0, 0.55))
	draw_arc(_arrow_pos, RING_RADIUS, 0.0, TAU, 24, body, 2.0, true)
	# One fixed triangle, rotated. Its area never changes, so it can never come
	# out degenerate the way a warped quad can.
	draw_set_transform(_arrow_pos, _arrow_angle, Vector2.ONE)
	var tri := PackedVector2Array([
		Vector2(ARROW_LENGTH, 0.0),
		Vector2(-2.0, -ARROW_HALF_WIDTH),
		Vector2(-2.0, ARROW_HALF_WIDTH)
	])
	draw_colored_polygon(tri, body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _font != null and _distance_text != "":
		var text_size := _font.get_string_size(_distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		var at := _arrow_pos + Vector2(-text_size.x * 0.5, RING_RADIUS + 14.0)
		draw_string_outline(_font, at, _distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0.0, 0.0, 0.0, 0.9))
		draw_string(_font, at, _distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, body)
