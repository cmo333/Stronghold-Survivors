# Tower Graphics Update Plan (v1)

## Outcome We Want
- Towers feel alive and readable under chaos.
- Motion feels smooth because each action has clear anticipation, impact, and recovery.
- Evolutions look like real transformations, not just tint swaps.

## My Recommendation
- Yes, add more movement, but not random movement.
- Use a consistent 8-state motion language across all towers, then give each tower a unique fire/evolution signature.
- Keep the base gameplay logic; replace visual layers and animation timing.

## Scope (Phase 1)
- In scope:
- Missile Turret (`arrow_turret`)
- Cannon Tower (`cannon_tower`)
- Tesla Tower (`tesla_tower`)
- Their tier transitions (T1 -> T2 -> T3)
- Their evolution variants:
- Missile: `gatling`, `sniper`
- Cannon: `hellfire`, `shockwave`
- Tesla: `storm_spire`, `arc_conduit`
- Out of scope for this pass:
- Trap visual overhaul
- Utility/wall building overhaul

## Motion Standard (8 States)
Each tower/evolution gets this same state set:
1. `idle_loop` (breathing + micro mechanical motion)
2. `acquire` (target lock anticipation)
3. `fire` (primary attack impact pose)
4. `recover` (settle back from fire)
5. `hit_react` (brief damage response)
6. `upgrade_infuse` (essence infusion motion)
7. `evolve_transform` (full transformation sequence)
8. `evolved_idle` (post-evolution sustained loop)

## Frame Targets (Per State)
- `idle_loop`: 6-8 frames
- `acquire`: 3-4 frames
- `fire`: 3-5 frames
- `recover`: 2-3 frames
- `hit_react`: 2 frames
- `upgrade_infuse`: 8-10 frames
- `evolve_transform`: 12-16 frames
- `evolved_idle`: 6-8 frames

## Art Package Structure
- Path:
- `assets/level1/towers/<tower_id>/<variant>/<state>/`
- Variant keys:
- `base_t1`, `base_t2`, `base_t3`
- `evo_gatling`, `evo_sniper`
- `evo_hellfire`, `evo_shockwave`
- `evo_storm_spire`, `evo_arc_conduit`
- Naming:
- `tower_<tower_id>_<variant>_<state>_f###_v001.png`

## Visual Identity by Tower
- Missile Turret:
- Mechanical tracking head motion, strong recoil snap, shell exhaust trails.
- Gatling evo: continuous barrel spin + heat shimmer.
- Sniper evo: charge glow + tight recoil + long muzzle beam pulse.
- Cannon Tower:
- Heavy weight shift, chassis compression on fire, smoke and ember linger.
- Hellfire evo: molten vents + persistent ember rhythm.
- Shockwave evo: radial pulse ring synced to each shot.
- Tesla Tower:
- Coil charge-up pulse, arcing electricity rhythm, orb oscillation.
- Storm Spire evo: sustained storm field sweep.
- Arc Conduit evo: chain burst cadence with pronounced post-hit crackle.

## Engine Wiring Plan
1. Add a lightweight tower visual state machine (`TowerVisualController`).
2. Split visuals into layers per tower scene:
- `Base`, `Head/Emitter`, `OverlayGlow`, `VFXAnchor`.
3. Drive state transitions from existing combat events:
- on target acquired
- on shot fired
- on damage taken
- on upgrade applied
- on evolve applied
4. Keep procedural FX support, but sync to animation key moments.
5. Add per-state fallback to existing static sprite if a frame set is missing.

## Evolution Upgrade Presentation
- Upgrade infusion (`U`) and evolution choice should both trigger dedicated animation sets.
- Evolution trigger sequence:
1. enter `upgrade_infuse`
2. lock tower fire briefly (short cinematic window)
3. play `evolve_transform`
4. transition to `evolved_idle`
5. burst set-piece FX + updated silhouette

## Performance Constraints
- Keep frame sizes constrained:
- towers: 48x48 or 64x64 max logical cell fit
- Avoid runtime-generated per-shot textures.
- Reuse cached `SpriteFrames` resources per tower variant/state.
- Hard cap concurrent optional evolution overlays by quality tier.
- Target:
- no new hitch during dense wave + rapid fire + multiple upgrades.

## Production Sequence
### Batch A (Foundation)
- Missile/Cannon/Tesla:
- `idle_loop`, `fire`, `recover`
- Integrate and validate smoothness + readability.

### Batch B (Tier Motion)
- T2/T3 visual variants + `upgrade_infuse`.
- Ensure tier differences are visible at glance in swarm conditions.

### Batch C (Evolution Motion)
- All 6 evolution variants:
- unique `evolve_transform`
- unique `evolved_idle`
- unique fire accent overlays.

### Batch D (Polish + Budget)
- Trim or simplify expensive frames.
- Tune FPS/state timings per tower cadence.
- Final readability/performance pass at 10m/15m/20m marks.

## Acceptance Criteria
- You can identify tower type + tier + evolution in <1s during live combat.
- Firing rhythm feels distinct between missile/cannon/tesla.
- Evolution always reads as a clear power spike visually.
- No noticeable stutter introduced by tower animation updates.

## Next Build Tasks
1. Implement `TowerVisualController` with state hooks only (no art dependency).
2. Convert one tower (Missile) to full 8-state pipeline as reference.
3. Validate in stress run, then apply same pattern to Cannon and Tesla.
