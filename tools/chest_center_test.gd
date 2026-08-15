extends SceneTree
## Do the chest and the ray burst share a centre?
##
## Reads the two Controls' real rects after the reveal has placed them, in the
## same viewport the game uses. A code reading cannot settle this -- both are
## PRESET_CENTER Controls whose on-screen position is anchors + offsets + size,
## and the whole bug was that two things that both "look centred" in the source
## were 150px apart.

var _frames := 0
var _ui: Node = null

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _frames == 2:
		_boot()
		return false
	if _ui == null:
		print("[CHEST] FAIL: the UI node never came up")
		quit(1)
		return true
	# Offsets written this frame are not in get_rect() until the Control has
	# laid out. Control has no queue_sort (that is Container), so the honest way
	# to wait for a layout pass is to let some frames go by.
	if _frames == 3:
		_ui._build_chest_reveal()
		_ui._place_chest_sprite()
		_ui._place_chest_rays()
		return false
	if _frames < 8:
		return false
	return _report()

func _boot() -> void:
	# ui.gd is not its own scene -- it is the "UI" CanvasLayer inside main.tscn,
	# so the whole game scene has to come up to get at it.
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		print("[CHEST] FAIL: could not load main.tscn")
		return
	var main = scene.instantiate()
	if main.get_script() == null:
		print("[CHEST] FAIL: main.tscn instantiated with NO SCRIPT")
		return
	root.add_child(main)
	_ui = main.get_node_or_null("UI")
	if _ui == null:
		print("[CHEST] FAIL: no UI node under main.tscn")
		return
	if _ui.get_script() == null:
		print("[CHEST] FAIL: the UI node has NO SCRIPT")
		_ui = null

func _report() -> bool:
	if not _ui.has_method("_build_chest_reveal"):
		print("[CHEST] FAIL: _build_chest_reveal missing")
		quit(1)
		return true
	var sprite = _ui._chest_sprite
	var rays = _ui._chest_rays
	if sprite == null or rays == null:
		print("[CHEST] FAIL: reveal nodes were not built")
		quit(1)
		return true

	var s_rect: Rect2 = sprite.get_rect()
	var r_rect: Rect2 = rays.get_rect()
	var s_c: Vector2 = s_rect.position + s_rect.size * 0.5
	var r_c: Vector2 = r_rect.position + r_rect.size * 0.5
	var d: Vector2 = s_c - r_c

	print("[CHEST] viewport            %s" % str(root.get_viewport().get_visible_rect().size))
	print("[CHEST] chest rect          pos=%s size=%s centre=%s" % [str(s_rect.position), str(s_rect.size), str(s_c)])
	print("[CHEST] ray burst rect      pos=%s size=%s centre=%s" % [str(r_rect.position), str(r_rect.size), str(r_c)])
	print("[CHEST] centre offset       %s  (magnitude %.2f px)" % [str(d), d.length()])
	print("[CHEST] rays pivot_offset   %s  (want half of size, %s)" % [str(rays.pivot_offset), str(r_rect.size * 0.5)])

	var ok := true
	if d.length() > 0.5:
		print("[CHEST] FAIL: the burst does not originate at the chest -- off by %.2f px" % d.length())
		ok = false
	var want_pivot: Vector2 = r_rect.size * 0.5
	if (rays.pivot_offset - want_pivot).length() > 0.5:
		print("[CHEST] FAIL: rays rotate about %s, not their own centre %s" % [str(rays.pivot_offset), str(want_pivot)])
		ok = false
	# Negative control: the rise must still be doing its job, or this "fix" is
	# just both things sitting at the viewport centre on top of the cards.
	var vp_c: Vector2 = Vector2(root.get_viewport().get_visible_rect().size) * 0.5
	var rise: float = vp_c.y - s_c.y
	print("[CHEST] chest sits %.1f px above the viewport centre (CHEST_SPRITE_RISE)" % rise)
	if rise < 100.0:
		print("[CHEST] FAIL: the chest lost its clearance over the prize cards")
		ok = false

	print("[CHEST] RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
