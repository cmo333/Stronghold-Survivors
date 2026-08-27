#!/usr/bin/env python3
"""Slice the 8 hunter_1 ChatGPT walk strips into a Godot 8-direction sprite set.

Each source strip is 2172x724 = 4 frames of 543x724. The strips ship with an
opaque near-white checkerboard background that must be flood-filled to alpha.

Heading mapping is chosen so left/right facings are guaranteed correct by
mirroring a single left-facing source for the right-facing direction (and the
up-right source for up-left). This fixes the "moonwalk" where a right-facing
pose was used while walking west.

  S  = strip 1 (faces viewer/down)
  N  = strip 2 (faces away/up)
  W  = strip 4 (clean left profile)
  E  = mirror(strip 4)            -> faces right
  SW = strip 5 (down-left)
  SE = mirror(strip 5)            -> faces down-right
  NE = strip 3 (up-right, away)
  NW = mirror(strip 3)            -> faces up-left

Output: assets/level1/level1_player_anim_hunterv2/player_hunterv2_32_<DIR>_move_f00N_v001.png
"""
import os
import glob
from PIL import Image

SRC_DIR = "/Users/mycomputer/Downloads/hunter_1"
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "level1", "level1_player_anim_hunterv2",
)
PREFIX = "player_hunterv2_32"
FRAMES = 4
FW = 543
FH = 724
TARGET_H = 40  # smaller than the old 48 so the player isn't oversized on screen

# (strip_index_1based, mirror_horizontally)
MAP = {
    "S":  (1, False),
    "N":  (2, False),
    "W":  (4, False),
    "E":  (4, True),
    "SW": (5, False),
    "SE": (5, True),
    "NE": (3, False),
    "NW": (3, True),
}


def is_bg(p):
    r, g, b = p[0], p[1], p[2]
    return r >= 238 and g >= 238 and b >= 238 and abs(r - g) < 12 and abs(g - b) < 12 and abs(r - b) < 12


def strip_bg(im):
    """Flood-fill from the four edges, clearing connected near-white bg to alpha."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))
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
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))
    return im


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    strips = sorted(glob.glob(os.path.join(SRC_DIR, "*.png")))
    if len(strips) != 8:
        raise SystemExit("Expected 8 source strips, found %d" % len(strips))

    # Pre-process: split every strip into 4 cleaned frames, keyed by 1-based index.
    cleaned = {}  # strip_idx -> list[Image]
    for i, path in enumerate(strips, start=1):
        im = Image.open(path)
        frames = []
        for f in range(FRAMES):
            crop = im.crop((f * FW, 0, (f + 1) * FW, FH))
            frames.append(strip_bg(crop))
        cleaned[i] = frames

    # Compute a single union bbox across EVERY frame we will export so all
    # directions share a consistent footing and scale.
    union = None
    for dir_key, (sidx, _mirror) in MAP.items():
        for fr in cleaned[sidx]:
            bb = fr.getbbox()
            if bb is None:
                continue
            if union is None:
                union = list(bb)
            else:
                union[0] = min(union[0], bb[0])
                union[1] = min(union[1], bb[1])
                union[2] = max(union[2], bb[2])
                union[3] = max(union[3], bb[3])
    if union is None:
        raise SystemExit("All frames empty after bg strip")

    uw = union[2] - union[0]
    uh = union[3] - union[1]
    scale = TARGET_H / float(uh)
    tw = max(1, int(round(uw * scale)))
    th = max(1, int(round(uh * scale)))
    canvas_w = th  # square-ish canvas, centered
    canvas_h = th
    print("union bbox", union, "-> frame", tw, "x", th, "canvas", canvas_w, "x", canvas_h)

    for dir_key, (sidx, mirror) in MAP.items():
        for f in range(FRAMES):
            fr = cleaned[sidx][f].crop((union[0], union[1], union[2], union[3]))
            fr = fr.resize((tw, th), Image.LANCZOS)
            if mirror:
                fr = fr.transpose(Image.FLIP_LEFT_RIGHT)
            canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
            ox = (canvas_w - tw) // 2
            oy = (canvas_h - th) // 2
            canvas.alpha_composite(fr, (ox, oy))
            out = os.path.join(OUT_DIR, "%s_%s_move_f%03d_v001.png" % (PREFIX, dir_key, f + 1))
            canvas.save(out)
    print("wrote", len(MAP) * FRAMES, "frames to", OUT_DIR)


if __name__ == "__main__":
    main()
