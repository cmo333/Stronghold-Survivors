#!/usr/bin/env python3
"""Slice the space-station + blight terrain sheets into 32x32 opaque ground tiles.

ground.gd renders terrain via a TileMap of 32x32 tiles and REJECTS any tile that
has a transparent pixel (_is_full_coverage_texture). So every tile here is forced
fully opaque (alpha 255) after downscaling.

Sheets (all row-major):
  space_clean : 3x2 grid -> 6 clean deck-plating variants     -> tile_space_deck_<a..f>_32
  space_worn  : 3x2 grid -> 6 worn/scorched hull variants      -> tile_space_hull_<a..f>_32
  blight_full : 3x2 grid -> 6 full blight-floor variants       -> tile_blight_base_<a..f>_32

(blight_edges, the 3x3 transition sheet, is intentionally skipped: ground.gd places
tiles per-cell without edge autotiling, so the full blight variants are what the
bonus-zone painter uses. The edge sheet can be wired later if autotiling is added.)
"""
import os
from PIL import Image

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJ, "assets", "level1", "level1_terrain_space")
DL = "/Users/mycomputer/Downloads/space terrain:blight patch"

TILE = 32
LETTERS = "abcdef"

# (source_file, cols, rows, output_prefix, count)
JOBS = [
    (os.path.join(DL, "ChatGPT Image Jun 19, 2026, 09_11_03 PM.png"), 3, 2, "tile_space_deck", 6),
    (os.path.join(DL, "ChatGPT Image Jun 19, 2026, 09_12_23 PM.png"), 3, 2, "tile_space_hull", 6),
    (os.path.join(DL, "ChatGPT Image Jun 19, 2026, 09_08_15 PM.png"), 3, 2, "tile_blight_base", 6),
]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for src, cols, rows, prefix, count in JOBS:
        im = Image.open(src).convert("RGB")
        w, h = im.size
        cw, ch = w // cols, h // rows
        # Inset a few px to avoid grabbing the seam/border lines between cells.
        inset = max(2, cw // 40)
        idx = 0
        for r in range(rows):
            for c in range(cols):
                if idx >= count:
                    break
                box = (c * cw + inset, r * ch + inset,
                       (c + 1) * cw - inset, (r + 1) * ch - inset)
                cell = im.crop(box).resize((TILE, TILE), Image.LANCZOS)
                # Force fully opaque RGBA so ground.gd accepts it as full-coverage.
                cell = cell.convert("RGBA")
                px = cell.load()
                for y in range(TILE):
                    for x in range(TILE):
                        rr, gg, bb, _ = px[x, y]
                        px[x, y] = (rr, gg, bb, 255)
                out = os.path.join(OUT_DIR, "%s_%s_32_v001.png" % (prefix, LETTERS[idx]))
                cell.save(out)
                idx += 1
        print("%s: %d tiles (cell %dx%d)" % (prefix, idx, cw, ch))


if __name__ == "__main__":
    main()
