# Tech/Upgrade Visuals Process

## Goals
- Make tech choices feel high-impact and readable at a glance.
- Add persistent build identity during the run.
- Make tower upgrades visually obvious in-world.

## Assets Generated (Image API)
UI panels and overlays live in `assets/ui/tech/`:
- `ui_tech_panel_480x320_v001.png` — Tech pick panel background.
- `ui_tech_card_common_420x74_v001.png` — Tech option card (common).
- `ui_tech_card_rare_420x74_v001.png` — Tech option card (rare).
- `ui_tech_card_epic_420x74_v001.png` — Tech option card (epic).
- `ui_tech_card_diamond_420x74_v001.png` — Tech option card (diamond).
- `ui_tech_ledger_360x56_v001.png` — “Build Path” tech ledger bar.
- `ui_upgrade_halo_t1_96_v001.png` — Tier 1 halo (unused; kept for expansion).
- `ui_upgrade_halo_t2_96_v001.png` — Tier 2 halo (active).
- `ui_upgrade_halo_t3_96_v001.png` — Tier 3 halo (active).
- `ui_upgrade_halo_evo_96_v001.png` — Evolution halo (active).

## Wiring Summary
- Tech panel styling and card frames are wired in `scripts/ui.gd`.
- Tech ledger (build history row) is built and updated in `scripts/ui.gd`.
- Tech ledger is refreshed on every tech pick in `scripts/main.gd`.
- Tower upgrade halos are wired in `scripts/tower.gd`.

## Mapping & Usage
Tech panel visuals:
- `TECH_PANEL_TEX` -> `ui_tech_panel_480x320_v001.png`
- `TECH_CARD_TEXTURES[rarity]` -> card frames per rarity
- Tech option labels and icons are positioned to align with the cards

Tech ledger:
- `TECH_LEDGER_TEX` -> `ui_tech_ledger_360x56_v001.png`
- Uses existing tech icons from `tech_defs`
- Shows top 8 picked techs with stack counts

Tower halos:
- Tier 2 -> `ui_upgrade_halo_t2_96_v001.png`
- Tier 3 -> `ui_upgrade_halo_t3_96_v001.png`
- Evolved -> `ui_upgrade_halo_evo_96_v001.png`
- Halos are additive blend sprites positioned behind the tower body

## Notes
- Panels and cards are sized for pixel-friendly scaling and crisp edges.
- If we add new tech icons later, update `tech_defs` in `scripts/main.gd`.
