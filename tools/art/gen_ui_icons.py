#!/usr/bin/env python3
"""Regenerate the 32x32 UI icon set (resources, build menu, rarity frames).

Run from the repo root:

    python3 tools/art/gen_ui_icons.py            # write the v002 assets
    python3 tools/art/gen_ui_icons.py --sheet X  # also write a review sheet

Why these are drawn in code rather than painted: at 32px an icon is decided by
a handful of choices that have to agree across the whole set -- one outline
colour, one light direction, one shade ramp per material, one silhouette budget.
Those are trivial to hold constant in a generator and very hard to hold constant
across two dozen separately painted PNGs, which is exactly how the v001 set
drifted into being unreadable (dark-on-dark buildings, gold that reads as rock,
stone that reads as ice).

House rules, applied to every icon here:
  * subject occupies roughly 26 of the 32 pixels, centred, so icons look the
    same size next to each other in the build bar
  * light from the upper left, always
  * every silhouette gets the same near-black outline, so nothing dissolves
    into the dark HUD behind it
  * emissive subjects (fire, lightning, crystal, acid, tesla, portal) carry a
    soft glow beneath the art so they read as light sources
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pixelkit import Canvas, Ramp, contact_sheet, mix, rgba  # noqa: E402

# --- materials ----------------------------------------------------------
GOLD = Ramp("#6b4410", "#a4741d", "#d9a437", "#f5cf5e", "#fff3b8")
STEEL = Ramp("#232a38", "#414d63", "#6f7f97", "#9fb0c6", "#e4eefb")
STONE = Ramp("#312e2c", "#514b45", "#7a7268", "#a49a8a", "#d2c9b8")
WOOD = Ramp("#2e1a0e", "#54321a", "#7d4c28", "#a56c3f", "#c99162")
BONE = Ramp("#453f33", "#7c7260", "#b6ab93", "#ded5bd", "#fffaea")
FIRE = Ramp("#701805", "#bc3a08", "#ef7a12", "#ffc23a", "#fff6c8")
ICE = Ramp("#123a5c", "#2170a6", "#4fa9dc", "#9adef4", "#eaffff")
GEM = Ramp("#0c3a4a", "#136d88", "#22b0c9", "#72ebf3", "#dcffff")
VOLT = Ramp("#7a4c00", "#c88b00", "#ffd21f", "#fff383", "#ffffff")
ACID = Ramp("#173a10", "#2f7a18", "#5cbf27", "#9df05a", "#e6ffc0")
CANVAS = Ramp("#463424", "#6e5236", "#9c7a52", "#c4a077", "#e8cfa8")
VOID = Ramp("#1b1030", "#3a1d63", "#6a34a8", "#a86ce6", "#f0ddff")
RUST = Ramp("#3a1c10", "#6b3316", "#9c5220", "#c47a3a", "#e4a765")

ICONS = {}


def icon(group, name):
    """Register a 32x32 icon under an output group."""
    def deco(fn):
        ICONS[(group, name)] = fn
        return fn
    return deco


# =======================================================================
# Resource icons
# =======================================================================

def _coin(c, cx, cy, r, ramp=GOLD, face=False):
    """One coin. Edge-on by default; `face` draws it flat to the camera so a
    pile has one readable disc in it instead of reading as stacked pebbles."""
    ry = r if face else max(1, int(r * 0.62))
    c.ell(cx - r, cy - ry, cx + r, cy + ry, ramp.mid)
    c.ell(cx - r, cy - ry, cx + r, cy + ry - 1, ramp.light)
    c.ell(cx - r + 1, cy - ry + 1, cx + r - 1, cy + ry - 2, ramp.mid)
    # Underside stays dark so stacked coins separate.
    c.d.arc([cx - r, cy - ry, cx + r, cy + ry], 20, 160, fill=rgba(ramp.dark))
    if face:
        c.ell(cx - r + 2, cy - ry + 2, cx + r - 2, cy + ry - 2, ramp.light)
        c.px(cx - 1, cy - 1, ramp.hi)
        c.px(cx, cy - 1, ramp.hi)
    else:
        c.hline(cx - r + 2, cx - r + 3, cy - ry + 1, ramp.hi)


@icon("res", "gold")
def gold(c):
    c.shadow(16, 28, 12, 3)
    # Pyramid pile: four rows narrowing upward, plus one face-on coin so the
    # subject is unmistakably currency and not the dark rock v001 drew.
    for cx in (7, 13, 19, 25):
        _coin(c, cx, 25, 5)
    for cx in (10, 16, 22):
        _coin(c, cx, 20, 5)
    for cx in (13, 19):
        _coin(c, cx, 15, 5)
    _coin(c, 16, 9, 6, face=True)
    c.rim(GOLD.hi, 0.35)
    c.outline()
    c.glow(16, 16, 15, "#ffcc55", 0.18)


@icon("res", "crystal")
def crystal(c):
    def shard(x0, y0, w, h, tilt=0):
        top = (x0 + w // 2 + tilt, y0)
        left = (x0, y0 + h // 3)
        right = (x0 + w, y0 + h // 3)
        bl = (x0 + 1, y0 + h)
        br = (x0 + w - 1, y0 + h)
        mid = x0 + w // 2
        c.poly([top, right, br, bl, left], GEM.shade)
        c.poly([top, (mid, y0 + h), bl, left], GEM.mid)          # lit facet
        c.poly([top, right, br, (mid, y0 + h)], GEM.dark)        # occluded facet
        c.line(top, (mid, y0 + h), GEM.light)
        c.line(top, left, GEM.hi)

    shard(4, 13, 9, 15, 1)
    shard(20, 11, 9, 17, -1)
    shard(10, 3, 12, 25)
    c.px(15, 8, GEM.hi)
    c.px(16, 9, GEM.hi)
    c.outline()
    c.glow(16, 15, 16, "#3fe0f0", 0.3)


@icon("res", "fire")
def fire(c):
    c.poly([(16, 2), (21, 9), (24, 16), (23, 23), (18, 28), (12, 28),
            (8, 22), (8, 14), (13, 8)], FIRE.shade)
    c.poly([(16, 6), (20, 12), (21, 18), (19, 25), (13, 26), (10, 20),
            (11, 14), (14, 10)], FIRE.mid)
    c.poly([(16, 11), (19, 17), (18, 23), (14, 24), (12, 19), (14, 15)], FIRE.light)
    c.poly([(16, 16), (18, 20), (16, 23), (14, 20)], FIRE.hi)
    # Cool-burning root: real flames are darkest where they meet the fuel.
    c.poly([(12, 26), (20, 26), (18, 29), (14, 29)], FIRE.dark)
    c.outline()
    c.glow(16, 18, 17, "#ff8a22", 0.34)


@icon("res", "ice")
def ice(c):
    # A six-spoke flake, not another gem cluster -- 'ice' and 'crystal' sat two
    # slots apart in the HUD and v001 drew both as blue shards.
    cx, cy = 16, 16
    import math
    for k in range(6):
        a = math.radians(90 + k * 60)
        ex, ey = cx + math.cos(a) * 12, cy - math.sin(a) * 12
        c.line((cx, cy), (ex, ey), ICE.mid, 3)
        c.line((cx, cy), (ex, ey), ICE.light)
        # Barbs, at 60 deg off the arm, halfway out.
        mx, my = cx + math.cos(a) * 6.5, cy - math.sin(a) * 6.5
        for s in (-1, 1):
            b = a + s * math.radians(58)
            c.line((mx, my), (mx + math.cos(b) * 4.5, my - math.sin(b) * 4.5), ICE.mid, 1)
    c.ell(cx - 4, cy - 4, cx + 4, cy + 4, ICE.mid)
    c.ell(cx - 3, cy - 3, cx + 2, cy + 2, ICE.light)
    c.ell(cx - 2, cy - 2, cx, cy, ICE.hi)
    c.outline()
    c.glow(cx, cy, 15, "#7fd8ff", 0.26)


@icon("res", "iron")
def iron(c):
    c.shadow(16, 28, 12, 3)

    def ingot(cx, y_top, half_top, half_bot, depth, height):
        """A cast bar: receding top face, draft-angled front, hard bevel.

        The draft angle is what sells it -- a bar with parallel sides is just a
        grey rectangle, which is what v001 drew.
        """
        fy = y_top + depth                                  # front top edge
        by = fy + height                                    # bottom edge
        c.poly([(cx - half_top, y_top), (cx + half_top, y_top),
                (cx + half_bot, fy), (cx - half_bot, fy)], STEEL.light)
        c.poly([(cx - half_bot, fy), (cx + half_bot, fy),
                (cx + half_bot - 2, by), (cx - half_bot + 2, by)], STEEL.mid)
        c.poly([(cx - half_bot + 1, by - 2), (cx + half_bot - 1, by - 2),
                (cx + half_bot - 2, by), (cx - half_bot + 2, by)], STEEL.shade)
        c.line((cx - half_top, y_top), (cx + half_top, y_top), STEEL.hi)
        c.line((cx - half_bot, fy), (cx + half_bot, fy), STEEL.hi)
        c.line((cx - half_top, y_top), (cx - half_bot, fy), STEEL.light)
        c.line((cx + half_top, y_top), (cx + half_bot, fy), STEEL.dark)

    ingot(13, 5, 7, 10, 4, 7)     # back bar
    ingot(18, 16, 8, 12, 4, 8)    # front bar, offset so both silhouettes read
    c.outline()


@icon("res", "stone")
def stone(c):
    c.shadow(16, 28, 12, 3)
    # Warm grey with flat top planes: 'stone' must not read as 'ice', which is
    # exactly what the pale blue-white v001 chunks did.
    def rock(x0, y0, x1, y1, top):
        c.poly([(x0, y1), (x0 + 1, y0 + top), (x0 + (x1 - x0) // 3, y0),
                (x1 - 2, y0 + 1), (x1, y0 + top + 1), (x1 - 1, y1)], STONE.mid)
        c.poly([(x0 + 1, y0 + top), (x0 + (x1 - x0) // 3, y0), (x1 - 2, y0 + 1),
                (x1, y0 + top + 1)], STONE.light)
        c.line((x0 + (x1 - x0) // 3, y0), (x1 - 2, y0 + 1), STONE.hi)
        c.poly([(x0 + (x1 - x0) // 2, y1), (x1 - 1, y1), (x1, y0 + top + 3)], STONE.shade)

    rock(3, 15, 15, 28, 4)
    rock(15, 17, 28, 28, 4)
    rock(9, 5, 23, 17, 4)
    c.outline()


@icon("res", "wood")
def wood(c):
    c.shadow(16, 29, 12, 2)

    def log(cx, cy, r):
        # Each log carries its own hard dark ring. Without it the three ends
        # merge into one round mass and the icon reads as a barrel.
        c.ell(cx - r, cy - r, cx + r, cy + r, "#1d0f07")
        c.ell(cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1, WOOD.shade)   # bark
        c.ell(cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2, WOOD.light)   # end grain
        c.ring(cx - r + 3, cy - r + 3, cx + r - 3, cy + r - 3, WOOD.mid)
        c.ring(cx - r + 5, cy - r + 5, cx + r - 5, cy + r - 5, WOOD.mid)
        c.px(cx, cy, WOOD.dark)
        c.d.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], 190, 300,
                fill=rgba(WOOD.hi))
        c.d.arc([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], 20, 150,
                fill=rgba("#3d2211"))

    log(9, 20, 8)
    log(24, 20, 7)
    log(16, 8, 7)
    c.outline()


def _bone_shaft(c, p0, p1, ramp=BONE):
    """A single bone: shaft plus twin knobs at each end."""
    c.line(p0, p1, ramp.mid, 5)
    c.line(p0, p1, ramp.light, 3)
    import math
    a = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
    perp = (math.cos(a + math.pi / 2), math.sin(a + math.pi / 2))
    for (ex, ey), s in ((p0, -1), (p1, 1)):
        bx, by = ex + math.cos(a) * s * 0.5, ey + math.sin(a) * s * 0.5
        for k in (-1, 1):
            kx, ky = bx + perp[0] * k * 2.4, by + perp[1] * k * 2.4
            c.ell(kx - 2.5, ky - 2.5, kx + 2.5, ky + 2.5, ramp.mid)
            c.ell(kx - 2, ky - 2, kx + 1, ky + 1, ramp.light)
            c.px(kx - 1, ky - 1, ramp.hi)


@icon("res", "bone")
def bone(c):
    # Ivory, not the orange v001 used -- crossed orange sticks read as kindling.
    _bone_shaft(c, (7, 24), (25, 7))
    _bone_shaft(c, (7, 7), (25, 24))
    c.outline()


@icon("res", "skull")
def skull(c):
    c.shadow(16, 29, 9, 2)
    # Cranium
    c.ell(5, 4, 27, 24, BONE.mid)
    c.ell(6, 5, 25, 22, BONE.light)
    c.ell(8, 6, 21, 16, BONE.hi)
    # Jaw
    c.poly([(9, 20), (23, 20), (22, 28), (10, 28)], BONE.mid)
    c.poly([(10, 21), (22, 21), (21, 25), (11, 25)], BONE.light)
    for x in range(11, 22, 3):
        c.vline(x, 25, 28, BONE.dark)
    c.hline(10, 22, 25, BONE.shade)
    # Sockets, with a live ember in each: this is the enemy/threat icon.
    for ex in (9, 18):
        c.ell(ex, 11, ex + 5, 17, "#0c0810")
        c.ell(ex + 1, 12, ex + 4, 16, "#170d16")
        c.px(ex + 2, 14, "#ff4b3a")
        c.px(ex + 3, 14, "#c02418")
    c.poly([(15, 17), (18, 17), (16, 21)], "#0c0810")
    c.outline()
    c.glow(16, 14, 13, "#ff4030", 0.14)


@icon("res", "lightning")
def lightning(c):
    bolt = [(21, 2), (11, 17), (16, 17), (9, 30), (24, 13), (18, 13), (26, 2)]
    c.poly(bolt, VOLT.shade)
    c.poly([(20, 5), (13, 17), (17, 17), (12, 26), (22, 14), (17, 14), (23, 5)], VOLT.mid)
    c.poly([(20, 8), (15, 17), (18, 17), (14, 24), (20, 15), (17, 15), (21, 8)], VOLT.light)
    c.line((20, 9), (16, 17), VOLT.hi)
    c.line((18, 17), (15, 23), VOLT.hi)
    c.outline()
    c.glow(17, 16, 17, "#ffd23a", 0.34)


# =======================================================================
# Build-menu icons
#
# These are read at a glance while enemies are on screen, so every one of them
# is built from a big silhouette plus one identifying detail. v001 lost most of
# them to dark-on-dark rendering; the fix is contrast, not more detail.
# =======================================================================

def _masonry(c, x0, y0, x1, y1, ramp, course=5):
    """Block courses with staggered head joints."""
    c.rect(x0, y0, x1, y1, ramp.mid)
    row = 0
    y = y0
    while y <= y1:
        c.hline(x0, x1, y, ramp.light if row == 0 else ramp.shade)
        offset = 0 if row % 2 == 0 else course // 2 + 1
        x = x0 + offset
        while x <= x1:
            c.vline(x, y + 1, min(y1, y + course - 1), ramp.shade)
            x += course + 1
        y += course
        row += 1
    c.vline(x1, y0, y1, ramp.dark)
    c.vline(x0, y0, y1, ramp.light)


@icon("build", "wall")
def b_wall(c):
    c.shadow(16, 29, 13, 3)
    _masonry(c, 3, 12, 28, 28, STONE)
    for x in (3, 11, 19, 27):
        c.rect(x - 1, 7, x + 2, 12, STONE.mid)
        c.hline(x - 1, x + 2, 7, STONE.hi)
        c.vline(x + 2, 8, 12, STONE.shade)
    c.outline()


@icon("build", "gate")
def b_gate(c):
    c.shadow(16, 29, 13, 3)
    _masonry(c, 2, 9, 10, 28, STONE)
    _masonry(c, 21, 9, 29, 28, STONE)
    for x in (2, 7, 21, 26):
        c.rect(x, 5, x + 3, 9, STONE.mid)
        c.hline(x, x + 3, 5, STONE.hi)
    # Arch + portcullis. The dark opening is the whole point of the read, so it
    # gets the strongest value contrast in the icon.
    c.rect(11, 14, 20, 28, "#0f0c14")
    c.d.pieslice([11, 9, 20, 19], 180, 360, fill=rgba("#0f0c14"))
    _masonry(c, 10, 10, 21, 13, STONE, course=4)
    for x in range(12, 21, 3):
        c.vline(x, 15, 28, STEEL.mid)
        c.px(x, 15, STEEL.hi)
    for y in range(17, 28, 5):
        c.hline(12, 20, y, STEEL.light)
        c.hline(12, 20, y + 1, STEEL.dark)
    c.outline()


@icon("build", "arrow_turret")
def b_arrow_turret(c):
    c.shadow(9, 29, 9, 3)
    _masonry(c, 2, 10, 15, 28, STONE, course=5)
    for x in (1, 7, 13):
        c.rect(x, 6, x + 3, 10, STONE.mid)
        c.hline(x, x + 3, 6, STONE.hi)
    c.rect(7, 15, 8, 22, "#0f0c14")       # arrow slit
    # A loosed arrow flying right, rather than an arrowhead stacked on the
    # tower -- stacked, it reads as a roof and the icon becomes another wall.
    c.rect(14, 13, 27, 14, WOOD.light)
    c.rect(14, 15, 27, 15, WOOD.shade)
    c.poly([(31, 14), (24, 10), (24, 19)], GOLD.mid)
    c.poly([(30, 14), (25, 11), (25, 17)], GOLD.light)
    c.px(27, 14, GOLD.hi)
    for fx in (14, 17):                                            # fletching
        c.poly([(fx, 14), (fx + 4, 9), (fx + 6, 9), (fx + 3, 14)], "#c8443a")
        c.poly([(fx, 15), (fx + 4, 20), (fx + 6, 20), (fx + 3, 15)], "#8f2a26")
    c.outline()


@icon("build", "cannon")
def b_cannon(c):
    c.shadow(16, 29, 12, 3)
    c.poly([(4, 22), (16, 22), (13, 29), (5, 29)], WOOD.mid)      # carriage
    c.poly([(4, 22), (16, 22), (16, 24), (4, 24)], WOOD.light)
    c.ell(15, 20, 27, 30, WOOD.shade)                             # wheel
    c.ell(17, 22, 25, 28, WOOD.mid)
    c.ell(19, 24, 23, 26, STEEL.shade)
    # Barrel, raised to the upper right so the muzzle sits at the icon's
    # brightest corner and reads as the business end.
    c.poly([(6, 20), (23, 6), (28, 12), (11, 25)], STEEL.shade)
    c.poly([(7, 19), (23, 8), (26, 11), (10, 23)], STEEL.mid)
    c.line((8, 18), (23, 9), STEEL.light)
    c.poly([(22, 5), (29, 11), (26, 14), (20, 8)], STEEL.mid)     # muzzle band
    c.line((23, 5), (29, 11), STEEL.hi)
    c.poly([(24, 7), (28, 11), (26, 13), (22, 9)], "#0d0a12")     # bore
    c.outline()


@icon("build", "tesla")
def b_tesla(c):
    c.shadow(16, 29, 11, 3)
    c.poly([(6, 24), (25, 24), (28, 29), (3, 29)], STEEL.shade)
    c.hline(6, 25, 24, STEEL.mid)
    c.rect(13, 13, 18, 24, STEEL.dark)
    for y in range(14, 24, 3):                                    # copper windings
        c.hline(12, 19, y, RUST.mid)
        c.hline(12, 19, y + 1, RUST.dark)
    c.vline(13, 13, 24, STEEL.mid)
    c.ell(8, 2, 23, 15, STEEL.mid)                                # toroid
    c.ell(9, 3, 20, 12, STEEL.light)
    c.ell(11, 4, 16, 8, STEEL.hi)
    c.d.arc([8, 2, 23, 15], 30, 160, fill=rgba(STEEL.dark))
    for pts in (((7, 9), (3, 13), (6, 14), (2, 19)),
                ((24, 9), (28, 13), (25, 14), (29, 19))):
        for i in range(len(pts) - 1):
            c.line(pts[i], pts[i + 1], GEM.light, 2)
            c.line(pts[i], pts[i + 1], GEM.hi)
    c.outline()
    c.glow(16, 10, 17, "#4fe4ff", 0.34)


@icon("build", "acid_trap")
def b_acid_trap(c):
    c.shadow(16, 29, 13, 3)
    c.ell(2, 12, 29, 29, STEEL.dark)                              # rim
    c.ell(3, 13, 28, 27, STEEL.shade)
    c.ell(5, 15, 26, 27, ACID.shade)                              # pool
    c.ell(6, 16, 25, 25, ACID.mid)
    c.ell(8, 17, 20, 22, ACID.light)
    for bx, by, br in ((10, 20, 2), (17, 18, 3), (21, 22, 2), (14, 23, 1)):
        c.ell(bx - br, by - br, bx + br, by + br, ACID.light)
        c.ell(bx - br + 1, by - br, bx + br - 1, by + br - 2, ACID.hi)
    c.d.arc([2, 12, 29, 29], 200, 340, fill=rgba(STEEL.light))
    c.outline()
    c.glow(16, 21, 15, "#7bec3a", 0.34)


@icon("build", "ice_trap")
def b_ice_trap(c):
    c.shadow(16, 29, 12, 3)
    c.ell(3, 22, 28, 30, STEEL.dark)                              # floor plate
    c.ell(4, 23, 27, 29, STEEL.shade)

    def spike(cx, top, half):
        c.poly([(cx, top), (cx + half, 26), (cx - half, 26)], ICE.shade)
        c.poly([(cx, top), (cx + half - 1, 26), (cx, 26)], ICE.mid)
        c.poly([(cx, top), (cx, 26), (cx - half + 1, 26)], ICE.light)
        c.line((cx, top), (cx - half + 2, 25), ICE.hi)

    spike(8, 13, 4)
    spike(24, 11, 4)
    spike(16, 2, 6)
    c.outline()
    c.glow(16, 16, 16, "#8fe4ff", 0.3)


@icon("build", "mine_trap")
def b_mine_trap(c):
    c.shadow(16, 29, 10, 3)
    import math
    for k in range(10):                                           # spikes first
        a = math.radians(k * 36 - 90)
        x0, y0 = 16 + math.cos(a) * 8, 18 + math.sin(a) * 8
        x1, y1 = 16 + math.cos(a) * 13, 18 + math.sin(a) * 13
        c.line((x0, y0), (x1, y1), STEEL.mid, 3)
        c.line((x0, y0), (x1, y1), STEEL.light)
    c.ell(6, 8, 26, 28, STEEL.shade)
    c.ell(7, 9, 24, 26, STEEL.mid)
    c.ell(9, 11, 18, 18, STEEL.light)
    c.d.arc([6, 8, 26, 28], 20, 160, fill=rgba(STEEL.dark))
    c.ell(18, 12, 22, 16, "#8f1620")                              # armed light
    c.ell(19, 13, 21, 15, "#ff5548")
    c.outline()
    c.glow(20, 14, 10, "#ff4436", 0.28)


@icon("build", "armory")
def b_armory(c):
    c.shadow(16, 30, 12, 2)
    # Hammer, resting across the anvil. Hammer-plus-anvil is the shortest
    # possible read for a smithy; the sword-behind-a-wedge version wasn't one.
    c.line((11, 9), (26, 16), WOOD.mid, 3)
    c.line((11, 9), (26, 16), WOOD.light, 1)
    c.poly([(3, 6), (11, 2), (15, 8), (7, 12)], STEEL.mid)
    c.poly([(3, 6), (11, 2), (13, 5), (5, 9)], STEEL.light)
    c.line((3, 6), (11, 2), STEEL.hi)
    c.poly([(11, 2), (15, 8), (13, 9), (9, 3)], STEEL.dark)
    # Anvil: horn, flat face, waist, splayed base -- the whole silhouette is
    # the identifier, so it gets the widest span in the icon.
    c.poly([(1, 17), (7, 15), (7, 20), (2, 20)], STEEL.mid)        # horn
    c.line((1, 17), (7, 15), STEEL.hi)
    c.rect(6, 15, 28, 20, STEEL.mid)                               # face
    c.hline(6, 28, 15, STEEL.hi)
    c.hline(6, 28, 16, STEEL.light)
    c.hline(6, 28, 20, STEEL.dark)
    c.poly([(12, 20), (23, 20), (20, 24), (15, 24)], STEEL.shade)  # waist
    c.poly([(8, 24), (27, 24), (29, 28), (6, 28)], STEEL.mid)      # base
    c.hline(8, 27, 24, STEEL.light)
    c.hline(6, 29, 28, STEEL.dark)
    c.outline()


@icon("build", "barracks")
def b_barracks(c):
    c.shadow(16, 29, 13, 3)
    c.poly([(16, 5), (30, 28), (2, 28)], CANVAS.mid)              # tent
    c.poly([(16, 5), (16, 28), (2, 28)], CANVAS.light)            # lit face
    c.line((16, 5), (2, 28), CANVAS.hi)
    for x0, x1 in ((7, 9), (20, 23)):                             # canvas seams
        c.line((16, 6), (x0, 28), CANVAS.shade)
        c.line((16, 6), (x1, 28), CANVAS.shade)
    c.poly([(13, 28), (16, 15), (19, 28)], "#150f14")             # entry
    c.poly([(14, 28), (16, 18), (16, 28)], "#241a20")
    c.vline(16, 0, 6, WOOD.light)                                 # pole + pennant
    c.poly([(17, 1), (26, 4), (17, 7)], "#a3202c")
    c.poly([(17, 1), (24, 3.5), (17, 4)], "#d63a3a")
    c.outline()


@icon("build", "shrine")
def b_shrine(c):
    c.shadow(16, 29, 12, 3)
    c.poly([(3, 25), (29, 25), (27, 29), (5, 29)], STONE.shade)   # steps
    c.hline(3, 29, 25, STONE.light)
    c.poly([(6, 21), (26, 21), (25, 25), (7, 25)], STONE.mid)
    c.hline(6, 26, 21, STONE.hi)
    c.poly([(12, 8), (20, 8), (21, 21), (11, 21)], STONE.mid)     # obelisk
    c.poly([(12, 8), (16, 8), (16, 21), (11, 21)], STONE.light)
    c.line((12, 8), (20, 8), STONE.hi)
    for y in (12, 16):                                            # carved runes
        c.hline(13, 18, y, VOID.light)
        c.px(15, y + 1, VOID.hi)
    # Offering flame, floating above the plinth.
    c.poly([(16, 0), (20, 5), (19, 9), (13, 9), (12, 5)], FIRE.mid)
    c.poly([(16, 2), (18, 6), (17, 8), (14, 8), (14, 5)], FIRE.light)
    c.px(16, 6, FIRE.hi)
    c.outline()
    c.glow(16, 6, 12, "#ffb03a", 0.3)


@icon("build", "tech_lab")
def b_tech_lab(c):
    c.shadow(16, 29, 13, 3)
    c.rect(3, 10, 28, 29, STEEL.dark)                             # cabinet
    c.hline(3, 28, 10, STEEL.mid)
    c.vline(3, 10, 29, STEEL.shade)
    c.rect(6, 13, 25, 23, "#08131c")                              # screen
    c.box(5, 12, 26, 24, STEEL.mid)
    c.hline(6, 25, 13, GEM.dark)
    for i, h in enumerate((3, 6, 4, 8, 5)):                       # readout bars
        x = 8 + i * 4
        c.rect(x, 22 - h, x + 2, 22, GEM.mid)
        c.hline(x, x + 2, 22 - h, GEM.hi)
    c.rect(6, 26, 25, 27, STEEL.shade)                            # LED strip
    c.px(7, 26, "#4bd964")
    c.px(9, 26, "#4bd964")
    c.px(11, 26, "#ffb03a")
    c.vline(24, 3, 10, STEEL.light)                               # antenna
    c.ell(22, 1, 26, 5, GEM.light)
    c.ell(23, 2, 25, 4, GEM.hi)
    c.outline()
    c.glow(16, 18, 15, "#2fd6f0", 0.22)


@icon("build", "stargate")
def b_stargate(c):
    c.shadow(16, 29, 11, 3)
    import math
    c.ell(1, 1, 30, 30, STEEL.shade)                              # outer ring
    c.ell(2, 2, 29, 29, STEEL.mid)
    c.d.arc([1, 1, 30, 30], 190, 350, fill=rgba(STEEL.light))
    c.ell(5, 5, 26, 26, STEEL.dark)
    for k in range(8):                                            # chevrons
        a = math.radians(k * 45 - 90)
        x, y = 15.5 + math.cos(a) * 12.5, 15.5 + math.sin(a) * 12.5
        c.ell(x - 1.5, y - 1.5, x + 1.5, y + 1.5, GOLD.mid)
        c.px(x, y, GOLD.hi)
    c.ell(6, 6, 25, 25, VOID.shade)                               # event horizon
    c.ell(8, 8, 23, 23, VOID.mid)
    c.ell(11, 11, 20, 20, VOID.light)
    c.ell(14, 13, 18, 18, VOID.hi)
    c.d.arc([7, 7, 24, 24], 200, 320, fill=rgba(VOID.hi))
    c.outline()
    c.glow(16, 16, 17, "#9a5cff", 0.36)


# =======================================================================
# Rarity frames
#
# Hollow 32x32 borders that sit behind a 32px icon, so the middle has to stay
# empty. Rarity is carried by colour, bracket weight and corner gems -- three
# signals, because colour alone is unreliable for colour-blind players.
# =======================================================================

def _frame(c, ramp, arm, gems, weight=1, double=False, spark=False):
    """Corner-bracket frame.

    The middle 24px must stay empty -- an icon is drawn inside it -- so rarity
    can only be carried by the border itself: bracket length, bracket weight,
    corner gems and edge flares, on top of colour. Three non-colour signals,
    because colour alone fails for colour-blind players and at small sizes.
    """
    inset = 1
    c.box(inset, inset, 31 - inset, 31 - inset, ramp.shade)
    if double:
        c.box(inset + 2, inset + 2, 29 - inset, 29 - inset, ramp.dark)
    lo, hi_ = inset, 31 - inset
    for cx, cy, sx, sy in ((lo, lo, 1, 1), (hi_, lo, -1, 1),
                           (lo, hi_, 1, -1), (hi_, hi_, -1, -1)):
        for w in range(weight):
            c.line((cx + sx * w, cy + sy * w), (cx + sx * (arm - w), cy + sy * w),
                   ramp.light if w else ramp.hi)
            c.line((cx + sx * w, cy + sy * w), (cx + sx * w, cy + sy * (arm - w)),
                   ramp.light if w else ramp.hi)
        if gems:
            # On the corner itself, where a bracket rivet would sit -- pulled
            # inward they just look like four dots floating in the middle.
            gx, gy = cx + sx * (weight + 1), cy + sy * (weight + 1)
            c.poly([(gx, gy - 2), (gx + 2, gy), (gx, gy + 2), (gx - 2, gy)], ramp.mid)
            c.poly([(gx, gy - 1), (gx + 1, gy), (gx, gy + 1), (gx - 1, gy)], ramp.hi)
    if spark:
        for x, y, dx, dy in ((15, inset, 0, 1), (15, hi_, 0, -1),
                             (inset, 15, 1, 0), (hi_, 15, -1, 0)):
            c.poly([(x, y), (x + 1, y), (x + 1 + dx * 2, y + dy * 2),
                    (x + dx * 2, y + dy * 2)], ramp.hi)
            c.px(x - dy * 2, y - dx * 2, ramp.light)
            c.px(x + 1 + dy * 2, y + dx * 2, ramp.light)


def _frame_bloom(c, ramp, strength):
    """Halo that hugs the border only.

    A radial glow centred on the frame washes the middle 24px -- which is where
    the item icon goes -- so the bloom is painted as a fading inset ring
    instead, leaving the interior clear.
    """
    base = rgba(ramp.mid)
    under = Canvas(c.w, c.h)
    for step in range(4):
        a = int(255 * strength * (1.0 - step / 4.0) ** 2)
        if a <= 0:
            continue
        i = 2 + step
        under.box(i, i, 31 - i, 31 - i, (base[0], base[1], base[2], a))
    under.im.alpha_composite(c.im)
    c.im = under.im
    from PIL import ImageDraw as _D
    c.d = _D.Draw(c.im)


COMMON = Ramp("#2c3630", "#4a5b4f", "#6f8a74", "#9fc4a4", "#e2ffe6")
RARE = Ramp("#12294a", "#1f4a86", "#3a7fd0", "#79b6f5", "#e0f1ff")
EPIC = Ramp("#2c1040", "#5a1e80", "#9235c9", "#c579f0", "#f6e2ff")
LEGENDARY = Ramp("#4a2a05", "#8a5410", "#d18c1c", "#f5c44b", "#fff6d0")


@icon("rarity", "common_frame")
def r_common(c):
    _frame(c, COMMON, 5, False, weight=1)


@icon("rarity", "rare_frame")
def r_rare(c):
    _frame(c, RARE, 7, True, weight=1)
    _frame_bloom(c, RARE, 0.22)


@icon("rarity", "epic_frame")
def r_epic(c):
    _frame(c, EPIC, 9, True, weight=2)
    _frame_bloom(c, EPIC, 0.32)


@icon("rarity", "legendary_frame")
def r_legendary(c):
    _frame(c, LEGENDARY, 11, True, weight=2, double=True, spark=True)
    _frame_bloom(c, LEGENDARY, 0.40)


# =======================================================================

OUT_DIRS = {
    "res": ("assets/ui", "ui_icon_%s_32_v002.png"),
    "build": ("assets/ui_build_icons", "ui_build_%s_32_v002.png"),
    "rarity": ("assets/ui_build_icons", "ui_rarity_%s_32_v002.png"),
}


def build_all():
    made = []
    for (group, name), fn in ICONS.items():
        c = Canvas(32, 32)
        fn(c)
        d, pattern = OUT_DIRS[group]
        made.append((group, name, os.path.join(d, pattern % name), c.im))
    return made


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", help="also write a magnified review sheet here")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    made = build_all()
    for group, name, path, im in made:
        if args.dry_run:
            print("would write", path)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im.save(path)
        print("wrote", path)

    if args.sheet:
        order = {"res": 0, "build": 1, "rarity": 2}
        entries = [(n, im) for g, n, _, im in
                   sorted(made, key=lambda m: (order[m[0]], m[1]))]
        contact_sheet(entries).save(args.sheet)
        print("sheet", args.sheet)


if __name__ == "__main__":
    main()
