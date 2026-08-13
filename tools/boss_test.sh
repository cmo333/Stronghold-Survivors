#!/usr/bin/env bash
# Measure what the bosses actually do, in a running engine.
#
#   tools/boss_test.sh                  # both modes
#   tools/boss_test.sh health           # what health a boss ends up with
#   tools/boss_test.sh path             # whether a boss routes around a wall
#   GODOT=/path/to/Godot tools/boss_test.sh
#
# WHY THIS EXISTS
#
# Both boss claims had previously been "verified" by reading the code, and both
# readings were wrong in the same way -- the state under test was never reached:
#
#   health  boss_base.setup() runs BEFORE _ready(), and every subclass assigns
#           max_health in its own _ready(). Any answer derived from setup() is an
#           answer about a value that gets overwritten a moment later. This reads
#           max_health off a boss that has been added to the tree.
#
#   path    the previous wall fixture was not sealed. The colossus "crossed" it
#           having moved 18px sideways, which is a boss walking through a wall,
#           not a boss routing around one. A fixture that never reaches the state
#           under test reports the same clean result in the broken build and the
#           fixed one, which is worse than no test.
#
# So the path mode proves its own fixture before it reports a single boss, on
# four independent counts, and refuses to print results if any of them fails:
#
#   geometry  every tile is a 32x32 collider on the 32px grid with no seam, on
#             GameLayers.BUILDING, with blocks_path set. (A ring of towers at
#             angular steps does NOT tile: grid snapping leaves holes.)
#   physics   an agent-sized circle stepped down the wall line at 1px must be
#             inside a building at every sample. Enemies have a ~7px radius, so
#             any opening over ~14px admits them -- a ray cast down the middle
#             of a 32px hole still reports "blocked".
#   flow      main.gd's BFS must agree: no point on the wall line may still be
#             is_flow_reachable(). Placement, the obstacle grid and the flow
#             field are three separate things and only the last one steers.
#   control   a CharacterBody2D with the enemy's exact collision profile, walking
#             the straight line, must fail to cross. This is the check whose
#             absence let the last fixture pass.
#
# The flow field rebuilds on a 0.35s timer, so the fixture waits for a rebuild
# before judging any route.
#
# And the fixture was checked against the bug it exists to catch: with the
# colossus reverted to its old raw `(target - self).normalized()` steering, this
# reports `colossus NO, min_d 343.0, lateral 0.0` and fails -- 343.0 being the
# wall's face, i.e. the boss parked against the wall exactly as it used to park
# against a tower. A fixture that has not been shown to fail on the broken build
# has not been shown to test anything.
#
# Runs under --fixed-fps so the simulation advances at a fixed 60Hz step as fast
# as the CPU allows, and so the result does not depend on how loaded the box is.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_godot() {
	[ -n "${GODOT:-}" ] && [ -x "$GODOT" ] && { echo "$GODOT"; return; }
	[ -f "$REPO_DIR/.play.godot" ] && {
		p="$(cat "$REPO_DIR/.play.godot")"
		[ -x "$p" ] && { echo "$p"; return; }
	}
	for app in /Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
		[ -x "$app/Contents/MacOS/Godot" ] && { echo "$app/Contents/MacOS/Godot"; return; }
	done
	command -v godot4 2>/dev/null && return
	command -v godot 2>/dev/null && return
}

GODOT_BIN="$(find_godot)"
if [ -z "$GODOT_BIN" ]; then
	echo "Could not find Godot. Set GODOT=/path/to/Godot" >&2
	exit 2
fi

run() {
	"$GODOT_BIN" --headless --fixed-fps 60 --path "$REPO_DIR" \
		--script "$REPO_DIR/tools/boss_test.gd" -- "--mode=$1" 2>&1 \
		| grep -E '^\[BOSS-TEST\]|SCRIPT ERROR|Parse Error'
	return "${PIPESTATUS[0]}"
}

status=0
for mode in ${@:-health path}; do
	run "$mode" || status=1
done
exit "$status"
