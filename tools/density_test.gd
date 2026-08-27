extends SceneTree
## How many enemies are actually ON SCREEN, minute by minute?
##
##   tools/density_test.sh                 # measure the current build
##   tools/density_test.sh 600             # sample out to 600s instead of 360
##
## "Not enough enemies" is a complaint about the screen, not about
## enemies_root.get_child_count(). Those two numbers are far apart here and the
## gap is the whole point of this harness:
##
##   - the camera sits at zoom 2.0 on a 1280x720 viewport, so the visible world
##     rect is 640x360 units -- half-width 320, half-height 180, and 367 to the
##     corner;
##   - _pick_reachable_spawn_position places every enemy 500-750 units out.
##
## So EVERY enemy spawns off-screen, at minimum 133 units past the nearest
## corner, and walks in. A field of 108 can read as a dozen. Reporting the field
## count alone would say the horde is fine while the player is looking at an
## empty screen, which is the exact mistake this is here to stop.
##
## Samples the real scene rather than a fixture: the counts depend on the
## extraction phase, the flow field, terrain reachability and enemies dying to
## towers, none of which a synthetic loop reproduces.
##
## ROWS PRINT AS THEY ARE MEASURED, and the header prints before the first one.
## The first version accumulated everything and printed at the end, so a run cut
## short -- by a timeout, by Ctrl-C, by anything -- produced ZERO output and
## said nothing about the time it HAD simulated. Several hundred enemies
## simulate far below real time headless, so being interrupted is the common
## case here, not the exceptional one: two 240s runs were killed at their
## timeout having printed not one row between them.

const DEFAULT_UNTIL := 360.0
const SAMPLE_EVERY := 1.0
## Report rows every 15s; the per-second samples feed the peaks. Short, because
## a row you have beats a tidier row you get killed before seeing.
const REPORT_EVERY := 15.0

var _main: Node = null
var _frames := 0
var _next_sample := 0.0
var _until := DEFAULT_UNTIL
var _rows: Array = []
var _bucket_field: Array = []
var _bucket_screen: Array = []
var _bucket_start := 0.0
var _failed := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--until="):
			_until = float(a.substr(8))

func _process(_delta: float) -> bool:
	_frames += 1
	# Frame 1 is too early: the autoloads are attached but main.tscn is not in
	# the tree yet, so `root.get_node_or_null` finds nothing and the run reports
	# a clean zero. Same family as the preload trap in the ally probe.
	#
	# Both early returns are load-bearing. Without the `< 2` guard the checks
	# below run on frame 1 -- before _boot() has been called at all -- and the
	# harness fails instantly blaming the scene for not being in a tree nothing
	# had yet tried to put it in.
	if _frames < 2:
		return false
	if _frames == 2:
		_boot()
		return false
	# The specific reason beats the generic one; otherwise a failed load reports
	# as "never entered the tree", which points at the wrong thing entirely.
	if _failed != "":
		return _fail(_failed)
	if _main == null:
		return _fail("main.tscn never entered the tree")
	if not is_instance_valid(_main):
		return _fail("main.tscn was freed mid-run")

	var t: float = _elapsed()
	if t >= _next_sample:
		_next_sample += SAMPLE_EVERY
		_sample(t)
	if t >= _until:
		_flush_bucket(t)
		return _report()
	return false

func _boot() -> void:
	var meta = root.get_node_or_null("MetaProgression")
	if meta != null:
		# Skip the menu and drop straight into a run, the same switch the menu
		# itself sets. Without it main.tscn sits on its start panel forever.
		meta.autostart_run = true
		meta.pending_hero = "warlock"
		meta.pending_level = "graveyard"
		meta.pending_modifier = "none"
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_failed = "could not load main.tscn"
		return
	_main = scene.instantiate()
	if _main.get_script() == null:
		_failed = "main.tscn instantiated with NO SCRIPT"
		return
	root.add_child(_main)
	_print_header()
	# The run clock does not start until spawn_delay has passed, and every
	# reading below is keyed to it, so zero it rather than measuring ten seconds
	# of a clock that says 0.0. Same fix the DPS harness needed.
	if "spawn_delay" in _main:
		_main.spawn_delay = 0.0
	_bucket_start = 0.0

func _print_header() -> void:
	var cam = _main.get("camera") if "camera" in _main else null
	var zoom = cam.zoom if cam != null and is_instance_valid(cam) else Vector2.ONE
	print("[DENSITY] viewport %s, camera zoom %s" % [
		str(root.get_viewport().get_visible_rect().size), str(zoom)])
	print("[DENSITY] spawn ring %.0f-%.0f units from the player" % [
		float(_main.spawn_radius_min), float(_main.spawn_radius_max)])
	print("[DENSITY]")
	print("[DENSITY]  t(s)  phase     field_avg  field_pk  SCREEN_avg  SCREEN_pk   cap  interval  horde")


func _print_row(r: Dictionary) -> void:
	print("[DENSITY] %5.0f  %-8s  %9.1f  %8d  %10.1f  %9d  %4d  %8.3f  %5.2f" % [
		r.t, r.phase, r.field_avg, r.field_peak, r.screen_avg, r.screen_peak,
		r.cap, r.interval, r.horde])


func _elapsed() -> float:
	if _main != null and "elapsed" in _main:
		return float(_main.elapsed)
	return 0.0

## The visible world rect, derived from the live camera rather than assumed --
## a zoom punch, the descent's reveal or a settings change all move it.
func _screen_rect() -> Rect2:
	var cam = _main.get("camera") if "camera" in _main else null
	if cam == null or not is_instance_valid(cam):
		return Rect2()
	var vp: Vector2 = Vector2(root.get_viewport().get_visible_rect().size)
	var zoom: Vector2 = cam.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0:
		return Rect2()
	var half: Vector2 = (vp / zoom) * 0.5
	return Rect2(cam.global_position - half, half * 2.0)

func _sample(t: float) -> void:
	var root_node = _main.get("enemies_root") if "enemies_root" in _main else null
	if root_node == null or not is_instance_valid(root_node):
		return
	var rect: Rect2 = _screen_rect()
	var field := 0
	var on_screen := 0
	for e in root_node.get_children():
		if e == null or not is_instance_valid(e):
			continue
		# Count bodies, not corpses: a dying enemy is still a child for the
		# length of its death animation and is not something the player reads as
		# a threat on screen.
		if "_is_dying" in e and e._is_dying:
			continue
		field += 1
		if rect.size != Vector2.ZERO and rect.has_point(e.global_position):
			on_screen += 1
	_bucket_field.append(field)
	_bucket_screen.append(on_screen)
	if t - _bucket_start >= REPORT_EVERY:
		_flush_bucket(t)

func _flush_bucket(t: float) -> void:
	if _bucket_field.is_empty():
		return
	var settings: Dictionary = {}
	if _main.has_method("_get_spawn_settings"):
		settings = _main._get_spawn_settings(_elapsed())
	var row := {
		"t": t,
		"field_avg": _avg(_bucket_field),
		"field_peak": _peak(_bucket_field),
		"screen_avg": _avg(_bucket_screen),
		"screen_peak": _peak(_bucket_screen),
		"cap": int(settings.get("max_enemies", 0)),
		"interval": float(settings.get("interval", 0.0)),
		"horde": float(settings.get("horde_mult", 0.0)),
		"phase": _phase_name()
	}
	_rows.append(row)
	# Printed here, not banked for the end. See the note at the top.
	_print_row(row)
	_bucket_field.clear()
	_bucket_screen.clear()
	_bucket_start = t

func _phase_name() -> String:
	if not ("extraction_phase" in _main):
		return "?"
	match int(_main.extraction_phase):
		0: return "SCOUT"
		1: return "SIEGE"
		2: return "OVERRUN"
	return "?"

func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0
	for v in a:
		s += int(v)
	return float(s) / float(a.size())

func _peak(a: Array) -> int:
	var m := 0
	for v in a:
		m = max(m, int(v))
	return m

func _fail(msg: String) -> bool:
	print("[DENSITY] FAIL: %s" % msg)
	quit(1)
	return true

func _report() -> bool:
	if _failed != "":
		return _fail(_failed)
	if _rows.is_empty():
		return _fail("no samples taken")
	print("[DENSITY] visible world rect %s" % str(_screen_rect().size))
	# Assertions, so a broken harness cannot pass as a measured result.
	var last = _rows[_rows.size() - 1]
	if last.field_peak <= 0:
		return _fail("no enemy ever reached the field -- the run never started")
	var any_screen := false
	for r in _rows:
		if r.screen_peak > 0:
			any_screen = true
			break
	if not any_screen:
		return _fail("no enemy was ever on screen -- the camera rect is probably wrong")
	print("[DENSITY] RESULT: PASS")
	quit(0)
	return true
