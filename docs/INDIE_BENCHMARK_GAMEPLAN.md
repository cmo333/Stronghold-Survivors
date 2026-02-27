# Indie Benchmark Gameplan

## Date
- Created: 2026-02-27

## Objective
- Raise moment-to-moment feel, visual readability, and UX quality to a level that can compete with top indie survivor titles while preserving Stronghold Survivors' maze-first identity.

## Benchmark Takeaways
- Vampire Survivors: extreme readability, fast pick loops, strong power cadence, minimal friction.
- Death Must Die: strong fantasy coherence, high-impact upgrade fantasy, clear progression identity.
- Soulstone Survivors: high spectacle and depth; community repeatedly flags visual clutter and performance pressure in later runs.

## Current State (Repo)
- Strong North Star and pillars are already explicit and aligned with a marketable hook.
- Pathing/maze foundations are functional but still sensitive in build-preview edge cases.
- UX is functional but fragmented (HUD, upgrade panel, pause/settings integration, readability controls).
- Visual language is mid-transition (theme and naming partially shifted, assets still mixed-era).
- Performance strategy exists (caps and some caching) but lacks a full quality ladder and profiling discipline.

## North Star Constraints for This Plan
- Keep maze rules deterministic and readable.
- Keep pixel art style.
- Player must stay visible in swarm density.
- Do not touch music implementation in this phase.

## Success Metrics (Vertical Slice)
- Frame pacing: no perceptible hitch on building placement on Apple Silicon laptops at 60 FPS target.
- Placement reliability: no false-invalid preview when placing adjacent towers on legal cells.
- Readability: player remains trackable in heavy combat without relying on pause.
- UX speed: level-up/upgrade decisions are readable and selectable in under 2 seconds average.
- Options trust: players can immediately reduce clutter/FX load from menu without restarting.

## Execution Plan

### Phase 1 - Stability and Clarity Baseline (1 week)
- Add lightweight profiling markers for build placement, flow rebuild, and heavy FX paths.
- Fix placement preview false negatives for adjacent tower placement and first-hover flicker.
- Unify and expose placement failure reasons in preview UI (blocked overlap vs path blocked vs cost).
- Add first-pass quality toggles wired to real behavior (FX density, trail density, shake intensity).

### Phase 2 - Combat Readability and Feel (1-2 weeks)
- Create a visual hierarchy pass: player > threats > tower fire lines > pickups > background.
- Standardize hit readability rules (impact flash, number budgets, color coding, fade timing).
- Reduce visual spam from overlapping secondary effects in high-density moments.
- Improve zone readability and silhouette contrast for movement and decision-making.

### Phase 3 - UI/UX System Pass (1-2 weeks)
- Replace current level-up screen style with a strong space-industrial panel language.
- Redesign upgrade cards for fast scan (icon, name, delta, rarity, one-line effect).
- Integrate pause/settings flow into main runtime path and verify all options are applied live.
- Add practical readability options: enemy outline toggle, projectile opacity slider, HUD scale.

### Phase 4 - Space Theme Visual Pivot (2-3 weeks)
- Build Mars terrain tileset set (regolith, basalt, seams, traversal readability variants).
- Replace resource zone circles with abyss-like, amorphous extraction field visuals.
- Complete missile turret visual identity (launcher silhouette, exhaust trail, impact signature).
- Refresh cannon visuals to industrial artillery style with stronger recoil/explosion readability.

### Phase 5 - Animation Standardization (parallel with phases 3-4)
- Move player animation target toward 8 directions x 8 frames (or staged migration with placeholders).
- Standardize enemy and tower animation timing for smoother cadence and consistent frame pacing.
- Enforce one shared animation timing table so idle/attack/fx loops feel coherent.

## Priority Fixes Before Broad Art Production
- Placement reliability and hitching around build preview.
- Settings system wiring and runtime options application.
- Upgrade UI information architecture and readability.

## Risks
- Large visual upgrades can regress readability if hierarchy is not enforced.
- More FX and longer animations can increase frame-time spikes if budgets are not hard-limited.
- Asset generation velocity can outpace integration quality without strict naming/versioning and review gates.

## Definition of Done for the First "Looks Good" Milestone
- A full 12-minute run on MacBook-class hardware with smooth placement, clear player visibility, and no major readability breakdown.
- Upgrade and settings UX feels deliberate and fast, not prototype-grade.
- Mars theme is immediately obvious from terrain, zones, and tower silhouettes.
