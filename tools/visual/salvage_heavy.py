"""Rebuild the Heavy enemy sheets from the only intact poses in the corrupted ones.

The original heavy_*_v1.png sheets (still recoverable from git history and from
Cyberfield_Visual_Integration_v1/) contain generation debris: caption text, zoomed
crops, opaque boxes and poses cut across cells. Seven whole poses survive. This tool
extracts them (largest connected component inside a reviewed box, so frame numbers
and slivers are dropped), faces them all right, aligns the feet to one baseline and
lays out the six sheets with the frame counts EnemyCharacterVisual expects:
idle 4, walk 6, attack 6, air 4, hurt 2, death 3.

This is a salvage, not a redesign: animation uses the few poses that exist.

    python3 -I tools/visual/salvage_heavy.py [--source REV] [--preview DIR]
"""
from __future__ import annotations

import io
import subprocess
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repack_wall_slide import components  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/enemies/heavy"
BASELINE = 140
HEIGHT = 144
# name: (source sheet, x0, x1, flip_to_face_right)
POSES = {
    "idle": ("idle", 748, 874, False),
    "step_a": ("walk_run", 739, 880, False),
    "step_b": ("walk_run", 973, 1098, False),
    "air": ("jump_air_fall", 1515, 1675, False),
}


def source(name: str, rev: str) -> Image.Image:
    rel = f"assets/enemies/heavy/heavy_{name}_v1.png"
    data = subprocess.check_output(["git", "-C", str(ROOT), "show", f"{rev}:{rel}"])
    return Image.open(io.BytesIO(data)).convert("RGBA")


def strip_plinth(im: Image.Image) -> Image.Image:
    """Some poses stand on a baked display plinth (with a frame number). The boots are
    the lowest saturated magenta pixels: everything more than 2 rows below them goes."""
    px = im.load()
    w, h = im.size
    boots = -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 40 and r > 140 and b > 90 and g < 120:
                boots = y
    if boots < 0:
        return im
    for y in range(boots + 3, h):
        for x in range(w):
            px[x, y] = (0, 0, 0, 0)
    return im


def extract(rev: str, key: str) -> Image.Image:
    sheet, x0, x1, flip = POSES[key]
    crop = source(sheet, rev).crop((x0, 0, x1 + 1, HEIGHT))
    parts = components(crop.getchannel("A"))
    body = max(parts, key=len)
    bx0, bx1 = min(x for x, _ in body) - 6, max(x for x, _ in body) + 6
    by0, by1 = min(y for _, y in body) - 6, max(y for _, y in body) + 6
    keep = Image.new("RGBA", crop.size)
    src, dst = crop.load(), keep.load()
    for part in parts:                       # every fragment inside the body box (dithered art)
        if all(bx0 <= x <= bx1 and by0 <= y <= by1 for x, y in part):
            for x, y in part:
                dst[x, y] = src[x, y]
    keep = strip_plinth(keep)
    pose = keep.crop(keep.getbbox())
    return pose.transpose(Image.FLIP_LEFT_RIGHT) if flip else pose


def layout(poses, cell, nudges=None):
    out = Image.new("RGBA", (cell * len(poses), HEIGHT))
    for i, pose in enumerate(poses):
        dx, dy = (nudges or [(0, 0)] * len(poses))[i]
        x = i * cell + (cell - pose.width) // 2 + dx
        y = BASELINE - pose.height + dy
        out.alpha_composite(pose, (max(i * cell, x), max(0, y)))
    return out


def projectile_sheets():
    """Heavy plasma slug (8x 80x104) and impact (6x 136x72), drawn in 2 px blocks
    because ProjectileVisual shows them at 0.45x. Replaces sheets full of debris."""
    import math
    import random
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from pixelkit import Canvas, hexc, mix, rgba
    white, mag, deep = hexc("fff0fa"), hexc("ff2a9a"), hexc("8a1060")
    move = Image.new("RGBA", (640, 104))
    for f in range(8):
        c = Canvas(80, 104)
        pulse = 1.0 + 0.12 * math.sin(f / 8 * 2 * math.pi)
        for k in range(5):                                   # trail, fading to the left
            r = int((14 - k * 2) * pulse)
            cx = 52 - k * 9 - (f % 2) * 2
            c.ellipse(cx - r, 52 - r // 2, cx + r, 52 + r // 2, rgba(mix(mag, deep, k / 5), 200 - k * 36))
        c.ellipse(40, 44, 66, 60, rgba(mag))
        c.ellipse(48, 47, 62, 57, rgba(white))
        rnd = random.Random(600 + f)
        for _ in range(6):
            x, y = rnd.randint(8, 44), rnd.randint(38, 66)
            c.rect(x - x % 2, y - y % 2, x - x % 2 + 1, y - y % 2 + 1, rgba(mag, 180))
        move.alpha_composite(c.im, (f * 80, 0))
    impact = Image.new("RGBA", (816, 72))
    for f in range(6):
        c = Canvas(136, 72)
        t = (f + 1) / 6
        r = 6 + t * 30
        alpha = int(255 * (1 - t) ** 0.7)
        c.d.ellipse((68 - r, 36 - r * 0.8, 68 + r, 36 + r * 0.8), outline=rgba(mix(white, mag, t), alpha), width=4 if f < 3 else 2)
        if f < 2:
            c.ellipse(56, 26, 80, 46, rgba(white, 240 - f * 100))
        rnd = random.Random(700)
        for _ in range(14):
            a, sp = rnd.uniform(0, 2 * math.pi), rnd.uniform(0.6, 1.0)
            d = 6 + t * 40 * sp
            x, y = int(68 + math.cos(a) * d), int(36 + math.sin(a) * d * 0.7)
            c.rect(x - x % 2, y - y % 2, x - x % 2 + 3, y - y % 2 + 3, rgba(mag, alpha))
        impact.alpha_composite(c.im, (f * 136, 0))
    return move, impact


def _sink(pose: Image.Image, rows: int) -> Image.Image:
    """Same baseline, bottom rows cut: reads as collapsing into the floor."""
    return pose.crop((0, 0, pose.width, pose.height - rows))


def main():
    rev = sys.argv[sys.argv.index("--source") + 1] if "--source" in sys.argv else "ponto-recuperacao-pre-renascimento"
    p = {k: extract(rev, k) for k in POSES}
    sheets = {
        "idle": layout([p["idle"]] * 4, 232, [(0, 0), (0, 1), (0, 1), (0, 0)]),
        "walk_run": layout([p["step_a"], p["step_b"], p["idle"], p["step_a"], p["step_b"], p["idle"]], 232),
        # The original shooting frames are dithered and holed; the clean firing stance
        # (from the jump sheet) carries the attack, with a small recoil.
        "attack_shoot": layout([p["idle"], p["air"], p["air"], p["air"], p["air"], p["idle"]], 264,
                               [(0, 0), (0, 0), (-3, 0), (0, 0), (-3, 0), (0, 0)]),
        "jump_air_fall": layout([p["air"]] * 4, 232, [(0, -2), (0, -1), (0, 0), (0, 1)]),
        "hurt": layout([p["idle"], p["idle"]], 232, [(-4, 0), (-2, 0)]),
        # Death plays for 0.3 s under CombatFx's burst: the body sinks out of view.
        "death": layout([p["idle"], _sink(p["idle"], 10), _sink(p["idle"], 22)], 304),
    }
    for name, im in sheets.items():
        im.save(OUT / f"heavy_{name}_v1.png", optimize=True)
    move, impact = projectile_sheets()
    move.save(OUT / "projectile/heavy_projectile_movement_v1.png", optimize=True)
    impact.save(OUT / "projectile/heavy_projectile_impact_v1.png", optimize=True)
    sheets["projectile_movement"], sheets["projectile_impact"] = move, impact
    if "--preview" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--preview") + 1])
        d.mkdir(parents=True, exist_ok=True)
        rows = list(sheets.values())
        board = Image.new("RGBA", (max(r.width for r in rows), sum(r.height + 6 for r in rows)), (90, 96, 110, 255))
        y = 0
        for r in rows:
            board.alpha_composite(r, (0, y)); y += r.height + 6
        board.save(d / "heavy_salvage.png")
    print("ok", ", ".join(sheets))


if __name__ == "__main__":
    main()
