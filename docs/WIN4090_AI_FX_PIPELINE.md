# Windows 4090 AI FX Pipeline

This is the local GPU batch path for hero FX and special set-piece sprites.

Use script:
- `/Users/mycomputer/Documents/New project/projects/stronghold-survivors/tools/win4090_biref_batch.py`

If you prefer cloud GPU, use Colab Pro quickstart:
- `/Users/mycomputer/Documents/New project/projects/stronghold-survivors/docs/COLAB_PRO_QUICKSTART.md`

## What It Does
1. Optional external BiRefNet inference run.
2. Builds luma-derived alpha from source frames.
3. Merges alpha as `max(biref_alpha, luma_alpha)`.
4. Optional downscale + palette reduction.
5. Exports processed PNG sequence and optional sprite sheet.

## Install (Windows)
```powershell
py -m pip install pillow
```

## Example A: Process Existing Source + BiRefNet Mattes
```powershell
py tools\win4090_biref_batch.py `
  --input D:\stronghold\fx_src\mortar_burst `
  --biref-dir D:\stronghold\fx_biref\mortar_burst `
  --output D:\stronghold\fx_out\mortar_burst `
  --luma-threshold 22 `
  --luma-gamma 1.15 `
  --luma-gain 1.2 `
  --downscale 2 `
  --palette-colors 32 `
  --sheet-cols 8
```

## Example B: Run BiRefNet First, Then Merge
```powershell
py tools\win4090_biref_batch.py `
  --input D:\stronghold\fx_src\tesla_arc `
  --output D:\stronghold\fx_out\tesla_arc `
  --run-birefnet-cmd "py D:\BiRefNet\inference.py --input {input} --output {output}" `
  --downscale 2 `
  --palette-colors 24 `
  --sheet-cols 10
```

## Output
- Processed frames: `<output>\*.png`
- Batch report: `<output>\batch_report.json`
- Optional sheet: `<output>\sheet.png` (or `--sheet-output`)

## Recommended Usage In Stronghold
- Use this for:
  - evolution transform bursts
  - elite/boss death hero FX
  - large impact set-pieces
- Do not use for:
  - high-frequency core tower fire loops (handled procedurally in-engine)
