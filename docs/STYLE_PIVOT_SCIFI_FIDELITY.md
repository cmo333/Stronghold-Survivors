# Style Pivot: Sci-Fi Fidelity Blend (v1)

## What We Are Changing
- We are moving from a simpler 32-style visual read toward a denser, higher-fidelity pixel style.
- The style blend is:
- Halls of Torment combat readability
- Warcraft 3 TD tower silhouette language
- StarCraft 1 industrial sci-fi material language

## External Reference Notes
- Halls of Torment store page emphasizes a pre-rendered, 90s-style visual direction:
- [Steam: Halls of Torment](https://store.steampowered.com/app/2218750/Halls_of_Torment/)
- Warcraft 3 visual refresh references show “uprezzed” fidelity while keeping recognizable gameplay readability:
- [Polygon coverage of Warcraft III: Reforged reveal](https://www.polygon.com/blizzcon/2018/11/2/18056598/warcraft-3-reforged-remaster-gameplay)
- StarCraft Remastered references emphasize HD visuals while preserving original gameplay readability:
- [IGN: StarCraft: Remastered gets first screenshots](https://www.ign.com/articles/2017/03/26/starcraft-remastered-gets-first-screenshots)
- Direct image-search launch points for continued visual picking:
- [Google Images: Halls of Torment gameplay](https://www.google.com/search?tbm=isch&q=Halls+of+Torment+gameplay)
- [Google Images: Warcraft 3 tower defense towers](https://www.google.com/search?tbm=isch&q=Warcraft+3+tower+defense+map+towers)
- [Google Images: StarCraft 1 remastered buildings sprites](https://www.google.com/search?tbm=isch&q=Starcraft+1+remastered+buildings+sprites)

## Practical Fidelity Targets
- Keep terrain on `32x32` grid for build/path logic.
- Increase perceived fidelity through:
- higher-detail tower sprites and overlays
- tighter shading ramps
- emissive accents and mechanical sub-components
- controlled decal layers on terrain
- Keep combat legibility hard constraints:
- silhouettes stay clean at zoomed-out view
- no terrain texture noise that competes with enemies/projectiles

## Tower Visual Language
- Missile Turret:
- military-industrial body, animated launcher head, recoil-heavy fire beat
- Cannon Tower:
- heavy chassis compression, smoke/heat exhaust, low cadence impact feel
- Tesla Tower:
- coil charge states, arc rhythm, electric field signatures
- Evolutions:
- each evolution must have unique silhouette + unique idle/fire rhythm

## Asset Production Rule
- “Detail up, clutter down”:
- add fidelity in local sprite shading/materials
- reduce random noise and unnecessary overlays
- this keeps both quality and readability in late-wave chaos

## Execution Order
1. Tower bodies and state animations (base tiers).
2. Evolution art + transform animation sets.
3. Terrain cleanup to support new tower readability.
4. UI skin pass toward sci-fi command-console presentation.
