"""Preview compositor for biome packs — SIMULATION, not a Godot capture.

Mirrors the placement rules of scene/biomes/visual/biome_visual_theme.gd (planes at
2x, ground fill, module haze, tiled skins, dressing slots) so composition can be
judged before running the game. Used by biome_art.py --preview.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

import pixelkit as pk

ROOT = Path(__file__).resolve().parents[2]
FLOOR = 420
CELL = (840, 480)
MODULES = [(0, 0), (1, 0), (2, 0), (1, -1)]
LAMP_SLOTS = (150, 690)


def _tile(img, w, h, u0=0):
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, img.height):
        for x in range(-(u0 % img.width), w, img.width):
            out.paste(img, (x, y))
    return out


def _strip(img, scroll, w):
    big = pk.up(img, 2)
    x = int(scroll) % big.width
    out = Image.new("RGBA", (w, big.height))
    for ox in range(-x, w, big.width):
        out.paste(big, (ox, 0))
    return out


def _tint(img, t):
    if tuple(t) == (1, 1, 1, 1):
        return img
    return Image.merge("RGBA", [c.point(lambda v, k=k: int(v * k)) for c, k in zip(img.split(), t)])


def frame(images, style, W, H, cam, name, out_dir):
    f = images["sky"].resize((W, H), Image.NEAREST).convert("RGBA")
    depth = max(-H * 1.2, min(H * 1.2, FLOOR - cam[1])) - 36
    adds = []
    for p in style["planes"]:
        key, top, fx, fy, _, tint, additive, role = p
        y = int(round(top + depth * fy))
        if role == "under":
            y = anchor_y + 660  # glued under the anchor plane's street line
        strip = _tint(_strip(images[key], cam[0] * fx, W), tint)
        if role == "rail":
            pass
        if role == "anchor":
            anchor_y = y
        if additive:
            pk.add_blend(f, strip, (0, y))
        else:
            if y < 0:
                strip, y = strip.crop((0, -y, W, strip.height)), 0
            if y < H:
                f.alpha_composite(strip.crop((0, 0, W, min(strip.height, H - y))), (0, y))
        if role == "anchor":
            gy = anchor_y + 660
            if gy < H:
                g = Image.new("RGBA", (W, H - max(gy, 0)), tuple(int(c * 255) for c in style["ground_fill"]) + (255,))
                f.alpha_composite(g, (0, max(gy, 0)))
    ox, oy = cam[0] - W / 2, cam[1] - H / 2
    world = Image.new("RGBA", (W, H))

    def put(img, x, y, add=False):
        x, y = int(x - ox), int(y - oy)
        if add:
            adds.append((img, x, y))
            return
        if x >= W or y >= H or x + img.width <= 0 or y + img.height <= 0:
            return
        c = img.crop((max(0, -x), max(0, -y), min(img.width, W - x), min(img.height, H - y)))
        world.alpha_composite(c, (max(0, x), max(0, y)))

    for gx, gy in MODULES:
        hz = style["haze"] if gy == 0 else style["haze_deep"]
        put(Image.new("RGBA", CELL, tuple(int(c * 255) for c in hz)), gx * 840, gy * 480)
    dress = style["dressing"]
    for i, (gx, gy) in enumerate(MODULES):
        bx, by = gx * 840, gy * 480
        _dress_preview(dress, images, put, i, bx, by)
        put(_tile(images["floor_tile"], 840, 60, bx), bx, by + FLOOR)
    put(_tile(images["catwalk_tile"], 190, 20, 1140), 1140, FLOOR - 110)
    for wx in (1170, 1332):
        put(_tile(images["wall_tile"], 18, 480), wx, -480)
    jh = Image.open(ROOT / "assets/players/jhon/jhon_v2_idle_v2.png").convert("RGBA").crop((0, 0, 56, 72))
    put(jh, cam[0] - 220, FLOOR - 72)
    en = Image.open(ROOT / "assets/enemies/common/v2/common_idle_v2.png").convert("RGBA")
    en = en.crop((0, 0, 104, 128)).transpose(Image.FLIP_LEFT_RIGHT)
    en = en.resize((83, 102), Image.NEAREST)
    put(en, cam[0] + 160, FLOOR - 102)
    f.alpha_composite(world)
    for img, x, y in adds:
        pk.add_blend(f, img, (x, y))
    f.save(out_dir / name)


def _dress_preview(kind, images, put, i, bx, by):
    if kind == "industrial":
        _dress_industrial(images, put, i, bx, by)
    if kind == "lab":
        _dress_lab(images, put, i, bx, by)
    if kind == "core" and i % 2 == 0:
        put(images["pylon"], bx + 200, by + FLOOR - 120)
        put(images["pylon_glow"], bx + 179, by + FLOOR - 135, True)
    if kind == "city":
        if i % 2 == 1:
            for fx in range(300, 520, 48):
                put(images["fence"], bx + fx, by + FLOOR - 52)
        if i % 3 != 1:
            lx = LAMP_SLOTS[i % 2]
            put(images["lamp"], bx + lx - 20, by + FLOOR - 180)
            put(images["lamp_cone"], bx + lx - 75, by + FLOOR - 156, True)
            put(images["lamp_glow"], bx + lx - 36, by + FLOOR - 190, True)
        put(images["reflection"], bx + (520 if i % 2 == 0 else 180), by + FLOOR + 2, True)
        if i % 4 == 2:
            put(images["board"], bx + 380, by + FLOOR - 86)
            put(images["board_glow"], bx + 361, by + FLOOR - 98, True)
        if i % 3 == 1:
            put(images["crates"], bx + 600, by + FLOOR - 30)
            put(images["ac"], bx + 672, by + FLOOR - 20)


def _dress_industrial(images, put, i, bx, by):
    put(images["pipes"], bx + (40 if i % 2 else 760), by + FLOOR - 200)
    if i % 3 != 1:
        lx = LAMP_SLOTS[i % 2]
        put(images["lamp"], bx + lx - 10, by + FLOOR - 190)
        put(images["lamp_cone"], bx + lx + 37 - 85, by + FLOOR - 172, True)
        put(images["lamp_glow"], bx + lx + 37 - 30, by + FLOOR - 196, True)
    if i % 2 == 0:
        put(images["vent"], bx + 400, by + FLOOR - 44)
        put(images["vent_glow"], bx + 372, by + FLOOR - 92, True)
    if i % 3 == 1:
        put(images["barrels"], bx + 600, by + FLOOR - 30)
        put(images["post"], bx + 280, by + FLOOR - 46)
        put(images["post_glow"], bx + 271, by + FLOOR - 52, True)
    if i % 4 == 0:
        put(images["gear"], bx + 520, by + 120)


def _dress_lab(images, put, i, bx, by):
    put(images["hang_lamp"], bx + (260 if i % 2 else 560), by)
    put(images["hang_cone"], bx + (260 if i % 2 else 560) - 50, by + 136, True)
    if i % 3 != 1:
        put(images["tank"], bx + LAMP_SLOTS[i % 2] - 17, by + FLOOR - 92)
        put(images["tank_glow"], bx + LAMP_SLOTS[i % 2] - 40, by + FLOOR - 106, True)
    if i % 2 == 0:
        put(images["terminal"], bx + 400, by + FLOOR - 46)
        put(images["terminal_glow"], bx + 387, by + FLOOR - 70, True)
    if i % 3 == 1:
        put(images["rack"], bx + 620, by + FLOOR - 70)
        put(images["rack"], bx + 652, by + FLOOR - 70)


def render_all(out_dir: Path, built: dict, styles: dict):
    out_dir.mkdir(parents=True, exist_ok=True)
    for sid, style in styles.items():
        images = built[style["dir"]]
        frame(images, style, 1600, 720, (1100, FLOOR - 0.28 * 720), f"{sid}_android.png", out_dir)
        frame(images, style, 1280, 720, (2300, FLOOR - 36), f"{sid}_desktop.png", out_dir)
