# Measured DPS baseline

Produced by `tools/dps_test.sh` (Godot 4.7.1, headless, `main.tscn`, character
`warlock`, clean save so every meta and keystone multiplier is 1.0). Every
number below is damage that landed on a real enemy in the real scene. Nothing
here is read off `structures.json`, because `structures.json` is wrong — see
"inflation" below.

Re-run it after any balance change. A `0.0` in its output is a broken harness,
not a measured zero, and its assertions will say which precondition broke.

## Total DPS, one source at a time

| source | T1 | T2 | T3 |
|---|---:|---:|---:|
| **player** (warlock, base) | **31.50** | — | — |
| arrow turret | 16.00 | 43.87 | **194.04** |
| cannon tower | 10.80 | 26.84 | **118.39** |
| tesla tower | 9.00 | 23.62 | **90.77** |

Control pass (nothing firing): **0.0** damage, confirming no other source on the
field contributed to any row.

Full run:

```
source                      damage  shots   hits  per_shot   window  dps_meas  dps_calc
silence (control)              0.0      0      0      0.00     3.01      0.00      0.00
player warlock               180.0     12     12     15.00     6.01     29.94     31.50
arrow_turret T1              144.0      9     18     16.00    10.02     14.38     16.00
arrow_turret T2              286.0     10     20     28.60     6.53     43.77     43.87
arrow_turret T3             1108.8     12     48     92.40     6.02    184.30    194.04
cannon_tower T1              180.0     10     10     18.00    16.68     10.79     10.80
cannon_tower T2              325.0     10     10     32.50    12.11     26.84     26.84
cannon_tower T3              951.4      9     37    105.71     8.93    106.50    118.39
tesla_tower T1               100.0     10     10     10.00    11.12      9.00      9.00
tesla_tower T2               182.0     10     10     18.20     7.72     23.59     23.62
tesla_tower T3               548.6     11     24     49.88     6.02     91.18     90.77
arrow_turret T1 mult=x2      144.0      9     18     16.00    10.00     14.40     16.00
```

`dps_meas` divides by the window and so carries the quantisation of a whole
number of shots; `dps_calc` is per-shot damage times the source's own fire rate
and does not. They agree everywhere, which is the cross-check.

## What the sheet says, and what actually happens

```
                         sheet_dmg  code_dmg  landed_per_shot  sheet_dps  real_dps  inflation
arrow_turret T1               8.0      8.00            16.00       8.00     16.00      2.00x
arrow_turret T2              11.0     14.30            28.60      14.30     43.87      3.07x
arrow_turret T3              14.0     23.10            92.40      21.00    194.04      9.24x
cannon_tower T1              18.0     18.00            18.00      10.80     10.80      1.00x
cannon_tower T2              25.0     32.50            32.50      17.50     26.84      1.53x
cannon_tower T3              32.0     52.80           105.71      25.60    118.39      4.62x
tesla_tower T1               10.0     10.00            10.00       9.00      9.00      1.00x
tesla_tower T2               14.0     18.20            18.20      15.40     23.62      1.53x
tesla_tower T3               19.0     31.35            49.88      24.70     90.77      3.68x
```

Three separate multipliers stack on top of the table, none of them visible in it:

1. **Essence infusion, per tier.** `tower.gd:_apply_tier_stats` multiplies sheet
   damage by `ESSENCE_INFUSION_DAMAGE_MULT` (`[1.0, 1.30, 1.65]`) and fire rate
   by `ESSENCE_INFUSION_RATE_MULT` (`[1.0, 1.18, 1.40]`). That is the gap
   between `sheet_dmg` and `code_dmg`, and it is why a T3 is worth ~2.3x its
   table entry before anything else happens.
2. **Per-shot multi-hits.** `hits` exceeds `shots` wherever a single shot lands
   more than once — see the pierce finding below, plus the cannon's T3 cluster
   bombs and burn (≈4.1 landings per shell) and the tesla's T3 lightning storm.
3. **Nothing from the meta tree.** See below.

## Findings

### The arrow turret's pierce hits the same enemy repeatedly

Measured: pierce 1 lands **exactly 2** hits on one stationary enemy, pierce 3
lands **exactly 4** (18/9, 20/10, 48/12 in the run above).

`projectile.gd:_handle_hit` decrements `remaining_pierce` and clears
`_has_impacted`, but keeps nothing that records which bodies it has already hit,
and it does not advance the projectile past the body. The next physics frame
raycasts from the same surface point into the same collider and damages it
again. So pierce is not "pass through to the enemy behind"; it is "hit the first
enemy `pierce_count + 1` times".

This is what makes the arrow turret the dominant pick. Per gold spent, at T3
(cumulative build + upgrades from the table):

| tower | measured DPS/gold | DPS/gold if pierce hit once |
|---|---:|---:|
| arrow turret | 1.70 | 0.43 |
| cannon tower | 0.70 | 0.70 |
| tesla tower | 0.47 | 0.47 |

Without the double-hit the arrow turret would be the **worst** buy rather than
2.4x the cannon and 3.6x the tesla. Any tower balance pass has to decide what
pierce means before the numbers mean anything.

### The tower-damage multiplier never reaches a tower

Measured, not inferred: doubling `get_tower_damage_mult()` moved per-shot damage
by **1.00x**. `arrow_turret T1` and `arrow_turret T1 mult=x2` are byte-identical
rows.

`get_tower_damage_mult()` (`meta_tower_damage_mult * keystone_damage_mult`) is
read in exactly one place — `tower.gd`'s base `_fire_at` — and arrow, cannon and
tesla all override `_fire_at`. So the permanent "tower damage" meta upgrade the
player spends cores on, and the keystone that grants the same thing, do nothing
at all. `get_tower_damage_bonus()`, `get_tower_rate_mult()` and
`get_tower_range_mult()` *are* read by the overrides and do work.

### Tower scaling is far steeper than the docs assume

The player opens at 31.5 DPS and out-damages any single T1 tower (9–16). By T3 a
single arrow turret is 6.2x the player's base. Earlier estimates put T3 towers
at 48–59 DPS; measured they are 91–194. The "the player is the damage engine"
framing holds for the first minutes and inverts completely by tier 3 — so the
gap is not that towers are weak, it is that the curve between the two is
unmeasured and the early game gives the player no reason to build.

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
