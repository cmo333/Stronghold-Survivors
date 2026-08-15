#!/usr/bin/env bash
# How many enemies are actually on screen, minute by minute?
#
#   tools/density_test.sh              # out to 360s
#   tools/density_test.sh 600          # out to 600s
#   GODOT=/path/to/Godot tools/density_test.sh
#
# Reports the FIELD count and the ON-SCREEN count side by side. They are not the
# same number and the gap is the point: the camera shows a 640x360 world rect
# while enemies spawn 500-750 units out, so every one of them arrives off-screen
# and walks in. Tuning the spawn cap without watching the screen column is how
# you end up with a heavier horde that still looks empty.
#
# Headless, so it runs the real simulation without a window. It is not fast --
# 360s of game time takes a few minutes of wall clock.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

UNTIL="${1:-360}"

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

"$GODOT_BIN" --headless --path . --script tools/density_test.gd -- "--until=$UNTIL" 2>&1 \
	| grep -E "^\[DENSITY\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
