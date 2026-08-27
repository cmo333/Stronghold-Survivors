# Colab Pro Quickstart (Phase 3 FX)

Use this when you want to run the Phase 3 hero FX batch on Colab GPU.

## Notebook
- `/Users/mycomputer/Documents/New project/projects/stronghold-survivors/tools/colab/stronghold_phase3_fx_colab.ipynb`

## What You Need To Do
1. Open Colab and upload the notebook above.
2. Set runtime to GPU:
- `Runtime -> Change runtime type -> T4 GPU` (or better).
3. Run cells top-to-bottom.

## Required Drive Folder Layout
The notebook expects:
- `/MyDrive/stronghold_fx/src/tower_evolution/*.png`
- `/MyDrive/stronghold_fx/src/elite_death/*.png`
- `/MyDrive/stronghold_fx/src/boss_death/*.png`
- `/MyDrive/stronghold_fx/src/cannon_impact/*.png`
- `/MyDrive/stronghold_fx/src/energy_impact/*.png`

Output will be written to:
- `/MyDrive/stronghold_fx/out/<job>/...`
- `/MyDrive/stronghold_fx/stronghold_phase3_fx_batch.zip`

## Optional BiRefNet
The notebook supports BiRefNet command templating via:
- `RUN_BIREFNET_CMD = "..."` in the config cell.

If left empty, it runs luma-alpha mode (still valid for first pass).

## What To Send Back
Send me one of:
1. Path to `/MyDrive/stronghold_fx/stronghold_phase3_fx_batch.zip`, or
2. The zip downloaded from Colab.

Then I will wire those frames into:
- `tower_evolution`
- `elite_death`
- `boss_death`
- `cannon_impact`
- `energy_impact`

## Notes
- Keep source sequences short for first pass (4-12 frames each).
- We will tune per-effect scale/FPS in-engine after first import.
