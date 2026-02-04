# Notes

## Current Prototype Systems
- Player: top-down movement + auto-attack.
- Spawner: continuous scaling enemy spawn with siege units.
- Added enemy variants: banshee, necromancer, hellhound, fiend duelist, plague abomination.
- Enemy behaviors: banshee slow pulse, necromancer summons, hellhound dash, plague abomination poison pulse.
- Economy: coins from enemies and breakables; spend on structures.
- XP + Tech Picks: choose 1 of 3 upgrades, mixes gun and tower tech.
- Build system: grid snap, placement validation, selection, upgrades.
- Structures: Arrow, Cannon, Tesla, Mine, Ice, Acid, Wall, Gate, Resource Generator, Stronghold Core, Barracks, Armory, Tech Lab, Shrine.
- Building effects: Barracks fires bolts, Armory boosts player damage, Tech Lab boosts tower fire rate, Shrine heals nearby units.

## Design Lessons (Applied)
- Readability ramps, never floods.
- Upgrades must be visually and mechanically obvious.
- Rare tiers must feel stronger and more unique.
- Pickups should aid flow, not block movement.
- Content volume cannot replace cohesion.
- Performance must be capped under heavy spam.

## North Star Reminder
- Minute 5: the map is shaped.
- Minute 15: the fortress is alive.
- The maze is your weapon; the gun is your lifeline.

## Next Design Questions
- Gate behavior (open/close lanes) and pathing rules.
- Chest loot tables and Diamond event drops.
- More tower paths beyond Arrow/Tesla tech.
