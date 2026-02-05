# Stronghold Survivors Art Brief (Engine-Safe)

## Output Rules (Important)
- **Native pixel size**: export at true 1x resolution (no upscale).
- **Do not upscale** to 1024. If your tool forces upscale, include the **scale factor** in a note.
- **Transparent background** for sprites; tiles can be opaque.
- **No drop shadow** outside sprite bounds.
- **Nearest-neighbor** look; no anti-aliasing.

## Target Sizes (Native)
- Tiles: `32x32`
- Small units: `32x32`
- Medium units: `48x48`
- Large units: `64x64`
- FX: `16x16`, `32x32`, `64x64` depending on effect
- Buildings/towers: `2x2 tiles` = `64x64`
- Traps: `1x1 tile` = `32x32`

## Naming (keep consistent)
- `tile_<theme>_<name>_32_v###.png`
- `prop_<theme>_<name>_32_v###.png`
- `unit_<faction>_<name>_<size>_move_f###_v###.png`
- `tower_<name>_2x2_fire_f###_v###.png`
- `building_<name>_2x2_active_f###_v###.png`
- `trap_<name>_1x1_trigger_f###_v###.png`
- `fx_<name>_<size>_f###_v###.png`

## Style Targets
- Vampire Survivors / Halls of Torment aesthetic
- High contrast, readable silhouettes
- Clear value separation (foreground vs ground)

