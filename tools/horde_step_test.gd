extends SceneTree
var _f := 0
var _m: Node = null
func _process(_d: float) -> bool:
	_f += 1
	if _f < 2: return false
	if _f == 2:
		var meta = root.get_node_or_null("MetaProgression")
		if meta != null:
			meta.autostart_run = true
			meta.pending_hero = "warlock"
			meta.pending_level = "graveyard"
		_m = load("res://scenes/main.tscn").instantiate()
		root.add_child(_m)
		return false
	if _f < 6: return false
	var ok := true
	print("[HORDE] five-minute step: +%.0f%% per 300s, capped at x%.1f" % [
		_m.HORDE_FIVE_MIN_STEP * 100.0, _m.HORDE_FIVE_MIN_MAX])
	print("[HORDE]   t(s)   step   full_horde_mult   spawn_cap   interval")
	var prev_step := 0.0
	var prev_cap := 0
	for t in [0.0, 150.0, 300.0, 450.0, 600.0, 900.0, 1200.0, 1800.0, 3600.0]:
		var step: float = _m._five_minute_step(t)
		var s: Dictionary = _m._get_spawn_settings(t)
		print("[HORDE] %6.0f  %5.2f   %15.3f   %9d   %8.3f" % [
			t, step, float(s.get("horde_mult", 0.0)), int(s.get("max_enemies", 0)), float(s.get("interval", 0.0))])
		var want: float = clampf(1.0 + floorf(t / 300.0) * _m.HORDE_FIVE_MIN_STEP, 1.0, _m.HORDE_FIVE_MIN_MAX)
		if absf(step - want) > 0.0001:
			print("[HORDE] FAIL: t=%.0f step %.4f, want %.4f" % [t, step, want]); ok = false
		if step + 0.0001 < prev_step:
			print("[HORDE] FAIL: the step went DOWN at t=%.0f" % t); ok = false
		prev_step = step
		prev_cap = int(s.get("max_enemies", 0))
	# Exact anchors the request named.
	for pair in [[300.0, 1.10], [600.0, 1.20], [900.0, 1.30]]:
		var got: float = _m._five_minute_step(pair[0])
		if absf(got - pair[1]) > 0.0001:
			print("[HORDE] FAIL: t=%.0f gave %.3f, asked for %.2f" % [pair[0], got, pair[1]]); ok = false
	# It must NOT have leaked into pack size -- that would be a third count of
	# run length on the same axis.
	var p300: int = _m._pack_size(300.0)
	var want_p: int = clampi(int(round(_m.PACK_BASE_SIZE * pow(_m.PACK_GROWTH_PER_MIN, (300.0 - _m.PACK_START_TIME) / 60.0))), 1, _m.PACK_MAX_SIZE)
	print("[HORDE] pack size at 300s = %d (unchanged by the step: want %d)" % [p300, want_p])
	if p300 != want_p:
		print("[HORDE] FAIL: the five-minute step leaked into _pack_size"); ok = false
	print("[HORDE] RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
