#!/usr/bin/env bash
# Prove the meta save survives corruption and refuses a purchase it cannot store.
#
#   tools/save_test.sh                  # find the engine the way play.sh does
#   GODOT=/path/to/Godot tools/save_test.sh
#
# WHY THIS EXISTS:
#
#   `meta_progress.json` used to have no version, no migration, no atomic write
#   and no backup. A corrupt file was indistinguishable from a fresh install:
#   the player lost every core and unlock with no message, and the next write
#   stamped defaults over the corrupt file, destroying the only copy that could
#   have been recovered. Every write failure was a `push_warning`, which is
#   compiled out of release builds, and no caller checked a return value — so a
#   player could spend 10000 cores on a hero, watch it unlock, and lose both on
#   restart.
#
#   That was rewritten, but only ever checked against a Python model of the
#   filesystem. A model cannot speak for Godot's own DirAccess.rename and
#   FileAccess.flush semantics, which is exactly where an atomic-write scheme
#   lives or dies. This runs the real autoload against real files.
#
# Three cases, each a separate boot because the load path runs once at startup:
#
#   1. corrupt save + good backup   -> recovered, player told, backup NOT
#                                      clobbered by the corrupt bytes
#   2. corrupt save + corrupt backup-> defaults, different message, and the
#                                      unreadable file LEFT ON DISK (it is the
#                                      player's only remaining artifact)
#   3. write cannot land            -> purchase refused, cores not taken
#
#   Case 3 blocks the write by making the temp path a directory rather than by
#   chmod, because this often runs as root and root ignores file permissions.
#
# SAFETY: this overwrites the real `user://meta_progress.json`. It refuses to
# start unless it can take a backup first, and restores it from an EXIT trap so
# an interrupt or a crash mid-run still puts your save back.

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

# Ask the engine where user:// actually is rather than guessing the platform's
# convention and the project-name mangling.
PROBE="$(mktemp -t userdir.XXXXXX).gd"
cat > "$PROBE" <<'EOF'
extends SceneTree
func _initialize() -> void:
	print("USERDIR=", OS.get_user_data_dir())
	quit()
EOF
UD="$("$GODOT_BIN" --headless --path "$REPO_DIR" --script "$PROBE" 2>/dev/null | sed -n 's/^USERDIR=//p' | tail -1)"
rm -f "$PROBE"
[ -n "$UD" ] && [ -d "$UD" ] || { echo "Could not resolve user:// (got '$UD')" >&2; exit 2; }

SAVE="$UD/meta_progress.json"
STASH="$(mktemp -d -t savetest.XXXXXX)"

restore() {
	rm -f "$SAVE" "$SAVE.bak" 2>/dev/null
	rmdir "$SAVE.tmp" 2>/dev/null
	rm -f "$SAVE.tmp" 2>/dev/null
	cp -a "$STASH"/. "$UD"/ 2>/dev/null
	rm -rf "$STASH"
}
trap restore EXIT INT TERM

# Refuse to run if the player's save cannot be put back afterwards.
for f in "$SAVE" "$SAVE.bak"; do
	[ -e "$f" ] && { cp -a "$f" "$STASH/" || { echo "Could not back up $f; refusing to run." >&2; exit 2; }; }
done

CORRUPT='NOT JSON AT ALL {{{ broken'
GOOD='{"version":1,"cores":4242,"lifetime_cores_earned":4242,"unlocked_heroes":{"warlock":true},"permanent_upgrades":{},"unlocked_levels":{}}'
RICH='{"version":1,"cores":5000,"lifetime_cores_earned":5000,"unlocked_heroes":{"warlock":true},"permanent_upgrades":{},"unlocked_levels":{}}'

clean() { rm -f "$SAVE" "$SAVE.bak"; rmdir "$SAVE.tmp" 2>/dev/null; rm -f "$SAVE.tmp" 2>/dev/null; }
run()   { "$GODOT_BIN" --headless --path "$REPO_DIR" --script "$REPO_DIR/tools/save_test.gd" -- "--mode=$1" 2>&1 | grep -E '^\[SAVE-TEST\]|SCRIPT ERROR|Parse Error'; }

FAILED=0
note() { grep -q "$1: PASS" <<<"$2" || FAILED=1; }

clean; printf '%s' "$CORRUPT" > "$SAVE"; printf '%s' "$GOOD" > "$SAVE.bak"
OUT="$(run recover)";   echo "$OUT"; note "recover-from-backup" "$OUT"

clean; printf '%s' "$CORRUPT" > "$SAVE"; printf '%s' 'also garbage ]]]' > "$SAVE.bak"
OUT="$(run nobackup)";  echo "$OUT"; note "no-usable-backup" "$OUT"

clean; printf '%s' "$RICH" > "$SAVE"; cp "$SAVE" "$SAVE.bak"
OUT="$(run writefail)"; echo "$OUT"; note "purchase-refused-when-write-fails" "$OUT"

echo "[SAVE-TEST] ALL: $([ $FAILED -eq 0 ] && echo PASS || echo FAIL)"
exit $FAILED
