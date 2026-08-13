#!/usr/bin/env bash
# Measure what every damage source in the game actually deals, on a real enemy.
#
#   tools/dps_test.sh                   # find the engine the way play.sh does
#   GODOT=/path/to/Godot tools/dps_test.sh
#
# Boots the real main.tscn headless, suppresses every spawner, pins one dummy
# and runs one source at a time against it: the player alone, then each tower at
# each tier. Prints a table and a PASS/FAIL line.
#
# WHY THE REAL SCENE, and not a minimal fixture:
#
#   A fixture isolates perfectly and proves nothing. Four earlier attempts at
#   this measurement returned 0.0 for everything, and the reasons were both in
#   the real scene: the horde was still spawning (a tower shoots whatever is
#   closest, so the dummy was never the target), and the clock read main.gd's
#   `elapsed`, which does not start until spawn_delay -- above the same early
#   return that builds the enemy cache every tower targets through. Neither bug
#   exists in a fixture, so a fixture would have "passed" while telling you
#   nothing about the game.
#
# A zero in the output is a broken harness, not a measured zero. Every pass
# asserts its own preconditions and the failures print by name.

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

# Roughly two minutes of measurement: each window is sized to hold ~10 shots, so
# the slow cannon takes the longest. The timeout is a backstop, not a budget.
exec "$GODOT_BIN" --headless --path "$REPO_DIR" -- --dps-test
