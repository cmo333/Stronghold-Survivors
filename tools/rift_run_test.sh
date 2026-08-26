#!/usr/bin/env bash
# Does the run consume the roll? Boots the REAL main.tscn behind a dealt
# manifest and measures the three wired consumptions inside it.
#
#   tools/rift_run_test.sh
#
#   seed_search   Finds a seed that deals salvage_deck + dense_horde +
#                 lean_purse -- searched at run time, not hardcoded, so a
#                 weight retune moves the seed instead of gutting the test.
#   spawn_filter  300 draws from _pick_enemy_scene() at late-game elapsed all
#                 come back from the rolled roster (husk + banshee + wraith on
#                 the salvage deck -- the dead ship is haunted, nothing else
#                 walks it).
#   horde_mult    _get_horde_count_multiplier with Dense rolled is exactly
#                 1.35x its own baseline, measured as a ratio at fixed time so
#                 every other ramp factor cancels.
#   gold_mult     add_resources(+100) lands as +70 with Lean rolled, and a
#                 negative amount is untouched -- a spend is never discounted.
#
# Run it and watch it PRINT before trusting the exit code.

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

"$GODOT_BIN" --headless --path . --script tools/rift_run_test.gd 2>&1 \
	| grep -E "^\[RIFTRUN\]|^\[RIFT\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
