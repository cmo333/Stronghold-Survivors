#!/usr/bin/env bash
# Does the stacked hellfire total stay under a white-out?
#
#   tools/hellfire_test.sh
#   GODOT=/path/to/Godot tools/hellfire_test.sh
#
# These pools blend ADDITIVELY, so the number that decides whether the screen is
# readable is count * alpha * scale(count) -- not the per-pool alpha, which is
# what everyone reaches for first and which was already halved once (3b047ab)
# without fixing this. Anything past 1.0 is white; a full late fort was reaching
# ~20 and taking the towers, the horde and the player with it.
#
# Asserts the total stays bounded AND never decreases as pools are added, and
# that a lone pool is left at exactly 1.0 -- without that last check a "ceiling"
# is just a dimmer, and the doomsday read this is meant to preserve is gone.
#
# Drives the real static on cannon_tower.gd rather than re-deriving the curve:
# a probe that re-implements what it measures agrees with itself forever.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

find_godot() {
	[ -n "${GODOT:-}" ] && [ -x "$GODOT" ] && { echo "$GODOT"; return; }
	[ -f "$REPO_DIR/.play.godot" ] && {
		p="$(cat "$REPO_DIR/.play.godot")"
		[ -x "$p" ] && { echo "$p"; return; }
	}
	for app in /Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
		[ -x "$app/Contents/MacOS/Godot" ] && { echo "$app/Contents/MacOS/Godot"; return; }
	done
	for c in godot4 godot; do
		command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
	done
}

GODOT_BIN="$(find_godot)"
[ -n "$GODOT_BIN" ] || { echo "Could not find Godot. Set GODOT=/path/to/Godot (must be 4.7.1)." >&2; exit 2; }

"$GODOT_BIN" --headless --path . --script tools/hellfire_test.gd 2>&1 \
	| grep -E "^\[HELLFIRE\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
