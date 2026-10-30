"""Cyberfield interactable props — Operação Renascimento (30/10/2026).

Original chests that replace the private third-party chest textures
(assets/temporary_items/pixelexplosive/metal_chest_*.png, never in the repository):
    assets/props/chests/loot_chest.png       56x44  (BiomeLoot)
    assets/props/chests/attribute_chest.png  64x46  (AttributeChest)
    assets/props/chests/trap_chest.png       56x44  (TrapChest)
    assets/props/gates/exit_gate.png         72x100 (BiomeExit, over the 68x96 door)
    assets/props/gates/teleporter_pad.png    80x56  (BiomeTeleporter)
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


def exit_gate():
    w, h = 72, 100
    c = Canvas(w, h)
    cyan = hexc("39dff2")
    c.rect(0, 0, w - 1, h - 1, rgba(STEEL_LO))                                # frame
    c.rect(2, 2, w - 3, h - 1, rgba(DARK))
    c.rect(0, 0, w - 1, 1, rgba(STEEL_HI))
    for x in (0, w - 1):
        c.rect(x, 2, x, h - 1, rgba(cyan))                                    # lit jambs
    c.rect(5, 6, w // 2 - 2, h - 2, rgba(mix(STEEL, DARK, 0.45)))             # two door leaves
    c.rect(w // 2 + 1, 6, w - 6, h - 2, rgba(mix(STEEL, DARK, 0.45)))
    c.rect(w // 2 - 1, 6, w // 2, h - 2, rgba(DARK))
    for y in range(14, h - 10, 18):                                           # panel seams
        c.rect(5, y, w - 6, y, rgba(STEEL_LO))
    for i, y in enumerate((30, 44, 58)):                                      # glowing chevrons ">>"
        for k in range(2):
            x0 = 22 + k * 14
            c.line([(x0, y - 6), (x0 + 7, y), (x0, y + 6)], rgba(cyan, 255 - i * 60), width=2)
    c.rect(8, h - 8, w - 9, h - 6, rgba(WARN))
    for x in range(8, w - 8, 6):
        c.rect(x, h - 8, x + 2, h - 6, rgba(DARK))
    return _outline(c)


def teleporter_pad():
    w, h = 80, 56
    c = Canvas(w, h)
    cyan = hexc("39dff2")
    c.poly([(6, 40), (18, 30), (62, 30), (74, 40), (62, 50), (18, 50)], rgba(STEEL_LO))   # hex base
    c.poly([(10, 40), (20, 33), (60, 33), (70, 40), (60, 47), (20, 47)], rgba(DARK))
    c.d.ellipse((18, 34, 62, 46), outline=rgba(cyan), width=2)                             # emitter ring
    c.d.ellipse((28, 37, 52, 43), outline=rgba(cyan, 150))
    for k in range(4):                                                                     # rising holo lines
        y = 26 - k * 7
        c.rect(26 + k * 2, y, 54 - k * 2, y, rgba(cyan, 180 - k * 40))
    return _outline(c)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    chests = {"loot_chest": loot_chest(), "attribute_chest": attribute_chest(), "trap_chest": trap_chest()}
    for name, im in chests.items():
        im.save(OUT / f"{name}.png", optimize=True)
    gates = ROOT / "assets/props/gates"
    gates.mkdir(parents=True, exist_ok=True)
    exit_gate().save(gates / "exit_gate.png", optimize=True)
    teleporter_pad().save(gates / "teleporter_pad.png", optimize=True)
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
