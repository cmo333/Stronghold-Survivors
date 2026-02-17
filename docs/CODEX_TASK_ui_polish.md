# Codex Task: UI Polish & Announcements

## Context
Stronghold Survivors is a Godot 4.2 tower defense game. We're doing a polish pass for higher quality feel. These tasks are all UI/HUD additions that don't touch core gameplay logic.

**IMPORTANT**: All `create_tween()` calls MUST be guarded with `if not is_inside_tree(): return` before the call. All `await get_tree()` calls need pre and post guards. This was established in the previous async safety audit.

## Task 1: Wave Announcement System

Add dramatic text announcements for key game moments. Create in `scripts/ui.gd`.

### Requirements:
- Large centered text that fades in, holds, then fades out (total ~2.5s)
- Font: Use the existing `res://assets/ui/pixel_font.ttf`
- Announcements needed:

| Trigger | Text | Color | Size |
|---------|------|-------|------|
| Game start (after pick) | "SURVIVE" | White | 48px |
| Every 60 seconds | "1:00", "2:00", etc | White, 50% alpha | 32px |
| Boss spawn (5/10/15/20 min) | "BOSS INCOMING" | Red (#FF3333) | 48px |
| Bat swarm (2 min event) | "BAT SWARM!" | Purple (#AA44FF) | 44px |
| Plant wall (4 min event) | "PLAGUE WALL!" | Green (#44FF44) | 44px |
| Elite killed | "+1 ESSENCE" | Purple (#CC66FF) | 28px, at kill position not center |

### Implementation:
- Add `func show_announcement(text: String, color: Color, size: int, duration: float = 2.5, at_position: Vector2 = Vector2.ZERO)` to ui.gd
- If `at_position` is zero, center on screen. Otherwise, show at world position (for "+1 ESSENCE")
- Animation: scale from 0.5 to 1.0 + fade in (0.3s) → hold → fade out (0.5s)
- In `main.gd`, call announcements from the appropriate places:
  - `_ready()` after character selection → "SURVIVE"
  - Wave manager boss spawn events → "BOSS INCOMING"
  - Special wave events → "BAT SWARM!" / "PLAGUE WALL!"
  - Time milestones → time display
  - Enemy death with essence drop → "+1 ESSENCE" at death position

## Task 2: Damage Number Color Coding

Currently damage numbers exist but may not be color-coded well. Improve them in `main.gd`'s damage number spawning.

### Color Rules:
| Condition | Color | Scale Bonus |
|-----------|-------|-------------|
| Normal damage | White (#FFFFFF) | 0 |
| Fire/burn DOT | Orange (#FF6622) | 0 |
| Lightning | Cyan (#44DDFF) | 0 |
| Poison/acid | Green (#66FF44) | 0 |
| Critical hit | Hot pink (#FF2288) | +0.3 |
| Kill shot | Gold (#FFD700) | +0.2 |
| Elite kill | Purple (#CC66FF) | +0.5 |

The `spawn_damage_number` function in main.gd already receives `is_crit`, `is_kill`, `is_elite`, and `damage_type`. Use those parameters to set colors. The label color should be set via `label.modulate` or `label.add_theme_color_override("font_color", color)`.

## Task 3: Build Preview Range Circle

When placing a tower, show a translucent range circle so the player knows the tower's coverage.

### Requirements:
- In `build_preview.gd`, add a range circle (simple `draw_arc` or a Sprite2D with a ring texture)
- Color: Cyan (#00FFFF) at 15% alpha for valid placement, Red at 10% for blocked
- Circle radius = tower range from `data/structures.json`
- Only show for towers (arrow_turret, cannon_tower, tesla_tower), not walls/traps
- The range needs to come from the structure data. In build_manager.gd, when setting up the preview, pass the range value.
- Use `draw_arc()` in a custom `_draw()` override for the circle, call `queue_redraw()` when range changes.

## Task 4: Simple Minimap

Add a small minimap in the top-right corner showing dots for key entities.

### Requirements:
- Size: 140x140 pixels, semi-transparent dark background (Color(0.1, 0.1, 0.1, 0.6))
- Position: Top-right corner with 10px margin
- Create as a new scene/script: `scripts/minimap.gd` extending `Control`
- Add it as a child of the UI node in main.gd's `_ready()`

### Dot Colors:
| Entity | Color | Size |
|--------|-------|------|
| Player | White | 4px |
| Enemies | Red | 2px |
| Elite enemies | Yellow | 3px |
| Towers | Cyan | 3px |
| Resource generators | Green | 3px |
| Bosses | Magenta | 5px |
| Stronghold core | White | 5px (square) |

### Implementation:
- Override `_draw()` to render dots
- Call `queue_redraw()` every 0.2 seconds (use a timer, NOT every frame)
- Scale: Map world coordinates to minimap space. Use the camera bounds or a fixed world size.
- Show a border around the minimap (1px white line)
- Only render enemies within a reasonable radius of the player (to avoid iterating thousands)

## Files to Create:
- `scripts/minimap.gd` (new)

## Files to Modify:
- `scripts/ui.gd` — announcement system
- `scripts/main.gd` — trigger announcements, damage number colors
- `scripts/build_preview.gd` — range circle
- `scripts/build_manager.gd` — pass range data to preview

## DO NOT Modify:
- Tower scripts (tower.gd, arrow_turret.gd, cannon_tower.gd, tesla_tower.gd)
- fx_manager.gd, fx.gd
- Enemy scripts (already being modified by main dev)

## Commit Message:
`feat: UI polish - announcements, damage colors, range preview, minimap`
