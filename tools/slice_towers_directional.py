#!/usr/bin/env python3
"""Slice the cannon/tesla 4x2 directional grids into per-heading PNGs.

Each source image is a 4-column x 2-row grid of the SAME tower rotated through 8
compass headings. Reading order (row-major) is mapped to headings:

    cell 0 (top-left)  -> N
    cell 1             -> NE
    cell 2             -> E
    cell 3 (top-right) -> SE
    cell 4 (bot-left)  -> S
    cell 5             -> SW
    cell 6             -> W
    cell 7 (bot-right) -> NW

The ChatGPT exports ship with an opaque near-white background that is flood-filled
to alpha from the edges. Each sliced cell is cropped to the union content bbox
(shared across all 8 of that tower's cells so they don't jitter) and saved at full
resolution as <prefix>_<DIR>.png in assets/level1/towers_directional/.
"""
import os
from PIL import Image

PROJ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJ, "assets", "level1", "towers_directional")

HEADINGS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
COLS, ROWS = 4, 2

# (source_path, output_prefix)
JOBS = [
    ("/Users/mycomputer/Downloads/cannon1/ChatGPT Image Jun 19, 2026, 08_57_25 PM.png", "cannon_t1"),
    ("/Users/mycomputer/Downloads/cannon2/ChatGPT Image Jun 19, 2026, 08_58_11 PM.png", "cannon_t2"),
    ("/Users/mycomputer/Downloads/tesla1/ChatGPT Image Jun 19, 2026, 09_00_18 PM.png", "tesla_t1"),
    ("/Users/mycomputer/Downloads/tesla2/ChatGPT Image Jun 19, 2026, 09_02_24 PM.png", "tesla_t2"),
]


def is_bg(p):
    r, g, b = p[0], p[1], p[2]
    return r >= 236 and g >= 236 and b >= 236 and abs(r - g) < 14 and abs(g - b) < 14 and abs(r - b) < 14


def strip_bg(im):
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        stack.append((x, 0)); stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y)); stack.append((w - 1, y))
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        idx = y * w + x
        if seen[idx]:
            continue
        seen[idx] = 1
        if not is_bg(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack.append((x + 1, y)); stack.append((x - 1, y))
        stack.append((x, y + 1)); stack.append((x, y - 1))
    return im


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for src, prefix in JOBS:
        im = Image.open(src)
        w, h = im.size
        cw, ch = w // COLS, h // ROWS
        cells = []
        for r in range(ROWS):
            for c in range(COLS):
                box = (c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)
                cells.append(strip_bg(im.crop(box)))
        # Shared union bbox so all 8 headings keep a consistent footprint.
        union = None
        for cell in cells:
            bb = cell.getbbox()
            if bb is None:
                continue
            if union is None:
                union = list(bb)
            else:
                union[0] = min(union[0], bb[0]); union[1] = min(union[1], bb[1])
                union[2] = max(union[2], bb[2]); union[3] = max(union[3], bb[3])
        if union is None:
            print("WARN: empty", prefix)
            continue
        for i, dir_key in enumerate(HEADINGS):
            cropped = cells[i].crop((union[0], union[1], union[2], union[3]))
            out = os.path.join(OUT_DIR, "%s_%s.png" % (prefix, dir_key))
            cropped.save(out)
        print("%s: cell %dx%d -> union %s (%dx%d), 8 frames" % (
            prefix, cw, ch, union, union[2] - union[0], union[3] - union[1]))


if __name__ == "__main__":
    main()
