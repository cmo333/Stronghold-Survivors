extends Node2D
class_name CoverageOverlay

# Draws each building's collision footprint while build mode is active.
#
# Mazing was guesswork: the sprite is not the same size as the blocker enemies
# actually squeeze past, so gaps looked closed when they were not. Outlining the
# true footprint turns the base into a readable grid to build against.
#
# An earlier version also drew every tower's range as translucent circles. With
# several towers those fills stacked into an opaque blue wash that obscured the
# grid, so they were dropped — the selected-tower range ring still covers the
# 'what does this cover' question on demand.
#
# Buildings change rarely, so the list is rebuilt on a slow timer.

const REFRESH_INTERVAL := 0.4
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
		var fp := 12.0
		if b.has_method("get_footprint_radius"):
			fp = float(b.get_footprint_radius())
		_entries.append([(b as Node2D).global_position, 0.0, fp])

func _draw() -> void:
	if not _active:
		return
	# Range circles were removed: with several towers their translucent fills
	# stacked into an opaque blue wash that hid the very thing the player was
	# trying to read. The footprint grid is what actually helps mazing — it
	# shows the collision extent enemies squeeze past, which is not the same as
	# the sprite.
	for e in _entries:
		var pos: Vector2 = e[0]
		var fp: float = e[2]
		draw_rect(Rect2(pos - Vector2(fp, fp), Vector2(fp * 2.0, fp * 2.0)),
			COLOR_FOOTPRINT, false, 1.5)
