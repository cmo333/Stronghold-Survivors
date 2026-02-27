# Visual Pivot Plan: Mars Surface + Smoother Animation

## Goal
Shift `Stronghold Survivors` from graveyard fantasy visuals toward a space-extraction/Mars surface theme while preserving the current gameplay feel and newly working pathing.

## Non-Negotiables
- Do not break pathing or placement readability.
- Do not change tower/mechanics behavior during visual swaps unless explicitly requested.
- Internal IDs can stay stable (for example `arrow_turret`) while player-facing labels/art change.
- Music is intentionally out of scope for this pass.

## Immediate Visual Direction
- **Theme**: hostile Mars regolith, industrial extraction hardware, emergency field-fortification vibe.
- **Palette**:
- `dust`: rust red / burnt orange / umber
- `rock`: dark basalt / charcoal
- `tech`: desaturated steel / gunmetal
- `accent`: cyan or amber UI energy highlights (rarity and interactables)
- **Readability rule**: paths and blockers must remain distinguishable at swarm density.

## First Production Pass (Recommended Order)
1. **Terrain replacement kit (Mars)**
   - Replace base grass/graveyard tiles with regolith + basalt + path transitions.
   - Keep path silhouettes high-contrast for enemy routing readability.
2. **Tower reskin pass**
   - `arrow_turret` becomes player-facing **Missile Turret**.
   - Cannon Tower shifts to heavy space-industrial artillery visuals.
   - Preserve footprints, firing timings, and targeting.
3. **Upgrade/build UI style pass**
   - Reskin panels to match extraction-combat-engineer fantasy.
   - Keep button hierarchy and readability under combat pressure.
4. **Animation smoothing pass**
   - Standardize loop timing and remove stepped pulses.
   - Add more continuous motion to idle/active tower states.

## Tower-Specific Notes

## Missile Turret (current `arrow_turret` mechanics)
- Keep current gameplay role (fast projectile tower) initially.
- Visual swap targets:
- Arrow/bolt visuals -> micro-missiles or darts with exhaust streaks.
- Floating arrow motifs -> missile rack / targeting fins / gyros.
- T3 effects -> targeting lights, exhaust glow, lock-on sweep.
- Future option (later): retune projectile FX/audio after art pass is stable.

## Cannon Tower
- Keep projectile arc/explosion gameplay role.
- Visual swap targets:
- Barrel casing and mount read as heavy industrial artillery.
- T2/T3 upgrade visuals feel mechanical/pressurized rather than magical runes.
- Smoke/vents can become exhaust/heat shimmer/dust kick.

## Upgrade Screen Direction (Inspired by User Reference)
- Strong central panel with obvious title and 3 clear choices.
- High-contrast rarity/readability first; style second.
- Space-extraction flavor ideas:
- "FIELD UPGRADE" / "SALVAGE PICK" framing
- utilitarian metal frames, warning stripes, signal lights
- rarity accents and icon framing that pop over battlefield background
- Keep interaction count low and obvious during active runs.

## Technical Notes (Current Repo Hooks)
- Upgrade toast popup is built in `scripts/ui.gd` (`show_upgrade_popup`).
- Build/tower names are sourced from `data/structures.json`.
- Tower procedural upgrade visuals live in `scripts/arrow_turret.gd` and `scripts/cannon_tower.gd`.
- Existing terrain/art asset pipeline already uses 32x32 tiles and versioned filenames.

## Done This Pass
- Smoothed tower pulse animations using continuous time (arrow + cannon procedural visuals).
- Renamed `arrow_turret` player-facing label to `Missile Turret` (internal ID unchanged).
