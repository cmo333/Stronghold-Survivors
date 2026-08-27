#!/usr/bin/env bash
# Prove pierce passes THROUGH an enemy to the one behind it.
#
#   tools/pierce_test.sh                # find the engine the way play.sh does
#   GODOT=/path/to/Godot tools/pierce_test.sh
#
# WHY THIS EXISTS SEPARATELY FROM tools/dps_test.sh:
#
#   The DPS harness puts exactly one enemy on the field, by design -- a tower
#   shoots whatever is closest, so a second body makes the measurement
#   meaningless. That means it can prove "one shot lands once on one target"
#   and can say nothing at all about what reaches the enemy behind.
#
#   Those are two different failures. `projectile.gd` used to keep no record of
#   which bodies a shot had already hit and left the projectile parked on the
#   collider surface, so the next frame's ray re-acquired the same body:
#   pierce_count = 3 dealt all four landings to the FIRST enemy and never
#   reached the others. The DPS harness now catches the double-hit half of that
#   (it asserts hits == shots). It would not notice pierce silently degrading
#   to "stop at the first body", which costs the same damage on one target.
#
# Fires one pierce_count = 3 projectile down a line of five stationary enemies.
# Expected: four DIFFERENT enemies damaged once each, the fifth untouched.

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

exec "$GODOT_BIN" --headless --path "$REPO_DIR" --script "$REPO_DIR/tools/pierce_test.gd"
