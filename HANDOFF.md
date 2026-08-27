# Session Handoff — Stronghold Survivors

> Working notes to resume work in a fresh session. Delete or update freely.

## Project
- **Game:** "Stronghold Survivors" — bullet-hell + tower-defense roguelite.
- **Engine:** Godot 4.2 (`4.2.stable`). Binary at
  `/Users/mycomputer/Downloads/Godot.app/Contents/MacOS/Godot`
  (the old `/opt/homebrew/bin/godot` path is GONE — that brew install is no
  longer present). NOTE: this shell mangles `VAR="path" && "$VAR"` assignments —
  always invoke the binary via its literal quoted path. There is also no
  `timeout`/`gtimeout` here; background a process with `&`, `sleep`, then `kill <pid>`.
- **Path:** `/Users/mycomputer/Documents/New project/projects/stronghold-survivors`
- **Git branch:** `codex/progression-overhaul-v1` (lots of uncommitted work).

## Current direction (user's words)
"Push toward greater clarity, fun, and power fantasy." Desktop/web only for now (no touch
UI). A **friend will play with a gamepad** — controller support is the active thread.

---

## ⚠️ PENDING — DO FIRST IF USER WANTS AN UPLOAD
**The itch zip is STALE.** `build/stronghold-survivors-web.zip` predates ALL of the latest
session's changes (custom cursor + controller-movement fixes). Re-export + rezip before any
new itch upload:
```bash
# 1. Re-export web build (success marker: a line containing `savepack: end`;
#    ignore RID/ObjectDB "leaked at exit" noise from headless shutdown).
/opt/homebrew/bin/godot --headless --export-release "Web" build/web/index.html
# 2. Rebuild the itch zip — index.html MUST be at the archive ROOT.
cd build/web && rm -f ../stronghold-survivors-web.zip \
  && zip -r -X ../stronghold-survivors-web.zip . -x "*.import" "*.DS_Store"
```
Output: `build/stronghold-survivors-web.zip` (~120 MB). itch upload: mark "played in the
browser", keep **SharedArrayBuffer support** toggle ON (fixes Cross-Origin-Isolation error).
Click once in-page before expecting sound; press a controller button once for the pad to
register on web.

---

## Latest session — work completed (all headless import + boot CLEAN, NOT yet committed, NOT yet exported)

### A. Custom mouse cursor (the ornate arrowhead/shield emblem)
- **Asset:** `assets/ui/cursor_arrowhead_48_v001.png` (note: filename says 48 but it's now
  **55×55** — kept the path stable so wiring/import didn't change). Built from the user's
  PNG (`~/Downloads/ChatGPT Image Jun 22, 2026, 08_02_47 PM.png`).
  - The source had a **solid light-gray background** (NOT transparent despite the checkered
    look). Removed it via an **edge flood-fill** of bright/low-saturation pixels (preserves
    the metal highlights inside the emblem), auto-cropped, then resized.
  - 15% larger than the first 48px pass → 55px, with a **soft dark outline halo** (dilated
    alpha → near-black ring) so it reads on bright AND dark backgrounds.
  - To regenerate: the cleaned full-res emblem is cached at `/tmp/cursor_full.png` (may be
    gone in a fresh session — re-run the flood-fill from the Downloads PNG if so). PIL 11.3
    is available at `/usr/bin/python3`.
- **Wiring:** `scripts/settings_manager.gd` (autoload) —
  - `apply_custom_cursor()` (renamed from `_apply_custom_cursor`, now PUBLIC) loads the
    texture and calls `Input.set_custom_mouse_cursor(tex, shape, CURSOR_HOTSPOT)` for **all
    cursor shapes** (ARROW, POINTING_HAND, IBEAM, CROSS, BUSY, DRAG, CAN_DROP, MOVE, HELP).
  - `CURSOR_HOTSPOT = Vector2(8, 2)` (arrowhead tip).
  - Called from `_ready()` at boot.
- **In-game fix:** cursor previously showed on the menu but NOT in gameplay because the
  scene change dropped the boot-time cursor. `scripts/main.gd::_ready()` (~line 1599) now
  RE-ASSERTS it: `_settings_manager.apply_custom_cursor()`. Applying to all shapes also
  prevents falling back to the OS cursor over buttons.
- Headless boot prints `WARNING: Custom cursor shape not supported by this display server`
  — that's HEADLESS-ONLY (no display). It does NOT appear on desktop/web. Harmless.

### B. Controller movement fixes (friend "couldn't move around very well")
Root causes found in `scripts/main.gd::_ensure_input_map()`:
1. **Deadzone too high** — left stick `move_*` was `0.3` (classic "stick feels dead").
   Lowered to **0.2** (also matches the project.godot defaults).
2. **D-pad double-bound** — the d-pad drove BOTH `move_*` AND `build_cursor_*` at once.
   Removed the d-pad from `build_cursor_*`; now **d-pad = always move the player**, and the
   **right stick alone** drives the build cursor. (move_* still has d-pad as a fallback.)
- Files touched: `scripts/main.gd` (lines ~5088-5091 move_*, ~5126-5135 build_cursor_*).

---

## Controller support — full reference (implemented in a PRIOR part of this thread)
Combat is already mouse-free (player auto-aims + auto-fires at nearest enemy in
`player.gd::_physics_process`). Only build PLACEMENT needed a mouse alternative → a virtual
cursor. All gamepad bindings live IN CODE via the runtime input registry
(`main.gd::_ensure_input_map()` + `_ensure_action(name, keys, buttons=[], axes=[], deadzone=-1.0)`),
NOT in project.godot (which stays keyboard-only to avoid brittle serialization).

**Mapping (Xbox/SDL layout, additive to keyboard/mouse):**
- Left stick / d-pad → move (`move_*`).
- Right stick → build cursor (`build_cursor_*`, gamepad-only).
- A → `start_game` / `interact` / `build_place` (confirm/place).
- B → `cancel`. Start → `pause`. Back/Select → `sell`.
- Y → `build_toggle`. X → `upgrade`. LB/RB → `build_prev`/`build_next` (cycle structures).
- Triggers → `zoom_out`/`zoom_in` (UNRELIABLE on web — zoom also stays on `-`/`+` keys).

**Virtual build cursor** (`scripts/build_manager.gd`):
- `_using_gamepad` flips in `_unhandled_input` (Mouse event → false, Joypad event → true).
- `_get_build_world_position()` returns `_virtual_cursor` when gamepad, else mouse pos.
- `_update_virtual_cursor(delta)` seeds at player pos, moves by right-stick * 520 px/s,
  clamps via `game.clamp_to_play_area`. Called in `_process`.
- `_cycle_build_selection(step)` cycles unlocked builds (`BUILD_CYCLE_ORDER`).
- Evolution panel gamepad path: A = option 1, X = option 2 (`build_manager.gd` ~line 107).
- `build_place` (just_pressed) → `_try_place()`/`_try_select()`.

**Menus** (`scripts/main_menu.gd`): `_focus_first_button()` + `call_deferred` in each panel
builder so d-pad/stick can navigate (Godot Buttons are navigable once one has focus).
`pause_menu.gd` already grab_focus's its resume button — no change needed.

**NOT updated:** `build_manager.gd::_controls_text()` (line ~983) still shows keyboard-only
hints ("LMB: place/select | ..."). Candidate to add a gamepad hint line if desired.

---

## Headless verification (do this after ANY script change)
```bash
/opt/homebrew/bin/godot --headless --editor --quit-after 200    # import (catches parse errors)
/opt/homebrew/bin/godot --headless --quit-after 220             # boot (authoritative; loads autoloads)
```
NOTE: `--check-only --script X.gd` gives FALSE positives ("AudioManager not found") because
autoloads aren't registered for a single-script check. The full boot is the real check.

## Commit / git state
- Earlier session's gameplay fixes are committed: **`bbcf247`** "fix: web audio init, maze
  line-of-sight, per-hit combat feedback". Nothing pushed to a remote.
- EVERYTHING from the controller + cursor work is UNCOMMITTED. Git identity is EMPTY (local
  + global). `bbcf247` used an inline neutral author (`Stronghold Dev <dev@localhost>`)
  WITHOUT changing git config — do NOT set git config unless the user asks.
- Recommended cleanup: add `.gitignore` for `build/`, `output/`, `.godot/`, then commit
  source deliberately. ONLY commit when the user explicitly asks.

## Key file map
- `scripts/settings_manager.gd` — autoload; `apply_custom_cursor()` (public), all settings.
- `scripts/main.gd` — game controller; `_ready()` re-asserts cursor; `_ensure_input_map()` /
  `_ensure_action()` = the runtime input registry (gamepad bindings live here).
- `scripts/build_manager.gd` — build placement, virtual gamepad cursor, evolution panel.
- `scripts/player.gd` — player: movement (`move_*`), auto-aim/auto-fire (mouse-free combat).
- `scripts/main_menu.gd` — main menu; controller focus via `_focus_first_button()`.
- `scripts/pause_menu.gd` — pause; already controller-ready.
- `scripts/constants.gd` — `GameLayers` (PLAYER=1, ENEMY=2, BUILDING=4, PROJECTILE=8,
  PICKUP=16, ALLY=32).
- `scripts/feedback_config.gd` — juice/feel tunables (flash, knockback).
- `scripts/audio_manager.gd` — autoload; SFX pool, buses, `_any_audio_exists` gate.
- `scenes/main.tscn` — root game scene. `scenes/main_menu.tscn` — menu.
- `export_presets.cfg` — Web preset.

## Important rules / gotchas
- Only commit when the user explicitly asks.
- Don't add music/sound assets unless asked.
- After ANY script edit, run headless import + boot to verify.
- Re-export + rezip whenever the user wants an updated itch upload (currently STALE — see top).
- Keyboard/mouse must stay fully intact; gamepad + custom cursor are purely additive.
