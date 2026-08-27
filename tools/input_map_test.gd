extends SceneTree
# Every InputMap action the game polls must exist, and the gamepad build-cycle
# must actually reach its handler.
#
#   godot --headless --path . --script tools/input_map_test.gd
#
# WHY THIS EXISTS:
#
#   `Input.is_action_just_pressed("nope")` is not a crash and not a warning --
#   it is an ERROR printed on every call that returns false, so one unregistered
#   action polled from a `_process` costs two log lines per frame for the whole
#   run. That is a dead feature you cannot see plus a log you cannot read, and
#   nothing in the build catches it: the name is a string, so it compiles.
#
#   Half the actions in this game are not in project.godot at all. They are
#   added at runtime by `main.gd::_ensure_input_map()` (see the note there --
#   the gamepad layout deliberately lives in code). So a static check against
#   project.godot would report false failures; the map has to be inspected from
#   inside a booted scene.
#
# The action list is SCANNED out of res://scripts/ rather than hardcoded, so a
# newly-typed action name is covered the moment it is written.
#
# WHY parse_input_event AND NOT action_press:
#
#   `Input.action_press("build_next")` sets the action's state directly. It
#   never becomes an InputEvent, so it does not travel through _input /
#   _unhandled_input, and -- the part that matters here -- it reports pressed
#   for an action that was never registered. A test built on it passes against
#   exactly the bug it is supposed to catch. Real InputEventKey /
#   InputEventJoypadButton objects fed to Input.parse_input_event go through the
#   engine's normal dispatch, which is the thing under test.

const SCRIPT_DIR := "res://scripts"

# Matches the action-name literal in every polling call the game makes.
const POLL_RE := "(?:is_action_just_pressed|is_action_just_released|is_action_pressed|get_action_strength|get_axis|get_vector)\\(\\s*\"([A-Za-z0-9_]+)\""

# Polled only by scripts/quick_actions.gd, which nothing instantiates: it is not
# an autoload, no scene references it and no script loads it. Its _process never
# runs, so these three never reach the InputMap and cost nothing at runtime.
# Listed here rather than registered, because registering an action for a node
# that does not exist would make the sweep pass while the feature stays dead.
const UNREACHABLE := ["repair_building", "sell_building", "upgrade_all"]

var _started := false

func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_go()
	return false

func _wait(n: int) -> void:
	for _i in range(n):
		await process_frame

func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _pad(button: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)

# Every action name passed to a polling call anywhere under res://scripts/.
func _scan_polled_actions() -> Array:
	var re := RegEx.new()
	re.compile(POLL_RE)
	var found := {}
	var dir := DirAccess.open(SCRIPT_DIR)
	if dir == null:
		return []
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var f := FileAccess.open(SCRIPT_DIR + "/" + file, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		for m in re.search_all(src):
			var action: String = m.get_string(1)
			if not found.has(action):
				found[action] = file
	var names := found.keys()
	names.sort()
	var out := []
	for n in names:
		out.append([n, found[n]])
	return out

func _go() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _wait(10)

	var game: Node = null
	for n in root.get_children():
		if n.is_in_group("game"):
			game = n
			break
	if game == null:
		print("[INPUT-TEST] FAIL: main.tscn produced no node in group 'game'")
		quit(1)
		return

	var failures := 0

	# 1. Coverage: everything polled is registered.
	var unregistered := []
	for entry in _scan_polled_actions():
		var action: String = entry[0]
		if InputMap.has_action(action):
			continue
		if UNREACHABLE.has(action):
			print("[INPUT-TEST] unreachable (known): %-20s %s" % [action, entry[1]])
			continue
		print("[INPUT-TEST] UNREGISTERED: %-20s polled by %s" % [action, entry[1]])
		unregistered.append(action)
	if unregistered.is_empty():
		print("[INPUT-TEST] action-coverage: PASS")
	else:
		print("[INPUT-TEST] action-coverage: FAIL (%d unregistered)" % unregistered.size())
		failures += 1

	# 2. The run has to be live before BuildManager reads any of it: its _process
	#    returns early until game_started. Start it with a real key event.
	if not game.game_started:
		_key(KEY_ENTER, true)
		await _wait(2)
		_key(KEY_ENTER, false)
		await _wait(5)
	if not game.game_started:
		print("[INPUT-TEST] FAIL: KEY_ENTER did not start the run")
		quit(1)
		return

	var bm: Node = game.get_node_or_null("BuildManager")
	if bm == null:
		print("[INPUT-TEST] FAIL: no BuildManager node")
		quit(1)
		return

	# 3. RB/LB reach _cycle_build_selection and move the selection both ways.
	var start_id: String = str(bm.current_id)
	_pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _wait(2)
	_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _wait(2)
	var after_next: String = str(bm.current_id)

	_pad(JOY_BUTTON_LEFT_SHOULDER, true)
	await _wait(2)
	_pad(JOY_BUTTON_LEFT_SHOULDER, false)
	await _wait(2)
	var after_prev: String = str(bm.current_id)

	print("[INPUT-TEST] build_next: %s -> %s" % [start_id, after_next])
	print("[INPUT-TEST] build_prev: %s -> %s" % [after_next, after_prev])
	if after_next != start_id:
		print("[INPUT-TEST] build_next-cycles: PASS")
	else:
		print("[INPUT-TEST] build_next-cycles: FAIL (selection did not move)")
		failures += 1
	# Gated on build_next having moved: "came back to the start" is trivially true
	# when nothing moved at all, and would report a PASS for a dead LB as well.
	if after_next == start_id:
		print("[INPUT-TEST] build_prev-cycles: SKIP (build_next never moved)")
	elif after_prev == start_id:
		print("[INPUT-TEST] build_prev-cycles: PASS")
	else:
		print("[INPUT-TEST] build_prev-cycles: FAIL (did not come back to %s)" % start_id)
		failures += 1

	print("[INPUT-TEST] ALL: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
