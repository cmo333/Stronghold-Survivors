#!/usr/bin/env bash
# Pull the latest work and relaunch the game.
#
#   ./play.sh
#
# Fetches origin/slim, snaps the working tree to it, and restarts the game so
# you're testing the newest build. Local edits are stashed (never discarded)
# before the reset.
#
# Overrides:
#   BRANCH=main ./play.sh                        # different branch
#   GODOT=/path/to/Godot ./play.sh               # explicit engine binary (remembered)
#   ./play.sh --no-run                           # update only, don't launch

set -uo pipefail

BRANCH="${BRANCH:-slim}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$REPO_DIR/.play.pid"
GODOT_PATH_FILE="$REPO_DIR/.play.godot"
LOG_FILE="$REPO_DIR/.play.log"
RUN_GAME=1
[ "${1:-}" = "--no-run" ] && RUN_GAME=0

cd "$REPO_DIR" || exit 1

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. Never lose local edits -----------------------------------------------
if [ -n "$(git status --porcelain)" ]; then
	STAMP="$(date +%Y%m%d-%H%M%S)"
	warn "You have local changes. Stashing them as 'play-$STAMP' so nothing is lost."
	warn "  Get them back with:  git stash pop"
	git stash push -u -m "play-$STAMP" >/dev/null || fail "Could not stash local changes; stopping."
fi

# --- 2. Fetch, with retries for flaky wifi -----------------------------------
say "Fetching origin/$BRANCH ..."
FETCHED=0
DELAY=2
for _ in 1 2 3 4; do
	if git fetch origin "$BRANCH"; then FETCHED=1; break; fi
	warn "Fetch failed, retrying in ${DELAY}s ..."
	sleep "$DELAY"
	DELAY=$((DELAY * 2))
done
[ "$FETCHED" -eq 1 ] || fail "Could not reach GitHub after 4 tries. Check your connection."

# --- 3. Snap to it -----------------------------------------------------------
OLD="$(git rev-parse --short HEAD)"
git reset --hard "origin/$BRANCH" >/dev/null || fail "Reset failed."
NEW="$(git rev-parse --short HEAD)"

if [ "$OLD" = "$NEW" ]; then
	say "Already up to date at $NEW."
else
	say "Updated $OLD -> $NEW"
	git --no-pager log --oneline "$OLD..$NEW" | sed 's/^/  /'
fi
echo
git --no-pager log --oneline -1 | sed 's/^/now at: /'

[ "$RUN_GAME" -eq 1 ] || exit 0

# --- 4. Find the engine ------------------------------------------------------
# Resolution order: explicit GODOT= -> remembered path -> installed app bundles
# (any Godot*.app, since versioned downloads keep their version in the name) ->
# PATH -> Spotlight. Whatever wins is remembered so this only happens once.
GODOT_BIN=""

try_bin() { [ -n "${1:-}" ] && [ -x "$1" ] && GODOT_BIN="$1"; }

# App bundles anywhere the installer or a download might have put them.
scan_bundles() {
	for app in \
		/Applications/Godot*.app \
		"$HOME"/Applications/Godot*.app \
		"$HOME"/Downloads/Godot*.app \
		"$HOME"/Desktop/Godot*.app; do
		[ -d "$app" ] || continue
		for inner in "$app/Contents/MacOS/Godot" "$app/Contents/MacOS/Godot_mono"; do
			if [ -x "$inner" ]; then echo "$inner"; return 0; fi
		done
	done
	return 1
}

[ -z "$GODOT_BIN" ] && try_bin "${GODOT:-}"
[ -z "$GODOT_BIN" ] && [ -f "$GODOT_PATH_FILE" ] && try_bin "$(cat "$GODOT_PATH_FILE" 2>/dev/null || true)"
[ -z "$GODOT_BIN" ] && try_bin "$(scan_bundles || true)"
[ -z "$GODOT_BIN" ] && try_bin "$(command -v godot4 2>/dev/null || true)"
[ -z "$GODOT_BIN" ] && try_bin "$(command -v godot 2>/dev/null || true)"
# Last resort: ask Spotlight where the app went.
if [ -z "$GODOT_BIN" ] && command -v mdfind >/dev/null 2>&1; then
	SPOT="$(mdfind "kMDItemKind == 'Application' && kMDItemFSName == 'Godot*.app'" 2>/dev/null | head -1)"
	[ -n "$SPOT" ] && try_bin "$SPOT/Contents/MacOS/Godot"
fi

if [ -z "$GODOT_BIN" ]; then
	warn ""
	warn "Updated, but couldn't find Godot to launch it."
	warn ""
	warn "Find it with either of these:"
	warn "  ls -d /Applications/Godot*.app ~/Applications/Godot*.app ~/Downloads/Godot*.app"
	warn "  mdfind -name 'Godot' | grep '\\.app$'"
	warn ""
	warn "Then point at the binary INSIDE the app, once:"
	warn "  GODOT='/Applications/Godot.app/Contents/MacOS/Godot' ./play.sh"
	warn ""
	warn "It gets remembered after that, so plain ./play.sh works from then on."
	exit 0
fi

# Remember it so the next run doesn't have to search.
if [ ! -f "$GODOT_PATH_FILE" ] || [ "$(cat "$GODOT_PATH_FILE" 2>/dev/null || true)" != "$GODOT_BIN" ]; then
	printf '%s\n' "$GODOT_BIN" > "$GODOT_PATH_FILE"
	echo "engine: $GODOT_BIN (remembered)"
fi

# --- 5. Restart the game -----------------------------------------------------
# Only ever kills a game this script started (tracked by PID), so an open Godot
# editor is left alone.
if [ -f "$PID_FILE" ]; then
	OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
	if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
		# Confirm the pid still belongs to the engine before signalling it. PIDs get
		# recycled, and a stale file must never take out an unrelated process.
		OLD_CMD="$(ps -o comm= -p "$OLD_PID" 2>/dev/null || true)"
		case "$OLD_CMD" in
			*[Gg]odot*|*"$(basename "$GODOT_BIN")"*)
				echo "closing previous run (pid $OLD_PID)"
				kill "$OLD_PID" 2>/dev/null || true
				sleep 1
				;;
			*)
				echo "stale pid $OLD_PID is not the engine, leaving it alone"
				;;
		esac
	fi
	rm -f "$PID_FILE"
fi

# Keep the engine's output. Discarding it meant a game that started wrong was
# undiagnosable - no parse errors, no startup state, nothing to look at.
: > "$LOG_FILE"

# --- 5a. Import anything the pull brought in ---------------------------------
# `godot --path .` does NOT run the import pipeline. A texture that arrived in
# the last pull has no entry in .godot/imported, so `load()` returns null and
# the art renders as nothing at all - not a placeholder, nothing. The .import
# sidecars are gitignored, so this hits every machine for every new asset, and
# it is invisible in the game log unless you know to look for "No loader found".
#
# The pass is a no-op once everything is cached, so it only costs engine startup
# on a run where nothing changed.
say "Importing assets ..."
if ! "$GODOT_BIN" --headless --path "$REPO_DIR" --import >>"$LOG_FILE" 2>&1; then
	warn "Import reported a problem; launching anyway. See $LOG_FILE"
fi
if grep -qE "Parse Error|Failed to load resource" "$LOG_FILE"; then
	warn "Import errors (first 5):"
	grep -E "Parse Error|Failed to load resource" "$LOG_FILE" | head -5
fi

say "Launching AVARICE ..."
"$GODOT_BIN" --path "$REPO_DIR" >>"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "running (pid $(cat "$PID_FILE"))"

# Surface the startup banner and anything that failed to load, so a bad launch
# announces itself instead of just looking wrong on screen.
sleep 3
if [ -f "$LOG_FILE" ]; then
	grep -E "^\[startup\]" "$LOG_FILE" | head -3
	if grep -qE "SCRIPT ERROR|Parse Error|Failed to compile" "$LOG_FILE"; then
		warn ""
		warn "Script errors during startup (first 5):"
		grep -E "SCRIPT ERROR|Parse Error|Failed to compile" "$LOG_FILE" | head -5
	fi
fi
echo "full log: $LOG_FILE"
