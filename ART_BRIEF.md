# Stronghold Survivors Art Brief (Engine-Safe, Style Pivot v2)

## Output Rules (Important)
- **Native pixel size**: export at true 1x resolution (no upscale baked into final game assets).
- If generation tools output larger images, downscale to target native size before import.
- **Transparent background** for sprites and FX; tiles can be opaque.
- **No external drop shadows** outside sprite bounds.
- **Nearest-neighbor** look with controlled subpixel noise only where intentional.

## Style Direction (Locked)
- Blend target:
- **Halls of Torment** contrast + gritty detail density
- **Warcraft 3 TD** chunky tower silhouette language
- **StarCraft 1** industrial sci-fi forms and readable emissive accents
- Theme pivot:
- Space-conquest combat engineer fantasy
- Mars/alien frontier ground with industrial defense network

## Fidelity Targets (Native)
- Terrain tiles: `32x32` base set + optional `32x32` detail decals/overlays.
- Props: `32x32` / `48x48`.
- Small enemies: `32x32`.
- Elite enemies: `48x48`.
- Bosses: `64x64` to `96x96` (sparingly).
- Player: `32x32` now, planned move toward denser detail pass while preserving readability.
- Core towers: `64x64` bodies (2x2 footprint), with optional overlay layers up to `96x96` for evolved effects only.
- Traps: `32x32`.
- Hero FX: `32x32` / `64x64`, rare set-piece `96x96` if perf-safe.

## Tower Animation Package (Required)
- States:
- `idle_loop`, `acquire`, `fire`, `recover`, `hit_react`, `upgrade_infuse`, `evolve_transform`, `evolved_idle`
- Frame ranges:
- regular states `3-8` frames
- evolve transform `12-16` frames
- Evolved towers must have:
- new silhouette treatment
- new idle rhythm
- new fire accent language

## Naming (keep consistent)
- `tile_<theme>_<name>_32_v###.png`
- `prop_<theme>_<name>_<size>_v###.png`
- `unit_<faction>_<name>_<size>_<state>_f###_v###.png`
- `tower_<tower_id>_<variant>_<state>_f###_v###.png`
- `building_<name>_2x2_active_f###_v###.png`
- `trap_<name>_1x1_trigger_f###_v###.png`
- `fx_<name>_<size>_f###_v###.png`

## Readability Rules
- Silhouette first, detail second.
- Ground values must stay lower contrast than combat actors.
- Player and build preview must remain visible in dense swarms.
- Avoid texture noise that competes with bullets/projectiles/health cues.
