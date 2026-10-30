"""Cyberfield hub — Casa Jhon stage 0, Operação Renascimento (30/10/2026).

Original composition for the hub the game actually loads (scene/casa_jhon_hub.tscn,
2560x768, floor top y=643). Drawn at native 1280x384 and shown at 2x by
scene/casa_jhon_presentation.gd. Zones follow the scene's anchors:
  main entry 64 | domestic core 512 | historic column 768 | MetaTerminal 960 |
  RunPortal 1120 | workshop core 1344 | spark slot 2240   (screen x)
Outputs:
    assets/environment/hub/hub_stage0_back.png    1280x384 room (opaque)
    assets/environment/hub/hub_stage0_lights.png  1280x384 additive light layer

    python3 -I tools/visual/hub_art.py [--preview DIR]
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelkit as pk  # noqa: E402
from pixelkit import Canvas, hexc, mix, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/environment/hub"
W, H, FLOOR = 1280, 384, 322           # native; FLOOR*2 - 1 = 643 on screen
WOOD, WOOD2, WOOD_D = hexc("3a2a2a"), hexc("46322e"), hexc("241a1c")
PANEL, PANEL2, SEAM = hexc("1c2440"), hexc("222c4c"), hexc("0e1428")
DARK, METAL, METAL_HI = hexc("12141c"), hexc("3a4256"), hexc("6a7690")
CYAN, MAG, AMBER, GREEN, WHITE = hexc("4fe3f0"), hexc("ff4fb4"), hexc("ffb347"), hexc("54f0a0"), hexc("e8f6ff")
HOME_END = 600                         # warm home on the left, lab on the right


def wall(c: Canvas, lights: Canvas):
    for x in range(0, W):                                              # back wall materials
        home = x < HOME_END
        col = (WOOD if (x // 22) % 2 else WOOD2) if home else (PANEL if (x // 40) % 2 else PANEL2)
        c.rect(x, 24, x, FLOOR - 1, rgba(col))
    for x in range(0, HOME_END, 22):
        c.rect(x, 24, x, FLOOR - 1, rgba(WOOD_D))
    for x in range(HOME_END, W, 40):
        c.rect(x, 24, x, FLOOR - 1, rgba(SEAM))
    for y in range(64, FLOOR, 46):
        c.rect(HOME_END, y, W - 1, y, rgba(SEAM))
    c.rect(0, FLOOR - 18, HOME_END, FLOOR - 1, rgba(mix(WOOD, DARK, 0.4)))     # wainscot
    c.rect(0, FLOOR - 19, HOME_END, FLOOR - 19, rgba(hexc("6a4a3a")))
    c.rect(HOME_END, FLOOR - 8, W - 1, FLOOR - 1, rgba(SEAM))
    lights.rect(HOME_END, FLOOR - 6, W - 1, FLOOR - 6, rgba(CYAN, 110))      # lab skirting strip
    c.rect(0, 0, W - 1, 23, rgba(hexc("0c0e16")))                              # ceiling
    for x in range(0, W, 64):
        c.rect(x, 0, x + 6, 23, rgba(hexc("1a1e2a")))
    for py in (8, 14):                                                         # ceiling pipes
        c.rect(0, py, W - 1, py + 2, rgba(METAL))
        c.rect(0, py, W - 1, py, rgba(METAL_HI))
    c.rect(HOME_END - 2, 24, HOME_END + 2, FLOOR - 1, rgba(DARK))               # home/lab partition


def window(c: Canvas, lights: Canvas, x0, y0, w, h):
    sky = Canvas(w, h)
    sky.vgradient(0, 0, w - 1, h - 1, [(0.0, hexc("0a0820")), (0.6, hexc("2a1240")), (1.0, hexc("6a2450"))], steps=4)
    rnd = random.Random(801)
    x = 0
    while x < w:                                                               # tiny city silhouette
        bw, bh = rnd.randint(6, 14), rnd.randint(20, h - 10)
        sky.rect(x, h - bh, x + bw, h - 1, rgba(hexc("150e26")))
        for wy in range(h - bh + 3, h - 2, 4):
            for wx in range(x + 1, x + bw - 1, 3):
                if rnd.random() < 0.12:
                    sky.px(wx, wy, rgba(rnd.choice([AMBER, CYAN, MAG])))
        x += bw + 1
    for i in range(30):                                                        # rain streaks
        rx, ry = rnd.randint(0, w - 1), rnd.randint(0, h - 8)
        sky.rect(rx, ry, rx, ry + 4, rgba(hexc("8a7ab0"), 120))
    c.im.alpha_composite(sky.im, (x0, y0))
    c.rect(x0 - 3, y0 - 3, x0 + w + 2, y0 - 1, rgba(DARK)); c.rect(x0 - 3, y0 + h, x0 + w + 2, y0 + h + 3, rgba(DARK))
    c.rect(x0 - 3, y0, x0 - 1, y0 + h, rgba(DARK)); c.rect(x0 + w, y0, x0 + w + 2, y0 + h, rgba(DARK))
    c.rect(x0 + w // 2 - 1, y0, x0 + w // 2, y0 + h, rgba(DARK))
    c.rect(x0, y0 + h // 2, x0 + w, y0 + h // 2, rgba(DARK))
    lights.im.alpha_composite(pk.radial((w + 40, 60), MAG, power=1.6, max_alpha=34, steps=24), (x0 - 20, y0 + h - 10))


def home(c: Canvas, lights: Canvas):
    c.rect(4, 214, 26, FLOOR - 1, rgba(DARK))                                  # entry door (main_entry)
    c.rect(7, 218, 23, FLOOR - 1, rgba(hexc("2a2030")))
    lights.rect(20, 262, 21, 268, rgba(GREEN))
    window(c, lights, 120, 120, 110, 80)
    c.rect(54, 280, 124, FLOOR - 1, rgba(hexc("4a3046")))                      # sofa-bed
    c.rect(54, 272, 124, 282, rgba(hexc("5a3a54")))
    c.rect(50, 268, 58, FLOOR - 1, rgba(hexc("3a2436")))
    c.rect(120, 268, 128, FLOOR - 1, rgba(hexc("3a2436")))
    c.rect(66, 276, 84, 284, rgba(hexc("c8b8c8")))                             # pillow
    c.rect(150, 300, 176, FLOOR - 1, rgba(WOOD_D))                             # crate side table
    c.rect(154, 292, 162, 300, rgba(hexc("6a5a4a")))                           # mug + lamp
    c.rect(166, 280, 168, 300, rgba(METAL)); c.rect(162, 276, 172, 281, rgba(AMBER))
    lights.im.alpha_composite(pk.radial((70, 60), AMBER, power=1.5, max_alpha=110, steps=24), (132, 248))
    c.rect(220, 230, 300, FLOOR - 1, rgba(hexc("2a2e38")))                      # kitchen counter (domestic core 256)
    c.rect(220, 230, 300, 234, rgba(hexc("6a7080")))
    for x in range(226, 296, 18):
        c.rect(x, 240, x + 14, FLOOR - 4, rgba(hexc("232630")))
        c.rect(x + 11, 262, x + 12, 268, rgba(METAL_HI))
    c.rect(234, 222, 246, 230, rgba(hexc("8a8a8a")))                           # kettle/pot
    c.rect(304, 196, 334, FLOOR - 1, rgba(hexc("4a5262")))                      # fridge
    c.rect(304, 250, 334, 251, rgba(DARK)); c.rect(330, 214, 331, 240, rgba(METAL_HI))
    lights.rect(308, 204, 312, 205, rgba(CYAN))
    c.rect(250, 24, 251, 120, rgba(DARK))                                      # pendant lamp
    c.rect(242, 120, 260, 126, rgba(hexc("8a5a2a")))
    lights.im.alpha_composite(pk.cone(120, 110, AMBER, max_alpha=60), (191, 126))
    for sx in range(360, 440, 26):                                             # shelves with things
        c.rect(sx, 170, sx + 22, 172, rgba(WOOD_D))
    rnd = random.Random(811)
    for sx in range(362, 440, 6):
        c.rect(sx, 160 + rnd.randint(0, 4), sx + 4, 170, rgba(rnd.choice([hexc("6a3a3a"), hexc("3a5a6a"), hexc("6a6a3a")])))


def historic_column(c: Canvas, lights: Canvas):
    cx = 384
    c.rect(cx - 16, 24, cx + 16, FLOOR - 1, rgba(hexc("4a4048")))              # structural column
    c.rect(cx - 16, 24, cx - 14, FLOOR - 1, rgba(hexc("6a5a66")))
    c.rect(cx - 20, 24, cx + 20, 34, rgba(hexc("2a2430"))); c.rect(cx - 20, FLOOR - 12, cx + 20, FLOOR - 1, rgba(hexc("2a2430")))
    c.rect(cx - 13, 140, cx + 13, 200, rgba(hexc("6a5440")))                    # memory board
    rnd = random.Random(821)
    for _ in range(8):                                                         # pinned photos / notes
        px_, py = rnd.randint(cx - 11, cx + 4), rnd.randint(142, 192)
        c.rect(px_, py, px_ + 6, py + 5, rgba(rnd.choice([hexc("e8e0d0"), hexc("c8d8e8"), hexc("e8d080")])))
        c.px(px_ + 3, py, rgba(MAG))
    c.line([(cx - 8, 150), (cx + 6, 170), (cx - 4, 186)], rgba(hexc("c03a3a")))  # red string
    lights.im.alpha_composite(pk.radial((60, 50), AMBER, power=1.6, max_alpha=60, steps=24), (cx - 30, 145))


def terminal(c: Canvas, lights: Canvas):
    cx = 480                                                                  # MetaTerminal at screen 960
    c.rect(cx - 34, 286, cx + 34, FLOOR - 1, rgba(hexc("1e2438")))              # desk
    c.rect(cx - 36, 282, cx + 36, 287, rgba(METAL_HI))
    for i, (mx, my, mw, mh) in enumerate(((cx - 30, 246, 20, 16), (cx - 8, 238, 22, 20), (cx + 16, 246, 20, 16))):
        c.rect(mx - 1, my - 1, mx + mw, my + mh, rgba(DARK))
        scr = [CYAN, CYAN, MAG][i]
        lights.rect(mx, my, mx + mw - 1, my + mh - 1, rgba(scr, 90))
        for k in range(3):
            lights.rect(mx + 2, my + 3 + k * 4, mx + 2 + (k * 7 + i * 3) % (mw - 4), my + 3 + k * 4, rgba(scr))
        c.rect(mx + mw // 2, my + mh, mx + mw // 2 + 1, 282, rgba(METAL))
    c.rect(cx - 6, 274, cx + 6, 281, rgba(hexc("2a3048")))                     # keyboard
    lights.im.alpha_composite(pk.radial((110, 80), CYAN, power=1.5, max_alpha=70, steps=24), (cx - 55, 220))
    pk.text(lights, cx - 14, 228, "META", rgba(CYAN))


def portal(c: Canvas, lights: Canvas):
    cx, base = 560, FLOOR                                                     # RunPortal at screen 1120
    c.poly([(cx - 46, base), (cx - 36, base - 10), (cx + 36, base - 10), (cx + 46, base)], rgba(METAL))   # platform
    c.rect(cx - 36, base - 10, cx + 36, base - 9, rgba(METAL_HI))
    c.ellipse(cx - 40, base - 96, cx + 40, base - 12, rgba(DARK))             # ring housing
    c.ellipse(cx - 34, base - 90, cx + 34, base - 18, rgba(hexc("0a0a18")))
    for k, (r, col, a) in enumerate(((38, CYAN, 230), (33, MAG, 170), (27, CYAN, 90))):
        lights.d.ellipse((cx - r, base - 54 - r * 1.1, cx + r, base - 54 + r * 1.1), outline=rgba(col, a), width=2)
    lights.im.alpha_composite(pk.radial((70, 76), CYAN, power=1.2, max_alpha=60, steps=24), (cx - 35, base - 92))
    for side in (-1, 1):                                                       # pylons with cables
        px_ = cx + side * 50
        c.rect(px_ - 4, base - 70, px_ + 4, base - 1, rgba(METAL))
        lights.rect(px_ - 1, base - 66, px_, base - 6, rgba(MAG if side < 0 else CYAN, 200))
    pk.text(lights, cx - 10, base - 108, "RUN", rgba(MAG))


def workshop(c: Canvas, lights: Canvas):
    cx = 672                                                                  # workshop core at screen 1344
    c.rect(cx - 50, 282, cx + 50, 287, rgba(hexc("5a5040")))                  # workbench
    c.rect(cx - 46, 287, cx - 40, FLOOR - 1, rgba(DARK)); c.rect(cx + 40, 287, cx + 46, FLOOR - 1, rgba(DARK))
    c.rect(cx - 40, 300, cx + 40, 302, rgba(DARK))
    for tx in range(cx - 40, cx + 40, 9):                                      # pegboard with tools
        c.rect(tx, 222, tx + 1, 240 + (tx % 7), rgba(METAL_HI))
    c.rect(cx - 46, 214, cx + 46, 216, rgba(hexc("4a4038")))
    c.rect(cx + 14, 262, cx + 18, 282, rgba(METAL))                            # robotic arm
    c.line([(cx + 16, 262), (cx + 4, 250), (cx - 12, 256)], rgba(METAL_HI), width=3)
    lights.px(cx - 13, 257, rgba(CYAN))
    c.rect(cx - 30, 272, cx - 14, 281, rgba(hexc("3a4a5a")))                   # robot part on bench
    lights.im.alpha_composite(pk.cone(140, 90, WHITE, max_alpha=34), (cx - 70, 196))
    c.rect(cx - 2, 24, cx - 1, 192, rgba(DARK))
    c.rect(cx - 16, 192, cx + 14, 196, rgba(METAL))


def lab(c: Canvas, lights: Canvas):
    rnd = random.Random(831)
    for rx in (760, 786, 812):                                                 # server racks
        c.rect(rx, 210, rx + 22, FLOOR - 1, rgba(hexc("161c30")))
        c.rect(rx + 1, 211, rx + 21, FLOOR - 2, rgba(hexc("1e2848")))
        for ry in range(214, FLOOR - 4, 6):
            c.rect(rx + 3, ry, rx + 19, ry + 3, rgba(SEAM))
            for lx in range(rx + 5, rx + 18, 4):
                if rnd.random() < 0.4:
                    lights.px(lx, ry + 1, rgba(rnd.choice([CYAN, GREEN, MAG])))
    cx, cy = 900, 150                                                          # holo ring screen
    c.ellipse(cx - 30, cy - 30, cx + 30, cy + 30, rgba(DARK))
    lights.d.ellipse((cx - 26, cy - 26, cx + 26, cy + 26), outline=rgba(CYAN), width=2)
    lights.d.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), outline=rgba(CYAN, 150))
    lights.d.arc((cx - 9, cy - 9, cx + 9, cy + 9), 40, 300, fill=rgba(WHITE), width=2)
    lights.im.alpha_composite(pk.radial((120, 120), CYAN, power=1.5, max_alpha=50, steps=24), (cx - 60, cy - 60))
    tx = 960                                                                   # specimen tank
    c.rect(tx, 226, tx + 30, FLOOR - 1, rgba(hexc("2a3660")))
    for y in range(234, FLOOR - 8):
        lights.rect(tx + 4, y, tx + 26, y, rgba(GREEN, 40 + int(20 * math.sin(y / 5))))
    c.ellipse(tx + 8, 250, tx + 22, 280, rgba(hexc("1a1028")))
    for k in range(4):                                                         # hanging cables
        c.line([(1000 + k * 8, 24), (1010 + k * 6, 110), (1004 + k * 7, 190)], rgba(DARK))
    for x in range(HOME_END + 10, W, 90):                                      # ceiling strip lights
        lights.rect(x, 25, x + 50, 26, rgba(MAG if (x // 90) % 3 == 0 else WHITE, 220))
    for wx in (1060, 1180):                                                    # wall monitors
        c.rect(wx - 1, 170, wx + 40, 200, rgba(DARK))
        lights.rect(wx, 171, wx + 39, 199, rgba(MAG if wx == 1060 else CYAN, 60))
        pts = [(wx + 2 + k * 4, 190 - rnd.randint(0, 14)) for k in range(10)]
        lights.line(pts, rgba(MAG if wx == 1060 else CYAN))


def lab_density(c: Canvas, lights: Canvas):
    rnd = random.Random(841)
    sx = 846                                                                   # equipment shelving
    for row, y in enumerate((236, 262, 288)):
        c.rect(sx, y, sx + 90, y + 2, rgba(METAL))
        for k in range(rnd.randint(4, 7)):
            bx = sx + 4 + k * 12
            bh = rnd.randint(8, 18)
            c.rect(bx, y - bh, bx + 8, y - 1, rgba(rnd.choice([hexc("2a3660"), hexc("3a3050"), hexc("1e3a48")])))
            if rnd.random() < 0.5:
                lights.px(bx + 2, y - bh + 2, rgba(rnd.choice([CYAN, GREEN, MAG])))
    c.rect(sx, 236, sx + 2, FLOOR - 1, rgba(METAL)); c.rect(sx + 88, 236, sx + 90, FLOOR - 1, rgba(METAL))
    for i, px_ in enumerate((1036, 1044, 1052)):                               # vertical pipe bundle
        c.rect(px_, 24, px_ + 5, FLOOR - 1, rgba(mix(METAL, DARK, i * 0.2)))
        c.rect(px_, 24, px_, FLOOR - 1, rgba(METAL_HI))
        for fy in range(60 + i * 17, FLOOR, 70):
            c.rect(px_ - 1, fy, px_ + 6, fy + 3, rgba(hexc("4a5268")))
    for vx in (720, 1200):                                                     # vents
        c.rect(vx, 90, vx + 30, 112, rgba(SEAM))
        for vy in range(92, 112, 4):
            c.rect(vx + 2, vy, vx + 28, vy, rgba(hexc("2a3660")))
    for wx, word in ((740, "LAB 0"), (1150, "ALTA TENSAO")):                   # wall decals
        c.rect(wx - 3, 130, wx + pk.text_width(word) + 2, 140, rgba(DARK))
        pk.text(lights, wx, 133, word, rgba(AMBER if "TENSAO" in word else CYAN, 220))


def spark_slot(c: Canvas, lights: Canvas):
    cx = 1120                                                                 # spark_slot_anchor at screen 2240
    c.rect(cx - 26, 230, cx + 26, FLOOR - 1, rgba(hexc("10142a")))             # alcove
    c.rect(cx - 28, 226, cx + 28, 230, rgba(METAL))
    c.rect(cx - 16, FLOOR - 10, cx + 16, FLOOR - 1, rgba(METAL))              # charging cradle
    lights.rect(cx - 14, FLOOR - 11, cx + 14, FLOOR - 11, rgba(CYAN))
    for side in (-1, 1):
        c.line([(cx + side * 24, 232), (cx + side * 10, 280), (cx + side * 14, FLOOR - 10)], rgba(DARK), width=2)
    lights.im.alpha_composite(pk.radial((90, 100), CYAN, power=1.4, max_alpha=60, steps=24), (cx - 45, 225))
    pk.text(lights, cx - 10, 236, "SPRK", rgba(CYAN, 200))


def floor(c: Canvas, lights: Canvas):
    for x in range(W):
        home = x < HOME_END
        c.rect(x, FLOOR, x, H - 1, rgba((WOOD2 if (x // 30) % 2 else WOOD) if home else (PANEL2 if (x // 32) % 2 else PANEL)))
    for x in range(0, HOME_END, 30):
        c.rect(x, FLOOR + 2, x, H - 1, rgba(WOOD_D))
    for x in range(HOME_END, W, 32):
        c.rect(x, FLOOR + 2, x, H - 1, rgba(SEAM))
    c.rect(0, FLOOR, HOME_END - 1, FLOOR, rgba(hexc("e0b088")))                # lit walkable edge
    c.rect(HOME_END, FLOOR, W - 1, FLOOR, rgba(hexc("8ff6ff")))
    c.rect(0, FLOOR + 1, W - 1, FLOOR + 2, rgba(hexc("2a2030")))
    fade = Canvas(W, H)
    for y in range(FLOOR + 10, H):
        fade.rect(0, y, W - 1, y, rgba(DARK, int(180 * (y - FLOOR - 10) / (H - FLOOR - 10))))
    c.im.alpha_composite(fade.im)


def build():
    back, lights = Canvas(W, H), Canvas(W, H)
    wall(back, lights)
    home(back, lights)
    historic_column(back, lights)
    terminal(back, lights)
    portal(back, lights)
    workshop(back, lights)
    lab(back, lights)
    lab_density(back, lights)
    spark_slot(back, lights)
    floor(back, lights)
    return back.im, lights.im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    back, lights = build()
    back.save(OUT / "hub_stage0_back.png", optimize=True)
    lights.save(OUT / "hub_stage0_lights.png", optimize=True)
    if "--preview" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--preview") + 1])
        d.mkdir(parents=True, exist_ok=True)
        frame = pk.up(back, 2)
        pk.add_blend(frame, pk.up(lights, 2), (0, 0))
        for x, name in ((160, "jhon"), (960, None), (1120, None)):
            if name:
                jh = Image.open(ROOT / "assets/players/jhon/jhon_v2_idle_v2.png").convert("RGBA").crop((0, 0, 56, 72))
                frame.alpha_composite(jh, (x - 28, 643 - 69))
        frame.save(d / "hub_full.png")
        frame.crop((0, 0, 1280, 768)).save(d / "hub_left.png")
        frame.crop((1280, 0, 2560, 768)).save(d / "hub_right.png")
    print("ok hub")


if __name__ == "__main__":
    main()
