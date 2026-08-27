# Hybrid Animation + FX Spec (v1)

## Goal
Ship smoother, clearer combat without relying on fragile full AI-video sprite sheets.

## Core Method
Use a hybrid pipeline:
- Tower animation: deterministic in-engine motion beats (idle, fire, recoil, charge, evolve).
- FX: mostly procedural (`GPUParticles2D`, lines, shader pulses, compact flipbooks).
- AI generation: concept frames and occasional special effects only, then pixel-clean + palette lock.

This keeps style consistent, avoids flicker, and performs better under heavy swarm load.

## Runtime Targets
- 60 FPS target through minute 10 on MacBook-class hardware.
- 45+ FPS at high build density after minute 10.
- No frame hitch on tower fire/upgrade loops from per-shot tween bursts.

## Tower Animation Spec
All tower gameplay states support 8 directional actor readability for moving units; towers use fixed-angle base + state pulses.

### Shared States (all towers)
- `idle`: breathing/bob motion, low amplitude.
- `acquire`: subtle tension/lean toward target.
- `fire`: recoil punch + brief flash.
- `cooldown`: settle back to idle.
- `hit`: quick desat/flash.
- `upgrade`: charge, pop, glow burst.
- `evolve`: longer transformation burst.
- `destroyed`: collapse + debris FX.

### Motion Budgets
- Idle bob amplitude: `~1-2 px` world-space equivalent.
- Fire kick duration: `80-140 ms`.
- Upgrade pop total: `450-700 ms`.
- Avoid spawning more than one new tween per fire event.

### Tower-Specific Beats
- Missile Turret: fast recoil cadence, optional spin-up feel on evolved mode.
- Cannon Tower: heavier recoil and settle, lower cadence, stronger muzzle impulse.
- Tesla Tower: light recoil, electric pulse/arc emphasis, line FX with short fade.

## FX Spec
### Procedural First
- Keep repeated combat FX procedural:
  - trails
  - impact sparks
  - shock rings
  - EMP arcs
  - tower charge glows
- Use compact sprite flipbooks only for hero impacts (explosion, elite death burst).

### FX Performance Rules
- Hard cap active particles by quality scale.
- Skip optional FX when adaptive perf scale drops.
- Prefer additive overlays with tiny textures over large full-screen effects.

## Damage Number Policy
- Numeric value is always text-rendered for correctness.
- Pattern/style overlays are optional and must never replace actual value.
- If style texture fails, fallback is clean outlined text.

## Asset Naming + Layout
- `assets/level1/towers/<tower_id>/<state>/...`
- `assets/level1/fx/<fx_type>/...`
- Naming:
  - `<category>_<id>_<state>_f###_v###.png`
  - Example: `tower_missile_fire_f003_v001.png`

## 4090 Windows Pipeline (Content Authoring)
Use local GPU for offline content prep:
1. Generate concept frame(s) or short motion source.
2. Extract alpha with BiRefNet (HR variant).
3. Generate luma-alpha mask.
4. Merge alpha as `max(biref_alpha, luma_alpha)`.
5. Downscale + palette-lock to Stronghold style.
6. Export PNG sequences + sprite sheets.

Operational script + usage are documented in `docs/WIN4090_AI_FX_PIPELINE.md`.

Use this path for:
- hero one-off FX
- rare evolution transformation effects
- biome set-piece events

Do not use it for high-frequency core combat loops by default.

## Implementation Milestones
### Phase 1 (now)
- Add deterministic shared tower motion hooks.
- Improve player visibility under swarm density.
- Improve build-preview legibility in combat clutter.

### Phase 2
- Migrate repeated tower shot FX to shared procedural emitters.
- Add quality tier presets (`low`, `mid`, `high`) with explicit caps.

### Phase 3
- Add first curated AI-assisted FX batch (explosion/energy variants).
- Validate palette/style consistency against in-game baseline.

## Acceptance Checklist
- Towers feel responsive without per-shot hitching.
- Player remains findable in <0.5s in dense combat screenshots.
- Build preview remains visible when enemies overlap placement area.
- Frame pacing remains stable with large mazes and active FX.
