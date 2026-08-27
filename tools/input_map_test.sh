#!/usr/bin/env bash
# Every action a script polls must actually be registered in the InputMap.
#
#   tools/input_map_test.sh             # find the engine the way play.sh does
#   GODOT=/path/to/Godot tools/input_map_test.sh
#
# WHY THIS EXISTS:
#
#   Godot logs "The InputMap action X doesn't exist" once per poll -- so an
#   unregistered action bound to a per-frame check produces thousands of lines a
#   run, the feature is silently dead, and any real error is buried. Half the
#   actions in this game are registered at runtime by main.gd's
#   _ensure_input_map(), not in project.godot, so a static check of the .cfg
#   reports false failures and cannot be used.
#
#   This boots the real main.tscn, scans the action names out of res://scripts/
#   at runtime (so new names are covered without editing this test), and drives
#   the build-cycle keys with real InputEventJoypadButton objects through
#   Input.parse_input_event -- never Input.action_press, which writes action
#   state directly and reports "pressed" for an action that was never
#   registered, i.e. passes against the exact bug it is meant to catch.
#
# Known-unreachable actions (polled by a script nothing instantiates) are
# listed rather than registered: giving an action to a node that does not exist
# would make this pass while the feature stayed dead.

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

exec "$GODOT_BIN" --headless --path "$REPO_DIR" --script "$REPO_DIR/tools/input_map_test.gd"
