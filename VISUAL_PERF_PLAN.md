# Visual + Performance Plan (v1)

## Objective
- Improve visual clarity, animation smoothness, and frame pacing while preserving maze-building identity.
- Execution spec for tower/FX production is in `docs/HYBRID_ANIMATION_FX_SPEC.md`.

## Platform Targets
- MacBook Air M-series: stable 60 FPS through minute 12, minimum 45 FPS at minute 20 stress.
- iPad-class target: stable 45+ FPS in standard runs.
- Keep input-to-action responsiveness under 80 ms during heavy waves.

## Phase 1: Readability Baseline
- Player readability:
- high-contrast player marker, stronger halo, local crowd occlusion around player.
- Build readability:
- placement ghost remains visible through swarm density.
- target ring + clearer blocked/valid feedback.
- Combat readability:
- reduce non-critical world labels in peak combat.
- strict z-order rules for player, projectiles, enemy bodies, and critical UI cues.

## Phase 2: Animation Smoothing Pass
- Standardize timing table:
- run, fire, hit, death, tower idle, tower fire, impact, pickup.
- move all primary combat loops to consistent frame cadence (8-dir actor sets, tower fire loops).
- add interpolation-safe transitions for abrupt state changes:
- move -> fire, idle -> death, target switch snaps.
- reduce animation hitch points:
- remove one-shot tween storms in high-frequency paths.
- precreate/reuse effect nodes for repeated flashes and small bursts.

## Phase 3: FX Budget + Performance Controls
- Define hard budgets:
- max active particles by tier (low/med/high intensity).
- max damage number emissions per second.
- max simultaneous additive-screen flashes.
- Introduce quality scaling profile:
- auto-downscale optional effects when frame average drops.
- prioritize gameplay-critical FX over cosmetic FX.
- Pool high-churn nodes:
- projectiles, lightweight impact flashes, shell casings, tiny burst particles.

## Phase 4: Terrain + Scene Cohesion
- Build 3 terrain presets with controlled variety:
- low-contrast base tiles + sparse accent tiles + decal pass.
- avoid high-contrast checker patterns that break path readability.
- enforce texture set compatibility by biome:
- only approved tile families can mix in one run.

## Phase 5: UX Scene Polish
- Pause/upgrade/chest moments become clean state transitions:
- deterministic slowdown or full hold.
- no damage leakage during modal states.
- stronger hierarchy for UI typography:
- key choices first, helper text second, flavor third.

## Validation Checklist
- Stress test at minute marks: 5, 10, 15, 20 with max-build maze density.
- Record average FPS + 1% lows for each pass.
- Compare readability snapshots:
- locate player in under 0.5 seconds in 10 randomized chaos frames.
- Balance validation:
- no single tech/chest line trivializes survival before intended spike windows.
