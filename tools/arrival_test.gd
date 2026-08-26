extends SceneTree

# Does the boot cinematic actually speak the rolled arrival, and does its
# timeline reflow to fit? See tools/arrival_test.sh for what each section
# guards. Same completion-counting shape as manifest_test.gd: a check that
# errors out partway must show up as missing, not as silence.

const EXPECTED := ["differing_seeds", "typed_rolled", "reflow", "fallback"]

var _f := 0
var _ok := true
var _done := {}

func _fail(msg: String) -> void:
	print("[ARRIVAL] FAIL: %s" % msg)
	_ok = false

func _mark(name: String) -> void:
	_done[name] = true


func _spawn_intro() -> Control:
	var intro: Control = (load("res://scenes/intro.tscn") as PackedScene).instantiate()
	root.add_child(intro)
	return intro


func _kill(intro: Control) -> void:
	root.remove_child(intro)
	intro.free()


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

	# Two seeds whose arrival texts differ in LENGTH -- required for the reflow
	# check to mean anything. If 200 seeds cannot produce two different lengths
	# the arrival table has collapsed to one entry, and that is itself a failure.
	var seed_a := -1
	var seed_b := -1
	var text_a := ""
	var text_b := ""
	for s in range(1, 200):
		var lines: Array = RM.roll_default(s).arrival_lines()
		if lines.is_empty():
			continue
		var joined: String = "\n".join(lines)
		if seed_a == -1:
			seed_a = s
			text_a = joined
		elif joined.length() != text_a.length():
			seed_b = s
			text_b = joined
			break
	if seed_a == -1 or seed_b == -1:
		_fail("could not find two seeds with different-length arrivals in 200 tries")
	else:
		print("[ARRIVAL] seeds %d (%d chars) and %d (%d chars)" % [
			seed_a, text_a.length(), seed_b, text_b.length()])
		_mark("differing_seeds")

	# The intro must type OUR roll, not its own and not the Alexander quote.
	RM.begin(seed_a)
	var intro := _spawn_intro()
	var typed: String = str(intro._quote.text)
	var end_a: float = float(intro._t_end)
	if typed != text_a:
		_fail("intro typed %d chars, the roll says %d: '%s'" % [
			typed.length(), text_a.length(), typed.left(60)])
	elif typed == intro.QUOTE:
		_fail("intro typed the Alexander quote despite a live roll")
	else:
		print("[ARRIVAL] intro typed the rolled arrival for seed %d" % seed_a)
		_mark("typed_rolled")
	_kill(intro)

	# THE REFLOW. The handoff's whole reason for wiring the intro first: every
	# beat derives from text length, so a different arrival must shift the end
	# of the cinematic by exactly the character difference over QUOTE_CPS.
	RM.begin(seed_b)
	var intro2 := _spawn_intro()
	var end_b: float = float(intro2._t_end)
	var want_delta: float = float(text_b.length() - text_a.length()) / float(intro2.QUOTE_CPS)
	var got_delta: float = end_b - end_a
	print("[ARRIVAL] reflow: t_end %0.3f -> %0.3f (delta %0.3f, want %0.3f)" % [
		end_a, end_b, got_delta, want_delta])
	if absf(got_delta - want_delta) > 0.001:
		_fail("timeline did not reflow with the text")
	elif absf(want_delta) < 0.0001:
		_fail("chosen seeds gave a zero expected delta -- check the seed search")
	else:
		_mark("reflow")
	_kill(intro2)

	# Empty tables must degrade to the old intro, not a blank screen.
	RM.current = RM.roll(1, {"races": [], "regions": [], "modifiers": []})
	var intro3 := _spawn_intro()
	if str(intro3._quote.text) != str(intro3.QUOTE):
		_fail("empty roll did not fall back to the Alexander quote")
	else:
		print("[ARRIVAL] empty tables fall back to the stock quote")
		_mark("fallback")
	_kill(intro3)
	RM.current = null

	for name in EXPECTED:
		if not _done.has(name):
			_fail("check '%s' never completed -- it errored out partway" % name)
	print("[ARRIVAL] checks completed: %d of %d" % [_done.size(), EXPECTED.size()])
	print("[ARRIVAL] RESULT: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)
	return true
