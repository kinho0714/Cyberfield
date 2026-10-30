"""Cyberfield — Lower City v2 layers for the in-game theme (30/10/2026).

Original, deterministic pixel art (no third-party pixels). Differences from the
concept layers in tools/experimental/lower_city_concept.py:
- palette rule: magenta/carmesim belongs to threats only, never to scenery
  (docs/DIRECAO_VISUAL_CYBERFIELD.md §2.2); signs use cyan, green and amber;
- two street districts per mid tile, so the facade rhythm repeats every 2880 px
  of world instead of 1440;
- textures are stored at NATIVE pixel size and drawn at 2x by the theme, which
  cuts their texture memory to a quarter (the concept files are pre-scaled 2x/4x).

    python3 -I tools/visual/lower_city_v2.py [--preview DIR]
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "experimental"))
import lower_city_concept as lc  # noqa: E402  (shared palette, Layer, 3x5 font, glow/haze)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/environment/lower_city_v2"
P = dict(lc.P)
P.update({
    "amber": (232, 168, 82), "amber_dim": (150, 98, 52), "cyan": (88, 220, 232),
    "green": (70, 214, 140), "ice": (150, 200, 240), "beacon": (255, 176, 92),
})
SIGN_COLOURS = {"cyan": P["cyan"], "green": P["green"], "amber": P["amber"], "ice": P["ice"]}
rgba = lc.rgba


def make_sky():
    """Native 320x180; the theme stretches it to the screen."""
    w, h = 320, 180
    im = Image.new("RGBA", (w, h))
    stops = [(0.0, P["sky0"]), (0.22, P["sky1"]), (0.48, P["sky2"]), (0.72, P["sky3"]), (1.0, P["sky3"])]
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                k = round((t - stops[i][0]) / (stops[i + 1][0] - stops[i][0]) * 4) / 4
                c = tuple(int(stops[i][1][j] + (stops[i + 1][1][j] - stops[i][1][j]) * k) for j in range(3))
                break
        for x in range(w):
            im.putpixel((x, y), rgba(c))
    clouds = lc.Layer(w, h, wrap=True)
    rnd = random.Random(7)
    for band_y, alpha in ((40, 70), (58, 60), (76, 90)):
        x = -40
        while x < w:
            length = rnd.randint(30, 90)
            y = band_y + rnd.randint(-2, 2)
            clouds.rect(x, y, x + length, y + 1, (44, 40, 80, alpha))
            clouds.rect(x + 3, y + 2, x + length - 3, y + 2, (92, 70, 120, alpha))
            x += length + rnd.randint(6, 30)
    im.alpha_composite(clouds.im)
    return im


def make_far():
    """640x360 tileable skyline + separate beacon layer (blinks in Godot)."""
    lay = lc.Layer(640, 360, wrap=True)
    beacons = lc.Layer(640, 360, wrap=True)
    rnd = random.Random(11)
    base, x = 330, 0
    while x < 640:
        bw, bh = rnd.randint(18, 44), rnd.randint(120, 270)
        col = P["far0"] if rnd.random() < 0.6 else P["far1"]
        lay.rect(x, base - bh, x + bw, base, rgba(col))
        if rnd.random() < 0.35:
            lay.rect(x + 4, base - bh - rnd.randint(6, 16), x + bw - 4, base - bh, rgba(col))
        if rnd.random() < 0.3:
            ax, top = x + bw // 2, base - bh - rnd.randint(18, 34)
            lay.rect(ax, top, ax, base - bh, rgba(P["far1"]))
            beacons.px(ax, top, rgba(P["beacon"]))  # aviation light: amber, never threat red
        for wy in range(base - bh + 6, base - 4, 5):
            for wx in range(x + 3, x + bw - 2, 4):
                if rnd.random() < 0.10:
                    lay.px(wx, wy, rgba(rnd.choice([P["cyan_dim"], P["amber_dim"], P["far_lit"], P["far_lit"]])))
        x += bw + rnd.randint(-6, 4)
    for i, hy in enumerate(range(92, 118, 3)):  # distant hologram billboard, low contrast violet
        lay.rect(214 + (i % 2), hy, 252 - (i % 3), hy, (96, 70, 150, 120))
    return lc.haze(lay.im, (20, 20, 46), 0.25), beacons.im


# District blocks: (x0, x1, height, kind, sign colour). Two districts per tile.
DISTRICTS = [
    (0, 120, 118, "res", None), (120, 236, 150, "hotel", "cyan"), (236, 330, 96, "res", None),
    (330, 470, 134, "farm", "green"), (470, 560, 104, "bar", "amber"), (560, 720, 142, "res", "amber"),
    (720, 830, 176, "tower", None), (830, 930, 98, "garage", None), (930, 1060, 128, "motel", "ice"),
    (1060, 1150, 112, "tattoo", "cyan"), (1150, 1290, 146, "cafe", "amber"), (1290, 1440, 120, "banco", "green"),
]
SIGN_TEXT = {"hotel": "HOTEL", "farm": "FARMACIA", "bar": "BAR", "motel": "MOTEL", "tattoo": "TATTOO",
             "cafe": "CAFE", "banco": "BANCO", "res": "24H"}


def make_mid():
    """1440x360 tileable street; returns (buildings, signs, sign glow)."""
    w = 1440
    lay = lc.Layer(w, 360, wrap=True)
    signs = lc.Layer(w, 360, wrap=True)
    rnd = random.Random(23)
    street = 330
    for x0, x1, height, kind, sign in DISTRICTS:
        top = street - height
        body = rnd.choice([P["mid0"], P["mid1"]])
        lay.rect(x0, top, x1, street, rgba(body))
        lay.rect(x0, top, x1, top + 2, rgba(P["trim"]))
        lay.rect(x1 - 3, top, x1, street, rgba(P["mid_dark"]))
        for _ in range(rnd.randint(1, 2)):  # caixas d'água / AC on the roof
            tx = rnd.randint(x0 + 6, max(x0 + 7, x1 - 18))
            lay.rect(tx, top - 9, tx + 12, top - 1, rgba(P["mid2"]))
            lay.rect(tx + 1, top - 10, tx + 11, top - 9, rgba(P["trim"]))
        if kind == "tower":  # tall residential tower: antenna mast and a step-back
            lay.rect(x0 + 10, top - 22, x1 - 14, top, rgba(body))
            lay.rect((x0 + x1) // 2, top - 48, (x0 + x1) // 2 + 1, top - 22, rgba(P["trim"]))
        for fy in range(top + 10, street - 30, 22):
            for wx in range(x0 + 6, x1 - 8, 14):
                lit = rnd.random()
                c = P["amber"] if lit < 0.07 else P["cyan_dim"] if lit < 0.12 else P["mid_dark"]
                lay.rect(wx, fy, wx + 7, fy + 9, rgba(c))
                if c == P["amber"]:
                    lay.rect(wx, fy + 7, wx + 7, fy + 9, rgba(P["amber_dim"]))
                if rnd.random() < 0.18:
                    lay.rect(wx + 8, fy + 6, wx + 12, fy + 10, rgba(P["mid2"]))
            if rnd.random() < 0.35:
                bx = rnd.randint(x0 + 4, max(x0 + 5, x1 - 40))
                lay.rect(bx, fy + 11, bx + 34, fy + 12, rgba(P["trim"]))
                for rx in range(bx, bx + 35, 3):
                    lay.rect(rx, fy + 7, rx, fy + 11, rgba(P["mid_dark"]))
            if rnd.random() < 0.25:
                lx = rnd.randint(x0 + 4, max(x0 + 5, x1 - 30))
                lay.line([(lx, fy + 1), (lx + 26, fy + 2)], rgba(P["mid_dark"]))
                for cx in range(lx + 3, lx + 24, 6):
                    lay.rect(cx, fy + 2, cx + 2, fy + 5, rgba(rnd.choice([P["rust2"], P["cyan_dim"], P["trim"]])))
        # Ground floor: storefront band, kind-specific.
        lay.rect(x0 + 2, street - 26, x1 - 4, street, rgba(P["mid_dark"]))
        if kind == "garage":
            lay.rect(x0 + 8, street - 24, x1 - 12, street - 1, rgba(P["mid2"]))
            for ly in range(street - 22, street - 1, 2):
                lay.rect(x0 + 8, ly, x1 - 12, ly, rgba(P["mid0"]))
        elif kind in ("bar", "cafe", "tattoo"):
            # Lit storefront: dark interior, warm light falling from the ceiling, mullions,
            # a door and counter silhouettes, so it reads as a place, not a coloured block.
            wx0, wx1, wy0, wy1 = x0 + 6, x1 - 10, street - 22, street - 3
            lay.rect(wx0, wy0, wx1, wy1, rgba((22, 18, 18)))
            for row in range(wy1 - wy0):
                k = max(0.0, 1.0 - row / 12.0)
                lay.rect(wx0 + 1, wy0 + 1 + row, wx1 - 1, wy0 + 1 + row,
                         rgba(tuple(int(18 + (P["amber"][j] - 18) * k * 0.55) for j in range(3))))
            for cx in range(wx0 + 6, wx1 - 4, 9):                                         # counter stools/heads
                lay.rect(cx, wy1 - 6, cx + 2, wy1 - 1, rgba((14, 12, 12)))
            for mx in range(wx0, wx1 + 1, 18):                                            # mullions
                lay.rect(mx, wy0, mx, wy1, rgba(P["mid_dark"]))
            door = wx1 - 12
            lay.rect(door, wy0 + 2, door + 9, street - 1, rgba((14, 12, 12)))
            lay.rect(door, wy0 + 2, door, street - 1, rgba(P["amber_dim"]))
            for i, ax in enumerate(range(x0 + 4, x1 - 8, 10)):                          # striped awning
                lay.rect(ax, street - 30, ax + 9, street - 26, rgba(P["rust2"] if i % 2 else (120, 110, 96)))
                lay.rect(ax, street - 26, ax + 9, street - 25, rgba(P["mid_dark"]))
        else:
            for sx in range(x0 + 6, x1 - 10, 30):
                lay.rect(sx, street - 22, sx + 22, street - 1, rgba(P["mid1"]))
                for ly in range(street - 21, street - 1, 3):
                    lay.rect(sx, ly, sx + 22, ly, rgba(P["mid0"]))
        for _ in range(2):  # low-contrast pichação
            gx = rnd.randint(x0 + 4, max(x0 + 5, x1 - 24))
            gy = street - rnd.randint(28, 40)
            lay.line([(gx, gy), (gx + 4, gy - 4), (gx + 8, gy), (gx + 12, gy - 3), (gx + 18, gy + 1)],
                     rgba(rnd.choice([P["rust2"], (60, 90, 120), (70, 70, 96)]), 200))
        if sign is not None:
            colour = SIGN_COLOURS[sign]
            word = SIGN_TEXT[kind]
            if kind == "hotel" or kind == "motel":
                lay.rect(x0 + 42, top + 14, x0 + 53, top + 16 + len(word) * 12, rgba(P["mid_dark"]))
                lc.text(signs, x0 + 46, top + 18, word, rgba(colour), vertical=True, scale=2)
            elif kind == "farm":
                cx, cy = x0 + 24, top + 26
                signs.rect(cx - 2, cy - 7, cx + 2, cy + 7, rgba(colour))
                signs.rect(cx - 7, cy - 2, cx + 7, cy + 2, rgba(colour))
                lc.text(signs, x0 + 38, top + 22, word, rgba(colour, 220))
            else:
                sx = x0 + max(4, (x1 - x0 - len(word) * 8) // 2)
                sy = street - 46 if kind != "res" else top + 30
                lay.rect(sx - 3, sy - 3, sx + len(word) * 8 + 1, sy + 12, rgba(P["mid_dark"]))  # backplate
                lc.text(signs, sx, sy, word, rgba(colour), scale=2)
    for x0, x1, y in ((60, 190, 236), (300, 420, 226), (480, 650, 244), (650, 790, 232),
                      (840, 1000, 230), (1080, 1230, 240), (1300, 1460, 228)):  # gambiarra cables
        pts = [(x, y + int(14 * math.sin(math.pi * (x - x0) / (x1 - x0)))) for x in range(x0, x1 + 1, 4)]
        lay.line(pts, rgba(P["mid_dark"]))
    return lc.haze(lay.im, P["sky2"], 0.28), signs.im, lc.glow(signs.im, 3.0, 1.4)


def make_rail():
    lay = lc.Layer(800, 360, wrap=True)
    deck_top, deck_bot = 30, 46
    lay.rect(0, deck_top, 799, deck_bot, rgba(P["rail1"]))
    lay.rect(0, deck_top, 799, deck_top + 1, rgba(P["rail_edge"]))
    lay.rect(0, deck_bot - 3, 799, deck_bot, rgba(P["rail0"]))
    for x in range(0, 800, 10):
        lay.line([(x, deck_bot), (x + 5, deck_bot + 8), (x + 10, deck_bot)], rgba(P["rail0"]))
    lay.rect(0, deck_bot + 8, 799, deck_bot + 9, rgba(P["rail0"]))
    for px_ in (130, 530):
        lay.rect(px_, deck_bot, px_ + 16, 330, rgba(P["rail0"]))
        lay.rect(px_ + 2, deck_bot, px_ + 3, 330, rgba(P["rail1"]))
        lay.poly([(px_ - 10, deck_bot), (px_ + 26, deck_bot), (px_ + 16, deck_bot + 14), (px_, deck_bot + 14)], rgba(P["rail0"]))
    for x in range(40, 800, 120):
        lay.px(x, deck_top - 1, rgba(P["amber_dim"]))
    return lay.im


def make_fog():
    w, h = 640, 80
    lay = lc.Layer(w, h, wrap=True)
    rnd = random.Random(3)
    for _ in range(40):
        x, y = rnd.randint(0, w), rnd.randint(20, 60)
        lay.rect(x, y, x + rnd.randint(40, 140), y + rnd.randint(4, 12), (120, 130, 170, rnd.randint(10, 24)))
    return lay.im.filter(ImageFilter.BoxBlur(2))


def make_puddles():
    im = Image.new("RGBA", (1920, 40))
    rnd = random.Random(5)
    for x0, x1 in ((420, 560), (1100, 1230), (1500, 1620)):
        for x in range(x0, x1):
            for y in range(2, 30):
                if (x + y) % 3 == 0 and rnd.random() < 0.55:
                    c = rnd.choice([P["cyan"], P["amber"], P["green"]])
                    im.putpixel((x, y), (c[0], c[1], c[2], int(70 * (1 - y / 30))))
    return im


def preview(out_dir: Path, layers: dict) -> None:
    """Static 1600x720 composition at camera x=0 (simulation, not a Godot capture)."""
    W, H = 1600, 720
    frame = layers["sky"].resize((W, H), Image.NEAREST)
    for name, top in (("far", -62), ("fog", 245), ("mid", -207), ("rail", -54)):
        img = layers[name].resize((layers[name].width * 2, layers[name].height * 2), Image.NEAREST)
        strip = Image.new("RGBA", (W, img.height))
        for ox in range(0, W, img.width):
            strip.paste(img, (ox, 0))
        if name == "rail":
            ground = Image.new("RGBA", (W, H), (8, 12, 17, 255))
            frame.alpha_composite(ground.crop((0, 0, W, H - (453))), (0, 453))
            strip = Image.merge("RGBA", [c.point(lambda v, k=k: int(v * k)) for c, k in zip(strip.split(), (0.5, 0.52, 0.66, 0.85))])
        frame.alpha_composite(strip.crop((0, max(0, -top), W, min(strip.height, H - top))), (0, max(0, top)))
        if name == "mid":
            for extra in ("mid_glow", "mid_signs"):
                e = layers[extra].resize((layers[extra].width * 2, layers[extra].height * 2), Image.NEAREST)
                strip_e = Image.new("RGBA", (W, e.height))
                for ox in range(0, W, e.width):
                    strip_e.paste(e, (ox, 0))
                lc.add_blend(frame, strip_e.crop((0, -top, W, strip_e.height)), (0, 0))
        if name == "far":
            b = layers["far_beacons"].resize((1280, 720), Image.NEAREST)
            lc.add_blend(frame, b.crop((0, -top, min(W, 1280), 720)), (0, 0))
    out_dir.mkdir(parents=True, exist_ok=True)
    frame.save(out_dir / "lower_city_v2_preview.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    far, far_beacons = make_far()
    mid, mid_signs, mid_glow = make_mid()
    layers = {"sky": make_sky(), "far": far, "far_beacons": far_beacons, "fog": make_fog(), "mid": mid,
              "mid_signs": mid_signs, "mid_glow": mid_glow, "rail": make_rail(), "puddles": make_puddles()}
    for name, img in layers.items():
        img.save(OUT / f"{name}.png", optimize=True)
    if "--preview" in sys.argv:
        preview(Path(sys.argv[sys.argv.index("--preview") + 1]), layers)
    print("ok", OUT)


if __name__ == "__main__":
    main()
