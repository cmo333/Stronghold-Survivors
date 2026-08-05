extends Node2D
class_name CoverageOverlay

# Shows every tower's firing range while build mode is active.
#
# Range rings previously appeared only for the one selected tower, so planning a
# maze meant clicking towers one at a time to work out what was already covered.
# Drawing all of them together makes coverage gaps obvious at a glance — the
# dead zones are where nothing overlaps.
#
# Buildings change rarely, so the list is rebuilt on a slow timer rather than
# every frame, and drawing a handful of arcs is negligible.

const REFRESH_INTERVAL := 0.4
const COLOR_RING := Color(0.35, 0.9, 1.0, 0.28)
const COLOR_FILL := Color(0.35, 0.9, 1.0, 0.05)
const COLOR_FOOTPRINT := Color(1.0, 0.85, 0.35, 0.55)

var _game: Node = null
var _timer := 0.0
var _entries: Array = []     # [position, range, footprint_radius]
var _active := false

func setup(game_ref: Node) -> void:
	_game = game_ref
	z_index = 55
	top_level = true
	visible = false

func set_active(active: bool) -> void:
	_active = active
	visible = active
	if active:
		_rebuild()
		queue_redraw()

func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_INTERVAL
		_rebuild()
		queue_redraw()

func _rebuild() -> void:
	_entries.clear()
	var buildings: Array = []
	if _game != null and _game.has_method("get_cached_buildings"):
		buildings = _game.get_cached_buildings()
	else:
		buildings = get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if b == null or not is_instance_valid(b) or not (b is Node2D):
			continue
		var rng := 0.0
		if b.has_method("get_range"):
			rng = float(b.get_range())
		var fp := 12.0
		if b.has_method("get_footprint_radius"):
			fp = float(b.get_footprint_radius())
		_entries.append([(b as Node2D).global_position, rng, fp])

func _draw() -> void:
	if not _active:
		return
	for e in _entries:
		var pos: Vector2 = e[0]
		var rng: float = e[1]
		var fp: float = e[2]
		if rng > 1.0:
			# Faint fill plus a crisper rim: overlapping fills read as stronger
			# coverage, which is exactly the information the player wants.
			draw_circle(pos, rng, COLOR_FILL)
			draw_arc(pos, rng, 0.0, TAU, 48, COLOR_RING, 1.5, true)
		# Solid footprint so wall gaps are unambiguous — the collision extent is
		# what enemies actually squeeze through, not the sprite.
		draw_rect(Rect2(pos - Vector2(fp, fp), Vector2(fp * 2.0, fp * 2.0)),
			COLOR_FOOTPRINT, false, 1.5)
