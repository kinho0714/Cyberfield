"""Cyberfield biome art generator — Operação Renascimento (30/10/2026).

Builds every gameplay biome's visual pack from code (original pixel art, fixed
seeds, reproducible) and writes the matching style table for Godot:

    assets/environment/biomes/<biome>/*.png
    scene/biomes/visual/biome_styles.gd   (generated, do not edit by hand)

Backdrop planes are stored at native pixel size and drawn at 2x; world props and
tiles are 1:1 with the 64 px characters.

    python3 -I tools/visual/biome_art.py [--preview DIR]
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelkit as pk  # noqa: E402
from pixelkit import Canvas, hexc, mix, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/environment/biomes"
STYLES_GD = ROOT / "scene/biomes/visual/biome_styles.gd"
STREET = 330  # native street row in every 360 px plane (screen row 660 at 2x)


# --------------------------------------------------------------------------- city
CITY = {
    "sky": [(0.0, hexc("070614")), (0.35, hexc("150c2c")), (0.66, hexc("341746")), (0.88, hexc("5f2150")), (1.0, hexc("7a2c55"))],
    "body": [hexc("1b1730"), hexc("201a37"), hexc("181428"), hexc("231b3a")],
    "dark": hexc("100c1c"), "trim": hexc("3a2c58"), "rim": hexc("6c3a7e"), "rim_c": hexc("2f6f86"),
    "sign": [hexc("4fe3f0"), hexc("ff4fb4"), hexc("ffb347"), hexc("a77bff"), hexc("54f0a0")],
    "win": [hexc("ffb347"), hexc("ffb347"), hexc("e8963a"), hexc("2f8696"), hexc("8a3a74")],
    "far": [hexc("1a1230"), hexc("21163a")], "haze": hexc("3b1a4c"),
}
WORDS = ["RAMEN", "HOTEL", "BAR", "24H", "ARCADE", "CYBER", "NEON", "DATA", "CLINICA", "LOJA", "KARAOKE", "FARMACIA"]


def city_sky():
    c = Canvas(320, 180)
    c.vgradient(0, 0, 319, 179, CITY["sky"], steps=5)
    rnd = random.Random(101)
    clouds = Canvas(320, 180, wrap=True)
    for band, alpha in ((52, 90), (74, 110), (96, 120), (118, 90)):
        x = rnd.randint(-40, 0)
        while x < 320:
            ln = rnd.randint(30, 110)
            y = band + rnd.randint(-3, 3)
            clouds.rect(x, y, x + ln, y + 1, (30, 16, 46, alpha))                 # dark top
            clouds.rect(x + 4, y + 2, x + ln - 4, y + 2, (150, 62, 120, alpha))  # lit underside (city glow)
            x += ln + rnd.randint(8, 40)
    c.im.alpha_composite(clouds.im)
    return c.im


def city_far():
    c = Canvas(640, 360, wrap=True)
    beacons = Canvas(640, 360, wrap=True)
    rnd = random.Random(111)
    for _ in range(70):  # stars live on a 2x plane: one crisp pixel each, never stretched blobs
        c.px(rnd.randint(0, 639), rnd.randint(0, 110), rgba(hexc("b8a6e0"), rnd.randint(50, 140)))
    x, base = 0, 320
    while x < 640:
        w, h = rnd.randint(14, 40), rnd.randint(140, 300)
        col = rnd.choice(CITY["far"])
        c.rect(x, base - h, x + w, base, rgba(col))
        if rnd.random() < 0.5:                                     # stepped crown
            c.rect(x + 3, base - h - rnd.randint(6, 18), x + w - 3, base - h, rgba(col))
        if rnd.random() < 0.35:                                    # vertical light strip
            sx = x + rnd.randint(3, max(3, w - 4))
            strip = rnd.choice([CITY["sign"][0], CITY["sign"][1], CITY["sign"][3]])
            c.rect(sx, base - h + 6, sx, base - 10, rgba(mix(strip, CITY["far"][0], 0.45)))
        if rnd.random() < 0.45:                                    # antenna + aviation light
            ax, top = x + w // 2, base - h - rnd.randint(16, 40)
            c.rect(ax, top, ax, base - h, rgba(CITY["far"][1]))
            beacons.px(ax, top, rgba(hexc("ff5a6e")))
        for wy in range(base - h + 6, base - 6, 5):
            for wx in range(x + 2, x + w - 1, 3):
                if rnd.random() < 0.07:
                    c.px(wx, wy, rgba(mix(rnd.choice(CITY["win"]), CITY["far"][0], 0.35)))
        x += w + rnd.randint(-6, 3)
    for i, hy in enumerate(range(80, 104, 3)):                      # distant holo ad
        c.rect(300 + (i % 2), hy, 344 - (i % 3), hy, (120, 70, 170, 110))
    return pk.haze(c.im, CITY["haze"], 0.30), beacons.im


def _sign_board(signs, lay, x, y, word, colour, vertical, rnd):
    if vertical:
        h = len(word) * 7 + 5
        lay.rect(x - 2, y - 3, x + 4, y + h, rgba(CITY["dark"]))
        signs.rect(x - 3, y - 3, x - 3, y + h, rgba(colour, 140))
        pk.text(signs, x, y, word, rgba(colour), vertical=True)
        return h
    w = pk.text_width(word)
    lay.rect(x - 3, y - 3, x + w + 2, y + 7, rgba(CITY["dark"]))
    signs.rect(x - 3, y - 3, x + w + 2, y - 3, rgba(colour, 150))
    signs.rect(x - 3, y + 7, x + w + 2, y + 7, rgba(colour, 150))
    pk.text(signs, x, y, word, rgba(colour))
    return w


def city_mid():
    W = 1440
    lay, signs = Canvas(W, 360, wrap=True), Canvas(W, 360, wrap=True)
    rnd = random.Random(123)
    x = 0
    while x < W:
        w = rnd.randint(70, 150) if W - x > 170 else W - x
        h = rnd.randint(110, 236)
        top, body = STREET - h, rnd.choice(CITY["body"])
        x1 = x + w - 1
        lay.rect(x, top, x1, STREET, rgba(body))
        lay.rect(x, STREET - 40, x1, STREET, rgba(mix(body, CITY["dark"], 0.45)))       # street-level shadow
        lay.rect(x, top, x1, top + 1, rgba(CITY["rim"]))                                  # sky-lit roof edge
        lay.rect(x1 - 2, top, x1, STREET, rgba(CITY["dark"]))
        if rnd.random() < 0.5:
            lay.rect(x, top + 2, x, STREET - 30, rgba(CITY["rim_c"] if rnd.random() < 0.5 else CITY["rim"]))
        for _ in range(rnd.randint(1, 3)):                                                 # rooftop kit
            kind, tx = rnd.random(), rnd.randint(x + 4, max(x + 5, x1 - 16))
            if kind < 0.45:
                lay.rect(tx, top - 10, tx + 12, top - 1, rgba(CITY["trim"]))
                lay.rect(tx + 1, top - 12, tx + 11, top - 10, rgba(CITY["dark"]))
            elif kind < 0.75:
                lay.rect(tx + 5, top - 26, tx + 5, top, rgba(CITY["trim"]))
                lay.px(tx + 5, top - 27, rgba(hexc("ff5a6e")))
            else:
                lay.ellipse(tx, top - 9, tx + 9, top - 2, rgba(CITY["trim"]))
        for ly in range(top + 18, STREET - 44, rnd.choice([26, 30, 34])):                   # floor ledges
            lay.rect(x, ly, x1 - 3, ly, rgba(mix(body, CITY["trim"], 0.5)))
        for wy in range(top + 6, STREET - 48, 10):                                         # windows
            for wx in range(x + 5, x1 - 7, 8):
                r = rnd.random()
                if r < 0.06:
                    col = rnd.choice(CITY["win"])
                    lay.rect(wx, wy, wx + 4, wy + 5, rgba(col))
                    lay.rect(wx, wy + 4, wx + 4, wy + 5, rgba(mix(col, body, 0.5)))
                elif r < 0.6:
                    lay.rect(wx, wy, wx + 4, wy + 5, rgba(mix(body, CITY["dark"], 0.6)))
                if rnd.random() < 0.05:                                                    # AC unit
                    lay.rect(wx + 5, wy + 3, wx + 9, wy + 7, rgba(CITY["trim"]))
        if rnd.random() < 0.4:                                                             # fire escape
            ex = rnd.randint(x + 6, max(x + 7, x1 - 30))
            for fy in range(top + 20, STREET - 50, 22):
                lay.rect(ex, fy, ex + 24, fy, rgba(CITY["trim"]))
                lay.line([(ex + 2, fy), (ex + 20, fy + 21)], rgba(CITY["trim"]))
        if rnd.random() < 0.35 and w > 80:                                                 # holo billboard
            bx, by = x + rnd.randint(8, w - 52), top + rnd.randint(14, max(15, h - 120))
            col = rnd.choice(CITY["sign"][:4])
            lay.rect(bx - 1, by - 1, bx + 40, by + 24, rgba(CITY["dark"]))
            for sy in range(by, by + 24, 2):
                signs.rect(bx, sy, bx + 39, sy, rgba(col, 70 + (sy - by) * 4))
            pict = rnd.choice(["bowl", "face", "arrow"])
            pc = rgba(mix(col, (255, 255, 255), 0.55), 220)
            if pict == "bowl":
                signs.rect(bx + 12, by + 12, bx + 27, by + 12, pc); signs.line([(bx + 13, by + 13), (bx + 16, by + 17), (bx + 23, by + 17), (bx + 26, by + 13)], pc)
                signs.line([(bx + 22, by + 5), (bx + 26, by + 11)], pc); signs.line([(bx + 25, by + 5), (bx + 28, by + 10)], pc)
            elif pict == "face":
                signs.d.ellipse((bx + 13, by + 4, bx + 26, by + 19), outline=pc)
                signs.rect(bx + 16, by + 9, bx + 17, by + 10, pc); signs.rect(bx + 22, by + 9, bx + 23, by + 10, pc)
                signs.rect(bx + 17, by + 15, bx + 22, by + 15, pc)
            else:
                signs.line([(bx + 10, by + 12), (bx + 22, by + 5), (bx + 22, by + 9), (bx + 30, by + 9), (bx + 30, by + 15), (bx + 22, by + 15), (bx + 22, by + 19), (bx + 10, by + 12)], pc)
        if w > 96 and h > 170 and rnd.random() < 0.55:                                     # big landmark sign
            word = rnd.choice(["HOTEL", "NEON", "ARCADE", "RAMEN", "CYBER", "DATA"])
            colour = rnd.choice(CITY["sign"][:4])
            bx, by = x + rnd.choice([6, w - 16]), top + 14
            if len(word) * 12 < h - 70:
                lay.rect(bx - 3, by - 4, bx + 8, by + len(word) * 12 + 1, rgba(CITY["dark"]))
                signs.rect(bx - 4, by - 4, bx - 4, by + len(word) * 12 + 1, rgba(colour, 170))
                signs.rect(bx + 9, by - 4, bx + 9, by + len(word) * 12 + 1, rgba(colour, 170))
                pk.text(signs, bx, by, word, rgba(colour), vertical=True, scale=2)
        elif rnd.random() < 0.75:                                                          # vertical sign
            colour = rnd.choice(CITY["sign"])
            sx = x + rnd.choice([3, w - 9]) if w > 20 else x + 3
            sy = top + rnd.randint(12, max(13, h - 140))
            if rnd.random() < 0.55:
                word = rnd.choice(WORDS)
                if len(word) * 7 < h - 80:
                    _sign_board(signs, lay, sx, sy, word, colour, True, rnd)
            else:
                n = rnd.randint(4, 9)
                lay.rect(sx - 2, sy - 3, sx + 4, sy + n * 7 + 1, rgba(CITY["dark"]))
                pk.glyph_column(signs, sx, sy, n, rgba(colour), rnd)
        # Street level: storefront or shutters, awning, horizontal sign.
        if rnd.random() < 0.6:
            sx0, sx1, sy0 = x + 5, x1 - 6, STREET - 24
            lay.rect(sx0, sy0, sx1, STREET - 2, rgba((16, 12, 20)))
            warm = rnd.choice([hexc("ffb347"), hexc("4fe3f0"), hexc("ff6fc0")])
            for row in range(20):
                k = max(0.0, 1 - row / 13)
                lay.rect(sx0 + 1, sy0 + 1 + row, sx1 - 1, sy0 + 1 + row, rgba(mix((16, 12, 20), warm, k * 0.5)))
            for mx in range(sx0, sx1, 16):
                lay.rect(mx, sy0, mx, STREET - 2, rgba(CITY["dark"]))
            for i, ax in enumerate(range(sx0 - 2, sx1, 8)):
                lay.rect(ax, sy0 - 6, ax + 7, sy0 - 3, rgba(mix(warm, (60, 30, 50), 0.55) if i % 2 else (70, 52, 80)))
            word = rnd.choice(WORDS)
            if pk.text_width(word) < w - 12:
                _sign_board(signs, lay, x + (w - pk.text_width(word)) // 2, sy0 - 16 - rnd.choice([0, 0, 8, 18, 30]), word, rnd.choice(CITY["sign"]), False, rnd)
        else:
            for sx in range(x + 5, x1 - 10, 26):
                lay.rect(sx, STREET - 22, sx + 20, STREET - 1, rgba(CITY["trim"]))
                for ly in range(STREET - 21, STREET - 1, 3):
                    lay.rect(sx, ly, sx + 20, ly, rgba(mix(CITY["trim"], CITY["dark"], 0.5)))
        x += w
    for cx0 in range(20, W, 120):                                                          # cables + string lights
        cx1, cy = cx0 + rnd.randint(70, 140), rnd.randint(150, 230)
        pts = [(xx, cy + int(12 * math.sin(math.pi * (xx - cx0) / (cx1 - cx0)))) for xx in range(cx0, cx1 + 1, 3)]
        lay.line(pts, rgba(CITY["dark"]))
        if rnd.random() < 0.4:
            for xx, yy in pts[2::4]:
                signs.px(xx, yy + 1, rgba(hexc("ffcf7a")))
    return pk.haze(lay.im, CITY["haze"], 0.18), signs.im, pk.glow(signs.im, 3.5, 2.2)


def under_layer(seed, wall, dark, pipe, lights, arch=True, kind="city"):
    """Substructure under the street (640x180 native): retaining wall, arches, pipes,
    service lights. Anchored right below the street line so the lower half of the
    screen is never an empty void.
    01/11 (Missão Visual 02): arcos irregulares e conteúdo por bioma, para a faixa não
    repetir o mesmo arco a cada 120 px — Cidade Baixa: barracas/lojas acesas, túneis com
    grade, cabos e pichações; Industrial: bocas de forno e esteiras; Laboratório/Núcleo:
    corredor de manutenção com escotilhas e caixas de conduíte."""
    c = Canvas(640, 180, wrap=True)
    rnd = random.Random(seed)
    hi = mix(wall, (255, 255, 255), 0.12)
    c.rect(0, 0, 639, 179, rgba(wall))
    c.rect(0, 0, 639, 2, rgba(hi))
    for y in range(8, 180, 14):                                     # masonry / panel courses
        c.rect(0, y, 639, y, rgba(mix(wall, dark, 0.5)))
    if arch:
        x = rnd.randint(4, 20)
        while x < 600:
            aw = rnd.randint(58, 96)
            top = rnd.randint(36, 48)
            c.ellipse(x, top, x + aw, top + aw + 20, rgba(dark))
            c.rect(x, top + aw // 2 + 6, x + aw, 179, rgba(dark))
            c.d.arc((x, top, x + aw, top + aw + 20), 180, 360, fill=rgba(mix(wall, (255, 255, 255), 0.18)))
            cx = x + aw // 2
            roll = rnd.random()
            if kind == "city" and roll < 0.45:                         # barraca/loja acesa no arco
                warm = rnd.choice([hexc("ffb347"), hexc("ff8a5a"), hexc("4fe3f0")])
                c.rect(x + 10, top + 30, x + aw - 10, top + 62, rgba(mix(warm, dark, 0.55)))
                c.rect(x + 12, top + 32, x + aw - 12, top + 46, rgba(mix(warm, dark, 0.25)))
                for sy in range(top + 32, top + 46, 3):                # persiana meio aberta
                    c.rect(x + 12, sy, x + aw - 12, sy, rgba(mix(warm, dark, 0.6)))
                c.rect(x + 8, top + 62, x + aw - 8, top + 64, rgba(pipe))
                sign = rnd.choice(["24H", "RAMEN", "FIX", "CHIPS", "BAR"])
                sx = cx - pk.text_width(sign) // 2
                c.rect(sx - 2, top + 20, sx + pk.text_width(sign) + 1, top + 27, rgba(dark))
                pk.text(c, sx, top + 21, sign, rgba(rnd.choice([hexc("ff4fb4"), hexc("4fe3f0"), hexc("ffb347")])))
            elif kind == "city" and roll < 0.70:                       # túnel com grade
                for gx in range(x + 8, x + aw - 6, 6):
                    c.rect(gx, top + 26, gx, 120, rgba(mix(wall, dark, 0.3)))
                c.ellipse(cx - 6, top + 46, cx + 6, top + 54, rgba(mix(lights[0], dark, 0.6)))
            elif kind == "industrial" and roll < 0.40:                 # boca de forno
                for k in range(6):
                    glow = mix(hexc("ff4a1f"), dark, k / 6)
                    c.rect(x + 12 + k, top + 40 + k * 3, x + aw - 12 - k, top + 60, rgba(glow))
                c.rect(x + 10, top + 60, x + aw - 10, top + 63, rgba(pipe))
                for k in range(4):
                    c.px(x + 16 + rnd.randint(0, aw - 30), top + 34 + rnd.randint(0, 6), rgba(hexc("ffd27a")))
            elif kind == "industrial" and roll < 0.65:                 # esteira com caixas
                c.rect(x + 6, top + 54, x + aw - 6, top + 57, rgba(pipe))
                for bx in range(x + 10, x + aw - 14, 16):
                    c.rect(bx, top + 46, bx + 10, top + 53, rgba(mix(hexc("6a4a2a"), dark, 0.3)))
            if kind == "city" and rnd.random() < 0.6:                  # cartaz no pilar
                px_ = x + aw + rnd.randint(6, 18)
                c.rect(px_, 46, px_ + 10, 62, rgba(rnd.choice([hexc("5a2a5a"), hexc("2a4a6a"), hexc("6a5a2a")])))
                c.rect(px_ + 2, 49, px_ + 8, 50, rgba(mix(wall, (255, 255, 255), 0.4)))
            if kind == "industrial" and rnd.random() < 0.5:            # faixa de perigo no pilar
                px_ = x + aw + 8
                for k in range(0, 14, 4):
                    c.rect(px_ + k, 70, px_ + k + 1, 74, rgba(hexc("ffb347")))
            x += aw + rnd.randint(26, 64)
    else:                                                           # corredor de manutenção (lab/núcleo)
        c.rect(0, 46, 639, 76, rgba(mix(wall, dark, 0.35)))
        c.rect(0, 46, 639, 46, rgba(hi))
        x = rnd.randint(6, 30)
        while x < 620:
            if rnd.random() < 0.55:                                     # escotilha iluminada
                c.ellipse(x, 52, x + 16, 68, rgba(pipe))
                c.ellipse(x + 3, 55, x + 13, 65, rgba(mix(lights[0], dark, 0.45)))
                c.px(x + 6, 57, rgba(mix(lights[0], (255, 255, 255), 0.4)))
            else:                                                       # caixa de conduíte
                c.rect(x, 54, x + 18, 68, rgba(pipe))
                c.rect(x + 2, 56, x + 16, 57, rgba(mix(pipe, (255, 255, 255), 0.2)))
                c.px(x + 14, 64, rgba(rnd.choice(lights)))
            x += rnd.randint(30, 70)
    for py in (26, 34, 120):                                        # pipe runs
        c.rect(0, py, 639, py + 4, rgba(pipe))
        c.rect(0, py, 639, py, rgba(mix(pipe, (255, 255, 255), 0.25)))
        for cx in range(rnd.randint(0, 40), 640, rnd.randint(70, 110)):
            c.rect(cx, py - 1, cx + 3, py + 5, rgba(dark))
    if kind == "city":
        for _ in range(7):                                          # cabos frouxos entre os canos
            x0 = rnd.randint(0, 600)
            span = rnd.randint(40, 90)
            sag = rnd.randint(4, 9)
            pts = [(x0 + k * span / 8, 18 + sag * math.sin(math.pi * k / 8)) for k in range(9)]
            c.line(pts, rgba(mix(dark, wall, 0.3)))
        for _ in range(5):                                          # pichações apagadas
            gx, gy = rnd.randint(0, 620), rnd.randint(66, 84)
            col = rnd.choice([hexc("ff4fb4"), hexc("4fe3f0"), hexc("ffb347")])
            pts = [(gx + k * 3, gy + rnd.randint(-3, 3)) for k in range(6)]
            c.line(pts, rgba(mix(col, wall, 0.5), 200))
    for lx in range(60, 640, 160):                                  # service lights
        col = lights[(lx // 160) % len(lights)]
        c.rect(lx, 12, lx + 5, 14, rgba(col))
    fade = Canvas(640, 180)
    for y in range(76, 180):                                        # sinks into darkness
        k = min(1.0, (y - 76) / 100)
        fade.rect(0, y, 639, y, rgba(dark, int(255 * round(k * 5) / 5)))
    c.im.alpha_composite(fade.im)
    return c.im


def city_rail():
    c = Canvas(800, 360, wrap=True)
    deck, beam = 150, 160
    trim, dark = hexc("2a2240"), hexc("120e1e")
    c.rect(0, deck, 799, beam, rgba(trim))
    c.rect(0, deck, 799, deck, rgba(hexc("6c4a8a")))
    c.rect(0, beam - 2, 799, beam, rgba(dark))
    for x in range(0, 800, 8):
        c.line([(x, beam), (x + 4, beam + 6), (x + 8, beam)], rgba(dark))
    for px_ in (140, 540):
        c.rect(px_, beam, px_ + 14, STREET, rgba(dark))
        c.rect(px_ + 2, beam, px_ + 3, STREET, rgba(trim))
        c.poly([(px_ - 12, beam), (px_ + 26, beam), (px_ + 14, beam + 16), (px_, beam + 16)], rgba(dark))
    for x in range(30, 800, 90):
        c.px(x, deck - 1, rgba(hexc("4fe3f0")))
    return c.im


def city_train():
    c = Canvas(240, 16)
    c.rect(0, 2, 239, 15, rgba(hexc("2a2440")))
    c.rect(0, 2, 239, 2, rgba(hexc("8a6ab0")))
    for x in range(6, 236, 10):
        c.rect(x, 5, x + 6, 9, rgba(hexc("9ff6ff")))
    c.rect(0, 12, 239, 12, rgba(hexc("ff4fb4")))
    c.poly([(239, 2), (232, 2), (239, 10)], (0, 0, 0, 0))
    return c.im


def mist(colour, seed, alpha=(10, 26)):
    c = Canvas(640, 80, wrap=True)
    rnd = random.Random(seed)
    for _ in range(46):
        x, y = rnd.randint(0, 640), rnd.randint(18, 62)
        c.rect(x, y, x + rnd.randint(40, 150), y + rnd.randint(4, 12), rgba(colour, rnd.randint(*alpha)))
    return c.im.filter(ImageFilter.BoxBlur(2))


def city_props():
    props = {}
    # Twin paper-lantern street lamp (176 px), warm amber: a practical light source.
    lamp = Canvas(40, 180)
    pole, cap = hexc("2a2236"), hexc("4a3a5e")
    lamp.rect(18, 8, 21, 179, rgba(pole))
    lamp.rect(17, 172, 22, 179, rgba(cap))
    lamp.rect(6, 8, 33, 10, rgba(pole))
    for lx in (6, 26):
        lamp.rect(lx + 3, 11, lx + 4, 13, rgba(pole))
        lamp.rect(lx, 14, lx + 7, 32, rgba(hexc("ffb347")))
        for sy in range(16, 32, 4):
            lamp.rect(lx, sy, lx + 7, sy, rgba(hexc("c8742a")))
        lamp.rect(lx, 14, lx + 7, 14, rgba(hexc("3a1e1a")))
        lamp.rect(lx, 32, lx + 7, 32, rgba(hexc("3a1e1a")))
        lamp.rect(lx + 1, 15, lx + 2, 30, rgba(hexc("ffe2a8")))
    props["lamp"] = lamp.im
    props["lamp_glow"] = pk.radial((72, 72), hexc("ffb347"), power=1.6, max_alpha=150)
    props["lamp_cone"] = pk.cone(150, 160, hexc("ffc061"), max_alpha=72)
    refl = Canvas(160, 30)
    rr = random.Random(161)
    for x in range(160):  # wet-street reflections: vertical streaks of the signs above
        col = [hexc("ff4fb4"), hexc("4fe3f0"), hexc("ffb347"), hexc("a77bff")][(x // 22) % 4]
        if rr.random() < 0.6:
            ln = rr.randint(4, 26)
            for y in range(2, 2 + ln):
                if (x + y) % 2 == 0:
                    refl.px(x, y, rgba(col, int(150 * (1 - y / 30))))
    props["reflection"] = refl.im
    # Chain-link fence, tileable 48x52.
    fence = Canvas(48, 52, wrap=True)
    wire = rgba(hexc("4a3c62"), 210)
    for i in range(-52, 48, 6):
        fence.line([(i, 4), (i + 48, 52)], wire)
        fence.line([(i + 48, 4), (i, 52)], wire)
    fence.rect(0, 0, 47, 2, rgba(hexc("5a4878")))
    fence.rect(0, 0, 1, 51, rgba(hexc("2a2236")))
    props["fence"] = fence.im
    # CRT billboard on legs with a scribbled doodle.
    board = Canvas(112, 86)
    board.rect(10, 60, 13, 85, rgba(pole)); board.rect(98, 60, 101, 85, rgba(pole))
    board.rect(0, 0, 111, 62, rgba(hexc("ff4fb4")))
    board.rect(2, 2, 109, 60, rgba(hexc("1a1430")))
    board.rect(5, 5, 106, 57, rgba(hexc("1c2a7a")))
    for sy in range(5, 58, 2):
        board.rect(5, sy, 106, sy, rgba(hexc("24369a")))
    rnd = random.Random(131)
    pts, px_, py = [], 14, 38
    for _ in range(26):
        px_ = min(100, px_ + rnd.randint(1, 6)); py = max(14, min(50, py + rnd.randint(-9, 9)))
        pts.append((px_, py))
    board.line(pts, rgba(hexc("e0b060")), width=2)
    props["board"] = board.im
    props["board_glow"] = pk.radial((150, 110), hexc("3a5aff"), power=1.4, max_alpha=90)
    # AC unit and steam vent.
    ac = Canvas(26, 20)
    ac.rect(0, 0, 25, 19, rgba(hexc("4a4260"))); ac.rect(1, 1, 24, 18, rgba(hexc("3a3450")))
    ac.ellipse(4, 3, 17, 16, rgba(hexc("2a2440")))
    for r in range(0, 6, 2):
        ac.line([(10, 9), (10 + r, 4 + r)], rgba(hexc("6a6080")))
    ac.rect(20, 4, 23, 15, rgba(hexc("2a2440")))
    props["ac"] = ac.im
    crates = Canvas(70, 30)
    for i, (cx, cy, cw) in enumerate(((0, 8, 26), (24, 2, 28), (50, 12, 20))):
        crates.rect(cx, cy, cx + cw, 29, rgba(hexc("3a2c48") if i % 2 else hexc("452f3c")))
        crates.rect(cx, cy, cx + cw, cy + 1, rgba(hexc("6a4a7a")))
        crates.line([(cx, cy), (cx + cw, 29)], rgba(hexc("241a2c")))
    props["crates"] = crates.im
    return props


def city_tiles():
    floor = Canvas(64, 60, wrap=True)
    floor.rect(0, 0, 63, 59, rgba(hexc("251c35")))
    floor.rect(0, 0, 63, 0, rgba(hexc("e0aef0")))            # bright walkable edge
    floor.rect(0, 1, 63, 1, rgba(hexc("9a62b4")))
    floor.rect(0, 2, 63, 5, rgba(hexc("3c2d52")))
    for x in (0, 32):
        floor.rect(x, 6, x, 59, rgba(hexc("1b1428")))
    rnd = random.Random(141)
    for _ in range(22):
        floor.px(rnd.randint(0, 63), rnd.randint(8, 52), rgba(hexc("2e2342")))
    for _ in range(5):
        floor.px(rnd.randint(0, 63), rnd.randint(7, 20), rgba(hexc("7a4e94")))  # wet glints
    floor.rect(0, 55, 63, 59, rgba(hexc("140f1e")))
    cat = Canvas(64, 20, wrap=True)
    cat.rect(0, 0, 63, 19, rgba(hexc("3a3050")))
    cat.rect(0, 0, 63, 0, rgba(hexc("e0aef0")))
    for gx in range(2, 64, 6):
        cat.rect(gx, 4, gx + 2, 13, rgba(hexc("161020")))
    cat.rect(0, 17, 63, 17, rgba(hexc("ff4fb4")))             # neon underglow strip
    cat.rect(0, 18, 63, 19, rgba(hexc("1a1424")))
    wall = Canvas(18, 64)
    wall.rect(0, 0, 17, 63, rgba(hexc("231b34")))
    wall.rect(0, 0, 0, 63, rgba(hexc("4fe3f0")))
    wall.rect(17, 0, 17, 63, rgba(hexc("4fe3f0")))
    wall.rect(3, 31, 14, 32, rgba(hexc("150f20")))
    return {"floor_tile": floor.im, "catwalk_tile": cat.im, "wall_tile": wall.im}


# --------------------------------------------------------------------------- industrial
IND = {
    "sky": [(0.0, hexc("0a1014")), (0.40, hexc("15222a")), (0.70, hexc("2a2c2a")), (0.88, hexc("6a3418")), (1.0, hexc("a4521c"))],
    "steel": [hexc("2b2d30"), hexc("33302c"), hexc("27292c")], "rust": hexc("5c3a24"), "rust2": hexc("7a4a28"),
    "dark": hexc("121416"), "edge": hexc("5a5c5e"), "amber": hexc("ffb347"), "fire": hexc("ff7a2a"),
    "teal": hexc("3fd6d0"), "warn": hexc("e8c23a"), "haze": hexc("2a2c2a"),
}


def _cylinder(c, x0, y0, x1, y1, base, light):
    for x in range(x0, x1 + 1):
        t = (x - x0) / max(x1 - x0, 1)
        shade = 1.0 - abs(t - 0.35) * 1.3
        c.rect(x, y0, x, y1, rgba(mix(base, light, max(0.0, shade) * 0.55)))


def _gear(c, cx, cy, r, col, teeth=10):
    for i in range(teeth):
        a = i * 2 * math.pi / teeth
        tx, ty = cx + math.cos(a) * (r + 2), cy + math.sin(a) * (r + 2)
        c.rect(int(tx) - 1, int(ty) - 1, int(tx) + 1, int(ty) + 1, col)
    c.ellipse(cx - r, cy - r, cx + r, cy + r, col)
    c.ellipse(cx - r // 3, cy - r // 3, cx + r // 3, cy + r // 3, (0, 0, 0, 0))


def _hazard(c, x0, y0, x1, y1):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            c.px(x, y, rgba(IND["warn"] if ((x + y) // 3) % 2 == 0 else IND["dark"]))


def ind_sky():
    c = Canvas(320, 180)
    c.vgradient(0, 0, 319, 179, IND["sky"], steps=5)
    smog = Canvas(320, 180, wrap=True)
    rnd = random.Random(201)
    for band, alpha in ((60, 70), (84, 90), (110, 110), (134, 90)):
        x = rnd.randint(-40, 0)
        while x < 320:
            ln = rnd.randint(40, 120)
            y = band + rnd.randint(-4, 4)
            smog.rect(x, y, x + ln, y + 2, (48, 44, 40, alpha))
            smog.rect(x + 5, y + 3, x + ln - 5, y + 3, (150, 80, 40, alpha // 2))
            x += ln + rnd.randint(6, 30)
    c.im.alpha_composite(smog.im)
    return c.im


def ind_far():
    c, beacons = Canvas(640, 360, wrap=True), Canvas(640, 360, wrap=True)
    rnd = random.Random(211)
    base, x = 320, 0
    sil, sil2 = hexc("1a2126"), hexc("20282c")
    while x < 640:
        kind = rnd.random()
        if kind < 0.3:                                              # chimney + smoke plume
            w, h = rnd.randint(8, 14), rnd.randint(180, 280)
            c.rect(x, base - h, x + w, base, rgba(sil2))
            for by in (base - h + 10, base - h + 18):
                c.rect(x, by, x + w, by + 2, rgba(hexc("6a2a20")))
            beacons.px(x + w // 2, base - h - 1, rgba(hexc("ff4a3a")))
            px_, py = x + w // 2, base - h - 6
            for i in range(26):                                     # rising, drifting smoke puffs
                r = 4 + i // 2
                px_ += rnd.randint(1, 4); py -= rnd.randint(2, 5)
                c.ellipse(px_ - r, py - r, px_ + r, py + r, rgba(hexc("3a3a3a"), max(20, 120 - i * 4)))
            x += w + rnd.randint(10, 26)
        elif kind < 0.48:                                           # cooling tower
            w, h = rnd.randint(40, 60), rnd.randint(90, 130)
            for y in range(h):
                t = y / h
                inset = int((1 - (2 * t - 1) ** 2) * w * 0.16)
                c.rect(x + inset, base - h + y, x + w - inset, base - h + y, rgba(sil))
            x += w + rnd.randint(6, 18)
        else:                                                       # factory block with saw roof
            w, h = rnd.randint(50, 110), rnd.randint(70, 150)
            c.rect(x, base - h, x + w, base, rgba(sil))
            for sx in range(x, x + w - 10, 12):
                c.poly([(sx, base - h), (sx + 12, base - h), (sx + 12, base - h - 8)], rgba(sil))
            for wy in range(base - h + 10, base - 8, 9):
                for wx in range(x + 4, x + w - 4, 7):
                    if rnd.random() < 0.08:
                        c.rect(wx, wy, wx + 3, wy + 2, rgba(mix(IND["amber"], sil, 0.4)))
            x += w + rnd.randint(-4, 6)
    return pk.haze(c.im, IND["haze"], 0.25), beacons.im


def ind_mid():
    W = 1440
    lay, glow_src = Canvas(W, 360, wrap=True), Canvas(W, 360, wrap=True)
    rnd = random.Random(221)
    x = 0
    while x < W:
        kind = rnd.random()
        if kind < 0.30:                                             # storage tanks
            w, h = rnd.randint(50, 80), rnd.randint(120, 200)
            top = STREET - h
            _cylinder(lay, x, top + 8, x + w, STREET, rnd.choice(IND["steel"]), hexc("8a8478"))
            lay.ellipse(x, top, x + w, top + 16, rgba(hexc("3a3a3c")))
            for ry in range(top + 30, STREET - 10, 34):
                lay.rect(x, ry, x + w, ry + 1, rgba(IND["dark"]))
            for _ in range(rnd.randint(3, 7)):
                rx, ry = rnd.randint(x + 3, x + w - 10), rnd.randint(top + 20, STREET - 20)
                lay.rect(rx, ry, rx + rnd.randint(3, 9), ry + rnd.randint(4, 16), rgba(IND["rust"], 190))
            lay.rect(x + w // 2 - 2, top + 20, x + w // 2 + 2, STREET, rgba(hexc("1e1e20")))   # ladder spine
            for ly in range(top + 22, STREET, 5):
                lay.rect(x + w // 2 - 4, ly, x + w // 2 + 4, ly, rgba(hexc("1e1e20")))
            pk.text(lay, x + 6, top + 40, "T-" + str(rnd.randint(1, 9)), rgba(IND["warn"]))
            x += w + rnd.randint(4, 14)
        elif kind < 0.68:                                           # furnace hall
            w, h = rnd.randint(110, 170), rnd.randint(130, 210)
            top = STREET - h
            body = rnd.choice(IND["steel"])
            lay.rect(x, top, x + w, STREET, rgba(body))
            lay.rect(x, top, x + w, top + 1, rgba(IND["edge"]))
            lay.rect(x, top + 4, x + w, top + 5, rgba(IND["teal"]))                    # teal edge strip (ref: cyan edges)
            for gx in range(x + 8, x + w - 30, 46):                                     # furnace mouths
                gy = STREET - 54
                lay.rect(gx - 2, gy - 2, gx + 28, gy + 30, rgba(IND["dark"]))
                for row in range(28):                                                   # fire seen through the grille
                    k = row / 27
                    lay.rect(gx, gy + row, gx + 26, gy + row, rgba(mix(hexc("5a1a08"), IND["fire"], k)))
                for bx in range(gx, gx + 27, 4):
                    lay.rect(bx, gy, bx + 1, gy + 28, rgba(IND["dark"]))                # grille bars
                glow_src.rect(gx + 4, gy + 16, gx + 22, gy + 27, rgba(IND["fire"], 110))  # bloom core only
            for py in range(top + 16, STREET - 70, 22):                                 # pipe bundle
                for k in range(3):
                    yy = py + k * 5
                    lay.rect(x - 4, yy, x + w + 4, yy + 3, rgba(mix(IND["steel"][1], hexc("8a8478"), 0.25)))
                    lay.rect(x - 4, yy, x + w + 4, yy, rgba(hexc("8a8478")))
            if rnd.random() < 0.7:
                _gear(lay, x + w - 26, top + 40, 16, rgba(hexc("4a4844")))
            _hazard(lay, x, STREET - 10, x + w, STREET - 6)
            word = rnd.choice(["PERIGO", "FORNO 2", "SETOR 7", "ALTA TENSAO", "CALOR"])
            sx = x + 10
            lay.rect(sx - 3, top + 14, sx + pk.text_width(word) + 2, top + 24, rgba(IND["dark"]))
            pk.text(glow_src, sx, top + 17, word, rgba(IND["warn"] if rnd.random() < 0.5 else IND["teal"]))
            x += w + rnd.randint(2, 10)
        elif kind < 0.84:                                           # hopper silo on legs
            w, h = rnd.randint(36, 54), rnd.randint(150, 210)
            top = STREET - h
            _cylinder(lay, x, top, x + w, top + h // 2, rnd.choice(IND["steel"]), hexc("8a8478"))
            lay.poly([(x, top + h // 2), (x + w, top + h // 2), (x + w // 2 + 5, top + h // 2 + 30), (x + w // 2 - 5, top + h // 2 + 30)], rgba(hexc("2e2c2a")))
            for lx in (x + 3, x + w - 5):
                lay.rect(lx, top + h // 2, lx + 2, STREET, rgba(hexc("3c3a38")))
            lay.rect(x, top + 10, x + w, top + 12, rgba(IND["rust"]))
            glow_src.px(x + w // 2, top - 1, rgba(hexc("ff4a3a")))
            x += w + rnd.randint(8, 24)
        else:                                                       # open steel frame / truss tower
            w, h = rnd.randint(40, 70), rnd.randint(150, 240)
            top = STREET - h
            col = rgba(hexc("3c3a38"))
            lay.rect(x, top, x + 2, STREET, col); lay.rect(x + w - 2, top, x + w, STREET, col)
            for yy in range(top, STREET - 20, 24):
                lay.rect(x, yy, x + w, yy + 1, col)
                lay.line([(x, yy), (x + w, yy + 24)], col); lay.line([(x + w, yy), (x, yy + 24)], col)
            glow_src.px(x + w // 2, top - 1, rgba(hexc("ff4a3a")))
            x += w + rnd.randint(6, 20)
    for cx in range(0, W, 160):                                     # conveyor at mid height
        cy = 120 + (cx // 160) % 3 * 18
        lay.rect(cx, cy, cx + 130, cy + 5, rgba(hexc("2a2826")))
        for rx in range(cx, cx + 130, 10):
            lay.ellipse(rx, cy + 4, rx + 4, cy + 8, rgba(hexc("1a1a1a")))
        for bx in range(cx + 6, cx + 120, 28):
            lay.rect(bx, cy - 7, bx + 9, cy - 1, rgba(IND["rust2"]))
    return pk.haze(lay.im, IND["haze"], 0.28), glow_src.im, pk.glow(glow_src.im, 4.0, 2.0)


def ind_gantry():
    c = Canvas(800, 360, wrap=True)
    beam_y = 70
    col, dark = hexc("3a3836"), hexc("181818")
    c.rect(0, beam_y, 799, beam_y + 12, rgba(col))
    c.rect(0, beam_y, 799, beam_y, rgba(hexc("6a6660")))
    for x in range(0, 800, 12):
        c.line([(x, beam_y + 12), (x + 6, beam_y + 20), (x + 12, beam_y + 12)], rgba(dark))
    _hazard(c, 300, beam_y + 13, 360, beam_y + 16)
    c.rect(318, beam_y + 16, 342, beam_y + 30, rgba(hexc("4a4642")))             # trolley
    for cy in range(beam_y + 30, beam_y + 150, 4):                                  # chain
        c.rect(329, cy, 331, cy + 2, rgba(dark))
    c.poly([(322, beam_y + 150), (338, beam_y + 150), (334, beam_y + 166), (330, beam_y + 160)], rgba(hexc("6a6660")))
    for px_ in (100, 620):
        c.rect(px_, beam_y + 12, px_ + 10, STREET, rgba(dark))
    return c.im


def ind_props():
    props = {}
    lamp = Canvas(48, 190)
    pole = hexc("2a2a2c")
    lamp.rect(8, 10, 11, 189, rgba(pole)); lamp.rect(6, 182, 13, 189, rgba(hexc("3a3a3c")))
    lamp.rect(8, 8, 40, 11, rgba(pole))
    lamp.rect(30, 12, 44, 16, rgba(hexc("3a3a3c"))); lamp.rect(31, 16, 43, 17, rgba(hexc("ffd27a")))
    props["lamp"] = lamp.im
    props["lamp_glow"] = pk.radial((60, 40), hexc("ffb347"), power=1.5, max_alpha=150)
    props["lamp_cone"] = pk.cone(170, 176, hexc("ff9a3a"), max_alpha=64)
    barrel = Canvas(44, 30)
    for i, bx in enumerate((0, 22)):
        _cylinder(barrel, bx, 2, bx + 18, 29, IND["rust"] if i else hexc("6a5a1a"), hexc("caa860"))
        barrel.rect(bx, 8, bx + 18, 9, rgba(IND["dark"])); barrel.rect(bx, 20, bx + 18, 21, rgba(IND["dark"]))
    _hazard(barrel, 23, 12, 39, 16)
    props["barrels"] = barrel.im
    post = Canvas(12, 46)
    post.rect(2, 6, 9, 45, rgba(IND["dark"]))
    _hazard(post, 3, 8, 8, 44)
    post.rect(1, 0, 10, 5, rgba(hexc("ff4a3a")))
    props["post"] = post.im
    props["post_glow"] = pk.radial((30, 30), hexc("ff4a3a"), power=1.6, max_alpha=170)
    vent = Canvas(64, 44)
    vent.rect(0, 0, 63, 43, rgba(IND["dark"]))
    for row in range(36):
        vent.rect(4, 4 + row, 59, 4 + row, rgba(mix(IND["fire"], (40, 10, 4), row / 36)))
    for bx in range(4, 60, 5):
        vent.rect(bx, 4, bx + 1, 40, rgba(IND["dark"]))
    props["vent"] = vent.im
    props["vent_glow"] = pk.radial((120, 70), hexc("ff7a2a"), power=1.4, max_alpha=120)
    gear = Canvas(44, 44)
    _gear(gear, 21, 21, 15, rgba(hexc("5a5650")), teeth=12)
    gear.ellipse(17, 17, 25, 25, rgba(hexc("2a2826")))
    props["gear"] = gear.im
    pipes = Canvas(40, 200)
    for i, px_ in enumerate((2, 16, 28)):
        _cylinder(pipes, px_, 0, px_ + 8 - i, 199, IND["steel"][i % 3], hexc("8a8478"))
        for fy in range(20 + i * 13, 200, 60):
            pipes.rect(px_ - 1, fy, px_ + 9 - i, fy + 3, rgba(hexc("4a4844")))
    pipes.rect(14, 90, 26, 102, rgba(hexc("c03a2a")))                                # valve wheel
    props["pipes"] = pipes.im
    return props


def ind_tiles():
    floor = Canvas(64, 60, wrap=True)
    floor.rect(0, 0, 63, 59, rgba(hexc("3a312a")))
    floor.rect(0, 0, 63, 0, rgba(hexc("ffcf7a")))
    floor.rect(0, 1, 63, 2, rgba(hexc("6a5a48")))
    _hazard(floor, 0, 3, 63, 6)
    for x in (0, 32):
        floor.rect(x, 7, x, 59, rgba(hexc("241e1a")))
        for ry in (10, 50):
            floor.px(x + 3, ry, rgba(hexc("6a5a48"))); floor.px(x + 28, ry, rgba(hexc("6a5a48")))
    rnd = random.Random(241)
    for _ in range(8):
        rx, ry = rnd.randint(0, 60), rnd.randint(9, 48)
        floor.rect(rx, ry, rx + rnd.randint(2, 7), ry + rnd.randint(1, 4), rgba(IND["rust"]))
    floor.rect(0, 55, 63, 59, rgba(hexc("181412")))
    cat = Canvas(64, 20, wrap=True)
    cat.rect(0, 0, 63, 19, rgba(hexc("4a4038")))
    cat.rect(0, 0, 63, 0, rgba(hexc("ffcf7a")))
    for gx in range(2, 64, 5):
        cat.rect(gx, 4, gx + 2, 14, rgba(hexc("1a1612")))
    cat.rect(0, 17, 63, 17, rgba(IND["teal"]))
    wall = Canvas(18, 64)
    wall.rect(0, 0, 17, 63, rgba(hexc("3a302a")))
    wall.rect(0, 0, 0, 63, rgba(IND["teal"])); wall.rect(17, 0, 17, 63, rgba(IND["teal"]))
    for ry in (6, 38):
        wall.px(4, ry, rgba(hexc("8a7a68"))); wall.px(13, ry, rgba(hexc("8a7a68")))
    _hazard(wall, 2, 28, 15, 33)
    return {"floor_tile": floor.im, "catwalk_tile": cat.im, "wall_tile": wall.im}


def build_industrial():
    out = OUT / "industrial"
    out.mkdir(parents=True, exist_ok=True)
    far, beacons = ind_far()
    mid, signs, glow_ = ind_mid()
    images = {"sky": ind_sky(), "far": far, "far_beacons": beacons, "mid": mid, "mid_signs": signs, "mid_glow": glow_,
              "under": under_layer(251, hexc("1e1a17"), hexc("0c0a09"), hexc("3a3430"), [hexc("ffb347"), hexc("ff4a3a")], kind="industrial"),
              "rail": ind_gantry(), "mist_far": mist(hexc("5a5048"), 261, (14, 34)), "mist_near": mist(hexc("8a6a50"), 262, (12, 30))}
    images.update(ind_props())
    images.update(ind_tiles())
    for name, im in images.items():
        im.save(out / f"{name}.png", optimize=True)
    return images


# --------------------------------------------------------------------------- laboratory
LAB = {
    "wall": [(0.0, hexc("080c1c")), (0.45, hexc("101632")), (0.75, hexc("1c1436")), (1.0, hexc("3c1640"))],
    "panel": [hexc("1a2340"), hexc("1e2848"), hexc("172038")], "seam": hexc("0c1124"), "edge": hexc("34436e"),
    "cyan": hexc("4fe3f0"), "mag": hexc("ff4fb4"), "green": hexc("54f0a0"), "white": hexc("cfe8ff"), "haze": hexc("1a1838"),
}


def lab_sky():
    c = Canvas(320, 180)
    c.vgradient(0, 0, 319, 179, LAB["wall"], steps=5)
    wash = Canvas(320, 180)
    for x in range(320):                                            # cyan light from the left, magenta from the right
        k = x / 319
        for y in range(0, 180, 1):
            if pk.BAYER4[y % 4][x % 4] < int((1 - k) * 3):
                wash.px(x, y, rgba(LAB["cyan"], 22))
            elif pk.BAYER4[y % 4][x % 4] < int(k * 3):
                wash.px(x, y, rgba(LAB["mag"], 22))
    c.im.alpha_composite(wash.im)
    return c.im


def lab_far():
    c, lights = Canvas(640, 360, wrap=True), Canvas(640, 360, wrap=True)
    rnd = random.Random(301)
    base = 320
    for x in range(0, 640, 4):                                      # far hall: ceiling ribs
        if x % 32 == 0:
            c.rect(x, 0, x + 2, base, rgba(hexc("121a32")))
    for cx in range(30, 640, 150):                                  # containment cylinders
        w = rnd.randint(34, 50)
        top = rnd.randint(90, 140)
        c.rect(cx, top, cx + w, base, rgba(hexc("141c36")))
        c.rect(cx + 3, top + 8, cx + w - 3, base - 10, rgba(hexc("0e2a3a")))
        for ly in range(top + 12, base - 12, 6):
            lights.rect(cx + 5, ly, cx + w - 5, ly, rgba(LAB["cyan"], 60))
        lights.rect(cx + w // 2 - 1, top + 10, cx + w // 2 + 1, base - 12, rgba(LAB["cyan"], 150))
        c.rect(cx - 4, top - 6, cx + w + 4, top, rgba(hexc("1e2848")))
        c.rect(cx - 4, base - 10, cx + w + 4, base, rgba(hexc("1e2848")))
    for y in (60, 200):                                             # distant catwalks
        c.rect(0, y, 639, y + 3, rgba(hexc("1a2240")))
        for x in range(0, 640, 10):
            c.rect(x, y - 8, x, y, rgba(hexc("1a2240")))
    return pk.haze(c.im, LAB["haze"], 0.25), lights.im


def lab_mid():
    W = 1440
    lay, lights = Canvas(W, 360, wrap=True), Canvas(W, 360, wrap=True)
    rnd = random.Random(311)
    top = 40
    for x in range(0, W, 48):                                       # modular wall panels
        col = rnd.choice(LAB["panel"])
        lay.rect(x, top, x + 47, STREET, rgba(col))
        lay.rect(x, top, x, STREET, rgba(LAB["seam"]))
        for y in range(top, STREET, 40):
            lay.rect(x, y, x + 47, y, rgba(LAB["seam"]))
            lay.rect(x + 1, y + 1, x + 46, y + 1, rgba(LAB["edge"]))
    detail = random.Random(317)                                     # 01/11: arquitetura dos painéis (RNG próprio)
    for x in range(0, W, 48):
        for y in range(top, STREET - 40, 40):
            roll = detail.random()
            if roll < 0.45:                                         # painel com recorte interno
                lay.rect(x + 6, y + 6, x + 41, y + 33, rgba(mix(LAB["panel"][0], hexc("05070e"), 0.35)))
                lay.rect(x + 6, y + 6, x + 41, y + 6, rgba(LAB["edge"]))
            elif roll < 0.60:                                       # grelha
                for gy in range(y + 8, y + 32, 3):
                    lay.rect(x + 10, gy, x + 37, gy, rgba(LAB["seam"]))
            for bx, by in ((x + 3, y + 3), (x + 44, y + 3), (x + 3, y + 36), (x + 44, y + 36)):
                lay.px(bx, by, rgba(LAB["edge"]))                   # parafusos
            if detail.random() < 0.12:
                lights.px(x + 40, y + 10, rgba(detail.choice([LAB["cyan"], LAB["green"], LAB["mag"]])))
    for px_ in range(24, W, 192):                                   # pilastras com fita de luz
        lay.rect(px_, top, px_ + 9, STREET, rgba(hexc("10162c")))
        lay.rect(px_, top, px_, STREET, rgba(LAB["edge"]))
        lights.rect(px_ + 4, top + 12, px_ + 5, STREET - 20, rgba(LAB["cyan"], 110))
    for cy in (top + 22, STREET - 30):                              # eletrodutos horizontais
        lay.rect(0, cy, W - 1, cy + 3, rgba(hexc("2a3660")))
        lay.rect(0, cy, W - 1, cy, rgba(hexc("4a5a90")))
        for bx in range(10, W, 64):
            lay.rect(bx, cy - 1, bx + 2, cy + 4, rgba(hexc("0e1428")))
    lay.rect(0, top - 6, W - 1, top, rgba(hexc("0e1428")))
    for x in range(0, W, 96):                                       # ceiling fluorescent bars
        col = LAB["mag"] if (x // 96) % 3 == 0 else LAB["white"]
        lights.rect(x + 20, top + 4, x + 76, top + 6, rgba(col))
    x = 10
    while x < W - 60:
        kind = rnd.random()
        if kind < 0.28:                                             # monitor bank
            for i in range(rnd.randint(2, 4)):
                mx, my = x + i * 34, rnd.choice([150, 170, 190])
                lay.rect(mx - 2, my - 2, mx + 29, my + 21, rgba(hexc("0a0e1c")))
                scr = rnd.choice([LAB["cyan"], LAB["mag"], LAB["green"]])
                lights.rect(mx, my, mx + 27, my + 19, rgba(scr, 70))
                pts = [(mx + 2 + k * 3, my + 14 - rnd.randint(0, 9)) for k in range(9)]
                lights.line(pts, rgba(scr))
                lights.rect(mx + 2, my + 2, mx + 12, my + 2, rgba(scr))
            x += 140
        elif kind < 0.48:                                           # specimen tanks
            for i in range(rnd.randint(1, 3)):
                tx, tt = x + i * 30, rnd.choice([226, 244])
                lay.rect(tx, tt - 6, tx + 22, STREET, rgba(hexc("1e2848")))
                lights.rect(tx + 3, tt, tx + 19, STREET - 12, rgba(LAB["green"] if i % 2 else LAB["cyan"], 42))
                for by in range(tt + 6, STREET - 14, 9):
                    lights.px(tx + 8 + (by % 5), by, rgba(LAB["white"]))
                lay.rect(tx - 2, STREET - 12, tx + 24, STREET, rgba(hexc("141a30")))
            x += 110
        elif kind < 0.62:                                           # holo ring screen (ref: round display)
            cx, cy = x + 30, rnd.choice([160, 180])
            lay.ellipse(cx - 28, cy - 28, cx + 28, cy + 28, rgba(hexc("0a0e1c")))
            lights.d.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), outline=rgba(LAB["cyan"]), width=2)
            lights.d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), outline=rgba(LAB["cyan"], 160))
            lights.d.arc((cx - 8, cy - 8, cx + 8, cy + 8), 40, 300, fill=rgba(LAB["white"]), width=2)
            x += 90
        elif kind < 0.80:                                           # blast door + warning sign
            dx = x
            lay.rect(dx, STREET - 90, dx + 50, STREET, rgba(hexc("0e1428")))
            lay.rect(dx + 3, STREET - 86, dx + 47, STREET, rgba(hexc("222c50")))
            lay.rect(dx + 24, STREET - 86, dx + 25, STREET, rgba(hexc("0e1428")))
            for hy in range(STREET - 80, STREET, 14):
                lights.rect(dx + 6, hy, dx + 20, hy, rgba(LAB["mag"], 140))
            word = rnd.choice(["LAB 4", "BIO", "SETOR 9", "ACESSO", "CRIO"])
            lay.rect(dx + 2, STREET - 106, dx + 4 + pk.text_width(word) + 2, STREET - 96, rgba(hexc("0a0e1c")))
            pk.text(lights, dx + 4, STREET - 103, word, rgba(LAB["cyan"]))
            x += 80
        else:                                                       # cable bundle + vent
            for k in range(4):
                lay.line([(x + k * 4, top), (x + 10 + k * 3, 120), (x + k * 5, 200)], rgba(hexc("0a0e1c")))
            lay.rect(x + 20, 220, x + 56, 248, rgba(hexc("0e1428")))
            for vy in range(222, 248, 4):
                lay.rect(x + 22, vy, x + 54, vy, rgba(hexc("2a3660")))
            x += 70
        x += rnd.randint(10, 30)
    wash = Image.new("RGBA", (W, 360))
    for i, wx in enumerate(range(0, W, 240)):                       # coloured light washes on the walls
        blob = pk.radial((260, 220), LAB["mag"] if i % 2 else LAB["cyan"], power=1.8, max_alpha=30, steps=24)
        for dx in (0, -W):
            wash.alpha_composite(blob, (wx - 10 + dx if wx - 10 + dx >= 0 else 0, 90)) if wx - 10 + dx >= 0 else None
    lay.rect(0, STREET - 6, W - 1, STREET, rgba(hexc("0e1428")))           # skirting with cyan strip
    lights.rect(0, STREET - 4, W - 1, STREET - 4, rgba(LAB["cyan"], 120))
    glow_img = pk.glow(lights.im, 3.5, 2.0)
    glow_img.alpha_composite(wash)
    return pk.haze(lay.im, LAB["haze"], 0.20), lights.im, glow_img


def lab_ceiling():
    c = Canvas(800, 360, wrap=True)
    for x in range(0, 800, 80):
        c.rect(x, 0, x + 6, 26, rgba(hexc("0e1428")))
    c.rect(0, 26, 799, 34, rgba(hexc("141c38")))
    c.rect(0, 26, 799, 26, rgba(hexc("34436e")))
    for x in range(20, 800, 80):
        c.rect(x, 35, x + 40, 37, rgba(hexc("cfe8ff")))
    return c.im


def lab_props():
    props = {}
    term = Canvas(64, 46)
    term.rect(0, 22, 63, 45, rgba(hexc("1e2848"))); term.rect(0, 22, 63, 23, rgba(hexc("4a5a8a")))
    term.rect(14, 0, 49, 21, rgba(hexc("0a0e1c"))); term.rect(16, 2, 47, 19, rgba(hexc("103a48")))
    for k in range(6):
        term.rect(18, 4 + k * 3, 18 + (k * 7) % 26, 4 + k * 3, rgba(LAB["cyan"]))
    term.rect(4, 26, 30, 29, rgba(hexc("2a3660")))
    for kx in range(6, 30, 4):
        term.px(kx, 27, rgba(LAB["mag"]))
    props["terminal"] = term.im
    props["terminal_glow"] = pk.radial((90, 60), LAB["cyan"], power=1.5, max_alpha=90)
    tank = Canvas(34, 92)
    tank.rect(0, 0, 33, 7, rgba(hexc("2a3660"))); tank.rect(0, 84, 33, 91, rgba(hexc("2a3660")))
    tank.rect(2, 8, 31, 83, rgba(hexc("0e2a3a")))
    for y in range(12, 82):
        tank.rect(4, y, 29, y, rgba(mix(hexc("0e3a48"), LAB["cyan"], 0.25 + 0.25 * math.sin(y / 6))))
    tank.ellipse(10, 30, 23, 56, rgba(hexc("1a1028")))               # dark specimen silhouette
    tank.rect(14, 54, 19, 70, rgba(hexc("1a1028")))
    for by in range(16, 80, 11):
        tank.px(8 + by % 13, by, rgba(LAB["white"]))
    tank.rect(4, 8, 5, 83, rgba(hexc("cfe8ff"), 120))
    props["tank"] = tank.im
    props["tank_glow"] = pk.radial((80, 120), LAB["cyan"], power=1.4, max_alpha=90)
    hang = Canvas(60, 150)
    hang.rect(29, 0, 30, 130, rgba(hexc("0a0e1c")))
    hang.rect(14, 130, 45, 136, rgba(hexc("2a3660"))); hang.rect(16, 136, 43, 137, rgba(LAB["white"]))
    props["hang_lamp"] = hang.im
    props["hang_cone"] = pk.cone(160, 170, LAB["white"], max_alpha=40)
    rack = Canvas(30, 70)
    rack.rect(0, 0, 29, 69, rgba(hexc("141a30"))); rack.rect(1, 1, 28, 68, rgba(hexc("1e2848")))
    rnd = random.Random(321)
    for ry in range(4, 66, 6):
        rack.rect(3, ry, 26, ry + 3, rgba(hexc("0e1428")))
        for lx in range(5, 25, 4):
            if rnd.random() < 0.4:
                rack.px(lx, ry + 1, rgba(rnd.choice([LAB["cyan"], LAB["green"], LAB["mag"]])))
    props["rack"] = rack.im
    return props


def lab_tiles():
    floor = Canvas(64, 60, wrap=True)
    floor.rect(0, 0, 63, 59, rgba(hexc("232c4e")))
    floor.rect(0, 0, 63, 0, rgba(hexc("8ff6ff")))
    floor.rect(0, 1, 63, 2, rgba(hexc("4a5a8a")))
    for x in (0, 32):
        floor.rect(x, 3, x, 59, rgba(hexc("1a2240")))
        floor.rect(x + 1, 3, x + 1, 59, rgba(hexc("2e3a62")))
    floor.rect(0, 30, 63, 30, rgba(hexc("1a2240")))
    floor.rect(0, 55, 63, 59, rgba(hexc("10162c")))
    cat = Canvas(64, 20, wrap=True)
    cat.rect(0, 0, 63, 19, rgba(hexc("1e2848")))
    cat.rect(0, 0, 63, 0, rgba(hexc("8ff6ff")))
    cat.rect(0, 3, 63, 12, rgba(hexc("2a3a6a")))
    cat.rect(0, 16, 63, 16, rgba(LAB["mag"]))
    wall = Canvas(18, 64)
    wall.rect(0, 0, 17, 63, rgba(hexc("4a5a8a")))
    wall.rect(2, 0, 15, 63, rgba(hexc("6a7aaa")))
    wall.rect(0, 0, 0, 63, rgba(LAB["cyan"])); wall.rect(17, 0, 17, 63, rgba(LAB["cyan"]))
    wall.rect(2, 31, 15, 32, rgba(hexc("2a3660")))
    return {"floor_tile": floor.im, "catwalk_tile": cat.im, "wall_tile": wall.im}


def build_lab():
    out = OUT / "lab"
    out.mkdir(parents=True, exist_ok=True)
    far, lights = lab_far()
    mid, signs, glow_ = lab_mid()
    images = {"sky": lab_sky(), "far": far, "far_beacons": lights, "mid": mid, "mid_signs": signs, "mid_glow": glow_,
              "under": under_layer(331, hexc("141a30"), hexc("070a16"), hexc("2a3660"), [LAB["cyan"], LAB["mag"]], arch=False, kind="lab"),
              "rail": lab_ceiling(), "mist_far": mist(hexc("4a3a8a"), 341, (8, 22)), "mist_near": mist(hexc("8a4aa0"), 342, (8, 22))}
    images.update(lab_props())
    images.update(lab_tiles())
    for name, im in images.items():
        im.save(out / f"{name}.png", optimize=True)
    return images


# --------------------------------------------------------------------------- core (boss arena)
CORE = {"sky": [(0.0, hexc("05040a")), (0.5, hexc("0e0814")), (0.85, hexc("1c0a1c")), (1.0, hexc("300e24"))],
        "metal": hexc("17141c"), "dark": hexc("0a0608"), "red": hexc("ff3d5f"), "mag": hexc("ff2a6d"), "haze": hexc("200810")}


def core_sky():
    c = Canvas(320, 180)
    c.vgradient(0, 0, 319, 179, CORE["sky"], steps=5)
    return c.im


def core_far():
    c, lights = Canvas(640, 360, wrap=True), Canvas(640, 360, wrap=True)
    cx, cy = 320, 170
    for r, col in ((120, hexc("140c10")), (100, hexc("0a0608"))):
        c.ellipse(cx - r, cy - r, cx + r, cy + r, rgba(col))
    for r, a in ((96, 200), (84, 120), (60, 90)):                   # reactor rings (pulse in Godot)
        lights.d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=rgba(CORE["red"], a), width=2)
    lights.ellipse(cx - 18, cy - 18, cx + 18, cy + 18, rgba(CORE["mag"], 200))
    for a in range(0, 360, 30):                                     # spokes
        x1, y1 = cx + math.cos(math.radians(a)) * 100, cy + math.sin(math.radians(a)) * 100
        c.line([(cx + math.cos(math.radians(a)) * 30, cy + math.sin(math.radians(a)) * 30), (x1, y1)], rgba(hexc("1e1418")), width=3)
    for x in range(0, 640, 64):                                     # chamber ribs
        c.rect(x, 0, x + 6, 360, rgba(hexc("100a0c")))
    return pk.haze(c.im, CORE["haze"], 0.2), lights.im


def core_mid():
    W = 1440
    lay, lights = Canvas(W, 360, wrap=True), Canvas(W, 360, wrap=True)
    rnd = random.Random(401)
    for x in range(0, W, 60):                                       # machinery wall
        h = rnd.randint(90, 170)
        lay.rect(x, STREET - h, x + 58, STREET, rgba(CORE["metal"]))
        lay.rect(x, STREET - h, x + 58, STREET - h + 1, rgba(hexc("3a2a30")))
        for py in range(STREET - h + 14, STREET - 10, 16):
            lay.rect(x + 4, py, x + 54, py + 3, rgba(hexc("241a1e")))
        if rnd.random() < 0.6:                                      # alarm light
            lights.rect(x + 26, STREET - h + 4, x + 31, STREET - h + 7, rgba(CORE["red"]))
        for cx in range(x + 8, x + 52, 14):                         # energy conduits (dim: the boss is crimson)
            if rnd.random() < 0.18:
                lights.rect(cx, STREET - h + 20, cx + 1, STREET - 6, rgba(hexc("a03a6a"), 70))
    return pk.haze(lay.im, CORE["haze"], 0.2), lights.im, pk.glow(lights.im, 3.5, 2.0)


def core_props():
    pylon = Canvas(28, 120)
    pylon.rect(8, 10, 19, 119, rgba(CORE["metal"])); pylon.rect(4, 112, 23, 119, rgba(hexc("2a1e22")))
    pylon.rect(12, 14, 15, 104, rgba(CORE["mag"]))
    pylon.rect(6, 0, 21, 10, rgba(hexc("2a1e22"))); pylon.rect(9, 3, 18, 6, rgba(CORE["red"]))
    return {"pylon": pylon.im, "pylon_glow": pk.radial((70, 150), CORE["mag"], power=1.6, max_alpha=110, steps=12)}


def core_tiles():
    floor = Canvas(64, 60, wrap=True)
    floor.rect(0, 0, 63, 59, rgba(hexc("1e161a")))
    floor.rect(0, 0, 63, 0, rgba(hexc("ff8aa0")))
    floor.rect(0, 1, 63, 2, rgba(hexc("4a2a34")))
    for x in (0, 32):
        floor.rect(x, 3, x, 59, rgba(hexc("120c0e")))
    floor.rect(10, 20, 54, 20, rgba(CORE["red"], 120))
    floor.rect(0, 55, 63, 59, rgba(hexc("0a0608")))
    cat = Canvas(64, 20, wrap=True)
    cat.rect(0, 0, 63, 19, rgba(hexc("2a1e22"))); cat.rect(0, 0, 63, 0, rgba(hexc("ff8aa0")))
    cat.rect(0, 16, 63, 16, rgba(CORE["red"]))
    wall = Canvas(18, 64)
    wall.rect(0, 0, 17, 63, rgba(hexc("1e161a"))); wall.rect(0, 0, 0, 63, rgba(CORE["red"])); wall.rect(17, 0, 17, 63, rgba(CORE["red"]))
    return {"floor_tile": floor.im, "catwalk_tile": cat.im, "wall_tile": wall.im}


def build_core():
    out = OUT / "core"
    out.mkdir(parents=True, exist_ok=True)
    far, lights = core_far()
    mid, signs, glow_ = core_mid()
    images = {"sky": core_sky(), "far": far, "far_beacons": lights, "mid": mid, "mid_signs": signs, "mid_glow": glow_,
              "under": under_layer(411, hexc("140c10"), hexc("060304"), hexc("2a1e22"), [CORE["red"]], arch=False, kind="core"),
              "mist_far": mist(hexc("6a1a2a"), 421, (10, 26)), "mist_near": mist(hexc("8a2a3a"), 422, (8, 20))}
    images.update(core_props())
    images.update(core_tiles())
    for name, im in images.items():
        im.save(out / f"{name}.png", optimize=True)
    return images


# --------------------------------------------------------------------------- styles
STYLES = {
    "lower_city_night": {
        "dir": "lower_city",
        "planes": [
            ["far", -62, 0.15, 0.10, 0.0, (1, 1, 1, 1), False, ""],
            ["far_beacons", -62, 0.15, 0.10, 0.0, (1, 1, 1, 1), True, "beacons"],
            ["mist_far", 236, 0.30, 0.20, -6.0, (1, 1, 1, 1), False, ""],
            ["mid", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), False, "anchor"],
            ["mid_glow", -207, 0.45, 0.30, 0.0, (1, 1, 1, 0.85), True, "glow"],
            ["mid_signs", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), True, "signs"],
            ["under", 0, 0.55, 0.30, 0.0, (0.78, 0.74, 0.86, 1), False, "under"],
            ["rail", -54, 0.70, 0.60, 0.0, (0.62, 0.58, 0.78, 0.92), False, "rail"],
            ["mist_near", 300, 0.80, 0.80, 10.0, (1, 1, 1, 0.75), False, ""],
        ],
        "ground_fill": (0.047, 0.035, 0.075), "haze": (0.05, 0.03, 0.09, 0.20), "haze_deep": (0.04, 0.025, 0.07, 0.32),
        "dressing": "city", "weather": "rain",
    },
    "industrial_forge": {
        "dir": "industrial",
        "planes": [
            ["far", -62, 0.15, 0.10, 0.0, (1, 1, 1, 1), False, ""],
            ["far_beacons", -62, 0.15, 0.10, 0.0, (1, 1, 1, 1), True, "beacons"],
            ["mist_far", 230, 0.30, 0.20, 4.0, (1, 1, 1, 1), False, ""],
            ["mid", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), False, "anchor"],
            ["mid_glow", -207, 0.45, 0.30, 0.0, (1, 1, 1, 0.9), True, "glow"],
            ["mid_signs", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), True, "signs"],
            ["under", 0, 0.55, 0.30, 0.0, (0.8, 0.78, 0.76, 1), False, "under"],
            ["rail", -54, 0.70, 0.60, 0.0, (0.6, 0.6, 0.62, 0.95), False, ""],
            ["mist_near", 300, 0.80, 0.80, 14.0, (1, 1, 1, 0.7), False, ""],
        ],
        "ground_fill": (0.047, 0.04, 0.035), "haze": (0.05, 0.045, 0.04, 0.22), "haze_deep": (0.04, 0.035, 0.03, 0.34),
        "dressing": "industrial", "weather": "embers",
    },
    "lab_cryo": {
        "dir": "lab",
        "planes": [
            ["far", -62, 0.15, 0.10, 0.0, (1, 1, 1, 1), False, ""],
            ["far_beacons", -62, 0.15, 0.10, 0.0, (1, 1, 1, 1), True, "glow"],
            ["mist_far", 230, 0.30, 0.20, 3.0, (1, 1, 1, 1), False, ""],
            ["mid", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), False, "anchor"],
            ["mid_glow", -207, 0.45, 0.30, 0.0, (1, 1, 1, 0.8), True, "glow"],
            ["mid_signs", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), True, "signs"],
            ["under", 0, 0.55, 0.30, 0.0, (0.85, 0.85, 0.9, 1), False, "under"],
            ["rail", -54, 0.70, 0.60, 0.0, (0.7, 0.72, 0.85, 1), False, ""],
            ["mist_near", 300, 0.80, 0.80, -5.0, (1, 1, 1, 0.6), False, ""],
        ],
        "ground_fill": (0.03, 0.035, 0.07), "haze": (0.03, 0.04, 0.09, 0.20), "haze_deep": (0.025, 0.03, 0.07, 0.32),
        "dressing": "lab", "weather": "dust",
    },
    "core_reactor": {
        "dir": "core",
        "planes": [
            # 31/10: lifted (measured: the arena was the darkest scene, 39% near-black).
            ["far", -62, 0.10, 0.06, 0.0, (1.35, 1.25, 1.3, 1), False, ""],
            ["far_beacons", -62, 0.10, 0.06, 0.0, (1, 1, 1, 1), True, "pulse"],
            ["mist_far", 230, 0.30, 0.20, 6.0, (1.2, 1.2, 1.2, 1), False, ""],
            ["mid", -207, 0.45, 0.30, 0.0, (1.45, 1.3, 1.4, 1), False, "anchor"],
            ["mid_glow", -207, 0.45, 0.30, 0.0, (1, 1, 1, 0.8), True, "glow"],
            ["mid_signs", -207, 0.45, 0.30, 0.0, (1, 1, 1, 1), True, "signs"],
            ["under", 0, 0.55, 0.30, 0.0, (0.85, 0.8, 0.8, 1), False, "under"],
            ["mist_near", 300, 0.80, 0.80, -8.0, (1, 1, 1, 0.6), False, ""],
        ],
        "ground_fill": (0.07, 0.03, 0.05), "haze": (0.05, 0.02, 0.03, 0.18), "haze_deep": (0.04, 0.015, 0.02, 0.28),
        "dressing": "core", "weather": "sparks",
    },
}


def write_styles_gd(styles):
    def col(c):
        return "Color(%s)" % ", ".join(f"{v:.3f}" if isinstance(v, float) else str(float(v)) for v in c)
    lines = [
        "extends RefCounted",
        "## GENERATED by tools/visual/biome_art.py — do not edit by hand.",
        "## Plane: [file, top_y, follow_x, follow_y, drift_px_s, tint, additive, role].",
        "",
        "const STYLES := {",
    ]
    for sid, st in styles.items():
        lines.append(f'\t&"{sid}": {{')
        lines.append(f'\t\t"dir": "res://assets/environment/biomes/{st["dir"]}/",')
        lines.append('\t\t"planes": [')
        for p in st["planes"]:
            lines.append(f'\t\t\t["{p[0]}", {float(p[1])}, {p[2]}, {p[3]}, {float(p[4])}, {col(p[5])}, {str(p[6]).lower()}, "{p[7]}"],')
        lines.append("\t\t],")
        for key in ("ground_fill", "haze", "haze_deep"):
            lines.append(f'\t\t"{key}": {col(st[key])},')
        lines.append(f'\t\t"dressing": "{st["dressing"]}",')
        lines.append(f'\t\t"weather": "{st["weather"]}",')
        lines.append("\t},")
    lines.append("}")
    STYLES_GD.parent.mkdir(parents=True, exist_ok=True)
    STYLES_GD.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_city():
    out = OUT / "lower_city"
    out.mkdir(parents=True, exist_ok=True)
    far, beacons = city_far()
    mid, signs, glow_ = city_mid()
    images = {"sky": city_sky(), "far": far, "far_beacons": beacons, "mid": mid, "mid_signs": signs, "mid_glow": glow_,
              "rail": city_rail(), "train": city_train(),
              "under": under_layer(171, hexc("1d1628"), hexc("0c0914"), hexc("2c2240"), [hexc("4fe3f0"), hexc("ffb347")]), "mist_far": mist(hexc("6a4a9a"), 151),
              "mist_near": mist(hexc("8a5aa8"), 152, (12, 30))}
    drop = Canvas(2, 14)
    for y in range(14):  # rain streak: brighter at the leading (bottom) end
        a = int(255 * (y / 13) ** 1.5)
        drop.px(0, y, (190, 200, 240, a)); drop.px(1, y, (190, 200, 240, a // 3))
    images["rain_drop"] = drop.im
    images.update(city_props())
    images.update(city_tiles())
    for name, im in images.items():
        im.save(out / f"{name}.png", optimize=True)
    return images


BUILDERS = {"lower_city": build_city, "industrial": build_industrial, "lab": build_lab, "core": build_core}


def main():
    built = {name: fn() for name, fn in BUILDERS.items()}
    write_styles_gd(STYLES)
    if "--preview" in sys.argv:
        import biome_preview
        biome_preview.render_all(Path(sys.argv[sys.argv.index("--preview") + 1]), built, STYLES)
    print("ok", ", ".join(built))


if __name__ == "__main__":
    main()
