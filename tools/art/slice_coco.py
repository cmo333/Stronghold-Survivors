#!/usr/bin/env python3
"""Slice the golden coco companion art into game-ready sprites.

    python3 tools/art/slice_coco.py [--sheet review.png]

Inputs (`assets/companion/source/`) are the delivered 1024px art. The sheet is
a 4x6 turnaround rather than a walk cycle: column 0 of every row is a rear
view and columns 1-3 turn progressively side-on, all facing LEFT. There is no
front-facing frame anywhere on it, and the bottom row is cropped mid-body.

So the in-world sprite is a single side-view run cycle taken from row 2 -- the
one row whose four frames share a facing and differ in leg and wing position --
and mirrored for eastward travel. A companion that scurries around the map at
speed reads fine on a mirrored side view; inventing a front pose that the art
does not contain would read worse than not having one.

Frames are aligned on their FEET, not their bounding boxes. Trimming each frame
to content and centring it makes the bird bob by however much the art's
silhouette happens to vary, which at this scale looks like it is being jostled
rather than running.
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "companion", "source")
OUT = os.path.join(ROOT, "assets", "companion")

# Grid measured off the delivered sheet rather than assumed: the cells are not
# an even division of the image, and the sixth row is a crop.
ROWS = [(28, 273), (310, 544), (583, 814), (851, 1086), (1128, 1361)]
COLS = [(39, 253), (272, 504), (524, 761), (777, 1014)]
RUN_ROW = 2

FRAME = 48          # in-world cell
BADGE = 64          # loot-card icon
FOOT_MARGIN = 3     # px of ground clearance inside the cell


def ink_mask(im):
    """Content mask that works whether the art is transparent or on white."""
    a = np.array(im)
    alpha = a[:, :, 3]
    rgb = a[:, :, :3].astype(int)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    return ((mx < 235) | ((mx - mn) > 28)) & (alpha > 8)


def content_box(im):
    m = ink_mask(im)
    ys, xs = np.where(m)
    if len(xs) == 0:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def whiten_to_alpha(im):
    """Drop the white paper the sheet is painted on, keeping soft edges."""
    a = np.array(im).astype(int)
    rgb, alpha = a[:, :, :3], a[:, :, 3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    # Near-white AND near-grey is background; saturated pixels are the bird.
    bg = (mx > 238) & ((mx - mn) < 14)
    alpha = np.where(bg, 0, alpha)
    a[:, :, 3] = alpha
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def build_run_strip(sheet):
    """Row `RUN_ROW`, four frames, scaled to a common foot baseline."""
    y0, y1 = ROWS[RUN_ROW]
    raw = []
    for x0, x1 in COLS:
        cell = whiten_to_alpha(sheet.crop((x0, y0, x1 + 1, y1 + 1)))
        box = content_box(cell)
        raw.append(cell.crop(box))

    # One scale for the whole cycle, driven by the tallest frame, so the bird
    # does not change size between frames.
    tallest = max(f.height for f in raw)
    scale = (FRAME - FOOT_MARGIN * 2) / float(tallest)

    strip = Image.new("RGBA", (FRAME * len(raw), FRAME), (0, 0, 0, 0))
    for i, f in enumerate(raw):
        w = max(1, int(round(f.width * scale)))
        h = max(1, int(round(f.height * scale)))
        small = f.resize((w, h), Image.LANCZOS)
        x = i * FRAME + (FRAME - w) // 2
        y = FRAME - FOOT_MARGIN - h      # feet on a shared baseline
        strip.alpha_composite(small, (x, max(0, y)))
    return strip


def build_badge(badge_src):
    box = content_box(badge_src)
    b = whiten_to_alpha(badge_src).crop(box)
    side = max(b.width, b.height)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(b, ((side - b.width) // 2, (side - b.height) // 2))
    return square.resize((BADGE, BADGE), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", help="write a magnified review image here")
    args = ap.parse_args()

    sheet_path = os.path.join(SRC, "coco_walk_sheet_v001.png")
    badge_path = os.path.join(SRC, "coco_badge_v001.png")
    for p in (sheet_path, badge_path):
        if not os.path.exists(p):
            print("missing source:", p, file=sys.stderr)
            return 2

    os.makedirs(OUT, exist_ok=True)
    strip = build_run_strip(Image.open(sheet_path).convert("RGBA"))
    strip_out = os.path.join(OUT, "companion_coco_%d_v001.png" % FRAME)
    strip.save(strip_out)
    print("wrote", strip_out, strip.size)

    badge = build_badge(Image.open(badge_path).convert("RGBA"))
    badge_out = os.path.join(OUT, "companion_coco_badge_%d_v001.png" % BADGE)
    badge.save(badge_out)
    print("wrote", badge_out, badge.size)

    if args.sheet:
        z = 5
        big = strip.resize((strip.width * z, strip.height * z), Image.NEAREST)
        canvas = Image.new("RGBA", (big.width, big.height + BADGE * 2 + 8), (34, 30, 26, 255))
        canvas.alpha_composite(big, (0, 0))
        canvas.alpha_composite(badge.resize((BADGE * 2, BADGE * 2), Image.NEAREST),
                               (0, big.height + 8))
        canvas.save(args.sheet)
        print("sheet", args.sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
