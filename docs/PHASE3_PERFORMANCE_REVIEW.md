# Phase 3 Performance Review

## Scope
This pass focused on late-wave stability and visual readability while preserving high-impact moments.

## Changes Shipped
1. Set-piece FX routing for rare events:
- `tower_evolution`
- `elite_death`
- `boss_death`
- `cannon_impact`
- `energy_impact`

2. Set-piece cooldown guards:
- Prevent repeated high-cost bursts from stacking in the same frame window.

3. Projectile cluster-bomb optimization:
- Removed per-cluster timer/await chains.
- Switched to synchronous secondary explosions and burn application.
- Eliminated freed-instance callback risk in delayed closures.

4. Damage-number perf gate:
- Under low adaptive perf scale, low-value non-critical spam is reduced.
- Crit/kill/elite numbers remain prioritized.

5. Elite aura particle throttling:
- Elite glow ambient particles now respect optional-FX gating.

6. Runtime quality UX:
- Pause menu now includes a one-click quality cycle button.
- Pause stats now display quality + live perf snapshot:
  - FPS
  - adaptive scale percent
  - FX/projectile caps
  - enemy/tower counts

## Why This Matters
- Keeps “hero moments” visible and punchy even when global FX density is reduced.
- Reduces mid/late-run frame spikes from timer-heavy explosion chains.
- Gives immediate in-run control over quality without opening nested menus.

## Validation Checklist
1. Run to `300s`:
- Verify evolution and elite death effects are noticeably stronger than baseline FX.

2. Run to `600s`:
- Build dense maze, trigger repeated cannon clusters.
- Confirm no callback/freed-instance errors.
- Confirm pause shows realistic perf counters.

3. Run to `900s`:
- Cycle quality `low -> medium -> high -> ultra` from pause.
- Confirm FPS and adaptive scale react, and gameplay remains stable.

## Next Perf Targets
1. Add adaptive enemy-cap taper at very low perf scale for post-600s stability.
2. Add optional “combat readability mode” preset:
- low non-essential FX
- high player/tower contrast
- preserved set-piece moments
3. Add lightweight in-game perf telemetry dump for balancing sessions.
