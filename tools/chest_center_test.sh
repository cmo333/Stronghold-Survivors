#!/usr/bin/env bash
# Does the chest reveal's ray burst originate AT the chest?
#
#   tools/chest_center_test.sh
#   GODOT=/path/to/Godot tools/chest_center_test.sh
#
# The chest and the burst are two separately-anchored PRESET_CENTER Controls
# that are meant to read as one event. They shipped 150px apart -- the lid
# opened above the circle rather than out of it -- and nothing in the source
# looked wrong, because both were "centred", just on different things.
#
# Reads the two Controls' real rects after placement instead of their code.
# Negative control: put _place_chest_rays back on the viewport centre (drop the
# CHEST_SPRITE_RISE terms) and this reports 150.00px and FAILs.

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

"$GODOT_BIN" --headless --path . --script tools/chest_center_test.gd 2>&1 \
	| grep -E "^\[CHEST\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
