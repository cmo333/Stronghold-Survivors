#!/usr/bin/env bash
# An ally in a horde must be fighting, and must never be swinging at a corpse.
#
#   tools/ally_target_test.sh            # find the engine the way play.sh does
#   GODOT=/path/to/Godot tools/ally_target_test.sh
#
# See tools/ally_target_test.gd for what this guards and the negative control
# that proves it can see the bug.

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

exec "$GODOT_BIN" --headless --path "$REPO_DIR" --script "$REPO_DIR/tools/ally_target_test.gd"
