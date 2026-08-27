"""Small pixel-art drawing kit shared by the asset generators in this folder.

Everything here works on integer pixel coordinates with no anti-aliasing, so a
32x32 icon stays a 32x32 icon: PIL's ImageDraw does not smooth edges, and every
helper takes and returns whole pixels. Colours are '#rrggbb' strings or RGBA
tuples.

The reason these generators exist at all is that a 32px icon lives or dies on a
handful of decisions -- silhouette, outline, where the light comes from -- and
those are far easier to keep consistent across two dozen icons in code than by
hand-editing PNGs one at a time.
"""

from PIL import Image, ImageDraw

# House outline. Near-black with a violet bias so it sits in the game's palette
# rather than punching a pure-black hole in the HUD.
OUTLINE = "#120d18"

# Light comes from the upper left in every asset. Highlights go top/left,
# occlusion goes bottom/right. Stated once so no icon quietly disagrees.
LIGHT = (-1, -1)


def rgba(c):
    if isinstance(c, tuple):
        return c if len(c) == 4 else (c[0], c[1], c[2], 255)
    c = c.lstrip("#")
    if len(c) == 6:
        return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), 255)
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), int(c[6:8], 16))


def mix(a, b, t):
    a, b = rgba(a), rgba(b)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


class Ramp:
    """A 5-step shade ladder, darkest first.

    Icons that share a material share a ramp, which is what makes the set read
    as one family instead of two dozen unrelated drawings.
    """

    def __init__(self, *steps):
        self.s = [rgba(s) for s in steps]

    def __getitem__(self, i):
        return self.s[max(0, min(len(self.s) - 1, i))]

    @property
    def dark(self):
        return self[0]

    @property
    def shade(self):
        return self[1]

    @property
    def mid(self):
        return self[2]

    @property
    def light(self):
        return self[3]

    @property
    def hi(self):
        return self[4]


class Canvas:
    def __init__(self, w=32, h=32):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    # --- primitives -----------------------------------------------------
    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((int(x), int(y)), rgba(c))

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.im.getpixel((int(x), int(y)))
        return (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, c):
        """Filled rectangle, inclusive of both corners."""
        self.d.rectangle([x0, y0, x1, y1], fill=rgba(c))

    def box(self, x0, y0, x1, y1, c):
        """1px outlined rectangle, inclusive."""
        self.d.rectangle([x0, y0, x1, y1], outline=rgba(c))

    def ell(self, x0, y0, x1, y1, c):
        self.d.ellipse([x0, y0, x1, y1], fill=rgba(c))

    def ring(self, x0, y0, x1, y1, c, w=1):
        self.d.ellipse([x0, y0, x1, y1], outline=rgba(c), width=w)

    def poly(self, pts, c):
        self.d.polygon([(int(p[0]), int(p[1])) for p in pts], fill=rgba(c))

    def line(self, p0, p1, c, w=1):
        self.d.line([(int(p0[0]), int(p0[1])), (int(p1[0]), int(p1[1]))],
                    fill=rgba(c), width=w)

    def hline(self, x0, x1, y, c):
        self.d.line([(x0, y), (x1, y)], fill=rgba(c))

    def vline(self, x, y0, y1, c):
        self.d.line([(x, y0), (x, y1)], fill=rgba(c))

    def blit(self, other, ox=0, oy=0):
        self.im.alpha_composite(other.im if isinstance(other, Canvas) else other,
                                (int(ox), int(oy)))

    # --- treatments -----------------------------------------------------
    def outline(self, c=OUTLINE, diagonal=True):
        """Wrap the silhouette in a 1px dark border.

        This is the single biggest readability win at 32px: without it, a dark
        icon on the game's dark HUD loses its edges entirely.
        """
        src = self.im.copy()
        w, h = self.w, self.h
        offs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diagonal:
            offs += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        oc = rgba(c)
        px = src.load()
        for y in range(h):
            for x in range(w):
                if px[x, y][3] > 8:
                    continue
                for dx, dy in offs:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 128:
                        self.im.putpixel((x, y), oc)
                        break

    def rim(self, c, strength=1.0, dirs=((-1, 0), (0, -1))):
        """Lift the lit edges of the silhouette toward `c`.

        Applied after the body is drawn but before the outline, so the icon
        gains a catchlight along its top-left without changing its shape.
        """
        src = self.im.copy()
        px = src.load()
        for y in range(self.h):
            for x in range(self.w):
                cur = px[x, y]
                if cur[3] < 128:
                    continue
                edge = False
                for dx, dy in dirs:
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < self.w and 0 <= ny < self.h) or px[nx, ny][3] < 128:
                        edge = True
                        break
                if edge:
                    self.im.putpixel((x, y), mix(cur, c, strength))

    def shadow(self, cx, y, rx, ry=2, c=(0, 0, 0, 90)):
        """Contact shadow under a grounded object, drawn beneath what exists."""
        under = Canvas(self.w, self.h)
        under.ell(cx - rx, y - ry, cx + rx, y + ry, c)
        under.im.alpha_composite(self.im)
        self.im = under.im
        self.d = ImageDraw.Draw(self.im)

    def glow(self, cx, cy, r, c, strength=0.55):
        """Additive-ish bloom under the art. Cheap, but it is what makes the
        emissive icons (fire, lightning, crystal) read as light sources."""
        under = Canvas(self.w, self.h)
        base = rgba(c)
        for y in range(max(0, int(cy - r)), min(self.h, int(cy + r) + 1)):
            for x in range(max(0, int(cx - r)), min(self.w, int(cx + r) + 1)):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if d > r:
                    continue
                a = (1.0 - d / r) ** 2 * strength
                under.px(x, y, (base[0], base[1], base[2], int(a * 255)))
        under.im.alpha_composite(self.im)
        self.im = under.im
        self.d = ImageDraw.Draw(self.im)

    def save(self, path):
        self.im.save(path)


def contact_sheet(entries, cell=96, cols=8, bg=(26, 24, 32, 255), label=True):
    """Lay generated icons out on the sort of dark panel they'll live on, at
    the magnification a reviewer actually needs. Judging a 32px icon at 32px is
    how bad icons ship."""
    from PIL import ImageDraw as _D
    rows = (len(entries) + cols - 1) // cols
    pad = 14 if label else 0
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + pad)), bg)
    d = _D.Draw(sheet)
    for i, (name, im) in enumerate(entries):
        x, y = (i % cols) * cell, (i // cols) * (cell + pad)
        big = im.resize((cell, cell), Image.NEAREST)
        sheet.alpha_composite(big, (x, y))
        if label:
            d.text((x + 2, y + cell + 1), name, fill=(190, 190, 200, 255))
    return sheet
