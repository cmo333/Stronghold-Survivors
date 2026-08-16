#!/usr/bin/env bash
# Does the flat five-minute horde step do what it says?
#
#   tools/horde_step_test.sh
#
# Asserts +10% per completed 300s (1.10 at 5:00, 1.20 at 10:00, 1.30 at 15:00),
# that it never decreases, and that it did NOT leak into _pack_size() -- run
# length is already expressed by the per-minute ramp and by this step, and a
# third count of the same axis is the shape of the boss health bug (fca9ca6).
#
# Also prints the spawn cap the table asks for at each mark. Read that column
# against HORDE_CAP_HARD_LIMIT: past roughly 6:00 the table wants more than the
# ceiling allows, so the late steps buy a shorter interval rather than more
# bodies. The ceiling is the real constraint late on, not the ramp.

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

"$GODOT_BIN" --headless --path . --script tools/horde_step_test.gd 2>&1 \
	| grep -E "^\[HORDE\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
