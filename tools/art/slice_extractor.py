#!/usr/bin/env python3
"""Slice the delivered extractor sheet into game-sized animation frames.

The sheet is 5x3 renders of the same building with a green plume at different
heights. Two things have to be true of the output or the building will not read
as one object animating:

  * every frame must share ONE scale factor, or the stonework breathes; and
  * every frame must be anchored on the STONE BASE, not on its own bounding box.

The second point is the whole job. The plume is what changes between frames, so
normalising each frame by its own bbox -- the obvious thing, and what a generic
slicer does -- pins the *plume* in place and makes the building underneath jump
around beneath it. Measured on this sheet, the base is rock steady (width 156-159
in all 15 cells, ground line identical within a row) while the full bbox height
swings 201-249. So the anchor is the base: its horizontal centre and the ground
line it sits on.

Frames are written in sheet reading order. The order they are *played* in is a
separate decision and lives in resource_generator.tscn, where it can be seen and
changed without re-cutting the art.
"""

import os
from PIL import Image
import numpy as np

SHEET = os.environ.get("EXTRACTOR_SHEET", "sheet.png")
ICON_SRC = os.environ.get("EXTRACTOR_ICON", "")
OUT_DIR = os.environ.get(
    "EXTRACTOR_OUT",
    "assets/level1/level1_buildings_traps_anim60",
)
OUT_FMT = "building_resource_generator_2x2_active_f%03d_v002.png"
ICON_OUT = os.environ.get(
    "EXTRACTOR_ICON_OUT",
    "assets/ui_build_icons/ui_build_resource_generator_32_v001.png",
)

# Build-bar icons are 32x32. The delivered render is 529x909 -- over 70% plume --
# and fitting all of it leaves the stonework 17px wide, thinner than anything
# else on the bar. Dropping the top 15% of the plume widens the base to 21px
# while still leaving a tapered tip inside the frame, so it reads as a jet
# rather than as a column cut off by the border.
ICON_SIZE = 32
ICON_INNER = 30
ICON_PLUME_TRIM = 0.15

# Cell boundaries. The sheet does not divide evenly -- the rows are 273/247/230
# tall -- so these are the measured gutters, not width/5 and height/3.
COLS = [(0, 225), (225, 450), (450, 675), (675, 900), (900, 1125)]
ROWS = [(0, 273), (273, 520), (520, 750)]

ALPHA_CUT = 16          # below this is sheet background, not art
BASE_BAND = 0.28        # bottom fraction of the content that is stonework only

# Match the outgoing v001 art so nothing else has to move: its base spans ~48px
# and its ground line sits 23px below the sprite centre. Keeping both means the
# new building lands on exactly the same footprint, health bar and beacon.
TARGET_BASE_W = 48.0
FRAME_W = 96
FRAME_H = 112
GROUND_Y = FRAME_H // 2 + 23


def cell_metrics(alpha, box):
    """Content bbox plus the base anchor (centre-x, ground-y) for one cell."""
    (x0, x1), (y0, y1) = box
    sub = alpha[y0:y1, x0:x1]
    ys = np.where(sub.any(axis=1))[0]
    xs = np.where(sub.any(axis=0))[0]
    cy0, cy1 = int(ys[0]), int(ys[-1])
    cx0, cx1 = int(xs[0]), int(xs[-1])
    band_top = cy1 - int((cy1 - cy0 + 1) * BASE_BAND)
    bxs = np.where(sub[band_top:cy1 + 1].any(axis=0))[0]
    return {
        "bbox": (x0 + cx0, y0 + cy0, x0 + cx1, y0 + cy1),
        "base_w": int(bxs[-1] - bxs[0] + 1),
        "base_cx": x0 + (int(bxs[0]) + int(bxs[-1])) / 2.0,
        "ground": y0 + cy1,
    }


def resize_premultiplied(img, size):
    """Downscale without dark fringes.

    The sheet's transparent pixels are black, so filtering straight RGBA bleeds
    black into every soft edge -- which on a glowing green plume is exactly the
    wrong direction.
    """
    a = np.asarray(img, dtype=np.float64) / 255.0
    a[..., :3] *= a[..., 3:4]
    small = np.asarray(
        Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGBA")
        .resize(size, Image.LANCZOS),
        dtype=np.float64,
    ) / 255.0
    alpha = np.clip(small[..., 3:4], 0.0, 1.0)
    rgb = np.divide(small[..., :3], alpha, out=np.zeros_like(small[..., :3]), where=alpha > 1e-4)
    out = np.concatenate([np.clip(rgb, 0.0, 1.0), alpha], axis=-1)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


def build_icon(path):
    """Cut the standalone hero render down to a 32x32 build-bar icon."""
    im = Image.open(path).convert("RGBA")
    alpha = np.array(im)[..., 3] > ALPHA_CUT
    ys = np.where(alpha.any(axis=1))[0]
    xs = np.where(alpha.any(axis=0))[0]
    top = int(ys[0] + (ys[-1] - ys[0] + 1) * ICON_PLUME_TRIM)
    crop = im.crop((int(xs[0]), top, int(xs[-1]) + 1, int(ys[-1]) + 1))
    scale = min(ICON_INNER / crop.width, ICON_INNER / crop.height)
    w = max(1, int(round(crop.width * scale)))
    h = max(1, int(round(crop.height * scale)))
    icon = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    # Bottom-anchored, like every other build icon: they all sit on the same
    # line so the bar does not look like it is bobbing.
    icon.alpha_composite(resize_premultiplied(crop, (w, h)), ((ICON_SIZE - w) // 2, ICON_SIZE - 1 - h))
    os.makedirs(os.path.dirname(ICON_OUT), exist_ok=True)
    icon.save(ICON_OUT)
    print("icon -> %s  (%dx%d in %d)" % (ICON_OUT, w, h, ICON_SIZE))


def main():
    if ICON_SRC:
        build_icon(ICON_SRC)
    sheet = Image.open(SHEET).convert("RGBA")
    alpha = np.array(sheet)[..., 3] > ALPHA_CUT

    cells = [
        cell_metrics(alpha, (c, r))
        for r in ROWS
        for c in COLS
    ]

    # One scale for all 15, off the mean base width. Per-frame scaling would let
    # the ~2% render-to-render variation in the stonework show up as a wobble.
    scale = TARGET_BASE_W / (sum(c["base_w"] for c in cells) / len(cells))
    os.makedirs(OUT_DIR, exist_ok=True)
    print("scale %.5f  (mean base %.1f px -> %.0f px)" % (
        scale, sum(c["base_w"] for c in cells) / len(cells), TARGET_BASE_W))

    for i, c in enumerate(cells, start=1):
        bx0, by0, bx1, by1 = c["bbox"]
        crop = sheet.crop((bx0, by0, bx1 + 1, by1 + 1))
        w = max(1, int(round(crop.width * scale)))
        h = max(1, int(round(crop.height * scale)))
        small = resize_premultiplied(crop, (w, h))

        # Anchor: the base's centre lands on the frame's centre column, and the
        # ground line lands on GROUND_Y. Everything above follows from that.
        dx = int(round(FRAME_W / 2.0 - (c["base_cx"] - bx0) * scale))
        dy = int(round(GROUND_Y - (c["ground"] - by0) * scale))

        frame = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
        frame.alpha_composite(small, (dx, dy))
        path = os.path.join(OUT_DIR, OUT_FMT % i)
        frame.save(path)

        fa = np.array(frame)[..., 3] > ALPHA_CUT
        ys = np.where(fa.any(axis=1))[0]
        print("f%02d -> %s  top=%d ground=%d" % (i, os.path.basename(path), ys[0], ys[-1]))


if __name__ == "__main__":
    main()
