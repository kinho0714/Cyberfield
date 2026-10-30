"""Cyberfield interactable props — Operação Renascimento (30/10/2026).

Original chests that replace the private third-party chest textures
(assets/temporary_items/pixelexplosive/metal_chest_*.png, never in the repository):
    assets/props/chests/loot_chest.png       56x44  (BiomeLoot)
    assets/props/chests/attribute_chest.png  64x46  (AttributeChest)
    assets/props/chests/trap_chest.png       56x44  (TrapChest)
Drawn 1:1 with the characters. The base metal and light strips are near-neutral on
purpose: the chest scripts tint the sprite by state (amber, grey, green, red).

    python3 -I tools/visual/props_art.py [--preview DIR]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelkit as pk  # noqa: E402
from pixelkit import Canvas, hexc, mix, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/props/chests"
STEEL, STEEL_HI, STEEL_LO, DARK = hexc("5a6474"), hexc("9aa6b8"), hexc("343b48"), hexc("141820")
LIGHT, WARN = hexc("e8f6ff"), hexc("e8c23a")


def _box(w, h, lid_h):
    c = Canvas(w, h)
    c.rect(1, lid_h, w - 2, h - 2, rgba(STEEL))                               # body
    for x in range(1, w - 1):                                                 # vertical shading
        t = abs((x - w / 2) / (w / 2))
        c.rect(x, lid_h + 1, x, h - 3, rgba(mix(STEEL, STEEL_LO, t * 0.6)))
    c.rect(1, h - 4, w - 2, h - 2, rgba(STEEL_LO))                            # foot
    c.poly([(4, 3), (w - 5, 3), (w - 2, lid_h), (1, lid_h)], rgba(mix(STEEL, STEEL_HI, 0.3)))   # bevelled lid
    c.rect(4, 3, w - 5, 3, rgba(STEEL_HI))
    c.rect(1, lid_h, w - 2, lid_h, rgba(DARK))                                # lid seam
    c.rect(1, lid_h + 1, w - 2, lid_h + 1, rgba(STEEL_HI))
    for x0 in (1, w - 6):                                                     # corner guards
        c.rect(x0, lid_h + 2, x0 + 4, h - 2, rgba(STEEL_LO))
        c.rect(x0 + 1, lid_h + 4, x0 + 1, lid_h + 5, rgba(STEEL_HI))
        c.rect(x0 + 1, h - 7, x0 + 1, h - 6, rgba(STEEL_HI))
    return c


def _outline(c: Canvas):
    return pk.outline(c.im, DARK)


def loot_chest():
    w, h, lid = 56, 44, 15
    c = _box(w, h, lid)
    c.rect(8, lid + 8, w - 9, lid + 10, rgba(LIGHT))                          # light strip
    c.rect(8, lid + 11, w - 9, lid + 11, rgba(mix(LIGHT, STEEL, 0.6)))
    c.rect(w // 2 - 4, lid - 3, w // 2 + 3, lid + 4, rgba(DARK))              # latch
    c.rect(w // 2 - 2, lid - 1, w // 2 + 1, lid + 2, rgba(LIGHT))
    for x in range(10, w - 10, 4):                                            # vent slots
        c.rect(x, lid + 16, x + 1, lid + 21, rgba(STEEL_LO))
    return _outline(c)


def attribute_chest():
    w, h, lid = 64, 46, 17
    c = _box(w, h, lid)
    cx, cy = w // 2, lid + 13                                                 # holographic emblem
    c.poly([(cx, cy - 8), (cx + 8, cy), (cx, cy + 8), (cx - 8, cy)], rgba(DARK))
    c.poly([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)], rgba(LIGHT))
    c.poly([(cx, cy - 3), (cx + 3, cy), (cx, cy + 3), (cx - 3, cy)], rgba(STEEL_HI))
    for x0, x1 in ((8, cx - 11), (cx + 11, w - 9)):
        c.rect(x0, cy - 1, x1, cy, rgba(LIGHT))
    for x in range(10, w - 10, 6):                                            # lid rivets
        c.px(x, 7, rgba(STEEL_HI))
    return _outline(c)


def trap_chest():
    w, h, lid = 56, 44, 15
    c = _box(w, h, lid)
    for x in range(2, w - 2):                                                 # warning band
        for y in range(lid + 3, lid + 8):
            if ((x + y) // 3) % 2 == 0:
                c.px(x, y, rgba(WARN))
            else:
                c.px(x, y, rgba(DARK))
    cx, cy = w // 2, lid + 18                                                 # "!" triangle
    c.poly([(cx, cy - 7), (cx + 8, cy + 6), (cx - 8, cy + 6)], rgba(DARK))
    c.poly([(cx, cy - 5), (cx + 6, cy + 5), (cx - 6, cy + 5)], rgba(LIGHT))
    c.rect(cx, cy - 2, cx, cy + 1, rgba(DARK))
    c.px(cx, cy + 3, rgba(DARK))
    return _outline(c)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    chests = {"loot_chest": loot_chest(), "attribute_chest": attribute_chest(), "trap_chest": trap_chest()}
    for name, im in chests.items():
        im.save(OUT / f"{name}.png", optimize=True)
    if "--preview" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--preview") + 1])
        d.mkdir(parents=True, exist_ok=True)
        tints = [(1, 1, 1), (1.0, 0.82, 0.48), (0.62, 1.0, 0.72), (1.0, 0.55, 0.48), (0.48, 0.48, 0.48)]
        board = Image.new("RGBA", (5 * 80 * 3, 3 * 56 * 3), (36, 26, 52, 255))
        for row, im in enumerate(chests.values()):
            for col, t in enumerate(tints):
                tinted = Image.merge("RGBA", [ch.point(lambda v, k=k: int(v * k)) for ch, k in zip(im.split(), (*t, 1))])
                board.alpha_composite(tinted.resize((im.width * 3, im.height * 3), Image.NEAREST), (col * 240 + 10, row * 168 + 10))
        board.save(d / "chests_preview.png")
    print("ok", ", ".join(chests))


if __name__ == "__main__":
    main()
