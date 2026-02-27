# Progression + Essence Overhaul Plan (v1)

## Snapshot Safety
- Baseline checkpoint branch: `codex/snapshot-20260226-171050`
- Baseline checkpoint tag: `snapshot-pre-overhaul-20260226-171050`
- Active implementation branch: `codex/progression-overhaul-v1`
- Rollback command:
`git switch codex/snapshot-20260226-171050`

## North Objectives
- Make level-up choices the primary source of power and discovery.
- Preserve maze-first gameplay by reducing in-combat tower micromanagement.
- Make rare outcomes feel dramatic and visible.
- Keep `Essence` as high-agency run currency.
- Ensure every reward moment changes behavior immediately.

## Core Decisions (Locked for v1)
- All core towers unlocked at run start.
- Most progression moved into level-up draft cards.
- Per-tower upgrades reduced to one specialization breakpoint per tower.
- Elite/boss chest flow reworked into deliberate choice moments.
- Add explicit life pickup drops (separate from XP crystals) with controlled rarity.

## Experience Targets
- Run length target: `20-25m`.
- Meaningful draft choices per run: `20-24`.
- Guaranteed `Rare+` momentum and late-run `Legendary/Mythic` spikes via pity logic.
- At least one strong "build-defining" combo by mid-run in successful runs.

## System Spec Summary

### 1) Draft System
- 3 options per level-up.
- Mixed offer categories: `Tower`, `Engineer`, `Economy/Zone`.
- No dead-screen rule: at least one behavior-changing option every draft.
- Tag-driven synergy and hidden breakthrough recipes.
- Rarity + pity logic to prevent flat runs.

### 2) Essence Agency Layer
- Essence sources: elites/boss/chests + specific economy picks.
- Essence spends in level-up:
- reroll offer
- lock option for next draft
- infuse selected card
- force category slot
- trigger ready breakthrough
- Essence spends in chest:
- refine rarity
- convert chest archetype

### 3) Chest Rework
- Chests become 3-option reward picks (not passive one-roll outcomes).
- Chest archetypes:
- Combat Chest (mostly character)
- Engineer Cache (tower/maze influence)
- Relic Vault (run-defining)
- Elites get pity-backed chest chance so elite kills keep tension/reward loop alive.

### 4) Life Drop Loop
- Distinct heal pickup art/VFX separate from XP currency.
- Low base drop from normal enemies.
- Missing-health scaling increases clutch survivability without trivializing danger.
- Elite and boss kills have higher heal reliability.

### 5) Readability + Reward Feedback
- Rare tiers get unique card frame/VFX language.
- Breakthrough unlocks use explicit reveal moment.
- All nonessential battlefield overlays hidden during draft screens.
- Upgrade moments must be high-contrast and readable at a glance.

## Implementation Phases

## Phase A: Foundation
- Build data model for tags, rarity tiers, pity counters, and breakthrough conditions.
- Add deterministic debug hooks for reward simulation.
- Add telemetry counters:
- rarity distribution per run
- dead-screen count
- breakthrough frequency/time
- chest quality spread

## Phase B: Draft Overhaul
- Replace current unlock-oriented tech offers with category/tag-driven card pool.
- Implement offer generation constraints + pity.
- Implement immediate behavior-impact validation per card.
- Integrate draft presentation polish and readability standards.

## Phase C: Essence Integration
- Add Essence actions to draft and chest flows.
- Add UX affordances and affordability feedback.
- Tune costs and escalate reroll pricing.

## Phase D: Chest + Elite Reward Rework
- Replace single-result chest with 3-option reward selection.
- Add chest archetypes and rarity floors.
- Hook elite kill pipeline to chest pity rules.

## Phase E: Tower Upgrade Simplification
- Remove repetitive in-combat tower micro-upgrade loop.
- Keep one specialization breakpoint per tower family.
- Ensure specialization visuals/behavior are immediate and obvious.

## Phase F: Healing + Sustain Loop
- Add heal pickup spawn table and health-scaling chance.
- Add elite/boss heal guarantees/chances.
- Tune so clutch recovery exists but late-game tension remains high.

## Balancing Guardrails
- Avoid small passive-only picks unless bundled with behavior change.
- If a reward cannot be felt within 5-10 seconds, redesign or remove it.
- Keep economic power from out-scaling combat readability.
- Keep failure reasons legible: player should lose from decisions, not noise.

## QA Checklist
- Can player identify top 3 active powers quickly from pause.
- No draft screen appears with 3 low-impact options.
- At least one major spike moment occurs in target run length.
- Chest rewards feel materially different across archetypes.
- Performance remains stable during high-VFX rare states.

## Open Design Items (Need Final Decision)
- Exact core tower list visible at start (and hotkey order).
- Number of breakthrough recipes to ship in first pass (`8`, `12`, or `16`).
- Rarity weight table final values by level band.
- Essence spend cost curve final values after telemetry pass.
