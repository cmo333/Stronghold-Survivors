# Sprite-Sheet Generation Prompts

Copy/paste AI image-generation prompts for new Stronghold Survivors art. Every prompt is built to
match the existing pixel-art pipeline so generated sheets drop into the engine with minimal cleanup.

How to use this file:
1. Pick a prompt below.
2. Prepend the **Global Style Block** (Section 0) to it — or paste the block once and reference it.
3. Generate, then run the output through the cleanup path in **Section 4** (alpha extract, downscale,
   palette-lock) and slice to the target filenames listed with each prompt.

---

## 0. Global Style Block (prepend to every prompt)

```
Top-down/slight-isometric 2D game sprite, retro pixel-art, hand-crafted limited palette (12-24 colors),
clean tight shading ramps, crisp readable silhouette that reads at small zoomed-out size, soft single
top-down key light, subtle emissive accents only on energy/metal highlights, no anti-aliased fuzz,
no outline border around the whole sheet, no text, no logos, no UI, no drop shadow on the canvas.
Fully TRANSPARENT background (alpha). Subject centered in each frame with consistent registration
(pivot at the base/feet), even margins, no cropping of limbs/barrels. Style reference: Halls of Torment
readability + Warcraft III tower silhouettes + StarCraft industrial sci-fi materials. "Detail up,
clutter down" — add fidelity in local shading, avoid random noise.
```

Layout conventions referenced below:
- **2x2 fire flipbook** = a single square sheet split into a 2x2 grid of 4 equal frames, read
  left-to-right, top-to-bottom (f001 top-left, f002 top-right, f003 bottom-left, f004 bottom-right).
  Frames form a seamless looping "fire" beat: charge → fire → recoil → settle.
- **8-way directional grid** = 8 poses, one per facing, in fixed compass order
  `E, SE, S, SW, W, NW, N, NE`. For move loops, each facing has 4 frames; lay out one facing per row
  (8 rows × 4 columns) OR generate one facing at a time (preferred for clean alpha).

---

## 1. End-Game Tower Upgrades (T3 + Evolutions)

Each tower escalates **t1 → t2 → t3** in silhouette, then branches into **two evolutions** with
distinct shapes. Keep the family DNA (same chassis lineage) for T3; break the silhouette hard for
evolutions.

Towers are fixed-angle bodies. T3 uses the **8-way directional** layout (matches `<type>_t1/t2_<DIR>`).
Evolutions are delivered as **2x2 fire flipbooks** (matches `tower_missile_evo_gatling_2x2_fire_*`).

### 1A. ARROW / MISSILE TURRET

**Arrow T3 — directional body**
Output: `arrow_t3_E.png`, `arrow_t3_SE.png`, `arrow_t3_S.png`, `arrow_t3_SW.png`, `arrow_t3_W.png`,
`arrow_t3_NW.png`, `arrow_t3_N.png`, `arrow_t3_NE.png` → `assets/level1/towers_directional/`
Resolution: ~256x256 per facing (hand-drawn high; engine downscales). Generate one facing at a time.
```
[GLOBAL STYLE BLOCK]
A military-industrial automated MISSILE TURRET, tier-3 apex of an arrow/missile tower line. Lineage:
t1 = single slim bolt-launcher on a tripod; t2 = twin reinforced launcher with armor plating; render
T3 as the apex: a heavy multi-rail missile rack (4-6 angled launch rails) on a wide armored swivel
base, with sighting optics, ammo feed cabling, and faint blue targeting emissive on the rail tips.
Aggressive forward-leaning silhouette. Show it aimed toward {FACING} (compass {FACING}). Static idle
pose, no muzzle flash. Transparent background.
```

**Arrow Evolution — GATLING (rotary)** — 2x2 fire flipbook
Output: `tower_missile_evo_gatling_2x2_fire_f001..f004_v001.png` → `assets/level1/level1_anim60/`
(Note: this set already exists — regenerate only if revising. Listed for completeness/consistency.)
```
[GLOBAL STYLE BLOCK]
A 2x2 sprite sheet (4 frames) of a GATLING-evolution missile turret firing. A fat rotary cluster of
6-8 short barrels spinning on an armored mount, heavy ammo drums on the sides, vents glowing orange.
Frame 1: barrels mid-spin, charge glow. Frame 2: muzzle flash burst across barrels, slight recoil.
Frame 3: recoil peak + ejected shells + smoke puff. Frame 4: settle, barrels still spinning, residual
glow. Seamless loop. Top-down. Transparent background.
```

**Arrow Evolution — SNIPER (long-barrel)** — 2x2 fire flipbook
Output: `tower_missile_evo_sniper_2x2_fire_f001..f004_v001.png` → `assets/level1/level1_anim60/`
(Already exists — regenerate only if revising.)
```
[GLOBAL STYLE BLOCK]
A 2x2 sprite sheet (4 frames) of a SNIPER-evolution missile turret firing. One very long precision
barrel with a large scope/optic, bipod stabilizers, and a thin blue laser sight line. Lean elegant
silhouette, opposite of the gatling. Frame 1: aim, laser dot charging, faint blue glow. Frame 2:
single sharp muzzle flash + barrel-length light streak. Frame 3: hard recoil kick, smoke at muzzle.
Frame 4: settle back to aim, laser re-acquires. Seamless loop. Top-down. Transparent background.
```

### 1B. CANNON TOWER

**Cannon T3 — directional body**
Output: `cannon_t3_E.png` … `cannon_t3_NE.png` (all 8) → `assets/level1/towers_directional/`
Generate one facing at a time.
```
[GLOBAL STYLE BLOCK]
A heavy siege CANNON TOWER, tier-3 apex. Lineage: t1 = single stubby cannon on a blocky base;
t2 = reinforced double-barrel with heat shrouds; render T3 as a massive compressed-chassis triple-bore
mortar-cannon on a thick armored turntable, with riveted plating, heat-exhaust stacks, and a dull
orange ember glow in the bore. Squat, heavy, low-cadence silhouette — reads as "big slow hard-hitter."
Aimed toward {FACING} (compass {FACING}). Static idle pose, no smoke plume. Transparent background.
```

**Cannon Evolution — HELLFIRE (molten/flame)** — 2x2 fire flipbook
Output: `tower_cannon_evo_hellfire_2x2_fire_f001..f004_v001.png` → `assets/level1/level1_anim60/`
```
[GLOBAL STYLE BLOCK]
A 2x2 sprite sheet (4 frames) of a HELLFIRE-evolution cannon firing molten ordnance. Cracked
red-hot armor with lava-vein emissive seams, a wide flared muzzle, magma glowing inside the bore.
Frame 1: bore charges, lava veins brighten. Frame 2: violent fireball muzzle blast, orange/red flame
plume. Frame 3: heavy recoil + rolling smoke and embers. Frame 4: settle, glowing bore cooling to deep
red. Hot color palette (black iron, deep red, molten orange, yellow core). Seamless loop. Top-down.
Transparent background.
```

**Cannon Evolution — SHOCKWAVE (concussive ring)** — 2x2 fire flipbook
Output: `tower_cannon_evo_shockwave_2x2_fire_f001..f004_v001.png` → `assets/level1/level1_anim60/`
```
[GLOBAL STYLE BLOCK]
A 2x2 sprite sheet (4 frames) of a SHOCKWAVE-evolution cannon firing a concussive blast. A wide
funnel/horn muzzle with concentric resonator rings, pale blue-white kinetic energy. Distinct from
hellfire: cold concussive, not flame. Frame 1: rings spin up, faint blue charge. Frame 2: a bright
expanding concentric shock ring bursts from the muzzle. Frame 3: ring expands further + dust kickup +
recoil. Frame 4: ring fades, muzzle settles. Cool palette (steel grey, pale blue, white). Seamless
loop. Top-down. Transparent background.
```

### 1C. TESLA TOWER

**Tesla T3 — directional body**
Output: `tesla_t3_E.png` … `tesla_t3_NE.png` (all 8) → `assets/level1/towers_directional/`
Generate one facing at a time.
```
[GLOBAL STYLE BLOCK]
A high-voltage TESLA TOWER, tier-3 apex. Lineage: t1 = single coil on a small base; t2 = twin coils
with a charge ring; render T3 as a tall multi-coil pylon — a central spire ringed by 3-4 secondary
coils, copper banding, insulator discs, and a crackling cyan-white arc orb at the crown. Tall, spiky,
electric silhouette. Subtle idle arcs between coils. Facing toward {FACING} (compass {FACING}) — the
crown arc-orb leans slightly that way. Static idle pose. Transparent background.
```

**Tesla Evolution — STORM SPIRE (chain lightning)** — 2x2 fire flipbook
Output: `tower_tesla_evo_storm_spire_2x2_fire_f001..f004_v001.png` → `assets/level1/level1_anim60/`
```
[GLOBAL STYLE BLOCK]
A 2x2 sprite sheet (4 frames) of a STORM SPIRE-evolution tesla tower discharging chain lightning.
A very tall slender spire crowned with a violent storm orb; jagged forked lightning branches off the
crown. Frame 1: orb charges, faint static. Frame 2: a bright forked lightning bolt erupts from the
crown. Frame 3: chained secondary forks branch outward, orb at peak brightness. Frame 4: arcs dissipate,
orb dims to idle crackle. Electric palette (deep blue, cyan, white-hot core, faint violet). Seamless
loop. Top-down. Transparent background.
```

**Tesla Evolution — ARC CONDUIT (linked beam)** — 2x2 fire flipbook
Output: `tower_tesla_evo_arc_conduit_2x2_fire_f001..f004_v001.png` → `assets/level1/level1_anim60/`
```
[GLOBAL STYLE BLOCK]
A 2x2 sprite sheet (4 frames) of an ARC CONDUIT-evolution tesla tower firing a sustained beam. Squat
twin-node emitter (two charged spheres on short arms) channeling a steady focused arc beam between/from
the nodes — controlled, not chaotic (contrast with storm spire's wild forks). Frame 1: nodes charge,
energy gathers between them. Frame 2: a clean concentrated arc beam projects forward. Frame 3: beam at
full intensity with a bright focus point + small sparks. Frame 4: beam cuts, nodes hold residual glow.
Cool electric palette (teal-cyan, white). Seamless loop. Top-down. Transparent background.
```

---

## 2. New Enemy "Baddies"

Layout: **4-frame move loop** (single sheet, 1x4 or 2x2 — pick to match your slicer; existing units
are 4 sequential frames). NOT directional. Loop = a walk/float cycle that reads from the top down.
Naming: `unit_<faction>_<name>_<size>_move_f001..f004_v001.png` → `assets/level1/level1_anim60/`.
Size = pixel footprint (32 = small/swarm, 48 = mid/elite, 64 = heavy/brute). Match size to role.

Each prompt below already lists faction, name, size, and output filenames.

**Demon brute — `void_brute` (64)**
Output: `unit_demon_void_brute_64_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down WALK loop of a hulking demon brute. Massive horned shoulders, cracked obsidian skin
with violet void-fire glowing in the cracks, heavy fists dragging. Slow lumbering gait: f1 weight on
left, f2 mid-stride, f3 weight on right, f4 mid-stride. Reads as a heavy tank enemy. 64px footprint.
Demon faction palette (charcoal black, deep violet, hot magenta cracks). Transparent background.
```

**Demon caster — `flame_warlock` (32)**
Output: `unit_demon_flame_warlock_32_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down FLOAT/walk loop of a lean demon spellcaster. Hooded robed figure with a horned
skull mask, holding a small floating fireball orb, robe hem flickering with embers. Light hovering
glide: subtle bob across f1-f4, orb pulsing. Reads as a ranged caster (fragile, dangerous). 32px.
Demon palette (dark robe, orange ember trim, glowing orange orb). Transparent background.
```

**Undead swarm runner — `bone_skitterer` (32)**
Output: `unit_undead_bone_skitterer_32_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down SCURRY loop of a fast low skittering undead — a clattering cluster of bone scraps
and a grinning skull on many tiny spider-like bone legs. Frantic fast cycle (legs blur across f1-f4),
hunched low silhouette. Reads as a cheap fast swarm unit. 32px. Undead palette (bone white, grey,
sickly green eye glow). Transparent background.
```

**Undead heavy — `tombguard` (48)**
Output: `unit_undead_tombguard_48_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down WALK loop of an armored undead knight. Rusted plate armor over a skeletal frame,
large tower shield in one hand, broken greatsword in the other, faint blue soul-glow in the helm.
Steady heavy march: f1-f4 deliberate stride, shield steady. Reads as a durable mid-elite blocker.
48px. Undead palette (rust brown, tarnished steel, cold blue soul glow). Transparent background.
```

**Undead flyer — `gravewing` (48)**
Output: `unit_undead_gravewing_48_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down FLAP loop of an undead flying terror — a skeletal bat-winged horror seen from above,
tattered membrane wings, exposed ribcage, trailing wisps of grave mist. Wing-beat cycle: f1 wings up,
f2 wings spread, f3 wings down, f4 wings spread. Slight altitude bob to read as airborne. 48px. Undead
palette (bone grey, tattered black membrane, pale green mist). Transparent background.
```

**Monstrous heavy — `granite_colossus` (64)**
Output: `unit_monstrous_granite_colossus_64_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down WALK loop of a stone-golem colossus. Massive boulder body, mossy cracked granite
plates, glowing rune-light in the chest seam, slab arms. Very slow ground-shaking gait (minimal bob,
heavy footplant on f1 and f3). Reads as a slow ultra-tank. 64px. Monstrous palette (grey stone, moss
green, warm amber rune glow). Transparent background.
```

**Monstrous mid — `gore_charger` (48)**
Output: `unit_monstrous_gore_charger_48_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down CHARGE-run loop of a bestial four-legged ram-beast. Low muscular body, forward
curved horns, hooves kicking dust. Fast galloping cycle (legs reach forward then back across f1-f4),
head lowered to charge. Reads as a fast mid-tier rusher. 48px. Monstrous palette (dark hide brown,
bone horns, red eye glow). Transparent background.
```

**New faction (blighted) caster — `blighted_spore_mother` (64)**
Output: `unit_blighted_spore_mother_64_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down CRAWL loop of a bloated plague creature — a sac-bodied spore mother dragging itself
forward, pulsing green spore pods on its back, dripping toxic ichor. Slow pulsing crawl (body bloats/
deflates across f1-f4, pods glow on the pulse). Reads as a heavy support/spawner enemy. 64px. Blighted
palette (sickly olive green, bruised purple, bright toxic green glow). Transparent background.
```

---

## 3. Heroes

Layout: **8-way directional move loop**, 4 frames per facing, **32px** footprint. Matches existing
`player_hunter_32_<DIR>_move_*`. Generate one facing at a time (8 facings × 4 frames each), compass
order `E, SE, S, SW, W, NW, N, NE`.
Naming: `player_<hero>_32_<DIR>_move_f001..f004_v001.png` → place in a new
`assets/level1/level1_player_anim_<hero>/` directory (mirrors `level1_player_anim_hunterv2` / `_pyro`).

**Hero — TECH MARKSMAN (`marksman`)**
Output: `player_marksman_32_<DIR>_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down WALK loop of a sci-fi marksman hero, facing {FACING} (compass {FACING}). Lean agile
soldier in a light armored coat, carrying a long-barreled energy rifle at the hip, optic visor glowing
faint cyan. Confident walk cycle: f1 left foot lead, f2 mid, f3 right foot lead, f4 mid; rifle steady.
Distinct readable hero silhouette (taller/cleaner than enemies). 32px. Palette: slate-grey coat,
gunmetal rifle, cyan visor/energy accents. Transparent background.
```

**Hero — ARC MAGE (`arcmage`)**
Output: `player_arcmage_32_<DIR>_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down WALK loop of an arc-mage hero, facing {FACING} (compass {FACING}). A robed
techno-sorcerer with a hovering energy focus crystal orbiting one hand, coat hem and crystal crackling
with electric blue arcs. Smooth glide-walk: gentle bob across f1-f4, crystal pulsing. Clear hero
silhouette. 32px. Palette: deep indigo robe, silver trim, electric blue/white arc glow. Transparent
background.
```

**Hero — HEAVY BULWARK (`bulwark`)**
Output: `player_bulwark_32_<DIR>_move_f001..f004_v001.png`
```
[GLOBAL STYLE BLOCK]
A 4-frame top-down WALK loop of a heavy bulwark hero, facing {FACING} (compass {FACING}). A broad
armored defender in thick riveted plate, carrying a large energy-edged shield and a short mace.
Slower powerful march: deliberate stride f1-f4, shield held forward. Bulky but still a clean readable
hero silhouette. 32px. Palette: heavy steel plate, brass trim, warm gold shield-edge glow. Transparent
background.
```

---

## 4. Usage / Pipeline Notes

### Sheet layouts
- **2x2 fire flipbook** (towers): one square canvas, 4 equal cells.
  ```
  +--------+--------+
  | f001   | f002   |
  +--------+--------+
  | f003   | f004   |
  +--------+--------+
  ```
  Frame order is the fire beat: charge → fire → recoil → settle (seamless loop back to f001).
- **Enemy move loop**: 4 frames in sequence (slice to f001–f004). Keep the pivot at the unit's feet so
  frames don't "swim" when looped.
- **Hero 8-way**: generate each facing separately for clean alpha, then 4 frames per facing. Compass
  order `E, SE, S, SW, W, NW, N, NE`. Keep the body centered and the same pivot across all facings.

### Per-frame consistency
- Lock the camera angle, light direction, scale, and pivot across all frames of a set. Drift between
  frames is the #1 cause of jitter in-engine.
- Transparent background is mandatory. No baked drop-shadow on the canvas (the engine adds shadows).

### Cleanup → engine-ready (from HYBRID_ANIMATION_FX_SPEC.md / WIN4090_AI_FX_PIPELINE.md)
1. Generate concept frame(s) at high resolution.
2. Extract alpha with BiRefNet (HR variant); also build a luma-alpha mask.
3. Merge alpha as `max(biref_alpha, luma_alpha)`.
4. Downscale to the target footprint (32/48/64 for units & heroes; tower sheets per existing sizes) and
   **palette-lock** to the Stronghold palette.
5. Export PNG sequences sliced to the exact target filenames listed with each prompt.

### Naming recap (must match exactly)
- Tower directional: `assets/level1/towers_directional/<type>_t3_<DIR>.png` (DIR ∈ E,SE,S,SW,W,NW,N,NE).
- Tower evolution fire: `assets/level1/level1_anim60/tower_<id>_evo_<evoid>_2x2_fire_f00N_v001.png`
  (arrow id = `missile`, evoids: `gatling`/`sniper`, `hellfire`/`shockwave`, `storm_spire`/`arc_conduit`).
- Enemy: `assets/level1/level1_anim60/unit_<faction>_<name>_<size>_move_f00N_v001.png`.
- Hero: `assets/level1/level1_player_anim_<hero>/player_<hero>_32_<DIR>_move_f00N_v001.png`.

### Out of scope (separate later task)
- Wiring new T3 sets, evolution flipbooks, enemies, and heroes into the engine (tower `_dir_tex_set()`
  T3 branch, enemy spawn tables, hero select) happens **after** the art exists.
