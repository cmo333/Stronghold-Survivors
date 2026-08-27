#!/usr/bin/env bash
# Produce the distributable builds.
#
#   tools/build.sh windows          # -> build/windows/Avarice.exe
#   tools/build.sh web              # -> build/web/ + build/web/Avarice-web.zip (itch.io)
#   tools/build.sh mac              # -> build/mac/Avarice.zip
#   tools/build.sh all
#   GODOT=/path/to/Godot tools/build.sh windows
#
# ON WINDOWS: run this from Git Bash (ships with Git for Windows). If you would
# rather not, the whole script is one command per target in PowerShell:
#
#   & "C:\path\to\Godot_v4.7.1-stable_win64.exe" --headless --path . `
#       --export-release "Windows Desktop" build/windows/Avarice.exe
#
# EXPORT TEMPLATES ARE REQUIRED AND ARE NOT IN THIS REPO. They are ~1GB, live
# per-machine, and must match the engine build EXACTLY (4.7.1.stable). Install
# them once from the editor: Editor > Manage Export Templates > Download and
# Install. Without them every export fails with "No export template found at the
# expected path" and nothing is written -- which is the only thing standing
# between this config and a build, as of the last check.
#
# WHAT THIS DOES NOT DO:
#   - Sign anything. The macOS preset is ad-hoc signed (codesign/identity="-"),
#     so the .zip will be stopped by Gatekeeper on any Mac but the one that
#     built it. Testers would have to right-click > Open, or you need an Apple
#     Developer ID in the preset. Windows is unsigned too; SmartScreen will warn.
#   - Touch steam_appid.txt, which is still Valve's Spacewar test ID (480).
#     A tester with Steam running launches into what Steam thinks is Spacewar.

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
	# Git Bash on Windows: the editor is usually just on PATH or beside the repo.
	for c in godot4 godot Godot_v4.7.1-stable_win64.exe ./Godot_v4.7.1-stable_win64.exe; do
		command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
	done
}

GODOT_BIN="$(find_godot)"
if [ -z "$GODOT_BIN" ]; then
	echo "Could not find Godot. Set GODOT=/path/to/Godot (must be 4.7.1)." >&2
	exit 2
fi

# A mismatched engine silently produces a build against the wrong templates, so
# say out loud which one is about to be used.
echo "engine: $("$GODOT_BIN" --version 2>/dev/null | head -1)  ($GODOT_BIN)"

export_one() {
	preset="$1"; out="$2"
	mkdir -p "$(dirname "$out")"
	echo "==> $preset -> $out"
	# --export-release writes nothing at all when templates are missing, and the
	# exit code alone does not always say so, hence the explicit existence check.
	"$GODOT_BIN" --headless --path . --export-release "$preset" "$out"
	if [ ! -e "$out" ]; then
		echo "FAILED: $preset produced no output at $out" >&2
		echo "        Almost always the export templates: install 4.7.1.stable from the editor." >&2
		return 1
	fi
	echo "    ok: $(du -h "$out" 2>/dev/null | cut -f1) $out"
}

target="${1:-all}"
rc=0

case "$target" in
	windows|all)
		export_one "Windows Desktop" "build/windows/Avarice.exe" || rc=1
		;;&
	mac|all)
		export_one "macOS" "build/mac/Avarice.zip" || rc=1
		;;&
	web|all)
		if export_one "Web" "build/web/index.html"; then
			# itch.io wants a zip with index.html at the ROOT, not inside a folder.
			( cd build/web && rm -f Avarice-web.zip && zip -q -r Avarice-web.zip . -x Avarice-web.zip ) \
				&& echo "    ok: build/web/Avarice-web.zip  (upload this to itch.io, tick 'This file will be played in the browser')"
		else
			rc=1
		fi
		;;&
	windows|mac|web|all) ;;
	*) echo "usage: tools/build.sh [windows|mac|web|all]" >&2; exit 2 ;;
esac

exit $rc
