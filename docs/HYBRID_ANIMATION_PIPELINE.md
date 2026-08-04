# Hybrid Animation Pipeline

This project should use a hybrid animation pipeline for gameplay actors.

## Why

Direct AI-generated frame sequences are not stable enough for final gameplay sprites. They drift in silhouette, lighting, and perspective. That drift reads as choppy motion when many units are on screen.

The correct use of AI for this project is:

- style exploration
- silhouette exploration
- motion studies and previs
- short FX ideation

The correct use of the game runtime is:

- aiming
- recoil
- anticipation
- settle
- secondary motion
- stable frame pacing

## Core Rule

Use AI to discover motion. Do not use AI to author final long gameplay sprite sequences.

Final in-game motion should come from one of these:

- procedural runtime motion
- short controlled sprite sheets
- split sprite presentation
- additive overlays and impact FX

## Tower Standard

Towers should follow a shared presentation contract:

- static or mostly static lower chassis
- rotating upper weapon or focus head
- short windup before firing
- readable muzzle event on release
- recoil on the weapon section, not the whole silhouette
- short recovery settle

### Tower Motion Beats

Each tower attack should read as:

1. acquire
2. windup
3. fire release
4. recoil
5. settle

### Tower Tuning Targets

- missile: fast tracking, medium recoil, strong muzzle flash, aggressive projectile readability
- cannon: slow traverse, heavy anticipation, heavy recoil, slower settle
- tesla: medium tracking, energy charge, snap release, brief afterglow
- flamethrower: limited traverse, cone sustain, visible nozzle pressure
- spike burst: snap acquire, radial release, low recoil, strong impact readability

## Character And Monster Standard

Characters and monsters should use a hybrid pipeline too:

- AI motion studies for gait and attack timing
- hand-selected key poses
- controlled gameplay sprite sheets for locomotion and attack cycles
- additive overlays for charge, hit, death burst, or elemental state

### Minimum Readability Requirement

At gameplay zoom, the player must be able to identify within one second:

- what is attacking
- where it is facing
- when it is about to fire
- what kind of projectile or damage it is using

## Production Workflow

### Phase A: Motion Study

Generate short reference clips per action only:

- idle
- move
- attack
- hit react
- death

Keep them short, single-angle, and anchored to one clear silhouette.

### Phase B: Beat Extraction

For each clip, extract:

- anticipation length
- release frame
- recoil distance or angle
- settle duration
- secondary motion lag

### Phase C: Runtime Build

Implement those beats in-engine first.

Only create sprite sheets when procedural motion is not enough.

### Phase D: Swarm Test

Nothing passes unless it still reads under combat density.

## Current Direction For Stronghold Survivors

The project should move toward:

- split-body towers for readability
- procedural tower attack motion
- stable 30 FPS render pacing with 60 Hz simulation
- short, high-contrast FX bursts
- controlled sprite sheets for living units

## Do Not Do

- do not ship long AI-generated frame sequences for towers
- do not mix multiple sprite fidelities in the same presentation pass
- do not add more towers before one tower feels correct
- do not judge motion from isolated art only; judge it at gameplay zoom and density

## Next Gold Standard Target

The missile tower remains the reference implementation target.

It should be the first tower to fully satisfy:

- stable silhouette
- readable south-facing idle pose
- clean upper-body target tracking
- muzzle and projectile release sync
- impact readability at swarm density
- no drift across tiers or evolutions
