# Stronghold Survivors

A Vampire Survivors-style tower defense game built in Godot 4.2. Defend your stronghold by building towers, upgrading them into powerful evolutions, and surviving endless waves of increasingly dangerous enemies.

## Run
1. Install Godot 4.2 or later.
2. Open `project.godot` in Godot.
3. Press Play.

## Controls

| Key | Action |
|-----|--------|
| **WASD** | Move |
| **1-9** | Select building to place |
| **Q/E/R/T** | Barracks / Armory / Tech Lab / Shrine |
| **Left Click** | Place building / Select tower |
| **U** (with tower selected) | Upgrade tower **or** Evolve a T3 tower |
| **G** | Toggle gate open/closed |
| **ESC** | Cancel placement / Close panels |
| **Mouse Wheel** | Zoom in/out |
| **1/2/3** (on tech pick screen) | Choose tech upgrade |

---

## Buildings

### Towers

| Tower | Cost | Range | Damage | Fire Rate | Special |
|-------|------|-------|--------|-----------|---------|
| **Arrow Turret** | 20 | 240 | 10 | 1.0/s | Pierces enemies |
| **Cannon Tower** | 30 | 230 | 22 | 0.6/s | Area explosion (80 radius) |
| **Tesla Tower** | 35 | 220 | 12 | 0.9/s | Chain lightning (3 targets) |

### Traps

| Trap | Cost | Effect |
|------|------|--------|
| **Mine Trap** | 12 | Explodes for 30 damage in 70 radius |
| **Ice Trap** | 16 | Slows enemies to 55% speed in 70 radius |
| **Acid Burst** | 20 | 22 damage, 2x bonus vs siege enemies |

### Utility Buildings

| Building | Cost | Effect |
|----------|------|--------|
| **Resource Generator** | 25 | +2 gold every 2 seconds |
| **Barracks** | 35 | Spawns allied soldiers every 30s |
| **Armory** | 40 | +2 damage bonus to all towers |
| **Tech Lab** | 45 | +8% fire rate to all towers |
| **Shrine** | 30 | Heals 4 HP/4s nearby + summons demons every 30s |
| **Wall** | 4 | Blocks enemy pathing (80 HP) |
| **Gate** | 6 | Wall you can toggle open/closed (90 HP) |

---

## Tower Upgrades (T1 > T2 > T3)

Select a tower and press **U** to upgrade. Each tier costs gold and improves stats.

### Arrow Turret
| Tier | Cost | Range | Damage | Fire Rate | Pierce |
|------|------|-------|--------|-----------|--------|
| T1 | 20 | 240 | 10 | 1.0 | 1 |
| T2 | 30 | 300 | 14 | 1.3 | 1 |
| T3 | 50 | 360 | 18 | 1.5 | 3 |

### Cannon Tower
| Tier | Cost | Range | Damage | Fire Rate | Blast Radius |
|------|------|-------|--------|-----------|-------------|
| T1 | 30 | 230 | 22 | 0.6 | 80 |
| T2 | 45 | 260 | 31 | 0.7 | 110 |
| T3 | 75 | 290 | 40 | 0.8 | 140 + cluster bombs + burn |

### Tesla Tower
| Tier | Cost | Range | Damage | Fire Rate | Chains | Special |
|------|------|-------|--------|-----------|--------|---------|
| T1 | 35 | 220 | 12 | 0.9 | 3 | — |
| T2 | 52 | 250 | 18 | 1.1 | 5 | — |
| T3 | 87 | 280 | 24 | 1.3 | 8 | Lightning storm, 25% stun |

---

## Tower Evolutions

T3 towers can **evolve** into a specialization using **Essence** (the purple crystal currency). Select a T3 tower and press **U** to pick one of two permanent paths.

### Arrow Turret Evolutions (3 Essence each)

| Evolution | Playstyle | Key Stats |
|-----------|-----------|-----------|
| **Gatling Turret** | Bullet hose | 4.0 fire rate, 8 damage, spins up over 2s |
| **Sniper Turret** | One-shot killer | 85 damage, 600 range, hitscan, infinite pierce |

### Cannon Tower Evolutions (4 Essence each)

| Evolution | Playstyle | Key Stats |
|-----------|-----------|-----------|
| **Hellfire Mortar** | Area denial | 200 blast radius, leaves fire pools (8 dmg/tick for 3s) |
| **Shockwave Cannon** | Crowd control | 120px knockback, 40% stun, faster fire rate |

### Tesla Tower Evolutions (3 Essence each)

| Evolution | Playstyle | Key Stats |
|-----------|-----------|-----------|
| **Storm Spire** | Zone damage | Permanent 200-radius lightning field (6 dmg every 0.5s) |
| **Arc Conduit** | Chain master | 15 chains, can re-hit targets, +10% damage per bounce |

---

## Essence

Purple crystal currency used for tower evolutions. Rare and valuable.

- **Elite enemies** always drop 1 Essence
- **Siege enemies** have a 50% chance to drop 1 Essence
- Appears as a purple glowing pickup — walk over it to collect

---

## Treasure Chests

Chests spawn periodically and contain **1-5 permanent upgrades** for the current run. Time slows during the opening sequence.

### Common Upgrades
| Upgrade | Effect |
|---------|--------|
| Firepower | +15% gun damage |
| Reach | +12% tower range |
| Swiftness | +10% move speed |
| Vitality | +20% max HP |
| Efficiency | -15% build cost |
| Quickload | -10% reload time |

### Rare Upgrades
| Upgrade | Effect |
|---------|--------|
| Precision | +8% crit chance |
| Devastation | +25% crit damage |
| Penetration | +1 pierce |
| Haste | -12% cooldowns |
| Magnetism | +30% pickup range |

### Epic Upgrades
| Upgrade | Effect |
|---------|--------|
| Double Tap | Fire 2 projectiles at once |
| Combustion | Projectiles explode on hit |
| Arc | Lightning chains to 3 extra targets |
| Life Drain | Heal 8% of damage dealt |

### Diamond Upgrades (~5% chance per chest)
| Upgrade | Effect |
|---------|--------|
| Multishot | Projectiles split into 2 on hit |
| Vampiric | 15% lifesteal on all damage |
| Chain Lord | Tesla bounces to 5 extra targets |
| Chronos | Slow-mo effects last 2x longer |
| Phoenix | Survive death once per wave at 1 HP |
| Fortress | Towers gain +50% HP and self-repair |

---

## Power-Ups

Spawn on the map every 60-90 seconds. Walk over them to activate. They blink before despawning.

| Power-Up | Color | Effect |
|----------|-------|--------|
| **Resource Cache** | Green | +500 gold instantly |
| **Time Crystal** | Cyan | Freeze all enemies for 5 seconds |
| **Ancient Relic** | Gold | Instantly upgrade a random tower to T3 |
| **Berserk Orb** | Red | 3x player damage for 15 seconds |

---

## Enemies

### Regular Types

| Enemy | Behavior |
|-------|----------|
| **Zombie** | Basic walker — heads straight for your base |
| **Charger** | Periodically charges at 2.8x speed |
| **Hellhound** | Quick dashes at 1.8x speed |
| **Spitter** | Ranged — shoots projectiles from a distance |
| **Banshee** | Screams to slow the player (0.6x speed for 1.4s) |
| **Necromancer** | Summons additional minions every 7s |
| **Plague Abomination** | Pulses 4 area damage every 6s + slows nearby |
| **Healer** | Heals nearby enemies 8 HP every 4s |

### Elites
Tougher versions of any enemy (2.2x health) with a special modifier:

| Modifier | Effect |
|----------|--------|
| **Aura** | Buffs nearby enemy damage |
| **Regen** | Regenerates 3 HP per second |
| **Splitter** | Splits into 2 smaller enemies on death |

Elites always drop **1 Essence + 3 gold**.

### Siege Enemies
Heavy enemies (2.6x HP, 0.7x speed, 1.8x damage) that **always target the player**. 50% chance to drop Essence.

### Bosses

| Boss | Appears At | Signature Moves |
|------|------------|-----------------|
| **Bone Colossus** | 5 min | Ground slam (40 dmg, 120 radius) |
| **Plague Bringer** | 10 min | Flies, spawns adds, poison clouds (15 DPS) |
| **Siegebreaker** | 15 min | 3000 HP shield, targets generators, fires mortars |
| **The Lich** | 20 min | Teleports, death nova (80 dmg), summons skeletons |

---

## Difficulty Curve

No discrete waves — difficulty ramps continuously. Enemies spawn faster and stronger over time.

| Time | Spawn Rate | Max Enemies | Elite % | Siege % |
|------|-----------|-------------|---------|---------|
| Start | 1.6s | 8 | 1% | 0% |
| 1 min | 1.15s | 18 | 2% | 3% |
| 3 min | 0.74s | 42 | 4.5% | 12% |
| 5 min | 0.54s | 78 | 7.5% | 24% |
| 7 min | 0.48s | 110 | 9.5% | 30% |
| 11+ min | 0.41s | 170 | 14% | 35% |

**Special events:**
- **2 min** — Bat Swarm (60 fast banshees)
- **4 min** — Plant Wall (18-28 plague abominations in formation)

---

## Tips

- Build **Resource Generators** early — income compounds fast
- Place **Ice Traps** at chokepoints to slow enemies into tower kill zones
- **Tesla Towers** shine against groups — evolve to **Arc Conduit** for swarm clear
- **Sniper Turret** one-shots most enemies but fires slowly — pair with crowd control towers
- **Hellfire Mortar** fire pools stack — multiple mortars on the same path melts bosses
- Save Essence for the evolution that complements your defense layout
- Grab **Power-Ups** before they despawn — Resource Cache (+500g) is game-changing early
- **Armory + Tech Lab** buff ALL your towers globally — build them once your core defense is solid
- Watch for the **Bat Swarm** at 2 minutes — have at least one Tesla Tower ready
