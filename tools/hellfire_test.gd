extends SceneTree
## What does the stacked hellfire total actually come to, per pool count?
##
## Additive alpha sums, and anything past 1.0 is white. So the number that
## decides whether the screen is readable is sum = count * ALPHA * scale(count),
## not the per-pool alpha everyone reaches for first.
##
## Calls the real static on cannon_tower.gd rather than re-deriving the formula
## here -- a probe that re-implements the thing it measures agrees with itself
## forever, which is lesson 34 and cost a whole boss-scaling pass.

const COUNTS := [1, 4, 8, 12, 20, 40, 80, 160]

var _frames := 0

# _process at frame 2, not _init/_initialize: a SceneTree script's entry point
# runs BEFORE the autoloads are attached, and cannon_tower.gd resolves them at
# compile time, so loading it there yields a script that silently fails to
# compile. Lesson 6.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	return _run()

func _run() -> bool:
	var cannon = load("res://scripts/cannon_tower.gd")
	if cannon == null:
		print("[HELLFIRE] FAIL: could not load cannon_tower.gd")
		quit(1)
		return true
	var alpha: float = cannon.HELLFIRE_POOL_ALPHA
	var soft: int = cannon.HELLFIRE_POOL_SOFT_COUNT
	print("[HELLFIRE] per-pool alpha %.3f, soft count %d, falloff %.2f" % [
		alpha, soft, cannon.HELLFIRE_POOL_FALLOFF])
	print("[HELLFIRE]  pools   scale   stacked_before   stacked_after   readable?")
	var ok := true
	var prev_after := -1.0
	for n in COUNTS:
		# Drive the real static by stuffing the registry with placeholder nodes,
		# so the scale comes from shipping code and not from a copy of it.
		cannon._live_pools = []
		for i in range(n):
			cannon._live_pools.append(Node2D.new())
		var scale: float = cannon._hellfire_density_scale()
		var before: float = float(n) * alpha
		var after: float = float(n) * alpha * scale
		print("[HELLFIRE] %6d  %6.3f  %14.2f  %14.2f   %s" % [
			n, scale, before, after, "core only" if after > 1.0 else "fully legible"])
		# The whole point: the stacked total must stay bounded well under the
		# ~20 that made everything white, while never DECREASING with more fire.
		if after > 5.0:
			print("[HELLFIRE] FAIL: %d pools still sum to %.2f -- that is a white-out" % [n, after])
			ok = false
		if after + 0.001 < prev_after:
			print("[HELLFIRE] FAIL: %d pools sum LOWER (%.2f) than the previous step (%.2f) -- more fire must never read as less" % [n, after, prev_after])
			ok = false
		prev_after = after
		for p in cannon._live_pools:
			p.free()
	# Negative control: a single pool must be untouched, or this "ceiling" is
	# just a dimmer and the doomsday read is gone.
	cannon._live_pools = []
	var one := Node2D.new()
	cannon._live_pools.append(one)
	var solo: float = cannon._hellfire_density_scale()
	print("[HELLFIRE] single pool scale %.4f (must be exactly 1.0)" % solo)
	if absf(solo - 1.0) > 0.0001:
		print("[HELLFIRE] FAIL: a lone pool was dimmed to %.4f" % solo)
		ok = false
	one.free()
	cannon._live_pools = []
	print("[HELLFIRE] RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
