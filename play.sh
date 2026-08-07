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
#   GODOT=/path/to/Godot ./play.sh               # explicit engine binary
#   ./play.sh --no-run                           # update only, don't launch

set -uo pipefail

BRANCH="${BRANCH:-slim}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$REPO_DIR/.play.pid"
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
GODOT_BIN=""
if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then
	GODOT_BIN="$GODOT"
else
	for candidate in \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
		"/Applications/Godot_mono.app/Contents/MacOS/Godot"; do
		if [ -x "$candidate" ]; then GODOT_BIN="$candidate"; break; fi
	done
fi
if [ -z "$GODOT_BIN" ]; then
	GODOT_BIN="$(command -v godot4 2>/dev/null || command -v godot 2>/dev/null || true)"
fi
if [ -z "$GODOT_BIN" ]; then
	warn ""
	warn "Updated, but couldn't find Godot to launch it."
	warn "Point at it once and it'll be remembered for that run:"
	warn "  GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./play.sh"
	exit 0
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

say "Launching AVARICE ..."
"$GODOT_BIN" --path "$REPO_DIR" >/dev/null 2>&1 &
echo $! > "$PID_FILE"
echo "running (pid $(cat "$PID_FILE"))"
