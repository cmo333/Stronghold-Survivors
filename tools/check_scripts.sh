#!/usr/bin/env bash
# Fail if any GDScript in the project does not parse.
#
#   tools/check_scripts.sh              # find the engine the way play.sh does
#   GODOT=/path/to/Godot tools/check_scripts.sh
#
# WHY THIS EXISTS, and why the obvious checks do not work:
#
#   `godot --headless --import` does not reparse scripts when there is nothing
#   to import. On a tree whose assets are already cached it reports a clean run
#   while a script is failing to parse.
#
#   A `load()` sweep over every .gd is worse than useless on its own, because
#   `load()` returns a non-null GDScript for a file that failed to parse. The
#   sweep happily reports "96 compiled, 0 failed" on a broken tree.
#
# The engine does print the failure -- to stderr, as "Parse Error" / "SCRIPT
# ERROR" -- while the return values say everything is fine. So this script
# reads the engine's output and ignores what the script sweep claims.
#
# Both of those false negatives were observed on this project, on changes that
# then broke on the player's machine at launch.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp -t gdparse.XXXXXX)"
trap 'rm -f "$LOG" "$LOG.gd"' EXIT

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

# Touching every script is what forces the parser to run over all of them; the
# return value is deliberately ignored, only the engine's output is trusted.
cat > "$LOG.gd" <<'SWEEP'
extends SceneTree

func _initialize():
	var n := 0
	for path in _walk("res://scripts", ".gd"):
		n += 1
		load(path)
	print("[check] touched %d scripts" % n)
	quit()

func _walk(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var p := dir.path_join(name)
		if d.current_is_dir():
			out.append_array(_walk(p, ext))
		elif name.ends_with(ext):
			out.append(p)
		name = d.get_next()
	d.list_dir_end()
	return out
SWEEP

"$GODOT_BIN" --headless --path "$REPO_DIR" -s "$LOG.gd" >"$LOG" 2>&1
grep -E "^\[check\]" "$LOG" || true

# The Steam plugin logs its own harmless init complaints on a machine with no
# Steam client; they are not script parse failures.
FAILURES="$(grep -E "Parse Error|SCRIPT ERROR|Failed to compile" "$LOG" | grep -v "steam" || true)"
if [ -n "$FAILURES" ]; then
	printf '\033[31m%s\033[0m\n' "GDScript parse failures:"
	printf '%s\n' "$FAILURES"
	exit 1
fi

printf '\033[32m%s\033[0m\n' "All GDScript parses clean."
