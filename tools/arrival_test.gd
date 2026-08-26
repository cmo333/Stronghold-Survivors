extends SceneTree

# The PLAY-deals flow, asserted with the real scenes: the boot intro never
# varies, RunManifest.deal() forwards the hand, and the descent narrates it.
# See tools/arrival_test.sh for what each section guards. Completion-counting
# shape as in manifest_test.gd: a check that errors out partway shows up as
# missing, never as silence.

const EXPECTED := ["intro_classic", "deal_forwards", "descent_speaks", "descent_fallback"]

var _f := 0
var _ok := true
var _done := {}

func _fail(msg: String) -> void:
	print("[ARRIVAL] FAIL: %s" % msg)
	_ok = false

func _mark(name: String) -> void:
	_done[name] = true


func _spawn(path: String) -> Control:
	var node: Control = (load(path) as PackedScene).instantiate()
	root.add_child(node)
	return node


func _kill(node: Control) -> void:
	root.remove_child(node)
	node.free()


func _process(_d: float) -> bool:
	_f += 1
	if _f < 2:
		return false

	var RM: GDScript = load("res://scripts/run_manifest.gd")
	if RM == null:
		_fail("run_manifest.gd failed to load")
		print("[ARRIVAL] RESULT: FAIL")
		quit(1)
		return true

	# The boot cinematic is the game's one fixed text. Even with a live roll
	# sitting in RunManifest.current it must type Alexander, nothing else.
	RM.begin(42)
	var intro := _spawn("res://scenes/intro.tscn")
	if str(intro._quote.text) != str(intro.QUOTE):
		_fail("intro deviated from the Alexander quote: '%s'" % str(intro._quote.text).left(60))
	else:
		print("[ARRIVAL] intro types the Alexander quote, roll or no roll")
		_mark("intro_classic")
	_kill(intro)
	RM.current = null

	# The PLAY press. deal() with a fixed seed must publish the roll and
	# forward body -> pending_hero and region terrain -> pending_level on the
	# REAL MetaProgression autoload, because that is the carrier main.gd reads.
	var meta = root.get_node_or_null("MetaProgression")
	if meta == null:
		_fail("MetaProgression autoload not attached -- cannot test the carrier")
	else:
		var m = RM.deal(meta, 42)
		var want_level: String = str(m.region().get("terrain", ""))
		if RM.current != m:
			_fail("deal() did not publish the roll to RunManifest.current")
		elif str(meta.pending_hero) != str(m.body_id):
			_fail("pending_hero is '%s', the roll dealt '%s'" % [meta.pending_hero, m.body_id])
		elif str(meta.pending_level) != want_level:
			_fail("pending_level is '%s', the region says '%s'" % [meta.pending_level, want_level])
		else:
			print("[ARRIVAL] deal(seed 42) forwarded body=%s level=%s" % [m.body_id, want_level])
			_mark("deal_forwards")

	# The descent speaks the dealt arrival -- the real descent.tscn, reading
	# the roll deal() just published.
	var expected: String = "\n".join(RM.current.arrival_lines())
	var descent := _spawn("res://scenes/descent.tscn")
	var spoken: String = str(descent._message.text)
	if expected == "":
		_fail("seed 42 dealt no arrival lines -- table problem, not a descent problem")
	elif spoken != expected:
		_fail("descent typed %d chars, the roll says %d: '%s'" % [
			spoken.length(), expected.length(), spoken.left(60)])
	elif spoken == str(descent.MESSAGE_LINES):
		_fail("descent typed the stock message despite a live roll")
	else:
		print("[ARRIVAL] descent speaks the dealt arrival (%d chars)" % spoken.length())
		_mark("descent_speaks")
	_kill(descent)

	# No roll (direct scene run, broken table) must fall back to the stock
	# lines, never a silent descent.
	RM.current = null
	var descent2 := _spawn("res://scenes/descent.tscn")
	if str(descent2._message.text) != str(descent2.MESSAGE_LINES):
		_fail("descent without a roll did not fall back to the stock message")
	else:
		print("[ARRIVAL] descent without a roll falls back to the stock message")
		_mark("descent_fallback")
	_kill(descent2)

	for name in EXPECTED:
		if not _done.has(name):
			_fail("check '%s' never completed -- it errored out partway" % name)
	print("[ARRIVAL] checks completed: %d of %d" % [_done.size(), EXPECTED.size()])
	print("[ARRIVAL] RESULT: %s" % ("PASS" if _ok else "FAIL"))

	# The descents started a threaded load of main.tscn that outlives them.
	# Quitting while it is mid-flight tears resources out from under the loader
	# thread and prints a wall of spurious "Could not preload resource file"
	# errors after the RESULT line. Block until it lands, then quit clean.
	var status := ResourceLoader.load_threaded_get_status("res://scenes/main.tscn")
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get("res://scenes/main.tscn")

	quit(0 if _ok else 1)
	return true
