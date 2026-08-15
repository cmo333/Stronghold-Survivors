#!/usr/bin/env bash
# Does a second mythic chest pull actually deliver something?
#
#   tools/mythic_test.sh
#   GODOT=/path/to/Godot tools/mythic_test.sh
#
# spawn_golden_coco() returns early when a companion is already out, while the
# chest roll used to pick blindly from MYTHIC_UPGRADES. So a second mythic pull
# printed the rarest card in the game, played the jackpot fanfare, spent a slot
# from the chest budget, and did nothing at all. At 2% a chest that is the
# normal outcome of a long run, not an edge case -- it was reported from the
# first serious one, at 83 chests opened.
#
# Walks the real sequence against the real scene: golden, then rainbow, then
# nothing, asserting each spawn actually landed on the field rather than that
# the roll returned a nice-looking string. Also toggles the rainbow group off
# and back to confirm the tower buff genuinely moves get_tower_damage_mult and
# get_tower_rate_mult -- a multiplier that reads right but reaches no tower is
# this project'"'"'s most repeated bug (6adb3ee, ae7b959).

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

"$GODOT_BIN" --headless --path . --script tools/stargate_test.gd 2>&1 \
	| grep -E "^\[MYTHIC\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
