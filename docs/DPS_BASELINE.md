# Measured DPS baseline

Produced by `tools/dps_test.sh` (Godot 4.7.1, headless, `main.tscn`, character
`warlock`, clean save so every meta and keystone multiplier is 1.0). Every
number below is damage that landed on a real enemy in the real scene. Nothing
here is read off `structures.json`, because `structures.json` is wrong — see
"inflation" below.

Re-run it after any balance change. A `0.0` in its output is a broken harness,
not a measured zero, and its assertions will say which precondition broke.

**Current as of `ae7b959`.** These numbers are *after* three bugs the harness
found were fixed: pierce re-hitting the first enemy, the tower-damage
multiplier reaching no tower, and towers firing blanks past their unmultiplied
range. The pre-fix figures are kept below where the difference is the point,
labelled as such. If you are comparing against a note written before those
commits, the arrow turret's numbers moved a long way.

## Total DPS, one source at a time

| source | T1 | T2 | T3 |
|---|---:|---:|---:|
| **player** (warlock, base) | **31.50** | — | — |
| arrow turret | 8.00 | 21.94 | **48.51** |
| cannon tower | 10.80 | 26.84 | **119.14** ⚠ |
| tesla tower | 9.00 | 23.62 | **90.77** |

⚠ **`cannon_tower T3` is not reproducible and should not be quoted as a fixed
number.** Its cluster bomblets pick `randf()` angles and radii per shell, so
whether each catches the dummy is chance. Observed across runs with no code
change between them: **85.44 / 94.48 / 105.71 / 106.37 / 119.60** per shot,
`hits` swinging 28–45 on 9 shots. Every other row in this table is stable to the
cent. Treat the cannon T3 row as "roughly 90–120" until the harness gets a
seeded RNG or a much longer window; the same caveat applies to the cannon's
DPS/gold below.

Control pass (nothing firing): **0.0** damage, confirming no other source on the
field contributed to any row.

Full run:

```
source                      damage  shots   hits  per_shot   window  dps_meas  dps_calc
silence (control)              0.0      0      0      0.00     3.01      0.00      0.00
player warlock               180.0     12     12     15.00     6.00     29.98     31.50
arrow_turret T1               72.0      9      9      8.00    10.02      7.19      8.00
arrow_turret T2              143.0     10     10     14.30     6.53     21.89     21.94
arrow_turret T3              277.2     12     12     23.10     6.00     46.20     48.51
cannon_tower T1              180.0     10     10     18.00    16.67     10.80     10.80
cannon_tower T2              325.0     10     10     32.50    12.12     26.82     26.84
cannon_tower T3              957.4      9     38    106.37     8.93    107.17    119.14
tesla_tower T1               100.0     10     10     10.00    11.12      9.00      9.00
tesla_tower T2               182.0     10     10     18.20     7.72     23.59     23.62
tesla_tower T3               548.6     11     24     49.88     6.01     91.30     90.77
arrow_turret T1 mult=x2      144.0      9      9     16.00    10.00     14.40     16.00
tesla_tower T1 range=x2      100.0     10     10     10.00    11.12      8.99      9.00
```

`dps_meas` divides by the window and so carries the quantisation of a whole
number of shots; `dps_calc` is per-shot damage times the source's own fire rate
and does not. They agree everywhere, which is the cross-check.

The last two rows are probes, not towers you can build:

- `mult=x2` doubles `get_tower_damage_mult()`. It must read exactly **2.00x**
  against the `T1` row above. It read 1.00x until `6adb3ee`.
- `range=x2` doubles `get_tower_range_mult()` and puts the dummy at 280px, past
  the tesla's raw 187px reach but inside its multiplied 374px. It must land its
  shots. It landed **none** until `ae7b959`.

## What the sheet says, and what actually happens

```
                         sheet_dmg  code_dmg  landed_per_shot  sheet_dps  real_dps  inflation
arrow_turret T1               8.0      8.00             8.00       8.00      8.00      1.00x
arrow_turret T2              11.0     14.30            14.30      14.30     21.94      1.53x
arrow_turret T3              14.0     23.10            23.10      21.00     48.51      2.31x
cannon_tower T1              18.0     18.00            18.00      10.80     10.80      1.00x
cannon_tower T2              25.0     32.50            32.50      17.50     26.84      1.53x
cannon_tower T3              32.0     52.80           106.37      25.60    119.14      4.65x
tesla_tower T1               10.0     10.00            10.00       9.00      9.00      1.00x
tesla_tower T2               14.0     18.20            18.20      15.40     23.62      1.53x
tesla_tower T3               19.0     31.35            49.88      24.70     90.77      3.68x
```

Two multipliers stack on top of the table, neither visible in it:

1. **Essence infusion, per tier.** `tower.gd:_apply_tier_stats` multiplies sheet
   damage by `ESSENCE_INFUSION_DAMAGE_MULT` (`[1.0, 1.30, 1.65]`) and fire rate
   by `ESSENCE_INFUSION_RATE_MULT` (`[1.0, 1.18, 1.40]`). That is the gap
   between `sheet_dmg` and `code_dmg`, and it is why a T3 is worth ~2.3x its
   table entry before anything else happens. Every T2 row is exactly 1.53x for
   this reason, across all three towers — a useful sanity check.
2. **Per-shot multi-hits, on two towers only.** `landed_per_shot` exceeds
   `code_dmg` for the cannon's T3 cluster bombs (≈4 landings per shell) and the
   tesla's T3 lightning storm. The arrow turret used to be in this list because
   of the pierce bug; it no longer is, and its `landed_per_shot` now equals its
   `code_dmg` at every tier.

A third multiplier — the meta tower-damage tree — reached nothing at all until
`6adb3ee`. See below.

## Findings

### Pierce hit the same enemy repeatedly — fixed in `72155f5`

Pierce did not mean "pass through to the enemy behind"; it meant "hit the first
enemy `pierce_count + 1` times". `projectile.gd:_handle_hit` kept no record of
which bodies it had already hit and left the projectile parked on the collider
surface, so the next frame's ray cast from that point into that same body and
landed again. Measured: pierce 1 landed exactly 2 hits, pierce 3 exactly 4.

| arrow turret | per_shot before | after | hits/shots before | after |
|---|---:|---:|---:|---:|
| T1 | 16.00 | **8.00** | 20/10 | **10/10** |
| T2 | 28.60 | **14.30** | 20/10 | **10/10** |
| T3 | 92.40 | **23.10** | 48/12 | **12/12** |

This is what made the arrow turret the dominant pick, and fixing it inverts the
ranking. Per gold spent at T3 (cumulative build + upgrades: arrow 114, cannon
170, tesla 192):

| tower | DPS/gold before | DPS/gold now |
|---|---:|---:|
| arrow turret | **1.70** | **0.43** |
| cannon tower | 0.70 | 0.70 |
| tesla tower | 0.47 | 0.47 |

The arrow turret went from 2.4x the cannon and 3.6x the tesla to the **worst**
buy of the three. No balance numbers were changed to achieve that — the table
is simply telling the truth now, and a retune against it is a separate
decision.

`tools/pierce_test.sh` guards the behaviour this harness structurally cannot
see: it puts one enemy on the field by design, so it can prove "one shot lands
once on one target" and nothing about what reaches the body behind. That probe
fires one `pierce_count = 3` shot down a line of five and asserts four
*different* enemies take one hit each.

### The tower-damage multiplier never reached a tower — fixed in `6adb3ee`

Measured, not inferred: doubling `get_tower_damage_mult()` moved per-shot damage
by **1.00x**. `get_tower_damage_mult()` was read in exactly one place —
`tower.gd`'s base `_fire_at` — and every tower overrides `_fire_at`. So the
permanent "Siege Doctrine" upgrade and the three keystones that multiply tower
damage were bought with cores and did nothing.

There turned out to be **five** overriding towers, not three: `flamethrower` and
`spike_burst` had the bug too. Fourteen damage paths now scale, including three
that never run through `_fire_at` (the hellfire pool, the T3 lightning storm,
the storm spire field). The probe row now reads 2.00x.

Not scaled, deliberately: traps and the units barracks and shrines summon. They
extend `Trap`/ally, not `Tower`, and never took the additive
`get_tower_damage_bonus()` either — scaling only the multiplicative half would
create a worse inconsistency than the one being fixed.

### Towers fired blanks past their unmultiplied range — fixed in `ae7b959`

The same bug class, found while fixing the one above. Targeting honours
`get_tower_range_mult()`, but eight sites in the *firing* code re-tested
distance against the raw `range` member. Above 1.0x range a tower acquired a
target, played the windup, spent the cooldown, played the sound — and dealt
nothing. **Every point of range the player bought made the tower waste more
shots.**

    before:  dummy at 280px, raw range 187, effective 374, shots=10 hits=0
    after:   dummy at 280px, raw range 187, effective 374, shots=10 hits=10

Twice now a multiplier has reached the code deciding *whether* to shoot but not
the code deciding what the shot does, which is why both probes are permanent
rows in the table rather than one-off checks.

### Tower scaling is steeper than the docs assume, but less than it looked

The player opens at 31.5 DPS and out-damages any single T1 tower (8–11). By T3 a
single tower is 1.5x–3.8x the player's base. Earlier estimates put T3 towers at
48–59 DPS; measured they are 48–119 — so the low end of that estimate was right
and the top end was three bugs. The "the player is the damage engine" framing
holds for the first minutes and inverts by tier 3, and the real gap is that the
curve between the two is unmeasured and the early game gives the player no
reason to build.

## Method

- The real `main.tscn`, behind `--dps-test`, not a fixture. Both of the bugs
  that made four earlier attempts print `0.0` lived in the real scene: the horde
  was still spawning (a tower shoots whatever is closest), and the enemy cache
  every tower targets through is built *below* the `spawn_delay` early return,
  so for the first ten seconds no tower can see anything.
- One damage tap at `enemy.gd`'s `health -= amount` — the only place an enemy
  loses health — and one shot tap at `tower.gd`'s single `_fire_at` call site.
  Both gated on a bool that is false in normal play.
- One source live per pass; the rest silenced with `inert`. Total damage in the
  window is that source's DPS, so no per-source attribution is needed.
- A fresh dummy each pass (health pinned at 1e9, physics off), projectiles
  cleared at the window's open and drained at its close, a one-second warm-up so
  the cooldown phase is arbitrary, and windows sized to hold about ten shots.
- Every pass asserts: exactly one enemy alive, the source fired, something
  landed, the dummy survived, the run clock never froze — and a control pass
  with nothing firing that must take exactly zero damage.

### Sibling harnesses

This one measures damage against a single target. Three others cover what it
structurally cannot, each documenting the false negative it defeats and each
with a negative control proving it can see the bug it guards:

- `tools/pierce_test.sh` — pass-through across multiple bodies.
- `tools/input_map_test.sh` — every action a script polls is actually
  registered. Boots the real scene and drives real input events, because
  `Input.action_press` reports "pressed" for unregistered actions and would pass
  against the exact bug it tests.
- `tools/boss_test.sh` — boss health scaling and maze routing, with a wall the
  fixture proves is sealed four ways before it trusts a single result.
