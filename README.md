# Stronghold Survivors

Vampire Survivors movement and chaos with a player-built stronghold, built in Godot.

## Run
1. Install Godot 4.2 or later.
2. Open `projects/stronghold-survivors/project.godot` in Godot.
3. Press Play.

## Controls
- WASD / Arrow Keys: Move
- B: Toggle build mode
- 1-9: Select build (Arrow, Cannon, Tesla, Mine, Ice, Acid, Wall, Gate, Resource Gen)
- Q/E/R/T: Barracks / Armory / Tech Lab / Shrine
- Left Click: Place or select building
- U: Upgrade selected building
- G: Toggle gate open/closed
- Esc: Cancel build mode
- Tech Picks: When shown, press 1/2/3 to choose

## Prototype Contents
- Player auto-attacks nearest enemy with upgradeable gun tech.
- Enemies spawn in a widening ring and scale over time.
- Siege enemies target buildings; regular enemies chase the player.
- Resource drops and pickup economy.
- Breakable pots/chests for loot and XP.
- Build placement with grid snap and collision check.
- Three towers and three traps plus walls, data-driven via `data/structures.json`.
- Tech picks (choose 1 of 3) mix gun and tower upgrades.
