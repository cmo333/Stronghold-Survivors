extends SceneTree
## Does a second mythic pull actually deliver something?
##
##   tools/mythic_test.sh
##
## The bug this guards: spawn_golden_coco() returns early when a companion is
## already out, while the chest roll picked blindly from MYTHIC_UPGRADES. A
## second pull therefore printed the rarest card in the game, played the jackpot
## fanfare, spent a slot from the chest's own budget, and did nothing. At 2% a
## chest that is the NORMAL outcome of a long run, not an edge case.
##
## Drives the real spawners and the real _pick_mythic against the real scene --
## the whole failure was an interaction between two files that each looked
## correct on its own, which is precisely what a fixture cannot reproduce.

var _frames := 0
var _main: Node = null
var _chest: Node = null
var _failed := ""

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _frames == 2:
		_boot()
		return false
	if _failed != "":
		return _fail(_failed)
	if _main == null:
		return _fail("main.tscn never entered the tree")
	# Give the run a few frames to settle before touching its groups.
	if _frames < 8:
		return false
	return _report()

func _boot() -> void:
	var meta = root.get_node_or_null("MetaProgression")
	if meta != null:
		meta.autostart_run = true
		meta.pending_hero = "warlock"
		meta.pending_level = "graveyard"
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_failed = "could not load main.tscn"
		return
	_main = scene.instantiate()
	if _main.get_script() == null:
		_failed = "main.tscn instantiated with NO SCRIPT"
		_main = null
		return
	root.add_child(_main)
	var cscene: PackedScene = load("res://scenes/treasure_chest.tscn")
	if cscene == null:
		_failed = "could not load treasure_chest.tscn"
		return
	_chest = cscene.instantiate()
	if _chest.get_script() == null:
		_failed = "treasure_chest.tscn instantiated with NO SCRIPT"
		_chest = null
		return
	root.add_child(_chest)
	if _chest.has_method("setup"):
		_chest.setup(_main)

func _fail(msg: String) -> bool:
	print("[MYTHIC] FAIL: %s" % msg)
	quit(1)
	return true

# get_nodes_in_group directly, not get_tree(): this script IS the SceneTree, so
# there is no get_tree() on it to call.
func _companions() -> int:
	return get_nodes_in_group("companions").size()

func _rainbows() -> int:
	return get_nodes_in_group("rainbow_companions").size()

func _report() -> bool:
	if _chest == null:
		return _fail("no chest to roll from")
	var ok := true

	# --- the sequence -------------------------------------------------------
	var first: String = _chest._pick_mythic()
	print("[MYTHIC] nothing owned          -> _pick_mythic() = '%s'" % first)
	if first != "golden_coco":
		print("[MYTHIC] FAIL: the first mythic must be the golden")
		ok = false
	_main.spawn_golden_coco()

	var second: String = _chest._pick_mythic()
	print("[MYTHIC] golden owned           -> _pick_mythic() = '%s'  (companions=%d)" % [second, _companions()])
	if second != "rainbow_coco":
		print("[MYTHIC] FAIL: the second mythic must escalate to the rainbow, not repeat the golden")
		ok = false
	_main.spawn_rainbow_coco()

	var third: String = _chest._pick_mythic()
	print("[MYTHIC] both owned             -> _pick_mythic() = '%s'  (companions=%d, rainbow=%d)" % [
		third, _companions(), _rainbows()])
	if third != "":
		print("[MYTHIC] FAIL: a third mythic must yield the slot back, not print a dead card")
		ok = false

	# --- both actually exist -------------------------------------------------
	# The old bug was a spawn that silently no-oped, so counting the group is the
	# assertion that matters -- not that the roll returned a nice string.
	if _companions() != 2:
		print("[MYTHIC] FAIL: expected 2 companions on the field, found %d" % _companions())
		ok = false
	if _rainbows() != 1:
		print("[MYTHIC] FAIL: expected exactly 1 rainbow, found %d" % _rainbows())
		ok = false

	# --- one only ------------------------------------------------------------
	_main.spawn_rainbow_coco()
	_main.spawn_golden_coco()
	if _rainbows() != 1 or _companions() != 2:
		print("[MYTHIC] FAIL: duplicate spawns got through (companions=%d, rainbow=%d)" % [
			_companions(), _rainbows()])
		ok = false

	# --- the buff reaches the towers ----------------------------------------
	# Folded into get_tower_damage_mult/get_tower_rate_mult precisely so it
	# cannot miss a firing path. Measured by toggling the rainbow off and on --
	# a multiplier that reads correctly but never reaches a tower is this
	# project's most repeated bug (6adb3ee, ae7b959).
	var dmg_on: float = _main.get_tower_damage_mult()
	var rate_on: float = _main.get_tower_rate_mult()
	for c in get_nodes_in_group("rainbow_companions"):
		c.remove_from_group("rainbow_companions")
	var dmg_off: float = _main.get_tower_damage_mult()
	var rate_off: float = _main.get_tower_rate_mult()
	var want_d: float = _main.COMPANION_COCO_SCRIPT.RAINBOW_TOWER_DAMAGE_MULT
	var want_r: float = _main.COMPANION_COCO_SCRIPT.RAINBOW_TOWER_RATE_MULT
	print("[MYTHIC] tower damage mult      %.4f with rainbow, %.4f without  (x%.3f, want x%.3f)" % [
		dmg_on, dmg_off, dmg_on / maxf(dmg_off, 0.0001), want_d])
	print("[MYTHIC] tower rate   mult      %.4f with rainbow, %.4f without  (x%.3f, want x%.3f)" % [
		rate_on, rate_off, rate_on / maxf(rate_off, 0.0001), want_r])
	if absf(dmg_on / maxf(dmg_off, 0.0001) - want_d) > 0.001:
		print("[MYTHIC] FAIL: the rainbow damage buff is not reaching get_tower_damage_mult")
		ok = false
	if absf(rate_on / maxf(rate_off, 0.0001) - want_r) > 0.001:
		print("[MYTHIC] FAIL: the rainbow rate buff is not reaching get_tower_rate_mult")
		ok = false

	print("[MYTHIC] RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
