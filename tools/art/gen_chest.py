#!/usr/bin/env python3
"""Generate the treasure chest sprite sheet.

    python3 tools/art/gen_chest.py [--sheet review.png]

The chest is the single biggest reward beat in a run, and until now it was
`prop_graveyard_crates_32_v001.png` -- a dark 32px stack of packing crates
borrowed from the graveyard set, blown up 2.25x in the world and 6x in the
full-screen reveal. At that magnification it was four muddy browns with no
readable silhouette, which is a poor thing to build a jackpot around.

Output is one horizontal 4-frame strip at 48px, drawn to be magnified:

    0  closed          idle in the world
    1  strained        lid seated but light leaking out; the rattle beat
    2  cracked         lid lifting, interior glow spilling up
    3  open            lid back, coins and a gem visible, rays out the top

Frames are the same size and share the same base and shadow, so a Sprite2D can
step through them without the chest appearing to jump.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from pixelkit import Canvas, Ramp, mix  # noqa: E402

S = 48

WOOD = Ramp("#2a170c", "#4d2c15", "#7a4823", "#a3683a", "#c98f5c")
IRON = Ramp("#171a24", "#2d3546", "#4d5a72", "#7d8ca6", "#b9c8de")
GOLD = Ramp("#6b4410", "#a4741d", "#d9a437", "#f5cf5e", "#fff3b8")
GEM = Ramp("#0c3a4a", "#136d88", "#22b0c9", "#72ebf3", "#dcffff")
INNER = "#140b06"

# The lid pivots about its back edge, so every frame is the same drawing with
# one number changed. Values are how far the lid front has swung up, in pixels.
LIFT = [0, 2, 8, 14]
# How hard the interior is lit, 0..1. Frame 1 leaks light before the lid really
# moves, which is what makes the rattle read as pressure building rather than
# as the chest wobbling for no reason.
LEAK = [0.0, 0.45, 0.8, 1.0]


def _planks(c, x0, y0, x1, y1, ramp, seams=(0.34, 0.68)):
    """Plank courses with a lit top edge and a dark bottom edge."""
    c.rect(x0, y0, x1, y1, ramp.mid)
    h = y1 - y0
    for f in seams:
        y = int(y0 + h * f)
        c.hline(x0, x1, y, ramp.dark)
        c.hline(x0, x1, y + 1, ramp.light)
    c.hline(x0, x1, y0, ramp.light)
    c.hline(x0, x1, y1, ramp.dark)
    c.vline(x0, y0, y1, ramp.shade)
    c.vline(x1, y0, y1, ramp.dark)
    # Grain: a few darker verticals, deliberately irregular.
    for x in (x0 + 4, x0 + 11, x1 - 6, x1 - 13):
        if x0 < x < x1:
            c.vline(x, y0 + 2, y1 - 2, ramp.shade)


def _band(c, x, y0, y1, ramp=IRON):
    """Vertical iron strap with rivets."""
    if y1 < y0:
        return
    c.rect(x, y0, x + 3, y1, ramp.shade)
    c.vline(x, y0, y1, ramp.mid)
    c.vline(x + 3, y0, y1, ramp.dark)
    c.vline(x + 1, y0, y1, ramp.light)
    for y in range(y0 + 2, y1, 6):
        c.px(x + 2, y, ramp.hi)
        c.px(x + 2, y + 1, ramp.dark)


def _interior(c, lift, leak):
    """The cavity, lit from inside. Only meaningful once the lid moves."""
    if lift <= 0 and leak <= 0.0:
        return
    top = LID_Y - lift
    if lift > 2:
        # Back inner wall first. Without it the raised lid reads as a plank
        # hovering over the box rather than as the lid of an open chest.
        c.rect(9, top, 38, LID_Y + 2, "#2c190b")
        c.rect(9, top + 2, 38, LID_Y + 2, INNER)
        # Loot sits in the mouth of the chest so it is visible the instant the
        # lid cracks -- waiting for the lid to finish opening wastes the beat.
        g = int(255 * leak)
        c.rect(10, max(top + 2, 21), 37, LID_Y + 2,
               (int(0.52 * g), int(0.39 * g), int(0.13 * g), 255))
        for cx, cy, r in ((14, 25, 3), (21, 24, 3), (28, 25, 3), (34, 24, 3), (24, 22, 3)):
            if cy - r < top + 1:
                continue
            c.ell(cx - r, cy - r + 1, cx + r, cy + r - 1, GOLD.mid)
            c.ell(cx - r, cy - r + 1, cx + r, cy + r - 2, GOLD.light)
            c.px(cx - 1, cy - 1, GOLD.hi)
        if lift > 8:
            c.poly([(24, 14), (28, 19), (24, 24), (20, 19)], GEM.mid)
            c.poly([(24, 14), (24, 24), (20, 19)], GEM.light)
            c.px(23, 17, GEM.hi)


CX = 24          # chest centre column
LID_Y = 26       # where the closed lid's lower lip sits
CROWN_HALF = 13  # lid half-width at the top of the dome
BASE_HALF = 19   # lid half-width at its lower lip (overhangs the body)


def _lid(c, lift):
    """Domed lid, hinged at the back. `lift` raises the front edge.

    Drawn a row at a time with a widening half-width rather than as stacked
    slabs: the dome is what separates a treasure chest from a packing crate,
    and three flat slabs read as the crate.

    The lid also foreshortens as it swings -- a hinged panel rotating away from
    the camera loses apparent height. Modelling that as one shrinking height
    keeps the drawing well-formed at every angle; deriving the back edge
    independently lets it overtake the front and invert the shape.
    """
    front = LID_Y - lift
    height = max(5, int(round(13 - lift * 0.55)))
    back = front - height

    def half(row):
        return int(round(CROWN_HALF + (BASE_HALF - CROWN_HALF) * (row / height) ** 0.5))

    for row in range(height + 1):
        y = back + row
        hw = half(row)
        x0, x1 = CX - hw, CX + hw
        t = row / height
        col = WOOD.light if t < 0.28 else (WOOD.mid if t < 0.7 else WOOD.shade)
        c.hline(x0, x1, y, col)
        c.px(x0, y, WOOD.shade)       # left edge catches the key light
        c.px(x0 + 1, y, WOOD.light)
        c.px(x1, y, WOOD.dark)        # right edge falls away
        c.px(x1 - 1, y, WOOD.shade)
    c.hline(CX - CROWN_HALF + 1, CX + CROWN_HALF - 1, back, WOOD.hi)
    for f in (0.42, 0.74):
        row = int(height * f)
        hw = half(row) - 2
        c.hline(CX - hw, CX + hw, back + row, WOOD.dark)

    # Iron rim along the lower lip, then straps arching over the crown.
    hw = half(height)
    c.rect(CX - hw - 1, front - 2, CX + hw + 1, front, IRON.shade)
    c.hline(CX - hw - 1, CX + hw + 1, front - 2, IRON.light)
    c.hline(CX - hw - 1, CX + hw + 1, front, IRON.dark)
    for x in (CX - 13, CX + 10):
        _band(c, x, back + 1, front - 3)
    c.px(CX - hw, front - 1, IRON.hi)
    if lift > 4:
        # Unlit underside. A raised lid with no thickness reads as a shelf
        # floating over the box.
        c.rect(CX - hw + 1, front + 1, CX + hw - 1, front + 2, "#1c0f06")
        c.hline(CX - hw + 1, CX + hw - 1, front + 1, "#2e1a0b")
    return front


def _seam(c, front, leak):
    """Light escaping under the lid.

    Drawn after the lid, not with the interior: the lid's iron rim covers the
    top of the cavity, so a seam painted underneath it is invisible -- which is
    exactly what made the straining frame indistinguishable from the closed one.
    Brightness carries the intensity; the pixels stay opaque, because a
    half-transparent warm line over dark wood is simply a slightly less dark
    line.
    """
    if leak <= 0.0:
        return
    # Starts already bright and only gets brighter. A seam that ramps linearly
    # from the wood colour spends its low end looking like more wood, which is
    # what made the straining frame read as identical to the closed one.
    core = mix("#8a5a12", "#fff4c8", 0.5 + 0.5 * leak)
    c.rect(8, front + 1, 40, front + 2, core)
    c.hline(12, 36, front + 1, mix(core, "#ffffff", 0.5))
    c.hline(9, 39, front + 3, mix("#3a2409", core, 0.45))


def _body(c):
    """Box below the lid. Identical in every frame."""
    _planks(c, 7, LID_Y + 1, 41, 42, WOOD)
    # Iron collar right under the lid rim. Two bands with a sliver of wood
    # between them is the strongest lid/body separation available at this size.
    c.rect(7, LID_Y + 1, 41, LID_Y + 2, IRON.shade)
    c.hline(7, 41, LID_Y + 1, IRON.mid)
    c.hline(7, 41, LID_Y + 2, IRON.dark)
    for x in (CX - 13, CX + 10):
        _band(c, x, LID_Y + 1, 42)
    # Foot rail, so the chest sits on the ground instead of floating.
    c.rect(6, 40, 42, 42, IRON.shade)
    c.hline(6, 42, 40, IRON.mid)
    c.hline(6, 42, 42, IRON.dark)
    c.rect(5, 41, 8, 44, IRON.shade)
    c.rect(40, 41, 43, 44, IRON.shade)


def _lock(c, lift, leak):
    """Gold hasp. Bridges the lid/body seam when shut, hangs open once lifted."""
    if lift > 4:
        c.rect(21, 30, 27, 38, GOLD.shade)
        c.rect(22, 31, 26, 37, GOLD.mid)
        c.hline(22, 26, 31, GOLD.light)
        c.ell(22, 33, 26, 37, "#3a2606")
        return
    top = LID_Y - lift - 6
    c.rect(20, top, 28, 36, GOLD.shade)
    c.rect(21, top + 1, 27, 35, GOLD.mid)
    c.hline(21, 27, top + 1, GOLD.hi)
    c.vline(21, top + 2, 35, GOLD.light)
    c.vline(27, top + 2, 35, GOLD.dark)
    # Waisted plate: a plain gold rectangle reads as a sticker, the pinch reads
    # as hardware.
    c.px(20, top + 4, (0, 0, 0, 0))
    c.px(28, top + 4, (0, 0, 0, 0))
    # Keyhole. Brightens as the interior lights up, so the lock looks strained.
    kc = "#2a1a04" if leak < 0.3 else (255, 244, 200, 255)
    c.ell(22, 28, 26, 32, kc)
    c.poly([(23, 31), (25, 31), (26, 34), (22, 34)], kc)


def frame(i):
    c = Canvas(S, S)
    c.shadow(24, 44, 19, 4, (0, 0, 0, 110))
    _body(c)
    _interior(c, LIFT[i], LEAK[i])
    front = _lid(c, LIFT[i])
    if LIFT[i] <= 2:
        _seam(c, front, LEAK[i])
    _lock(c, LIFT[i], LEAK[i])
    c.outline()
    if LEAK[i] > 0:
        # Bloom out of the seam. Sits under the art, so the chest stays solid.
        c.glow(24, 24 - LIFT[i] // 2, 22 + LIFT[i], "#ffd76b", 0.30 * LEAK[i])
    return c.im


def _recentre(frames):
    """Shift every frame by one shared offset so the idle pose is centred.

    The sprite's origin is its centre, and the chest is drawn sitting on the
    bottom of its cell, so uncorrected it would hang ~5px low in the world and
    in the reveal. The offset is derived from frame 0 alone and applied to all
    four: centring each frame on its own bounds would make the chest hop
    upward as the lid rises.
    """
    def solid_box(f):
        # Measure the chest, not its bloom. The glow spans most of the cell on
        # the open frames, so an alpha>0 bbox reports "already centred" and the
        # correction silently does nothing.
        a = f.getchannel("A").point(lambda v: 255 if v > 200 else 0)
        return a.getbbox()

    box = solid_box(frames[0])
    dy = (S - (box[1] + box[3])) // 2
    # Never push a frame off the top -- the open lid is the tallest pose.
    headroom = min(solid_box(f)[1] for f in frames)
    dy = max(dy, -headroom)
    if dy == 0:
        return frames, 0
    out = []
    for f in frames:
        moved = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        moved.alpha_composite(f, (0, dy))
        out.append(moved)
    return out, dy


def build_strip():
    frames, dy = _recentre([frame(i) for i in range(4)])
    strip = Image.new("RGBA", (S * 4, S), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * S, 0))
    return strip, dy


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/props/prop_treasure_chest_48_v001.png")
    ap.add_argument("--sheet")
    args = ap.parse_args()

    strip, dy = build_strip()
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    strip.save(args.out)
    print("wrote", args.out, strip.size, "recentred by", dy)
    for i in range(4):
        print("  frame %d bbox %s" % (i, strip.crop((i * S, 0, (i + 1) * S, S)).getbbox()))

    if args.sheet:
        big = strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (28, 30, 26, 255))
        bg.alpha_composite(big)
        bg.save(args.sheet)
        print("sheet", args.sheet)


if __name__ == "__main__":
    main()
