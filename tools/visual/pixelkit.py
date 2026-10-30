"""Shared pixel-art toolkit for Cyberfield asset generators (30/10/2026).

Everything here is deterministic and original: shapes are authored in code, no
third-party pixels. Generators in tools/visual/ build on these helpers.
"""
from __future__ import annotations

import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def hexc(value: str):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


class Canvas:
    """RGBA drawing surface; wrap=True makes horizontal strips tile seamlessly."""

    def __init__(self, w, h, wrap=False, fill=(0, 0, 0, 0)):
        self.w, self.h, self.wrap = w, h, wrap
        self.im = Image.new("RGBA", (w, h), fill)
        self.d = ImageDraw.Draw(self.im)

    def _shifts(self, x0, x1):
        if not self.wrap:
            return [0]
        shifts = [0]
        if x0 < 0:
            shifts.append(self.w)
        if x1 >= self.w:
            shifts.append(-self.w)
        return shifts

    def rect(self, x0, y0, x1, y1, c):
        if x1 < x0 or y1 < y0:
            return
        for s in self._shifts(x0, x1):
            self.d.rectangle((x0 + s, y0, x1 + s, y1), fill=c)

    def px(self, x, y, c):
        self.rect(x, y, x, y, c)

    def line(self, pts, c, width=1):
        xs = [p[0] for p in pts]
        for s in self._shifts(min(xs), max(xs)):
            self.d.line([(x + s, y) for x, y in pts], fill=c, width=width)

    def poly(self, pts, c):
        xs = [p[0] for p in pts]
        for s in self._shifts(min(xs), max(xs)):
            self.d.polygon([(x + s, y) for x, y in pts], fill=c)

    def ellipse(self, x0, y0, x1, y1, c):
        for s in self._shifts(x0, x1):
            self.d.ellipse((x0 + s, y0, x1 + s, y1), fill=c)

    def dither_rect(self, x0, y0, x1, y1, c, density):
        """Ordered (Bayer) dither: density 0..1 of pixels painted, pixel-art friendly."""
        level = int(density * 16)
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(x0, x1 + 1):
                if BAYER4[y % 4][x % 4] < level:
                    self.px(x % self.w if self.wrap else x, y, c)

    def vgradient(self, x0, y0, x1, y1, stops, steps=8, dither=True):
        """Banded vertical gradient with dithered transitions between bands."""
        h = y1 - y0 + 1
        for row in range(h):
            t = row / max(h - 1, 1)
            for i in range(len(stops) - 1):
                if stops[i][0] <= t <= stops[i + 1][0]:
                    k = (t - stops[i][0]) / max(stops[i + 1][0] - stops[i][0], 1e-6)
                    lo = math.floor(k * steps) / steps
                    hi = min(1.0, lo + 1.0 / steps)
                    frac = (k - lo) * steps
                    ca, cb = mix(stops[i][1], stops[i + 1][1], lo), mix(stops[i][1], stops[i + 1][1], hi)
                    for x in range(x0, x1 + 1):
                        use_b = dither and BAYER4[(y0 + row) % 4][x % 4] < int(frac * 16)
                        self.im.putpixel((x % self.w, y0 + row), rgba(cb if use_b else ca))
                    break


# 3x5 pixel font: full Latin capitals, digits and a few marks (original glyphs).
FONT = {
    "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"],
    "C": ["011", "100", "100", "100", "011"], "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "G": ["011", "100", "101", "101", "011"], "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"], "J": ["001", "001", "001", "101", "010"],
    "K": ["101", "101", "110", "101", "101"], "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"], "N": ["110", "101", "101", "101", "101"],
    "O": ["010", "101", "101", "101", "010"], "P": ["110", "101", "110", "100", "100"],
    "Q": ["010", "101", "101", "110", "011"], "R": ["110", "101", "110", "101", "101"],
    "S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "011"], "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"], "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"], "Z": ["111", "001", "010", "100", "111"],
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["110", "001", "010", "100", "111"], "3": ["110", "001", "010", "001", "110"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "110", "001", "110"],
    "6": ["011", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "110"],
    "-": ["000", "000", "111", "000", "000"], "/": ["001", "001", "010", "100", "100"],
    ".": ["000", "000", "000", "000", "010"], ":": ["000", "010", "000", "010", "000"],
    "+": ["000", "010", "111", "010", "000"], " ": ["000", "000", "000", "000", "000"],
}


def text(canvas: Canvas, x, y, s, c, vertical=False, scale=1):
    for i, ch in enumerate(s):
        glyph = FONT.get(ch, FONT[" "])
        ox, oy = (x, y + i * 6 * scale) if vertical else (x + i * 4 * scale, y)
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    canvas.rect(ox + gx * scale, oy + gy * scale, ox + gx * scale + scale - 1, oy + gy * scale + scale - 1, c)


def glyph_column(canvas: Canvas, x, y, count, c, rnd: random.Random):
    """Abstract signage glyphs (not a real script): dense vertical neon text."""
    for i in range(count):
        for gy in range(5):
            for gx in range(3):
                if rnd.random() < 0.55:
                    canvas.px(x + gx, y + i * 7 + gy, c)


def text_width(s, scale=1):
    return len(s) * 4 * scale - scale


def glow(im: Image.Image, radius: float, strength: float) -> Image.Image:
    blurred = im.filter(ImageFilter.GaussianBlur(radius))
    r, g, b, a = blurred.split()
    a = a.point(lambda v: int(min(255, v * strength)))
    return Image.merge("RGBA", (r, g, b, a))


def haze(im: Image.Image, colour, amount: float) -> Image.Image:
    r, g, b, a = im.split()
    mixed = Image.blend(Image.merge("RGB", (r, g, b)), Image.new("RGB", im.size, colour), amount)
    return Image.merge("RGBA", (*mixed.split(), a))


def outline(im: Image.Image, colour) -> Image.Image:
    """1 px outer outline around opaque pixels (sprite readability on busy scenery)."""
    alpha = im.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    grown = alpha.filter(ImageFilter.MaxFilter(3))
    edge = ImageChops.subtract(grown, alpha)
    out = Image.new("RGBA", im.size, rgba(colour, 0))
    out.putalpha(edge)
    solid = Image.new("RGBA", im.size, rgba(colour))
    result = Image.composite(solid, Image.new("RGBA", im.size, (0, 0, 0, 0)), edge)
    result.alpha_composite(im)
    return result


def radial(size, colour, power=2.0, max_alpha=200, steps=6):
    """Banded radial glow for additive light sprites."""
    w, h = size
    im = Image.new("RGBA", size)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / (w / 2), (y - cy) / (h / 2))
            if d < 1.0:
                a = (1.0 - d) ** power
                a = round(a * steps) / steps
                im.putpixel((x, y), rgba(colour, int(max_alpha * a)))
    return im


def cone(width, height, colour, max_alpha=70, steps=5, pool=True):
    """Downward light cone with stepped falloff and an elliptical pool at the bottom."""
    im = Image.new("RGBA", (width, height))
    body = height - (14 if pool else 0)
    for y in range(body):
        half = 4 + y * (width / 2 - 4) / max(body, 1)
        for x in range(width):
            dx = abs(x - width / 2)
            if dx <= half:
                a = (1 - y / height) * (1 - (dx / half) ** 4)
                a = round(a * steps) / steps
                if (x + y) % 2 and a < 0.25:
                    a = 0
                im.putpixel((x, y), rgba(colour, int(max_alpha * a)))
    if pool:
        for y in range(height - 14, height):
            for x in range(width):
                nx, ny = (x - width / 2) / (width * 0.42), (y - (height - 7)) / 7.0
                d = nx * nx + ny * ny
                if d <= 1:
                    im.putpixel((x, y), rgba(colour, int(max_alpha * 1.3 * (1 - d) // 18 * 18)))
    return im


def up(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def add_blend(frame: Image.Image, img: Image.Image, pos):
    """Preview-only approximation of Godot additive blending."""
    x, y = int(pos[0]), int(pos[1])
    box = (max(0, x), max(0, y), min(frame.width, x + img.width), min(frame.height, y + img.height))
    if box[0] >= box[2] or box[1] >= box[3]:
        return
    src = img.crop((box[0] - x, box[1] - y, box[2] - x, box[3] - y))
    r, g, b, a = src.split()
    lit = Image.merge("RGB", [ImageChops.multiply(ch, a) for ch in (r, g, b)])
    base = frame.crop(box).convert("RGB")
    frame.paste(ImageChops.add(base, lit).convert("RGBA"), box[:2])
