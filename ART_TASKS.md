# Art Task List (Mars Pivot)

## Guardrails (Do Not Regress Gameplay)
- Keep pathing readability first (tile silhouettes and blockers must stay obvious).
- Preserve current collision/footprint sizes while visuals are replaced.
- Re-export all sprites at **native size** (no upscale).
- If upscale is unavoidable, include **scale factor** in a text note.

## Priority 1 (Theme Pivot First Pass)
- Mars terrain base kit (32x32): red dust, compacted regolith, cracked stone, dark basalt.
- Mars path kit (32x32): traversable lane variants + edge transitions that clearly read as path.
- Mars terrain edges/corners (32x32): dust-to-rock and dust-to-path transitions.
- Build blockers for space theme (32x32/64x64): modular metal wall/gate variants that read cleanly in swarms.
- Replace **Arrow Turret** visuals with **Missile Turret** visuals (64x64, 4+ frames idle/active).
- Update **Cannon Tower** visuals for space-industrial look (64x64, 4+ frames idle/active).
- Upgrade/build UI pass: sci-fi panel style matching the new North Star (space extraction / combat engineer).

## Priority 2 (Animation Smoothness Pass)
- Increase motion consistency on tower idle loops (continuous pulses/rotations, no stepped timing).
- Add smoother active fire loops for Missile Turret and Cannon Tower (recoil/vents/spin cadence).
- Refresh player/enemy locomotion timing to feel more even at current game speed (no gameplay stat changes).
- Standardize frame counts for key loops where possible (target 6-8 frames for hero towers/units that need it).

## Priority 3 (Mood + Variety, Space Set Dressing)
- Props: extractors, antennae, cargo crates, hazard beacons, broken rover debris (32/48/64).
- Additional enemies reskinned toward alien/planet-defense theme while preserving silhouettes.
- FX pass for sci-fi combat: missile exhaust, impact sparks, dust plumes, explosions, shield/electric hits.
- Upgrade reward card/icon polish for rarity readability on the new UI theme.

## Deferred (Intentional)
- Music/audio composition remains deferred for now (user will handle later).
