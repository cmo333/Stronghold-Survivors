# Removed Buildings (config-only removal)

These structures were removed from the **buildable set** so the player only has the five they
actually use: **Arrow Turret, Cannon Tower, Tesla Tower, Resource Generator, Shrine (Stargate)**.

The removal is **config-only** — every removed building keeps its script, scene, and
`data/structures.json` definition intact. They are simply no longer offered in the build palette,
hotkeys, core-build list, or level-up tech picks. Re-adding any of them is a small, reversible edit
(see "How to re-add" at the bottom). The intent is to bring them back later in a more useful form,
possibly tied to meta-progression.

Removed on branch `codex/progression-overhaul-v1`.

---

## What was removed and what each did

### Traps (one-shot / aura placeables, `type: "trap"`, do NOT block pathing)

**Mine Trap** (`mine_trap`) — `scripts/mine_trap.gd`, `scenes/buildings/mine_trap.tscn`
- One-shot proximity mine. Arms on placement; when an enemy enters `trigger_radius`, after a ~0.12s
  delay it calls `game.damage_enemies_in_radius()` over `explosion_radius` then `queue_free()`s.
- T1: cost 12, trigger_radius 22, damage 30, explosion_radius 70.
- T2: cost 18, trigger_radius 24, damage 40, explosion_radius 85.
- Purpose served: cheap burst AoE for chokepoints; single-use.

**Ice Trap** (`ice_trap`) — `scripts/ice_trap.gd`, `scenes/buildings/ice_trap.tscn`
- Persistent slow-field aura (does NOT auto-destruct). Applies a slow debuff to enemies inside
  `field_radius` (on body_entered), removes it on body_exited. Stackable.
- T1: cost 16, health 20, field_radius 70, slow_factor 0.55.
- T2: cost 24, health 30, field_radius 90, slow_factor 0.45.
- Purpose served: area crowd-control / swarm slowing; the only persistent trap.

**Acid Burst** (`acid_trap`) — `scripts/acid_trap.gd`, `scenes/buildings/acid_trap.tscn`
- One-shot proximity burst with anti-siege bonus. On trigger (~0.12s delay) calls
  `damage_enemies_in_radius()` with an `acid` damage type and `siege_bonus` multiplier vs siege units,
  then frees itself.
- T1: cost 20, trigger_radius 24, damage 22, explosion_radius 80, siege_bonus 2.0.
- T2: cost 28, trigger_radius 26, damage 30, explosion_radius 95, siege_bonus 2.3.
- Purpose served: counter to heavy/siege enemies.

**Spike Trap** (`spike_trap`) — `scripts/spike_trap.gd`, `scenes/buildings/spike_trap.tscn`
- One-shot pulse trap with a brief stun. On trigger (~0.08s delay) deals `damage` in `pulse_radius`,
  applies `stun_duration`, then frees itself.
- T1: cost 14, trigger_radius 24, damage 20, pulse_radius 56, stun_duration 0.25.
- T2: cost 22, trigger_radius 28, damage 30, pulse_radius 72, stun_duration 0.4.
- Purpose served: cheap damage + micro-stun for chokes. (Was never wired into the palette/hotkeys; only
  present in `CORE_BUILD_IDS`. Now removed from that list.)

### Extra active towers (`type: "tower"`, BLOCK pathing) — were never used by the player

**Spike Burst Tower** (`spike_burst_tower`) — `scripts/spike_burst_tower.gd`,
`scenes/buildings/spike_burst_tower.tscn`
- Active tower firing `burst_count` projectiles in a radial pattern. Evolutions: `razorstorm`,
  `frostburst` (frostburst projectiles apply slow).
- T1: cost 32, range 162, fire_rate 0.72, damage 7, burst_count 8.
- T3: cost 104, range 190, fire_rate 0.95, damage 12, burst_count 12, pierce 1.
- Note: used the `ui_build_ice_trap` icon (icon mismatch).

**Flamethrower Tower** (`flamethrower_tower`) — `scripts/flamethrower_tower.gd`,
`scenes/buildings/flamethrower_tower.tscn`
- Active tower firing a cone of flame; applies damage + slow to targets in `flame_cone_deg` /
  `flame_length`, capped at `max_targets`. Evolutions: `long_range`, `ice_flame`.
- T1: cost 34, range 170, fire_rate 4.8, damage 5, flame_length 142, cone 52°, max_targets 8.
- T3: cost 112, range 196, fire_rate 6.4, damage 7, flame_length 186, cone 48°, max_targets 12.
- Note: used the `ui_build_acid_trap` icon (icon mismatch).

### Utility buildings — were unlock-gated, never built by the player

**Barracks** (`barracks`) — "Train allied fighters to help defend."
**Tech Lab** (`tech_lab`) — "Boost tower fire rate globally."
**Armory** (`armory`) — "Boost your gun damage."
- These were only reachable via level-up "Unlock: …" tech picks, which are now removed. Their building
  scripts/scenes and `structures.json` defs remain intact. (The buff logic, if any, lives in the
  building scripts and is only active when the building is built.)

---

## Exactly what changed (touch points)

1. `scripts/ui.gd` — `PALETTE_ORDER` trimmed to the 5 kept buildings (hotkeys 1–5).
2. `scripts/build_manager.gd`
   - `BUILD_BINDINGS` trimmed to the 5 kept buildings (hotkeys `build_1`–`build_5`, plus `build_shrine`).
   - `RANGE_PREVIEW_IDS` trimmed to `arrow_turret, cannon_tower, tesla_tower`.
3. `scripts/main.gd`
   - `CORE_BUILD_IDS` trimmed to the 5 kept buildings (so all 5 are unlocked at start via
     `_unlock_core_builds()`).
   - All nine `"unlock_*"` build-unlock tech picks removed from the tech definitions
     (`unlock_cannon/tesla/shrine` were redundant once the 5 are unlocked at start;
     `unlock_mine/ice_trap/acid_trap/barracks/tech_lab/armory` referenced removed buildings).
   - `_check_level_unlocks()` (level-5 resource_generator auto-unlock) is now a no-op since
     resource_generator starts unlocked — left in place, harmless.
4. `scripts/quick_actions.gd` — fallback `default_costs` trimmed to the 5 kept buildings.

Nothing else in the codebase references these building/tech ids, so removal is purely data-driven.
Scene files (`scenes/buildings/*.tscn`), scripts (`scripts/*_trap.gd`, `flamethrower_tower.gd`,
`spike_burst_tower.gd`), `structures.json` defs, and build icons (`assets/ui_build_icons/*`) are all
untouched.

---

## How to re-add a building

1. **Buildable now:** add its id back to `CORE_BUILD_IDS` (`scripts/main.gd`) → it becomes unlocked at
   start. Or re-add a `"unlock_<id>"` tech pick (with `"unlock_build": "<id>"`) to gate it behind a
   level-up choice instead.
2. **Palette + hotkey:** add `{"id": "<id>", "key": "<n>"}` to `PALETTE_ORDER` (`scripts/ui.gd`) and a
   matching `"build_<n>": "<id>"` entry in `BUILD_BINDINGS` (`scripts/build_manager.gd`).
3. **Range ring** (towers only): add the id to `RANGE_PREVIEW_IDS` (`scripts/build_manager.gd`).
4. **Refund fallback (optional):** add the id to `default_costs` in `scripts/quick_actions.gd`.
5. The script, scene, `structures.json` def, and icon already exist, so no asset work is needed.

### Meta-progression idea (future)
Re-introduce these as meta-progression unlocks: gate `mine_trap`/`ice_trap`/`acid_trap`/`spike_trap`
and the extra towers behind Cores spent in the main-menu meta tree
(`scripts/meta_progression.gd`), rather than per-run tech picks — so they become persistent account
unlocks that then appear in `unlocked_builds` / the palette when owned.
