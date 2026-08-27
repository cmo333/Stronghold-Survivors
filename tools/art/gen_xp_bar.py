#!/usr/bin/env python3
"""Redraw the XP bar pair.

The v001 art was authored as a 384x16 plate whose lower half is a drop shadow:
rows 0-7 carry the gold fill and rows 8-15 are near-black socket. The HUD node is
260x10, so the whole 16 rows are squeezed into 10 and the bar renders as half
gold, half black at every fill level.

The empty plate is worse - it is near-black across every row (mean luma 0.026 to
0.044 over its opaque pixels), which is the reported "XP bar renders as a black
rectangle at 0%". It is not a rendering fault; the texture really is a black slab.

This writes a v002 pair drawn for the rect the bar actually occupies: artwork
across the full height, an empty slot that reads as an empty slot rather than a
hole, and the same gold the fill already used so the HUD palette is unchanged.

The alpha silhouette is lifted from the v001 empty plate, so the rounded ends and
overall shape are pixel-identical to what shipped and nothing about the layout
moves.

    python3 tools/art/gen_xp_bar.py
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
UI = ROOT / "assets" / "ui"
SRC_MASK = UI / "ui_bar_xp_empty_384x16_v001.png"
OUT_EMPTY = UI / "ui_bar_xp_empty_384x16_v002.png"
OUT_FILL = UI / "ui_bar_xp_384x16_v002.png"

W, H = 384, 16

# Empty slot: dark, but a slot. A rail you can see is what makes a fill of zero
# read as "nothing yet" instead of "nothing here".
EMPTY_TOP = (18, 23, 33)
EMPTY_BOTTOM = (11, 14, 21)
EMPTY_BORDER = (52, 64, 88)
EMPTY_INNER_SHADOW = (7, 9, 14)

# Fill: the gold the v001 plate already used at its brightest, carried all the
# way down instead of stopping halfway.
FILL_TOP = (255, 226, 130)
FILL_UPPER = (253, 196, 0)
FILL_LOWER = (186, 114, 0)
FILL_BOTTOM = (128, 74, 4)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def alpha_mask() -> Image.Image:
    src = Image.open(SRC_MASK).convert("RGBA")
    if src.size != (W, H):
        raise SystemExit("mask source is %s, expected %dx%d" % (src.size, W, H))
    return src.getchannel("A")


def build_empty() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        t = y / float(H - 1)
        base = lerp(EMPTY_TOP, EMPTY_BOTTOM, t)
        for x in range(W):
            c = base
            if y <= 1:
                # A lit top edge: the slot has a lip, so light catches it.
                c = EMPTY_BORDER
            elif y == 2:
                c = EMPTY_INNER_SHADOW
            elif y >= H - 2:
                c = EMPTY_BORDER
            px[x, y] = (c[0], c[1], c[2], 255)
    return img


def build_fill() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        t = y / float(H - 1)
        if t < 0.5:
            base = lerp(FILL_UPPER, FILL_LOWER, t / 0.5)
        else:
            base = lerp(FILL_LOWER, FILL_BOTTOM, (t - 0.5) / 0.5)
        for x in range(W):
            c = base
            if y <= 1:
                c = FILL_TOP
            elif y == H - 1:
                c = lerp(FILL_BOTTOM, (0, 0, 0), 0.35)
            px[x, y] = (c[0], c[1], c[2], 255)
    return img


def luma(c):
    return (c[0] * 0.299 + c[1] * 0.587 + c[2] * 0.114) / 255.0


def report(name, img):
    px = img.load()
    rows = []
    for y in range(H):
        vals = [luma(px[x, y]) for x in range(W) if px[x, y][3] > 200]
        rows.append(sum(vals) / len(vals) if vals else 0.0)
    flat = [v for v in rows if v > 0]
    print("%-38s rows %.3f..%.3f  mean %.3f" % (name, min(flat), max(flat), sum(flat) / len(flat)))
    return sum(flat) / len(flat)


def main() -> None:
    mask = alpha_mask()
    empty = build_empty()
    empty.putalpha(mask)
    fill = build_fill()
    fill.putalpha(mask)
    empty.save(OUT_EMPTY)
    fill.save(OUT_FILL)
    e = report(OUT_EMPTY.name, empty)
    f = report(OUT_FILL.name, fill)
    print("fill / empty luma ratio: %.1fx" % (f / e if e > 0 else 0.0))


if __name__ == "__main__":
    main()
