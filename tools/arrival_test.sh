#!/usr/bin/env bash
# PLAY deals the run; the descent narrates it; the boot intro never varies.
#
#   tools/arrival_test.sh
#
# The Rift roll happens at the PLAY press (RunManifest.deal, called by the
# menu), not at boot: the story you are told is the story of the run you are
# about to play, not of a load that might sit on the menu for an hour. This
# asserts the chain with the real scenes, not models of them:
#
#   intro_classic     intro.tscn types the Alexander quote even with a live
#                     roll present -- the boot cinematic is fixed text again.
#   deal_forwards     deal(seed) publishes RunManifest.current and forwards
#                     body -> pending_hero, region terrain -> pending_level on
#                     the REAL MetaProgression autoload, the carrier main.gd
#                     and every harness read.
#   descent_speaks    descent.tscn's rift message is exactly the dealt
#                     arrival's lines, and provably not the stock message.
#   descent_fallback  With no roll, the descent types the stock lines -- a
#                     direct scene run or broken rift.json is never silent.
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
	| grep -E "^\[ARRIVAL\]|^\[RIFT\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
