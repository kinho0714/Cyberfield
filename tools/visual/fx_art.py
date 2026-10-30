"""Cyberfield combat FX sheets — Operação Renascimento (30/10/2026).

Original pixel-art effect sheets used by scene/fx/combat_fx.gd:
    assets/fx/hit_spark.png    4 frames, 32x32  (white core, carmine rays)
    assets/fx/death_burst.png  6 frames, 64x64  (shockwave ring + shards)
    assets/fx/heal_ring.png    6 frames, 64x40  (green ground ring + rising crosses)

    python3 -I tools/visual/fx_art.py [--preview DIR]
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelkit import Canvas, hexc, mix, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/fx"
WHITE, CARMINE, PINK, GREEN, MINT = hexc("fff4f8"), hexc("ff2a6d"), hexc("ff8ab0"), hexc("43f2b0"), hexc("c8ffe8")


def hit_spark():
    frames = []
    for f in range(4):
        c = Canvas(32, 32)
        reach = [6, 12, 14, 13][f]
        width = [2, 2, 1, 1][f]
        for k in range(8):
            a = k * math.pi / 4 + (math.pi / 8 if f % 2 else 0)
            r0 = [0, 3, 7, 10][f]
            x0, y0 = 16 + math.cos(a) * r0, 16 + math.sin(a) * r0
            x1, y1 = 16 + math.cos(a) * reach * (1.0 if k % 2 == 0 else 0.6), 16 + math.sin(a) * reach * (1.0 if k % 2 == 0 else 0.6)
            col = [WHITE, PINK, CARMINE, CARMINE][f]
            c.line([(x0, y0), (x1, y1)], rgba(col, [255, 255, 220, 120][f]), width=width)
        if f < 2:
            r = [4, 3][f]
            c.ellipse(16 - r, 16 - r, 16 + r, 16 + r, rgba(WHITE))
        frames.append(c.im)
    return frames


def death_burst():
    frames = []
    rnd = random.Random(501)
    shards = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.6, 1.0), rnd.randint(1, 2)) for _ in range(18)]
    for f in range(6):
        c = Canvas(64, 64)
        t = (f + 1) / 6
        r = 6 + t * 24
        alpha = int(255 * (1 - t) ** 0.7)
        c.d.ellipse((32 - r, 32 - r, 32 + r, 32 + r), outline=rgba(mix(WHITE, CARMINE, t), alpha), width=2 if f < 3 else 1)
        if f < 2:
            c.ellipse(26, 26, 38, 38, rgba(WHITE, 230 - f * 90))
        for a, speed, size in shards:
            d = 4 + t * 28 * speed
            x, y = 32 + math.cos(a) * d, 32 + math.sin(a) * d + t * t * 8
            c.rect(int(x), int(y), int(x) + size, int(y) + size, rgba(mix(PINK, CARMINE, t), alpha))
        frames.append(c.im)
    return frames


def heal_ring():
    frames = []
    for f in range(6):
        c = Canvas(64, 40)
        t = (f + 1) / 6
        rx, ry = 10 + t * 20, 3 + t * 5
        alpha = int(255 * (1 - t * 0.85))
        c.d.ellipse((32 - rx, 32 - ry, 32 + rx, 32 + ry), outline=rgba(GREEN, alpha), width=2)
        for k, cx in enumerate((18, 32, 46)):
            y = 26 - t * 22 - k * 3
            if 1 < y < 36:
                col = rgba(MINT if k == 1 else GREEN, alpha)
                c.rect(cx - 1, int(y) - 3, cx, int(y) + 3, col)
                c.rect(cx - 3, int(y) - 1, cx + 2, int(y), col)
        frames.append(c.im)
    return frames


def sheet(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for i, frame in enumerate(frames):
        out.alpha_composite(frame, (i * w, 0))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {"hit_spark": sheet(hit_spark()), "death_burst": sheet(death_burst()), "heal_ring": sheet(heal_ring())}
    for name, im in sheets.items():
        im.save(OUT / f"{name}.png", optimize=True)
    if "--preview" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--preview") + 1])
        d.mkdir(parents=True, exist_ok=True)
        rows = [im.resize((im.width * 4, im.height * 4), Image.NEAREST) for im in sheets.values()]
        board = Image.new("RGBA", (max(r.width for r in rows), sum(r.height + 8 for r in rows)), (20, 14, 32, 255))
        y = 0
        for r in rows:
            board.alpha_composite(r, (0, y)); y += r.height + 8
        board.save(d / "fx_preview.png")
    print("ok", ", ".join(sheets))


if __name__ == "__main__":
    main()
