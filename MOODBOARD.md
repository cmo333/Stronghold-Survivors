# Moodboard

## Core Style Blend (Locked)
- **Halls of Torment**: gritty, high-contrast, pre-rendered-feel pixel shading and dramatic combat readability.
- **Warcraft 3 TD maps**: chunky, modular tower silhouettes and instantly readable base-defense shapes.
- **StarCraft 1 / Remastered**: industrial sci-fi material language, strong faction color coding, clean top-down readability.

## Image Search References
- [Google Images: Halls of Torment gameplay](https://www.google.com/search?tbm=isch&q=Halls+of+Torment+gameplay)
- [Google Images: Warcraft 3 tower defense towers](https://www.google.com/search?tbm=isch&q=Warcraft+3+tower+defense+map+towers)
- [Google Images: StarCraft 1 remastered sprites/buildings](https://www.google.com/search?tbm=isch&q=Starcraft+1+remastered+buildings+sprites)

## Fidelity Direction
- Move from flat/simple 32-style look to **higher-detail pixel assets** while keeping swarm performance.
- Keep tile grid at `32x32`, but increase perceived fidelity using:
- richer material rendering
- layered decals/overlays
- stronger light-value contrast
- Tower readability target:
- base tower body remains bold silhouette first
- detailed machinery and emissive accents second
- Combat readability target:
- high value separation between ground, towers, enemies, and VFX
- no low-contrast muddy blends during peak waves

## Animation Feel Target
- Every tower and evolution uses explicit motion states:
- idle, acquire, fire, recover, hit, upgrade, evolve, evolved idle
- Motion should read as weight + intent:
- anticipation -> impact -> settle
- Evolution should be visually unmistakable:
- new silhouette + new movement rhythm + new emissive language

## UI/UX Visual Tone
- Sci-fi command-console framing over fantasy parchment.
- Strong rarity color hierarchy and legible iconography.
- Keep battlefield primary; UI supports decisions without obscuring combat.
