"""Cyberfield — Lower City visual experiment (29/10/2026).

Generates ORIGINAL pixel-art layers for the isolated scene
res://scene/experimental/lower_city_concept.tscn. No third-party pixels are used:
every shape below is authored in code, deterministic (fixed seed) and reproducible.

    python3 -I tools/experimental/lower_city_concept.py [--preview DIR]

Output: assets/experimental/lower_city_concept/*.png (+ optional preview frames that
simulate the Godot Parallax2D math; previews are NOT runtime captures).
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/experimental/lower_city_concept"

# --- Shared gameplay contract (mirrors BiomeGenerator) -----------------------
FLOOR_TOP = 420
FLOOR_HEIGHT = 60
WORLD_W = 1920
VIEW = (1280, 720)
CAM_TOP = 24  # camera centred on the player (y≈384) → floor at 55 % of the screen

# --- Palette: cool steel base, warm practical light, neon only as focal points --
P = {
    "sky0": (6, 9, 20), "sky1": (12, 17, 40), "sky2": (30, 26, 62), "sky3": (58, 36, 72),
    "far0": (13, 16, 34), "far1": (17, 20, 42), "far_lit": (52, 62, 104),
    "mid0": (20, 33, 44), "mid1": (26, 41, 54), "mid2": (33, 51, 64), "mid_dark": (12, 20, 28),
    "rust": (70, 46, 38), "rust2": (92, 60, 44), "trim": (46, 68, 80),
    "warm": (232, 168, 82), "warm_dim": (150, 98, 52), "cyan": (88, 220, 232), "cyan_dim": (44, 120, 138),
    "mag": (214, 70, 150), "mag_dim": (120, 44, 92), "green": (70, 214, 140),
    "rail0": (14, 22, 30), "rail1": (22, 34, 44), "rail_edge": (40, 60, 72),
    "street": (20, 27, 34), "street2": (25, 34, 42), "curb": (44, 60, 70), "edge": (122, 196, 206),
    "under0": (8, 12, 17), "under1": (14, 20, 27), "pipe": (34, 46, 54), "pipe_hi": (58, 76, 86),
}


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


class Layer:
    """Draw helper with optional horizontal wrap (tileable parallax strips)."""

    def __init__(self, w, h, wrap=False, fill=(0, 0, 0, 0)):
        self.w, self.h, self.wrap = w, h, wrap
        self.im = Image.new("RGBA", (w, h), fill)
        self.d = ImageDraw.Draw(self.im)

    def _xs(self, x0, x1):
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
        for s in self._xs(x0, x1):
            self.d.rectangle((x0 + s, y0, x1 + s, y1), fill=c)

    def poly(self, pts, c):
        xs = [p[0] for p in pts]
        for s in self._xs(min(xs), max(xs)):
            self.d.polygon([(x + s, y) for x, y in pts], fill=c)

    def px(self, x, y, c):
        self.rect(x, y, x, y, c)

    def line(self, pts, c, width=1):
        xs = [p[0] for p in pts]
        for s in self._xs(min(xs), max(xs)):
            self.d.line([(x + s, y) for x, y in pts], fill=c, width=width)


# 3x5 pixel font for signage (original glyphs).
FONT = {
    "A": ["010", "101", "111", "101", "101"], "C": ["011", "100", "100", "100", "011"],
    "E": ["111", "100", "110", "100", "111"], "F": ["111", "100", "110", "100", "100"],
    "H": ["101", "101", "111", "101", "101"], "I": ["111", "010", "010", "010", "111"],
    "L": ["100", "100", "100", "100", "111"], "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"], "O": ["010", "101", "101", "101", "010"],
    "R": ["110", "101", "110", "101", "101"], "S": ["011", "100", "010", "001", "110"],
    "T": ["111", "010", "010", "010", "010"], "U": ["101", "101", "101", "101", "011"],
    "G": ["011", "100", "101", "101", "011"], "B": ["110", "101", "110", "101", "110"],
    "X": ["101", "101", "010", "101", "101"], "-": ["000", "000", "111", "000", "000"],
    "2": ["110", "001", "010", "100", "111"], "4": ["101", "101", "111", "001", "001"],
    " ": ["000", "000", "000", "000", "000"],
}


def text(layer, x, y, s, c, vertical=False, scale=1):
    for i, ch in enumerate(s):
        glyph = FONT.get(ch, FONT[" "])
        ox, oy = (x, y + i * 6 * scale) if vertical else (x + i * 4 * scale, y)
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    layer.rect(ox + gx * scale, oy + gy * scale, ox + gx * scale + scale - 1, oy + gy * scale + scale - 1, c)


def glow(im: Image.Image, radius: float, strength: float) -> Image.Image:
    """Soft additive halo from the bright pixels of a sign layer."""
    blurred = im.filter(ImageFilter.GaussianBlur(radius))
    r, g, b, a = blurred.split()
    a = a.point(lambda v: int(min(255, v * strength)))
    return Image.merge("RGBA", (r, g, b, a))


def haze(im: Image.Image, colour, amount: float) -> Image.Image:
    """Atmospheric perspective: pull a background layer toward the sky colour."""
    r, g, b, a = im.split()
    mixed = Image.blend(Image.merge("RGB", (r, g, b)), Image.new("RGB", im.size, colour), amount)
    return Image.merge("RGBA", (*mixed.split(), a))


def add_blend(frame: Image.Image, img: Image.Image, pos):
    """Preview-only approximation of Godot's CanvasItemMaterial BLEND_MODE_ADD."""
    x, y = int(pos[0]), int(pos[1])
    box = (max(0, x), max(0, y), min(frame.width, x + img.width), min(frame.height, y + img.height))
    if box[0] >= box[2] or box[1] >= box[3]:
        return
    src = img.crop((box[0] - x, box[1] - y, box[2] - x, box[3] - y))
    r, g, b, a = src.split()
    lit = Image.merge("RGB", [ImageChops.multiply(ch, a) for ch in (r, g, b)])
    base = frame.crop(box).convert("RGB")
    frame.paste(ImageChops.add(base, lit).convert("RGBA"), box[:2])


def up(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


# ---------------------------------------------------------------------------
def make_sky():
    w, h = 320, 180
    im = Image.new("RGBA", (w, h))
    stops = [(0.0, P["sky0"]), (0.22, P["sky1"]), (0.48, P["sky2"]), (0.72, P["sky3"]), (1.0, P["sky3"])]
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                k = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                # 4-step banding: pixel-art sky instead of a smooth gradient.
                k = round(k * 4) / 4
                c = tuple(int(stops[i][1][j] + (stops[i + 1][1][j] - stops[i][1][j]) * k) for j in range(3))
                break
        for x in range(w):
            im.putpixel((x, y), rgba(c))
    clouds = Layer(w, h)
    rnd = random.Random(7)
    # Low cloud shelves catching city light from below (lighter underside).
    for band_y, alpha in ((40, 70), (58, 60), (76, 90)):
        x = -40
        while x < w:
            length = rnd.randint(30, 90)
            y = band_y + rnd.randint(-2, 2)
            clouds.rect(x, y, x + length, y + 1, (44, 40, 80, alpha))
            clouds.rect(x + 3, y + 2, x + length - 3, y + 2, (92, 70, 120, alpha))
            x += length + rnd.randint(6, 30)
    im.alpha_composite(clouds.im)
    return up(im, 4)


def make_far():
    # Half resolution, tileable 640 → 1280 world px. Base of the skyline at row 330.
    lay = Layer(640, 360, wrap=True)
    rnd = random.Random(11)
    base = 330
    x = 0
    while x < 640:
        bw = rnd.randint(18, 44)
        bh = rnd.randint(120, 270)
        col = P["far0"] if rnd.random() < 0.6 else P["far1"]
        lay.rect(x, base - bh, x + bw, base, rgba(col))
        if rnd.random() < 0.35:  # stepped crown
            lay.rect(x + 4, base - bh - rnd.randint(6, 16), x + bw - 4, base - bh, rgba(col))
        if rnd.random() < 0.3:  # antenna with aircraft light
            ax = x + bw // 2
            top = base - bh - rnd.randint(18, 34)
            lay.rect(ax, top, ax, base - bh, rgba(P["far1"]))
            lay.px(ax, top, rgba(P["mag_dim"]))
        for wy in range(base - bh + 6, base - 4, 5):
            for wx in range(x + 3, x + bw - 2, 4):
                if rnd.random() < 0.10:
                    lay.px(wx, wy, rgba(rnd.choice([P["cyan_dim"], P["warm_dim"], P["far_lit"], P["far_lit"]])))
        x += bw + rnd.randint(-6, 4)
    # One distant hologram billboard: desaturated, far focal point.
    for i, hy in enumerate(range(92, 118, 3)):  # hologram ad: scanlines, no readable text
        lay.rect(214 + (i % 2), hy, 252 - (i % 3), hy, (96, 70, 150, 120))
    return up(haze(lay.im, (20, 20, 46), 0.25), 2)


def make_mid():
    # Half resolution, tileable 720 → 1440 world px. Street level at row 330.
    lay = Layer(720, 360, wrap=True)
    signs = Layer(720, 360, wrap=True)
    rnd = random.Random(23)
    street = 330
    blocks = [
        (0, 120, 118, "res"), (120, 236, 150, "hotel"), (236, 330, 96, "res"),
        (330, 470, 134, "farm"), (470, 560, 104, "res"), (560, 720, 142, "res"),
    ]
    for x0, x1, height, kind in blocks:
        top = street - height
        body = rnd.choice([P["mid0"], P["mid1"]])
        lay.rect(x0, top, x1, street, rgba(body))
        lay.rect(x0, top, x1, top + 2, rgba(P["trim"]))          # roof cap
        lay.rect(x1 - 3, top, x1, street, rgba(P["mid_dark"]))    # side shadow
        # Rooftop water tanks (caixas d'água) and AC: Lower City silhouette.
        for _ in range(rnd.randint(1, 2)):
            tx = rnd.randint(x0 + 6, max(x0 + 7, x1 - 18))
            lay.rect(tx, top - 9, tx + 12, top - 1, rgba(P["mid2"]))
            lay.rect(tx + 1, top - 10, tx + 11, top - 9, rgba(P["trim"]))
        floor_h = 22
        for fy in range(top + 10, street - 30, floor_h):
            # Window bands; a few lit warm, a few cold.
            for wx in range(x0 + 6, x1 - 8, 14):
                lit = rnd.random()
                c = P["warm"] if lit < 0.07 else P["cyan_dim"] if lit < 0.12 else P["mid_dark"]
                lay.rect(wx, fy, wx + 7, fy + 9, rgba(c))
                if c == P["warm"]:
                    lay.rect(wx, fy + 7, wx + 7, fy + 9, rgba(P["warm_dim"]))  # curtain shade
                if rnd.random() < 0.18:  # AC unit
                    lay.rect(wx + 8, fy + 6, wx + 12, fy + 10, rgba(P["mid2"]))
            if rnd.random() < 0.35:  # balcony with railing
                bx = rnd.randint(x0 + 4, max(x0 + 5, x1 - 40))
                lay.rect(bx, fy + 11, bx + 34, fy + 12, rgba(P["trim"]))
                for rx in range(bx, bx + 35, 3):
                    lay.rect(rx, fy + 7, rx, fy + 11, rgba(P["mid_dark"]))
            if rnd.random() < 0.25:  # laundry line
                lx = rnd.randint(x0 + 4, max(x0 + 5, x1 - 30))
                lay.line([(lx, fy + 1), (lx + 26, fy + 2)], rgba(P["mid_dark"]))
                for cx in range(lx + 3, lx + 24, 6):
                    lay.rect(cx, fy + 2, cx + 2, fy + 5, rgba(rnd.choice([P["rust2"], P["cyan_dim"], P["trim"]])))
        # Ground floor: shop shutters / doors.
        lay.rect(x0 + 2, street - 26, x1 - 4, street, rgba(P["mid_dark"]))
        for sx in range(x0 + 6, x1 - 10, 30):
            lay.rect(sx, street - 22, sx + 22, street - 1, rgba(P["mid1"]))
            for ly in range(street - 21, street - 1, 3):
                lay.rect(sx, ly, sx + 22, ly, rgba(P["mid0"]))
        # Pichação: short tags at hand height, low contrast.
        for _ in range(2):
            gx = rnd.randint(x0 + 4, max(x0 + 5, x1 - 24))
            gy = street - rnd.randint(28, 40)
            lay.line([(gx, gy), (gx + 4, gy - 4), (gx + 8, gy), (gx + 12, gy - 3), (gx + 18, gy + 1)], rgba(rnd.choice([P["rust2"], (60, 90, 120), (90, 60, 100)]), 200))
        if kind == "hotel":
            text(signs, x0 + 46, top + 18, "HOTEL", rgba(P["cyan"]), vertical=True, scale=2)
            lay.rect(x0 + 42, top + 14, x0 + 53, top + 78, rgba(P["mid_dark"]))  # sign backplate
        if kind == "farm":
            cx, cy = x0 + 24, top + 26
            signs.rect(cx - 2, cy - 7, cx + 2, cy + 7, rgba(P["green"]))
            signs.rect(cx - 7, cy - 2, cx + 7, cy + 2, rgba(P["green"]))
            text(signs, x0 + 38, top + 22, "FARMACIA", rgba(P["green"], 220))
    # Gambiarra: sagging power cables across the street (Lower City identity).
    for x0, x1, y in ((60, 190, 236), (300, 420, 226), (480, 650, 244), (650, 790, 232)):
        sag = 14
        pts = [(x, y + int(sag * math.sin(math.pi * (x - x0) / (x1 - x0)))) for x in range(x0, x1 + 1, 4)]
        lay.line(pts, rgba(P["mid_dark"]))
    text(signs, 610, 210, "24H", rgba(P["mag"]), scale=2)
    sign_glow = glow(signs.im, 3.0, 1.4)
    out = haze(lay.im, P["sky2"], 0.28)
    return up(out, 2), up(signs.im, 2), up(sign_glow, 2)


def make_rail():
    # Elevated viaduct: half resolution, tileable 800 → 1600 world px.
    lay = Layer(800, 360, wrap=True)
    deck_top, deck_bot = 30, 46
    lay.rect(0, deck_top, 799, deck_bot, rgba(P["rail1"]))
    lay.rect(0, deck_top, 799, deck_top + 1, rgba(P["rail_edge"]))
    lay.rect(0, deck_bot - 3, 799, deck_bot, rgba(P["rail0"]))
    for x in range(0, 800, 10):  # truss
        lay.line([(x, deck_bot), (x + 5, deck_bot + 8), (x + 10, deck_bot)], rgba(P["rail0"]))
    lay.rect(0, deck_bot + 8, 799, deck_bot + 9, rgba(P["rail0"]))
    for px_ in (130, 530):  # pillars, darker than any gameplay wall
        lay.rect(px_, deck_bot, px_ + 16, 330, rgba(P["rail0"]))
        lay.rect(px_ + 2, deck_bot, px_ + 3, 330, rgba(P["rail1"]))
        lay.poly([(px_ - 10, deck_bot), (px_ + 26, deck_bot), (px_ + 16, deck_bot + 14), (px_, deck_bot + 14)], rgba(P["rail0"]))
    # A train passing is too busy; just signal lights on the deck.
    for x in range(40, 800, 120):
        lay.px(x, deck_top - 1, rgba(P["mag_dim"]))
    return up(lay.im, 2)


def make_world():
    """World plane (1:1, not tileable): street skin, underworks, props, platform skin."""
    h_top = -200
    height = 980  # world y -200 .. 780
    lay = Layer(WORLD_W, height)
    lights = Layer(WORLD_W, height)
    rnd = random.Random(31)
    Y = lambda y: y - h_top  # world y → image row

    # Street surface (the floor collider is 0..1920 × 420..480).
    lay.rect(0, Y(FLOOR_TOP), WORLD_W - 1, Y(FLOOR_TOP + FLOOR_HEIGHT), rgba(P["street"]))
    lay.rect(0, Y(FLOOR_TOP), WORLD_W - 1, Y(FLOOR_TOP) + 1, rgba(P["edge"]))          # walkable lit edge
    lay.rect(0, Y(FLOOR_TOP) + 2, WORLD_W - 1, Y(FLOOR_TOP) + 5, rgba(P["curb"]))
    for x in range(0, WORLD_W, 32):
        lay.rect(x, Y(FLOOR_TOP) + 6, x, Y(FLOOR_TOP + FLOOR_HEIGHT), rgba(P["street2"]))
    for x0 in (520, 1250):  # storm drains
        lay.rect(x0, Y(FLOOR_TOP) + 10, x0 + 28, Y(FLOOR_TOP) + 16, rgba(P["under0"]))
        for gx in range(x0 + 2, x0 + 28, 4):
            lay.rect(gx, Y(FLOOR_TOP) + 10, gx + 1, Y(FLOOR_TOP) + 16, rgba(P["pipe"]))

    # Underworks below the street: replaces the black void seen in captures.
    lay.rect(0, Y(FLOOR_TOP + FLOOR_HEIGHT) + 1, WORLD_W - 1, height - 1, rgba(P["under0"]))
    for y, thick in ((520, 10), (556, 6), (610, 14)):
        lay.rect(0, Y(y), WORLD_W - 1, Y(y) + thick, rgba(P["pipe"]))
        lay.rect(0, Y(y), WORLD_W - 1, Y(y), rgba(P["pipe_hi"]))
        for x in range(rnd.randint(0, 80), WORLD_W, rnd.randint(140, 220)):
            lay.rect(x, Y(y) - 2, x + 6, Y(y) + thick + 2, rgba(P["under1"]))  # clamps
    for x in range(90, WORLD_W, 360):
        lay.rect(x, Y(FLOOR_TOP + FLOOR_HEIGHT), x + 22, height - 1, rgba(P["under1"]))
    for x in range(200, WORLD_W, 420):  # sodium service lamps, very dim
        lights.rect(x, Y(500), x + 3, Y(503), rgba(P["warm_dim"]))

    # --- Props (behind actors). Combat lane 700–1400 kept clear on purpose. ----
    # 1) Lámen stall, start zone focal point (warm).
    sx, base = 150, FLOOR_TOP
    lay.rect(sx, Y(base) - 40, sx + 200, Y(base) - 1, rgba(P["mid_dark"]))           # counter
    lay.rect(sx, Y(base) - 42, sx + 200, Y(base) - 40, rgba(P["trim"]))
    for i, x in enumerate(range(sx - 10, sx + 210, 20)):                                # striped awning
        c = P["rust2"] if i % 2 == 0 else (150, 130, 110)
        lay.poly([(x, Y(base) - 112), (x + 20, Y(base) - 112), (x + 24, Y(base) - 92), (x + 4, Y(base) - 92)], rgba(c))
    lay.rect(sx - 10, Y(base) - 92, sx + 214, Y(base) - 90, rgba(P["mid_dark"]))
    lay.rect(sx + 4, Y(base) - 90, sx + 6, Y(base) - 42, rgba(P["pipe"]))
    lay.rect(sx + 194, Y(base) - 90, sx + 196, Y(base) - 42, rgba(P["pipe"]))
    lay.rect(sx + 60, Y(base) - 132, sx + 142, Y(base) - 114, rgba(P["mid_dark"]))         # sign board
    text(lights, sx + 66, Y(base) - 130, "LAMEN", rgba(P["warm"]), scale=3)
    for lx in (sx + 50, sx + 110, sx + 165):                                           # paper lanterns
        lights.rect(lx, Y(base) - 86, lx + 8, Y(base) - 76, rgba(P["warm"]))
        lay.rect(lx + 3, Y(base) - 90, lx + 4, Y(base) - 87, rgba(P["mid_dark"]))
    for st in (sx + 30, sx + 80, sx + 130):                                            # stools
        lay.rect(st, Y(base) - 18, st + 14, Y(base) - 15, rgba(P["rust2"]))
        lay.rect(st + 6, Y(base) - 15, st + 8, Y(base) - 1, rgba(P["pipe"]))
    for i in range(6):                                                                  # pots + steam
        lay.rect(sx + 20 + i * 28, Y(base) - 50, sx + 34 + i * 28, Y(base) - 42, rgba(P["pipe_hi"]))

    # 2) Street lamp (cone is a separate additive sprite in Godot).
    lx = 600
    lay.rect(lx, Y(base) - 170, lx + 3, Y(base) - 1, rgba(P["pipe"]))
    lay.rect(lx, Y(base) - 170, lx + 30, Y(base) - 167, rgba(P["pipe"]))
    lights.rect(lx + 22, Y(base) - 166, lx + 34, Y(base) - 163, rgba((255, 214, 150)))

    # 3) Vending machine, cyan focal point, after the combat lane.
    vx = 1450
    lay.rect(vx, Y(base) - 86, vx + 44, Y(base) - 1, rgba(P["mid_dark"]))
    lights.rect(vx + 4, Y(base) - 80, vx + 30, Y(base) - 30, rgba(P["cyan_dim"]))
    for r in range(4):
        for c in range(3):
            lights.rect(vx + 7 + c * 8, Y(base) - 76 + r * 11, vx + 11 + c * 8, Y(base) - 70 + r * 11, rgba(rnd.choice([P["warm"], P["mag"], P["green"], P["cyan"]])))
    lay.rect(vx + 33, Y(base) - 70, vx + 40, Y(base) - 50, rgba(P["pipe"]))
    lights.rect(vx + 4, Y(base) - 20, vx + 30, Y(base) - 12, rgba(P["cyan"], 160))

    # 4) Crates and trash bags at the far end.
    for i, cx in enumerate((1560, 1592, 1576)):
        cy = Y(base) - (26 if i < 2 else 52)
        lay.rect(cx, cy, cx + 28, cy + 25, rgba(P["rust"]))
        lay.rect(cx, cy, cx + 28, cy + 2, rgba(P["rust2"]))
        lay.line([(cx, cy), (cx + 28, cy + 25)], rgba(P["mid_dark"]))
    for bx in (1630, 1650, 1666):
        lay.poly([(bx, Y(base)), (bx + 6, Y(base) - 16), (bx + 16, Y(base) - 18), (bx + 22, Y(base))], rgba((18, 22, 26)))

    # Catwalk skin for the one-way platform (collider: x 760–1060, y 300, h 14).
    px0, px1, py = 760, 1060, 300
    lay.rect(px0, Y(py), px1, Y(py) + 14, rgba(P["pipe"]))
    lay.rect(px0, Y(py), px1, Y(py) + 1, rgba(P["edge"]))
    for gx in range(px0 + 4, px1, 6):
        lay.rect(gx, Y(py) + 4, gx + 2, Y(py) + 10, rgba(P["under1"]))
    for sx_ in (px0 + 20, px1 - 24):  # hangers to the viaduct: reads as hung, not floating
        lay.rect(sx_, Y(py) - 260, sx_ + 1, Y(py), rgba(P["pipe"]))

    # Underworks fade to near-black: depth below the street, never a hard void edge.
    fade = Image.new("RGBA", (WORLD_W, height))
    fd = ImageDraw.Draw(fade)
    start = Y(FLOOR_TOP + FLOOR_HEIGHT) + 30
    for row in range(start, height):
        k = min(1.0, (row - start) / 180.0)
        fd.line([(0, row), (WORLD_W, row)], fill=(4, 6, 10, int(230 * round(k * 6) / 6)))
    lay.im.alpha_composite(fade)
    return lay.im, lights.im


def make_rain_drop():
    im = Image.new("RGBA", (2, 14))
    for y in range(14):
        a = int(255 * (y / 13) ** 1.5)
        im.putpixel((0, y), (170, 200, 230, a))
        im.putpixel((1, y), (170, 200, 230, a // 3))
    return im


def make_steam():
    im = Image.new("RGBA", (6, 6))
    for y in range(6):
        for x in range(6):
            d = ((x - 2.5) ** 2 + (y - 2.5) ** 2) ** 0.5
            if d < 3:
                im.putpixel((x, y), (210, 215, 225, int(150 * (1 - d / 3))))
    return im


def make_lamp_cone():
    """Additive sprite: hard-edged cone in 5 light steps + elliptical pool on the street."""
    w, h = 220, 176
    im = Image.new("RGBA", (w, h))
    for y in range(h - 14):
        half = 4 + y * 0.55
        for x in range(w):
            dx = abs(x - w / 2)
            if dx <= half:
                a = (1 - y / h) * (1 - (dx / half) ** 4)
                a = round(a * 5) / 5
                if (x + y) % 2 and a < 0.25:  # ordered dither at the faint edge
                    a = 0
                im.putpixel((x, y), (255, 170, 84, int(70 * a)))
    for y in range(h - 14, h):
        for x in range(w):
            nx, ny = (x - w / 2) / (w * 0.42), (y - (h - 7)) / 7.0
            d = nx * nx + ny * ny
            if d <= 1:
                im.putpixel((x, y), (255, 170, 84, int(90 * (1 - d) // 18 * 18)))
    return im


def make_fog():
    w, h = 640, 80
    im = Image.new("RGBA", (w, h))
    rnd = random.Random(3)
    lay = Layer(w, h, wrap=True)
    lay.im = im
    lay.d = ImageDraw.Draw(im)
    for _ in range(40):
        x = rnd.randint(0, w)
        y = rnd.randint(20, 60)
        lay.rect(x, y, x + rnd.randint(40, 140), y + rnd.randint(4, 12), (120, 130, 170, rnd.randint(10, 24)))
    return up(im.filter(ImageFilter.BoxBlur(2)), 2)


def make_puddles(signs: Image.Image):
    """Street reflections: vertical flip of the sign colours, squashed, very faint."""
    w = WORLD_W
    im = Image.new("RGBA", (w, 40))
    rnd = random.Random(5)
    for x0, x1 in ((420, 560), (1100, 1230), (1500, 1620)):
        for x in range(x0, x1):
            for y in range(2, 30):
                if (x + y) % 3 == 0 and rnd.random() < 0.55:
                    c = rnd.choice([P["cyan"], P["warm"], P["mag"]])
                    im.putpixel((x, y), (c[0], c[1], c[2], int(70 * (1 - y / 30))))
    return im


PUDDLES: list = []


def preview(layers, cam_x, out_path):
    sky, far, mid, mid_signs, mid_glow, rail, world, lights, cone, fog = layers
    W, H = VIEW
    frame = sky.copy()

    def place(img, pos, scroll, wrap, additive=False):
        sx = pos[0] - cam_x * scroll[0]
        sy = pos[1] - CAM_TOP * scroll[1]
        offsets = [sx]
        if wrap:
            k0 = int(math.floor(-sx / img.width)) - 1
            offsets = [sx + k * img.width for k in range(k0, k0 + W // img.width + 3)]
        for ox in offsets:
            if additive:
                add_blend(frame, img, (ox, sy))
            else:
                if ox >= W or ox + img.width <= 0 or sy >= H:
                    continue
                crop = img.crop((max(0, int(-ox)), max(0, int(-sy)), img.width, img.height))
                frame.alpha_composite(crop, (max(0, int(ox)), max(0, int(sy))))

    place(far, (0, -60), (0.15, 0.1), True)
    place(fog, (0, 250), (0.3, 0.2), True)
    place(mid, (0, -200), (0.45, 0.3), True)
    place(mid_glow, (0, -200), (0.45, 0.3), True, True)
    place(mid_signs, (0, -200), (0.45, 0.3), True, True)
    place(rail, (0, -40), (0.7, 0.6), True)
    place(fog, (320, 330), (0.8, 0.8), True)
    place(world, (0, -200), (1, 1), False)
    place(lights, (0, -200), (1, 1), False, True)
    place(cone, (600 + 28 - cone.width // 2, 420 - cone.height + 4), (1, 1), False, True)
    place(PUDDLES[0], (0, 422), (1, 1), False, True)
    # Official character sprites, only to judge readability at real scale.
    jhon = Image.open(ROOT / "assets/players/jhon/jhon_v2_idle_v2.png").crop((0, 0, 56, 72))
    enemy = Image.open(ROOT / "assets/enemies/common/v2/common_idle_v2.png")
    fw = enemy.height
    enemy = enemy.crop((0, 0, fw, enemy.height)).resize((fw * 3 // 4, enemy.height * 3 // 4), Image.NEAREST)
    for img, wx, wy in ((jhon, 820, FLOOR_TOP - 72), (enemy, 1220, FLOOR_TOP - enemy.height), (enemy, 900, 300 - enemy.height)):
        x, y = wx - cam_x, wy - CAM_TOP
        if -img.width < x < W:
            crop = img.crop((max(0, -x), 0, img.width, img.height))
            frame.alpha_composite(crop, (max(0, x), y))
    frame.save(out_path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sky = make_sky()
    far = make_far()
    mid, mid_signs, mid_glow = make_mid()
    rail = make_rail()
    world, lights = make_world()
    cone = make_lamp_cone()
    fog = make_fog()
    puddles = make_puddles(mid_signs)
    PUDDLES[:] = [puddles]
    for name, img in (("sky", sky), ("far", far), ("mid", mid), ("mid_signs", mid_signs), ("mid_glow", mid_glow),
                      ("rail", rail), ("world", world), ("world_lights", lights), ("lamp_cone", cone),
                      ("fog", fog), ("puddles", puddles), ("rain_drop", make_rain_drop()), ("steam", make_steam())):
        img.save(OUT / f"{name}.png", optimize=True)
    if "--preview" in sys.argv:
        out_dir = Path(sys.argv[sys.argv.index("--preview") + 1])
        out_dir.mkdir(parents=True, exist_ok=True)
        layers = (sky, far, mid, mid_signs, mid_glow, rail, world, lights, cone, fog)
        for cam in (0, 320, 640):
            preview(layers, cam, out_dir / f"preview_cam{cam}.png")
    print("ok", OUT)


if __name__ == "__main__":
    main()
