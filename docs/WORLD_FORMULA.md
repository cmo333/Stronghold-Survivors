# The world formula — one climate space for everything

How procedural worlds compose, who walks in them, and why the boss never
belongs. The data lives in `data/rift.json`; the code is
`RunManifest.climate_compatible()`; the proofs are `tools/manifest_test.sh`
(the table and the roll) and `tools/rift_run_test.sh` (the run consuming it).

## The rule

Every biome, enemy and boss occupies a **range** on four axes, each 0..3:

| axis | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| `heat` | frozen | cool | warm | molten |
| `light` | abyssal | dim | lit | radiant |
| `wet` | arid | damp | soaked | submerged |
| `depth` | sky/orbit | surface | underground | abyss |

**Two things are compatible iff their ranges overlap on every axis.** That is
the entire formula. No mixing matrix, no special cases: lava `heat:[3,3]` and
forest `heat:[1,2]` share no value, so they can never mix, while caves span
`heat:[1,3]` — underground is insulated — so icy caves, forest caves and lava
caves all fall out of the same interval test.

A range is *capability*, not appearance: lava spans `depth:[1,2]` because
magma lives on the surface and in tubes. Where a biome *presents* for art
purposes is pinned separately in `tools/art/rift_biome_prompts.py`.

## What the space decides

- **Regions compose as primary + accents.** The primary must be `wired`
  (real terrain art — a `LEVEL_TERRAIN` key in `ground.gd`) and carries the
  run. 0–2 accents roll from the biomes compatible with it; accents may be
  unwired scaffolds, because today they are flavor and tomorrow they are
  sub-areas.
- **The regular roster is derived, not rolled**: exactly the enemies whose
  range overlaps the primary. The world decides who belongs in it. On the
  graveyard that is all twelve; on the salvage deck it is the husk mass plus
  the two ghosts — a dead ship, haunted, and the first time composition
  changed gameplay.
- **Bosses invert the rule.** The rolled boss comes from the *incompatible*
  set — the thing the world could not have produced, which is why it sticks
  out. The lich (frozen, deep) intrudes on a warm surface; the siegebreaker
  (forge-dry) intrudes anywhere damp. If every boss is native the roll falls
  back to the full set rather than rolling nothing.

## Growth promised by the user's design, in this order

lava × {caves} only; forest × {ocean, caves, light}; light × {forest};
salvage deck × nothing organic. These are locked as assertions in
`manifest_test.gd::_check_formula` — retune the axes all you like, but if a
locked truth flips, the design broke, whatever the numbers say.

## Adding a biome

1. Add the entry to `biomes` in `data/rift.json` with axes and `wired: false`.
2. Add its kit (terrain slot meanings, props, presentation depth) to
   `tools/art/rift_biome_prompts.py`, run it, read the brief.
3. Generate art (`tools/art/rift_generate.py <id>`, needs `OPENAI_API_KEY`) —
   output lands in `assets/gen/<id>/`, deliberately outside the shipped
   folders. Look at it.
4. Promote: move approved tiles into the asset tree, add a `LEVEL_TERRAIN`
   entry in `ground.gd`, set `wired: true`, add the biome's compatibility
   truths to `_check_formula`.
5. Run `tools/manifest_test.sh` — the tables check will hold you to all of it.

Adding an enemy or boss is steps 1 and 5 with the `enemies`/`bosses` table,
plus a scene or script that exists.

## Current wiring, honestly

| piece | state |
|---|---|
| primary + accents rolled | live (accents cosmetic so far — the descent and menu can name them; terrain generation does not mix them yet) |
| roster filters spawns | live (`_pick_enemy_scene`, empty-filter falls back to full pool) |
| `dense_horde` ×1.35, `lean_purse` ×0.7 | live at the single choke points |
| boss-as-intruder | rolled on the manifest; `BOSS_SCHEDULE` not yet driven by it |
| unwired biomes | roll as accents only; primaries need art |
| `elite_pressure`, `long_dusk`, `thin_ground` | roll and display; change nothing yet |
