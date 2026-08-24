#!/usr/bin/env bash
# Is a run a rolled object, and does one seed always give the same run?
#
#   tools/manifest_test.sh
#
# Nothing in this project represented "a run" before RunManifest: content was
# either fixed or rolled on global randi() at the point of use, which cannot be
# given a negative control. This harness is the reason the manifest is worth
# having -- it is the proof that procedural content stays measurable.
#
# What each section guards:
#
#   arithmetic    All mixing is on 31-bit operands so no product reaches int64.
#                 A seed that wraps differently on two machines is a seed that
#                 does not mean the same thing on two machines.
#   determinism   Same seed, same run. 400 seeds, each rolled twice.
#   varies        THE NEGATIVE CONTROL. A manifest that returned one fixed run
#                 for every seed passes "determinism" perfectly. This asserts
#                 every axis with a real choice actually takes more than one
#                 value, so the check above means something.
#   independence  Adding a modifier must not re-deal race/body/arrival/region.
#                 With one shared sequential stream it would, and every seed
#                 recorded in a save or a bug report would silently decode to a
#                 different run the next time a roll was added.
#   weighting     Weights are honoured, not merely present -- a _pick that chose
#                 uniformly would pass every other section here.
#   tables        "A data table is not the truth." Every tower id rift.json hands
#                 out must resolve in structures.json, every body in main.gd's
#                 real characters array, every terrain key in ground.gd. Read off
#                 those files, not restated, so a rename fails here instead of at
#                 the moment a run rolls something unbuildable.

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

"$GODOT_BIN" --headless --path . --script tools/manifest_test.gd 2>&1 \
	| grep -E "^\[MANIFEST\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
