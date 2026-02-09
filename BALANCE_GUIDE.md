# Balance Guide

> *Numbers, formulas, and tuning guidelines for Stronghold Survivors*

---

## Core Philosophy

The balance of Stronghold Survivors follows these principles:

1. **Early game generosity** - Players need room to experiment
2. **Mid-game pressure** - Resource management becomes critical
3. **Late-game escalation** - Without generators, you fall behind
4. **Clear tower roles** - Each tower has a distinct purpose
5. **Meaningful choices** - No single "correct" build path

---

## Starting Conditions

| Stat | Value | Notes |
|------|-------|-------|
| **Starting Gold** | 200 | Enough for generator (25) + arrow turret (25) + walls (4×4=16) + buffer |
| **Player Max HP** | 120 | Forgiving early, dangerous late |
| **Player Speed** | 230 | Fast enough to kite, slow enough to be threatened |
| **Player Damage** | 16 | Baseline for gun damage |
| **Player Attack Rate** | 2.5 shots/sec | Feels responsive without being OP |
| **Projectile Speed** | 780 | Fast enough to hit moving targets |

---

## Economy

### Income Sources

| Source | Rate | Notes |
|--------|------|-------|
| **Generator T1** | 3 gold / 2.0s = 1.5/s | Essential early investment |
| **Generator T2** | 3 gold / 1.8s = 1.67/s | +11% income for +60% cost |
| **Enemy Drops** | 1 gold (3 for elite) | Primary early income |
| **Resource Cache** | 500 gold (power-up) | Game-changing windfall |
| **Chest Rewards** | Varies by rarity | See Chest Upgrade table |

### Economic Flow Analysis

| Phase | Time | Cumulative Income | Key Purchases |
|-------|------|-------------------|---------------|
| Early | 0-2 min | ~200g (start) | Generator, first towers |
| Setup | 2-5 min | ~380g | T2 upgrades, walls, traps |
| Mid | 5-10 min | ~830g | T3 towers, utility buildings |
| Late | 10+ min | ~1400g+ | Replacements, emergency upgrades |

**Critical Rule**: Without at least one generator, late-game economy collapses (~50-100g/min from drops vs ~150-200g/min with generators).

---

## Tower Statistics

### Arrow Turret
**Role**: Reliable single-target DPS, early game workhorse

| Tier | Cost | Health | Range | Fire Rate | Damage | DPS | Pierce |
|------|------|--------|-------|-----------|--------|-----|--------|
| T1 | 25 | 40 | 240 | 1.0 | 10 | 10.0 | 1 |
| T2 | 40 | 55 | 300 | 1.3 | 14 | 18.2 | 1 |
| T3 | 70 | 75 | 360 | 1.5 | 18 | 27.0 | 2 |

**Upgrade Path**: Linear improvements across all stats

### Cannon Tower
**Role**: Area damage, anti-clump, siege specialist

| Tier | Cost | Health | Range | Fire Rate | Damage | DPS | Explosion Radius |
|------|------|--------|-------|-----------|--------|-----|------------------|
| T1 | 35 | 50 | 230 | 0.6 | 22 | 13.2 | 90 |
| T2 | 55 | 70 | 260 | 0.75 | 34 | 25.5 | 115 |
| T3 | 90 | 95 | 290 | 0.8 | 40 | 32.0 | 140 |

**T3 Special**: Cluster bombs + burn effect

### Tesla Tower
**Role**: Crowd control, excels vs groups, weak vs tanks

| Tier | Cost | Health | Range | Fire Rate | Damage | Chain Count | Storm |
|------|------|--------|-------|-----------|--------|-------------|-------|
| T1 | 35 | 45 | 220 | 0.9 | 12 | 2 | No |
| T2 | 55 | 65 | 250 | 1.1 | 18 | 4 | No |
| T3 | 95 | 90 | 280 | 1.3 | 24 | 6 | Yes |

**Effective DPS**: Chain count × damage (assumes all hits). Real DPS lower due to spread.

**T3 Storm**: Periodic lightning strikes all nearby enemies (interval: 0.8s)

### Sniper Tower
**Role**: Extreme range, priority target elimination

| Tier | Cost | Health | Range | Fire Rate | Damage | DPS | Pierce | Instakill |
|------|------|--------|-------|-----------|--------|-----|--------|-----------|
| T1 | 120 | 50 | 600 | 0.5 | 80 | 40.0 | 5 | 0% |
| T2 | 180 | 70 | 700 | 0.5 | 104 | 52.0 | 5 | 0% |
| T3 | 300 | 95 | 750 | 0.5 | 130 | 65.0 | 8 | 20% |

**Note**: High cost reflects its specialized role. Place to cover multiple lanes.

### Barrage Tower
**Role**: Close-quarters devastation, chokepoint defender

| Tier | Cost | Health | Range | Fire Rate | Damage | Pellets | Spread |
|------|------|--------|-------|-----------|--------|---------|--------|
| T1 | 100 | 55 | 150 | 2.5 | 15 | 6 | 45° |
| T2 | 150 | 75 | 150 | 3.0 | 15 | 8 | 45° |
| T3 | 250 | 100 | 225 | 3.0 | 18 | 8 | 45° |

**T3 Special**: Pellets gain pierce (hit multiple enemies)

---

## Trap Statistics

### Mine Trap
**Role**: Contact detonation, chokepoint control

| Tier | Cost | Trigger Radius | Damage | Explosion Radius |
|------|------|----------------|--------|------------------|
| T1 | 10 | 22 | 30 | 70 |
| T2 | 15 | 24 | 40 | 85 |

### Ice Trap
**Role**: Area slow, swarm control

| Tier | Cost | Field Radius | Slow Factor |
|------|------|--------------|-------------|
| T1 | 14 | 70 | 0.55 (45% slow) |
| T2 | 20 | 90 | 0.45 (55% slow) |

### Acid Burst
**Role**: Anti-siege specialist

| Tier | Cost | Trigger Radius | Damage | Explosion | Siege Bonus |
|------|------|----------------|--------|-----------|-------------|
| T1 | 18 | 24 | 22 | 80 | 2.0× |
| T2 | 25 | 26 | 30 | 95 | 2.3× |

---

## Wall Statistics

| Type | T1 Cost | T1 HP | T2 Cost | T2 HP | Notes |
|------|---------|-------|---------|-------|-------|
| **Wall** | 4 | 80 | 7 | 140 | Basic barrier |
| **Gate** | 6 | 90 | 10 | 150 | Opens/closes with 'G' |

**Economics**: Walls are intentionally cheap to encourage maze-building experimentation.

---

## Utility Building Statistics

### Resource Generator
| Tier | Cost | Health | Income | Interval |
|------|------|--------|--------|----------|
| T1 | 25 | 150 | 3 | 2.0s |
| T2 | 40 | 150 | 3 | 1.8s |

**ROI**: Pays for itself in ~17 seconds (T1) or ~24 seconds (T2, including upgrade)

### Barracks
| Tier | Cost | Ally Health | Ally Damage | Ally Speed | Spawn Interval |
|------|------|-------------|-------------|------------|----------------|
| T1 | 40 | 120 | 14 | 110 | 25s |
| T2 | 60 | 145 | 18 | 120 | 22s |

**Vulture Chance**: 25% (T1) / 35% (T2) - Ally becomes ranged attacker

### Armory
| Tier | Cost | Gun Damage Bonus |
|------|------|------------------|
| T1 | 35 | +3 |
| T2 | 50 | +5 |

### Tech Lab
| Tier | Cost | Tower Fire Rate Bonus |
|------|------|------------------------|
| T1 | 40 | +8% |
| T2 | 60 | +12% |

### Shrine
| Tier | Cost | Heal Amount | Heal Radius | Demon Stats |
|------|------|-------------|-------------|-------------|
| T1 | 35 | 4 HP | 140 | 160 HP, 24 dmg |
| T2 | 55 | 6 HP | 160 | 190 HP, 30 dmg |

**Caster Chance**: 35% (T1) / 45% (T2) - Demon gains AoE attack

---

## Enemy Scaling Formula

### Base Stats (Grunt)
- Health: 20
- Speed: 92
- Damage: 10
- Attack Rate: 1.05/sec

### Difficulty Multiplier
Difficulty scales over time based on `SPAWN_CURVE` in `main.gd`:

| Time | Difficulty Mult | HP Mult | Speed Mult |
|------|-----------------|---------|------------|
| 0:00 | 1.0 | 1.0 | 1.0 |
| 1:00 | 1.12 | 1.12 | 1.036 |
| 3:00 | 1.4 | 1.4 | 1.12 |
| 5:00 | 1.85 | 1.85 | 1.255 |
| 10:00 | 2.45 | 2.45 | 1.435 |

**Final Stats** = Base × Difficulty × (Enemy-specific multipliers)

### Spawn Curve

| Time | Spawn Interval | Max Enemies | Elite Chance | Siege Chance |
|------|----------------|-------------|--------------|--------------|
| 0:00 | 1.8s | 6 | 0% | 0% |
| 0:30 | 1.5s | 10 | 0.5% | 0% |
| 1:00 | 1.3s | 15 | 1% | 0% |
| 2:00 | 1.0s | 22 | 2% | 3% |
| 3:00 | 0.85s | 32 | 3% | 5% |
| 4:00 | 0.72s | 45 | 4% | 8% |
| 5:00 | 0.62s | 58 | 5% | 12% |
| 7:00 | 0.55s | 85 | 7% | 18% |
| 9:00 | 0.50s | 110 | 9% | 25% |
| 11:00 | 0.46s | 140 | 12% | 30% |

### Elite Multipliers
- Health: 2.2× base
- Speed: 1.1× base
- Damage: 1.4× base
- Scale: 1.35× visual size

### Wave Events

**Bat Swarm** (2:30)
- Count: 50
- Health: 0.6× normal
- Speed: 1.7× normal
- Damage: 0.65× normal

**Plant Wall** (4:00)
- Count: 18-28 (line formation)
- Health: 2.2× normal
- Speed: 0.6× normal
- Damage: 1.0× normal

---

## Enemy Type Reference

| Enemy | HP Mult | Speed Mult | Dmg Mult | Special |
|-------|---------|------------|----------|---------|
| Grunt | 1.0 | 1.0 | 1.0 | Basic melee |
| Charger | 0.8 | 1.4 | 0.9 | Fast rush |
| Hellhound | 0.7 | 1.5 | 0.85 | Fast, agile |
| Spitter | 0.9 | 0.9 | 0.8 | Ranged attack |
| Banshee | 0.6 | 1.3 | 0.7 | Flying (ignores walls) |
| Bomber | 1.1 | 0.9 | 1.2 | Explodes on death |
| Fiend Duelist | 1.2 | 1.0 | 1.3 | Higher damage |
| Healer | 0.8 | 0.8 | 0.5 | Heals nearby enemies |
| Necromancer | 0.9 | 0.7 | 0.6 | Summons skeletons |
| Plague Abomination | 2.5 | 0.5 | 1.1 | Very tanky |
| Juggernaut | 4.0 | 0.6 | 1.5 | Boss-tier tank |

---

## Chest Upgrade System

Treasure chests from elite enemies contain random upgrades by rarity:

### Common (60%)
| Upgrade | Effect |
|---------|--------|
| Gun Damage | +2 damage |
| Tower Range | +6% range |
| Speed | +12 movement speed |
| Max HP | +12 health |
| Build Cost | -8% building costs |
| Reload Speed | -10% attack cooldown |

### Rare (25%)
| Upgrade | Effect |
|---------|--------|
| Crit Chance | +8% critical hit chance |
| Crit Damage | +25% critical damage |
| Pierce | +1 projectile pierce |
| Cooldown | -12% ability cooldown |
| Pickup Range | +30% pickup attraction |

### Epic (10%)
| Upgrade | Effect |
|---------|--------|
| Multishot | Burst fire every 3rd shot |
| Explosive | Projectiles explode (60 radius) |
| Chain | Projectiles chain to 3 nearby enemies |
| Vampiric | 8% life steal on damage |

### Legendary (4%)
| Upgrade | Effect |
|---------|--------|
| Multishot Split | Burst fires split projectiles |
| Vampiric Heart | 15% life steal |
| Chain Master | Chains to 5 enemies |
| Time Dilation | Slower enemy projectiles |

### Diamond (0.4%)
| Upgrade | Effect |
|---------|--------|
| Phoenix | Revive once per run |
| Fortress | +50% tower HP, self-repair |

---

## Power-up Spawn Rates

| Type | Chance | Spawn Distance | Duration on Map |
|------|--------|----------------|-----------------|
| Resource Cache | 35% | 400-600 | 45s |
| Time Crystal | 25% | 500-700 | 20s |
| Berserk Orb | 25% | 700-900 | 25s |
| Ancient Relic | 15% | 600-800 | 30s |

Spawn interval: 60-90 seconds between power-ups
Max on map: 3

---

## How to Adjust Difficulty

### Making the Game Easier

1. **Increase starting gold** (`main.gd`: `resources = 200`)
2. **Slow spawn curve** (increase interval values in `SPAWN_CURVE`)
3. **Reduce max enemies** (lower `max_enemies` in curve)
4. **Buff generator income** (`resource_generator.gd`: increase `income`)
5. **Reduce enemy difficulty** (lower `difficulty` values)
6. **Nerf siege chance** (reduce `siege` percentages)
7. **Increase player HP** (`player.gd`: `max_health`)

### Making the Game Harder

1. **Reduce starting gold** (as low as 100)
2. **Speed up spawn curve** (decrease intervals)
3. **Increase max enemies** (up to 200, watch performance)
4. **Increase elite chance** (multiply by 1.5-2.0)
5. **Buff enemy scaling** (increase `difficulty` multipliers)
6. **Reduce tower ranges** (edit `structures.json`)
7. **Increase siege targeting** (raise `siege` percentages)

### Tuning Specific Waves

Edit `SPAWN_CURVE` in `main.gd`:

```gdscript
# Example: Make minute 5 easier
{"time": 300.0, "interval": 0.8, "max_enemies": 50, "difficulty": 1.6, "elite": 0.04, "siege": 0.10}
# Was: 0.62 interval, 58 max, 1.85 difficulty, 0.05 elite, 0.12 siege
```

### Tuning Tower Balance

Edit `data/structures.json`:

```json
{
  "arrow_turret": {
    "tiers": [
      {
        "cost": 25,        // Increase to slow early game
        "damage": 10,      // Decrease to reduce DPS
        "fire_rate": 1.0,  // Decrease to slow firing
        "range": 240       // Reduce to require better placement
      }
    ]
  }
}
```

### Tuning Enemy Pools

Edit `ENEMY_POOLS` in `main.gd`:

```gdscript
{
    "time": 120.0,  // At 2 minutes
    "weights": [
        [ENEMY_SCENE, 36],        // Increase for more grunts
        [CHARGER_SCENE, 14],      // Reduce to fewer chargers
        // Add new enemy type here
        [MY_NEW_ENEMY, 10]
    ]
}
```

---

## Balance Checklist

When making changes, verify:

- [ ] Can a new player reach 5 minutes without a guide?
- [ ] Does the 10-minute mark feel challenging but fair?
- [ ] Are all towers viable in some situation?
- [ ] Is the generator a compelling first purchase?
- [ ] Do elites feel threatening but rewarding?
- [ ] Are wave events telegraphed clearly enough?
- [ ] Does the economy feel tight but not punishing?
- [ ] Is there a reason to upgrade vs. building new?

---

## Metrics to Monitor

Track these during playtesting:

| Metric | Target | Too Low | Too High |
|--------|--------|---------|----------|
| Average survival time | 8-12 min | <5 min | >20 min |
| Generator build rate | 90%+ by 2 min | <70% | 100% (too essential) |
| T3 tower rate | 2-3 by 10 min | <1 | >5 (economy too loose) |
| Player death cause | 60% overwhelmed | 80% gun | 80% base breach |
| Elite kill rate | 80%+ | <50% | 100% (too easy) |

---

*For implementation details, see `DEVELOPER_GUIDE.md`*
