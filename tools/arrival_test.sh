#!/usr/bin/env bash
# Does the boot cinematic speak the rolled arrival, and reflow to fit it?
#
#   tools/arrival_test.sh
#
# The Rift roll happens in intro.gd's _ready (first roller wins), and every
# beat of the cinematic derives from how long the typed text is. This asserts
# the chain end to end, with the real intro.tscn, not a model of it:
#
#   differing_seeds  Finds two seeds whose arrival texts differ in length.
#                    If 200 seeds cannot, the arrival table has collapsed to
#                    one entry and the variety the pivot promises is gone.
#   typed_rolled     A pre-rolled manifest's lines are exactly what the intro
#                    puts in its quote label -- not the Alexander quote, and
#                    not a roll of the intro's own.
#   reflow           t_end shifts by exactly (chars difference / QUOTE_CPS)
#                    between the two seeds. This is the "editing the text
#                    reflows the whole cinematic" property, measured.
#   fallback         A roll from empty tables leaves the stock Alexander
#                    quote, so a broken rift.json degrades to the old intro
#                    rather than a blank screen.
#
# Wrapper derived from manifest_test.sh. Run it and watch it PRINT before
# trusting the exit code -- two earlier wrappers shipped green-because-silent.

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

"$GODOT_BIN" --headless --path . --script tools/arrival_test.gd 2>&1 \
	| grep -E "^\[ARRIVAL\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
