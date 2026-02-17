# Stronghold Survivors - Session Handoff

## Session 3: Tower Evolutions & Essence System (2026-02-16)

### New Feature: Essence Resource
- **Purple crystal currency** dropped by elite (guaranteed) and siege (50% chance) enemies
- Displayed in HUD below gold with purple color
- Used to pay for tower evolutions (3-4 Essence each)
- New "essence" pickup type with purple pulsing glow visual

**Files**: `main.gd` (add_essence), `enemy.gd` (drops), `pickup.gd` (essence type), `ui.gd` (HUD label)

### New Feature: Tower Evolution System (6 Specializations)
When a T3 tower exists and the player has enough Essence, pressing U opens an Evolution Choice panel (pick 1 of 2). Evolution is permanent and transforms the tower.

#### Arrow Turret Evolutions (Cost: 3 Essence)
- **Gatling Turret** — Rapid fire (4.0 rate), low damage (8), spin-up mechanic over 2s, barrel rotation visual, yellow tint
- **Sniper Turret** — Slow fire (0.3 rate), high damage (85), 600 range, hitscan instant-hit, red laser sight, pierces all enemies in line

#### Cannon Tower Evolutions (Cost: 4 Essence)
- **Hellfire Mortar** — Larger explosions (200 radius), leaves fire pools on impact (3s, 8 dmg/tick), orange fire visual
- **Shockwave Cannon** — Knockback (120px), 40% stun chance (0.5s), faster fire rate, blue energy ring visual

#### Tesla Tower Evolutions (Cost: 3 Essence)
- **Storm Spire** — Permanent lightning field (200 radius, 6 dmg/0.5s), fewer chains (4), doubles during storms, crackling circle visual
- **Arc Conduit** — 15 chains, can re-hit targets (ping-pong), +10% damage per bounce, dense lightning web visual

**Files**: `tower.gd` (evolution state/methods), `arrow_turret.gd`, `cannon_tower.gd`, `tesla_tower.gd` (evolution logic), `build_manager.gd` (evolution UI trigger + input), `ui.gd` (evolution choice panel)

### Evolution UI
- Centered panel with 2 choice cards (press 1 or 2 to select, ESC to cancel)
- Purple-themed with dark background, animated entrance/exit
- Shows name, description, and essence cost per option
- Cards greyed out if player can't afford
- Evolved towers show "EVO" badge instead of tier number
- Tower selection panel shows "[U: EVOLVE]" when evolution available

---

## Session 2: Performance & Polish (prior session)

### FX Spawn Order Fix
- Fixed 3,200+ "Parent not in tree" warnings by deferring FX spawning
- Root cause: `add_child()` called before parent was in scene tree

### Performance Optimizations
- Shared static QuadMesh and cached textures across all FX instances
- Lowered particle caps and spawn rates
- Reduced max enemy cap

### Camera Zoom
- Added mouse wheel zoom (in/out) to camera controller

### Tier Badges on Towers
- Floating tier numerals (I, II, III) above towers
- Color-coded: White T1, Cyan T2, Magenta T3

### NavigationServer2D (Attempted & Reverted)
- Tried enabling nav mesh pathfinding for enemies
- Enemies got stuck on obstacles — fully reverted to direct-line movement

### Walls/Gates Removed from Build Palette
- Cleaned up build options to remove non-functional wall/gate entries

---

## Session 1: Crash Fixes & Foundations (earliest session)

### Game Startup Crashes (FIXED)
- Camera type mismatch at main.gd:30
- add_child() during _ready() — used call_deferred()
- Disabled disorienting mouse lean camera effect

### Build System (FIXED)
- Disabled broken flood-fill path validation (returns true always)
- Added all missing input actions (upgrade, toggle_gate, cancel, build keys)

### Death Crashes (FIXED)
- spawn_death_particle wrong args — added optional parameters
- Added set_death_vignette() and spawn_soul_fragment() stubs

### Duplicate Member Errors (FIXED)
- Removed duplicate vars inherited from parent classes across all tower scripts

### Type Errors (FIXED)
- Array type mismatch in arrow_turret.gd
- Vector2i.distance_to in shockwave_ring.gd

### Selection Radius (FIXED)
- Increased from `radius * 1.5` to `max(radius * 3.0, 40.0)`

---

## Planned: Next Sprints

### Sprint 2: Tower Synergy Combos
- Proximity-based bonuses when specific tower pairs are within 200px
- 6 combos: Electro-Shot, Inferno, Overcharge, Kill Zone, Arcane Battery, War Machine
- Visual: glowing lines connecting synergized towers + discovery popup
- New file: `scripts/synergy_manager.gd`

### Sprint 3: Player Abilities
- 6 active abilities: Dash, Shield Dome, Airstrike, Overclock, Magnetic Pull, Rally Cry
- Unlocked via tech picks, mapped to ability slots (Q/E/R)
- Cooldown-based with HUD indicators

### Sprint 4: Balance & Polish
- Evolution cost/power tuning
- Synergy bonus balancing
- Ability cooldown tuning
- Visual polish pass

See full plan: `.claude/plans/optimized-whistling-blossom.md`

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `scripts/main.gd` | Game state, spawning, economy (essence + gold), ~2300 lines |
| `scripts/tower.gd` | Base tower class, evolution state, synergy bonus tracking |
| `scripts/arrow_turret.gd` | Arrow tower + Gatling/Sniper evolutions |
| `scripts/cannon_tower.gd` | Cannon tower + Hellfire/Shockwave evolutions |
| `scripts/tesla_tower.gd` | Tesla tower + Storm Spire/Arc Conduit evolutions |
| `scripts/build_manager.gd` | Build/upgrade/evolution input, selection |
| `scripts/ui.gd` | All UI panels, evolution choice, essence HUD |
| `scripts/enemy.gd` | Enemy AI, death drops (gold, XP, essence) |
| `scripts/pickup.gd` | Pickup types: gold, heal, essence |
| `data/structures.json` | Tower/building stat definitions |
