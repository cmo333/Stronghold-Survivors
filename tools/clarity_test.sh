#!/usr/bin/env bash
# Does the upgrade panel tell the player the truth?
#
#   tools/clarity_test.sh
#   GODOT=/path/to/Godot tools/clarity_test.sh
#
# Three questions, all answered off CONFIGURED TOWERS rather than off
# structures.json -- the sheet has been wrong by 2.3x-4.65x before, and tuning
# against it is what caused the reverted balance pass (dc853f2):
#
#   1. The panel prints tier_data damage/range/fire_rate verbatim, but the tower
#      multiplies them by ESSENCE_INFUSION_*_MULT on top. Every T3 upgrade is
#      therefore advertised at 1/1.65 of the damage it delivers.
#   2. Towers override get_upgrade_cost() to a flat 500 gold + 1 essence and
#      never read tiers[N].cost, so those fields in the sheet are dead for all
#      five towers -- while being correct for the other twelve structures.
#   3. What an upgrade actually buys per gold, at the REAL price.
#
# Fails if the panel and the tower disagree on damage at any tier above 1.

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

"$GODOT_BIN" --headless --path . --script tools/clarity_test.gd 2>&1 \
	| grep -E "^\[MYTHIC\]|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
