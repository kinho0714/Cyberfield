"""Cyberfield — arte do arsenal, cyberwares e acessórios (01/11/2026).

Pixel art original e determinística (nada de terceiros). Gera:
  assets/arsenal/sprites_v2/<arma>.png          armas novas (mundo/inventário/mão)
  assets/arsenal/projectiles/<id>.png           projéteis (4 quadros) + impactos (5 quadros)
  assets/fx/arsenal/*.png                       golpes, clarões de cano, estados, explosões
  assets/cyberware/icons/<linha>.png            ícones 32x32 das seis linhas
  assets/cyberware/frames/<raridade>.png        moldura 36x36 por raridade
  assets/accessories/*.png                      ícones e sprites de mundo dos acessórios

    python3 -I tools/visual/arsenal_art.py [--preview DIR] [--only id1,id2]
"""
from __future__ import annotations

import math
import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelkit import Canvas, hexc, mix, outline, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
INK = hexc("0b0d14")

PAL = {
    "K": hexc("0b0d14"), "N": hexc("1d2a4a"), "D": hexc("2a3040"), "M": hexc("4f5a70"),
    "L": hexc("8e9ab0"), "W": hexc("e4ecf4"), "B": hexc("9a6234"), "b": hexc("5a341c"),
    "T": hexc("c9b48a"), "t": hexc("8a7650"), "R": hexc("a0522d"), "r": hexc("6b3418"),
    "C": hexc("39dff2"), "c": hexc("b8f6ff"), "P": hexc("ff4fb4"), "p": hexc("ffb0dc"),
    "Y": hexc("ffb347"), "y": hexc("ffe7a8"), "G": hexc("43f2b0"), "g": hexc("c8ffe8"),
    "O": hexc("ff7a2f"), "o": hexc("ffd0a0"), "V": hexc("c46bff"), "v": hexc("ecc8ff"),
    "S": hexc("ff2a6d"), "s": hexc("ff9ab8"), "E": hexc("6e7a92"),
}


def ascii_sprite(rows: list[str], outline_ink=True) -> Image.Image:
    width = max(len(r) for r in rows)
    im = Image.new("RGBA", (width + 2, len(rows) + 2))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in PAL:
                im.putpixel((x + 1, y + 1), rgba(PAL[ch]))
    return outline(im, INK) if outline_ink else im


# ---------------------------------------------------------------- armas novas
WEAPONS = {
    "baseball_bat": [
        "........................y...y...y.....",
        "..................bbbBBBBBBBBBBBBBBb..",
        "TtTtTt.......bbbBBBBBBBBBBBBBBBBBBBBBb",
        "tTtTtTbbbbbbbBBBBBBByyBBBBBBBBBBBBBBBb",
        "TtTtTtbbbbbbbBBBBBBBBBBBBBBBBBBBBBBBBb",
        "..................bbbBBBBBBBBBBBBBBBb.",
        "........................y...y...y.....",
    ],
    "iron_pipe": [
        "................................MMMMMM..",
        "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDLWWWLLM.",
        "LWWWLLLLLLLLRRLLLLLLLLLLLRrLLLLLLWWWLLLM",
        "MMLLLLLLLLLLLrRLLLLLLLLLLLLLLLLLLLLLLLLM",
        "DDDMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM",
        "................................MMMMMM..",
    ],
    "scrap_pistol": [
        "...MMMMMMMMMMMMMMMMMMM..",
        "..MLLLLLWLLLLLLLRRLLLLM.",
        "..MDDDDDDDDDDDDDDDDDDDDK",
        "...DDtTtTD..rRr.........",
        "...DTtTtTD..............",
        "...DtTtTtD..............",
        "...DTtTtTD..............",
        "....DDDDD...............",
    ],
    "corp_pistol": [
        "....WWWWWWWWWWWWWWWWWWW..",
        "...WLLLLLLLLLLLLLLLLLLLW.",
        "...LCCCCCCCCCCCCcLLLLLLLK",
        "...MMMMMMMMMMMMMMMMMMMMM.",
        "....DDDDDD..DM...........",
        "....DMMMMD..DM...........",
        "....DMCMMD...............",
        "....DMMMMD...............",
        ".....DDDD................",
    ],
    "scrap_shotgun": [
        "..............DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDK.",
        "bbbbB.........MLLLLLLLLLWLLLLLLLLLLLLLLLLLLLLM",
        "BBBBBBbbb.....MDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDM",
        "BBBBBBBBBBbbbbMLLLLLLLLRRLLLLLLLLLLLLLLLLLLLLM",
        "bBBBBBBBBBBBBBMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM.",
        "..bbbBBBBBBBBBDDOoO..DD.......................",
        ".......bbbBBBbDDOoO..DD.......................",
        "..............DDDDD...........................",
    ],
    "pulse_rifle": [
        "....................DDDDDDDDD.............................",
        "....................DgGGGGGgD.............................",
        "DDDDD...........DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD.......",
        "DMMMMDDD........MLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLM",
        "DMMMMMMMDDDDDDDDMGGgGGgGGgGGgGGgGGDLLLLLLLLLLLLLLLLLLLLLLK",
        "DMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM",
        ".DDMMMMMMMMDDDD.DDDDDD...DM.......DDDDDDDD................",
        "...DDDDDDDD.....DMMMMD...DM...............................",
        "................DMGMMD....................................",
        "................DDDDDD....................................",
    ],
    "neon_longbow": [
        "....VV..........",
        "...VvV..........",
        "..VvVD..........",
        "..VvD.c.........",
        ".VvVD..c........",
        ".VvD....c.......",
        "VvVD.....c......",
        "VvD......c......",
        "VvD.......c.....",
        "MMM.......c.....",
        "MCM........c....",
        "MMM........c....",
        "VvD.......c.....",
        "VvD......c......",
        "VvVD.....c......",
        ".VvD....c.......",
        ".VvVD..c........",
        "..VvD.c.........",
        "..VvVD..........",
        "...VvV..........",
        "....VV..........",
    ],
    # --- 02/11/2026 (P1-B): armas novas ---
    "police_baton": [
        ".....DD..........................",
        "............................ccC..",
        "TtTtDDDDDDDDDDDDDDDDDDDDDDDDDCCCc",
        "tTtTMMMMMMMMMMMMMMMMMMMMMMMMMCCCC",
        "TtTtDDDDDDDDDDDDDDDDDDDDDDDDDCCCc",
        "............................ccC..",
    ],
    "hydraulic_hammer": [
        ".............................MMMMMMMMMMM",
        ".............................MLLLLLLLLLM",
        "..........................DDDMLYYYYYYYLM",
        "TtTtTtLLLLLLLLLLLLLLLLLLLLLLLMLYKYKYKYLM",
        "tTtTtTMMMMMMMMMMMMMMMMMMMMMMMMLYYYYYYYLM",
        "..........................DDDMLLLLLLLLLM",
        ".............................MMMMMMMMMMM",
    ],
    "plasma_katana": [
        "........MM.....................................",
        "PpPpPpPpMMccccccccccccccccccccccccccccccccc....",
        "pPpPpPpPMMWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWc..",
        "........MMCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCc",
        "........MM.....................................",
    ],
    "heavy_revolver": [
        "...MMMMMMMMMMMMMMMMMMMMMMMMM.",
        "..MLLLLLLLLLLLLLLLLLLLLLLLLLK",
        "..MDDDLLLLLDDDDDDDDDDDDDDDDD.",
        "..MDLWLWLWLD.................",
        "...DDLLLLLDD.rRr.............",
        "...DBbBbD....................",
        "...DbBbBD....................",
        "...DBbBbD....................",
        "....DDDD.....................",
    ],
    "gang_smg": [
        "....DDDDDDDDDDDDDDDDDDDDDD....",
        "...DMMMMMMMMMMMMMMMMMMMMMMMDDK",
        "...DMLLLLLLLLLLSSLLLLLLLLLMDD.",
        "MMMDMMMMMMMMMMMMMMMMMMMMMMM...",
        "M..DDDDD.DDD..................",
        "M...DtD..DMD..................",
        "MM..DTD..DMD..................",
        ".....DD..DMD..................",
        "..........DD..................",
    ],
    "riot_shotgun": [
        "..............DDDDDDDDDDDDDDDDDDDDDDDDDDDDK.",
        "DDDD..........MLLLLLLLLLLLLLLLLLLLLLLLLLLLLM",
        "DMMMDDD.......MDDDDDDDDDDDDDDDDDDDDDDDDDDDDM",
        "DMMMMMMDDDDDDDMNNNNNNNCCNNNNNNNNNNNNNNNNNNNM",
        "DMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM.",
        "..DDDMMMMMMMMMDDMLMMMMMMM..................",
        "......DDDDDDDDDDDDD........................",
    ],
    "rivet_gun": [
        "......YYYYYYYYYYYYYYYYYY......",
        ".....YyYYYYYYYYYYYYYYYYYYMMMM.",
        ".....YYYYYYYYYYYYYYYYYYYYMLLLK",
        ".....DDDDDDDDDDDDDDDDDDDDMMMM.",
        "......DDMD.LWLWLWLWLW.........",
        "......DMMD....................",
        "......DMMD....................",
        ".......DD.....................",
    ],
    "gauss_rifle": [
        "...................DDDDDDDDDD...............................",
        "...................DCcCcCcCcD...............................",
        "DDDD...........DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD...",
        "DMMMDDD........MLLLLLLLLLLLLLLLLVVLLLVVLLLVVLLLVVLLLLLLLLLM..",
        "DMMMMMMDDDDDDDDMCCCCCCCCCCCCCCCCVvVLLVvVLLVvVLLVvVLLLLLLLLLLK",
        "DMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMVVMMMVVMMMVVMMMVVMMMMMMMMMMM.",
        ".DDMMMMMMMDDDD.DDDDDD...DM..................................",
        "...DDDDDDD.....DMMMMD...DM..................................",
        "...............DMCMMD.......................................",
        "...............DDDDDD.......................................",
    ],
}


# ---------------------------------------------------------------- projéteis
def projectile_frames(kind: str) -> list[Image.Image]:
    frames = []
    for f in range(4):
        if kind in ("scrap_round", "turret_round", "corp_round"):
            w, h = (12, 5) if kind != "corp_round" else (14, 5)
            core = {"scrap_round": hexc("ffe7a8"), "turret_round": hexc("ffd27a"), "corp_round": hexc("e8fdff")}[kind]
            tail = {"scrap_round": hexc("ff9a3d"), "turret_round": hexc("ffb347"), "corp_round": hexc("39dff2")}[kind]
            c = Canvas(w, h)
            length = w - 3 - (f % 2)
            for x in range(length):
                a = int(60 + 160 * x / length)
                c.px(x, 2, rgba(mix(tail, core, x / length), a))
            c.rect(w - 4, 1, w - 2, 3, rgba(core))
            c.px(w - 1, 2, rgba(core))
        elif kind == "pellet":
            c = Canvas(8, 6)
            c.rect(3, 1, 6, 4, rgba(hexc("ffd0a0")))
            c.px(7, 2, rgba(hexc("fff4e0")))
            c.px(2 - f % 2, 2, rgba(hexc("ff7a2f"), 160))
            c.px(1, 3, rgba(hexc("ff7a2f"), 90))
        elif kind == "pulse_bolt":
            c = Canvas(16, 7)
            pulse = [0, 1, 2, 1][f]
            c.ellipse(4 - pulse, 1, 15, 5, rgba(hexc("39dff2"), 150))
            c.ellipse(7, 2, 14, 4, rgba(hexc("b8f6ff")))
            c.rect(0, 3, 6, 3, rgba(hexc("39dff2"), 110))
        elif kind == "rifle_beam":
            c = Canvas(30, 7)
            for x in range(30):
                a = int(40 + 215 * (x / 29) ** 1.5)
                c.px(x, 3, rgba(hexc("c8ffe8"), a))
                if x > 6:
                    c.px(x, 2, rgba(hexc("43f2b0"), a // 2))
                    c.px(x, 4, rgba(hexc("43f2b0"), a // 2))
            c.rect(25, 1, 29, 5, rgba(hexc("43f2b0"), 120 + 40 * (f % 2)))
            c.rect(26, 2, 29, 4, rgba(hexc("f4fff9")))
        else:  # arc_arrow / neon_arrow
            neon = kind == "neon_arrow"
            w = 22 if neon else 19
            c = Canvas(w, 7)
            shaft, glowc, head = (hexc("ecc8ff"), hexc("c46bff"), hexc("b8f6ff")) if neon else (hexc("ffb0dc"), hexc("ff4fb4"), hexc("fff0fa"))
            c.rect(3, 3, w - 5, 3, rgba(shaft))
            c.poly([(w - 5, 1), (w - 1, 3), (w - 5, 5)], rgba(head))
            c.px(w - 5, 3, rgba(glowc))
            flick = [0, 1, 0, 2][f]
            c.line([(0, 1 + flick % 2), (3, 3)], rgba(glowc, 200))
            c.line([(0, 5 - flick % 2), (3, 3)], rgba(glowc, 200))
            for x in range(4, w - 6, 2):
                c.px(x, 2 + (x // 2 + f) % 3 - 1 + 1, rgba(glowc, 120))
        frames.append(c.im)
    return frames


def impact_frames(kind: str) -> list[Image.Image]:
    frames = []
    rnd = random.Random({"kinetic": 11, "pulse": 22, "plasma": 33}[kind])
    rays = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.5, 1.0)) for _ in range(9)]
    core, edge = {"kinetic": (hexc("fff4d8"), hexc("ffb347")), "pulse": (hexc("e8fdff"), hexc("39dff2")),
                  "plasma": (hexc("fff0fa"), hexc("ff4fb4"))}[kind]
    for f in range(5):
        c = Canvas(24, 24)
        t = (f + 1) / 5
        if kind == "kinetic":
            for a, s in rays:
                r0, r1 = 2 + t * 6 * s, 4 + t * 10 * s
                c.line([(12 + math.cos(a) * r0, 12 + math.sin(a) * r0), (12 + math.cos(a) * r1, 12 + math.sin(a) * r1)], rgba(mix(core, edge, t), int(255 * (1 - t * 0.8))))
            if f < 2:
                c.ellipse(9, 9, 15, 15, rgba(core))
        elif kind == "pulse":
            r = 2 + t * 9
            c.d.ellipse((12 - r, 12 - r, 12 + r, 12 + r), outline=rgba(mix(core, edge, t), int(255 * (1 - t * 0.7))), width=2 if f < 3 else 1)
            if f < 3:
                c.ellipse(10 - f, 10 - f, 14 + f, 14 + f, rgba(core, 230 - f * 60))
        else:
            for a, s in rays[:6]:
                r1 = 3 + t * 10 * s
                c.line([(12, 12), (12 + math.cos(a) * r1, 12 + math.sin(a) * r1)], rgba(edge, int(230 * (1 - t))), width=1)
            r = 2 + t * 6
            c.d.ellipse((12 - r, 12 - r, 12 + r, 12 + r), outline=rgba(core, int(255 * (1 - t))), width=1)
            if f < 2:
                c.ellipse(9, 9, 15, 15, rgba(core))
        frames.append(c.im)
    return frames


# ---------------------------------------------------------------- golpes e cano
def swing_frames(kind: str) -> list[Image.Image]:
    """Rastro do golpe, quase branco (o jogo tinge pela categoria/raridade)."""
    frames = []
    w, h = (48, 48) if kind == "slash" else (56, 48)
    for f in range(5):
        c = Canvas(w, h)
        t = f / 4
        start = -100 + t * 70 if kind == "slash" else -120 + t * 60
        sweep = 140 if kind == "slash" else 150
        radius = 20 if kind == "slash" else 22
        thick = [4, 5, 4, 3, 2][f] if kind == "slash" else [6, 7, 6, 4, 2][f]
        steps = 72
        for i in range(steps):
            a = math.radians(start + sweep * i / steps)
            fade = i / steps
            for k in range(thick):
                r = radius - k
                x, y = 8 + math.cos(a) * r + (6 if kind == "smash" else 0), h / 2 + math.sin(a) * r
                alpha = int(255 * fade * (1 - t * 0.75) * (1 - k / (thick + 1)))
                c.px(int(x), int(y), rgba(mix(hexc("ffffff"), hexc("d8f4ff"), k / thick), alpha))
        if kind == "smash" and f >= 2:
            rnd = random.Random(70 + f)
            for _ in range(6):
                x, y = rnd.randint(20, 46), rnd.randint(h // 2 + 6, h - 4)
                c.rect(x, y, x + 1, y + 1, rgba(hexc("fff2dc"), int(220 * (1 - t))))
        frames.append(c.im)
    return frames


def muzzle_frames(kind: str) -> list[Image.Image]:
    frames = []
    for f in range(3):
        c = Canvas(22, 14)
        fade = [255, 200, 110][f]
        reach = {"small": [8, 10, 6], "pulse": [10, 12, 8], "wide": [12, 15, 10], "beam": [18, 20, 14], "arc": [9, 12, 7]}[kind][f]
        spread = {"small": 2, "pulse": 2, "wide": 5, "beam": 1, "arc": 3}[kind]
        c.ellipse(0, 7 - 2, 4, 7 + 2, rgba(hexc("ffffff"), fade))
        for dy in range(-spread, spread + 1):
            length = int(reach * (1 - abs(dy) / (spread + 1.5)))
            c.line([(2, 7), (2 + length, 7 + dy * (1 if kind != "wide" else 2))], rgba(hexc("fffbe8"), int(fade * (1 - abs(dy) / (spread + 2)))))
        if kind == "arc" and f < 2:
            c.d.arc((4, 2, 16, 12), -60, 60, fill=rgba(hexc("ffffff"), fade))
        if kind == "pulse":
            c.d.ellipse((3, 3, 11, 11), outline=rgba(hexc("ffffff"), fade // 2))
        frames.append(c.im)
    return frames


# ---------------------------------------------------------------- estados e explosões
def frozen_frames() -> list[Image.Image]:
    frames = []
    rnd = random.Random(9)
    shards = [(rnd.randint(4, 26), rnd.randint(4, 36), rnd.randint(3, 7)) for _ in range(9)]
    for f in range(4):
        c = Canvas(32, 42)
        c.d.rounded_rectangle((3, 2, 28, 40), radius=6, fill=rgba(hexc("8fe9ff"), 70), outline=rgba(hexc("d8fbff"), 170))
        for i, (x, y, s) in enumerate(shards):
            a = 150 + 80 * (((i + f) % 4) == 0)
            c.poly([(x, y - s), (x + s // 2, y), (x, y + s // 2), (x - s // 2, y)], rgba(hexc("e8fdff"), a))
        c.px(6 + f * 5, 4 + f * 3, rgba(hexc("ffffff")))
        frames.append(c.im)
    return frames


def burning_frames() -> list[Image.Image]:
    frames = []
    for f in range(4):
        c = Canvas(26, 34)
        rnd = random.Random(40 + f)
        for k in range(5):
            x = 4 + k * 4 + rnd.randint(-1, 1)
            height = rnd.randint(10, 22)
            base = 33
            c.poly([(x - 3, base), (x + 3, base), (x + rnd.randint(-2, 2), base - height)], rgba(hexc("ff7a2f"), 210))
            c.poly([(x - 1, base), (x + 2, base), (x, base - height * 0.6)], rgba(hexc("ffd27a"), 230))
        c.px(6 + f * 4, 8 + (f % 2) * 3, rgba(hexc("ffe7a8")))
        frames.append(c.im)
    return frames


def burst_frames(kind: str) -> list[Image.Image]:
    frames = []
    rnd = random.Random(5 if kind == "ice" else 6)
    chunks = [(rnd.uniform(0, 2 * math.pi), rnd.uniform(0.4, 1.0), rnd.randint(2, 4)) for _ in range(22)]
    core, mid, edge = (hexc("ffffff"), hexc("b8f6ff"), hexc("39b8f2")) if kind == "ice" else (hexc("fff4d8"), hexc("ffb347"), hexc("ff4a1f"))
    for f in range(6):
        c = Canvas(96, 96)
        t = (f + 1) / 6
        r = 10 + t * 36
        c.d.ellipse((48 - r, 48 - r, 48 + r, 48 + r), outline=rgba(mix(mid, edge, t), int(255 * (1 - t) ** 0.6)), width=3 if f < 3 else 2)
        if f < 2:
            rr = 10 + f * 6
            c.ellipse(48 - rr, 48 - rr, 48 + rr, 48 + rr, rgba(mix(core, mid, f / 2), 150 - f * 70))
        for a, s, size in chunks:
            d = 6 + t * 40 * s
            x, y = 48 + math.cos(a) * d, 48 + math.sin(a) * d
            if kind == "ice":
                c.poly([(x, y - size), (x + size // 2 + 1, y), (x, y + size), (x - size // 2 - 1, y)], rgba(mix(core, mid, t), int(255 * (1 - t * 0.7))))
            else:
                c.rect(int(x), int(y), int(x) + size - 1, int(y) + size - 1, rgba(mix(mid, edge, t), int(255 * (1 - t * 0.8))))
        frames.append(c.im)
    return frames


def fire_zone_frames() -> list[Image.Image]:
    frames = []
    for f in range(4):
        c = Canvas(80, 22)
        rnd = random.Random(300 + f)
        c.rect(0, 18, 79, 21, rgba(hexc("ff4a1f"), 120))
        for k in range(14):
            x = 3 + k * 5.5 + rnd.uniform(-1, 1)
            height = rnd.randint(6, 16)
            c.poly([(x - 3, 21), (x + 3, 21), (x + rnd.uniform(-2, 2), 21 - height)], rgba(hexc("ff7a2f"), 200))
            c.poly([(x - 1, 21), (x + 1, 21), (x, 21 - height * 0.55)], rgba(hexc("ffd27a"), 230))
        frames.append(c.im)
    return frames


# ---------------------------------------------------------------- acessórios
def grenade_frames(kind: str) -> list[Image.Image]:
    frames = []
    body, light = (hexc("39b8f2"), hexc("e8fdff")) if kind == "ice" else (hexc("d8481f"), hexc("ffd27a"))
    for f in range(4):
        c = Canvas(14, 14)
        c.ellipse(2, 3, 11, 12, rgba(hexc("2a3040")))
        c.ellipse(3, 4, 10, 11, rgba(body))
        c.rect(5, 1, 8, 3, rgba(hexc("8e9ab0")))
        ang = f * math.pi / 2
        c.px(int(6.5 + math.cos(ang) * 3), int(7.5 + math.sin(ang) * 3), rgba(light))
        c.px(5, 5, rgba(light, 200))
        frames.append(outline(c.im, INK))
    return frames


def turret_frames() -> list[Image.Image]:
    frames = []
    for f in range(4):
        c = Canvas(30, 26)
        # tripé
        c.line([(15, 16), (5, 25)], rgba(PAL["M"]), width=2)
        c.line([(15, 16), (25, 25)], rgba(PAL["M"]), width=2)
        c.line([(15, 16), (15, 25)], rgba(PAL["D"]), width=2)
        # corpo
        c.rect(8, 8, 22, 16, rgba(PAL["D"]))
        c.rect(9, 9, 21, 15, rgba(PAL["M"]))
        c.rect(9, 9, 21, 10, rgba(PAL["L"]))
        # cano
        c.rect(22, 10, 29, 12, rgba(PAL["L"]))
        c.rect(27, 9, 29, 13, rgba(PAL["D"]))
        # sensor
        c.ellipse(11, 3, 17, 9, rgba(PAL["D"]))
        c.ellipse(12, 4, 16, 8, rgba(hexc("ffd27a") if f % 2 == 0 else hexc("ff7a2f")))
        c.px(13, 5, rgba(hexc("ffffff")))
        # LEDs de bateria
        for k in range(3):
            c.px(11 + k * 3, 13, rgba(hexc("43f2b0") if k <= (f % 3) else hexc("1d2a4a")))
        frames.append(outline(c.im, INK))
    return frames


def icon_canvas() -> Canvas:
    c = Canvas(32, 32)
    return c


def accessory_icon(kind: str) -> Image.Image:
    c = icon_canvas()
    if kind in ("ice_grenade", "fire_grenade"):
        ice = kind == "ice_grenade"
        body, light, dark = (hexc("39b8f2"), hexc("e8fdff"), hexc("1b5f8a")) if ice else (hexc("e0521f"), hexc("ffd27a"), hexc("7a2410"))
        c.ellipse(7, 9, 25, 29, rgba(dark))
        c.ellipse(8, 10, 24, 27, rgba(body))
        c.ellipse(11, 12, 16, 17, rgba(light, 200))
        c.rect(13, 4, 19, 9, rgba(PAL["L"]))
        c.rect(14, 5, 18, 8, rgba(PAL["M"]))
        c.d.arc((17, 1, 27, 11), 180, 340, fill=rgba(PAL["L"]), width=2)
        if ice:
            for x, y in ((12, 20), (18, 22), (15, 25)):
                c.poly([(x, y - 3), (x + 2, y), (x, y + 3), (x - 2, y)], rgba(hexc("ffffff")))
        else:
            c.poly([(12, 26), (16, 15), (20, 26)], rgba(hexc("ffd27a")))
            c.poly([(14, 26), (16, 20), (18, 26)], rgba(hexc("fff4d8")))
    else:
        im = turret_frames()[0]
        c.im.alpha_composite(im, (1, 4))
    return outline(c.im, INK)


# ---------------------------------------------------------------- cyberwares
def cyber_icon(line: str) -> Image.Image:
    c = icon_canvas()
    chrome, dark, mid = PAL["L"], PAL["D"], PAL["M"]
    accent = {"strength": hexc("ff6a3d"), "speed": hexc("43f2b0"), "dash": hexc("39dff2"),
              "physical": hexc("ff2a6d"), "intellect": hexc("c46bff"), "health": hexc("7dff9c")}[line]
    glow = mix(accent, hexc("ffffff"), 0.5)
    if line == "strength":  # braço com pistão
        c.rect(4, 12, 20, 20, rgba(dark)); c.rect(5, 13, 19, 19, rgba(mid)); c.rect(5, 13, 19, 14, rgba(chrome))
        c.rect(20, 10, 28, 22, rgba(dark)); c.rect(21, 11, 27, 21, rgba(chrome))
        c.rect(8, 9, 16, 11, rgba(accent)); c.rect(8, 21, 16, 23, rgba(accent))
        c.line([(6, 16), (18, 16)], rgba(glow))
        for x in (23, 25): c.line([(x, 12), (x, 20)], rgba(mid))
    elif line == "speed":  # perna com mola
        c.rect(12, 3, 19, 13, rgba(dark)); c.rect(13, 4, 18, 12, rgba(chrome))
        for i in range(5):
            c.line([(11, 14 + i * 2), (20, 15 + i * 2)], rgba(accent))
        c.rect(10, 24, 24, 28, rgba(dark)); c.rect(11, 25, 23, 27, rgba(mid)); c.rect(20, 25, 23, 27, rgba(glow))
        for k in range(3): c.line([(2, 10 + k * 5), (8, 10 + k * 5)], rgba(accent, 160))
    elif line == "dash":  # propulsor
        c.poly([(6, 8), (20, 8), (24, 16), (20, 24), (6, 24)], rgba(dark))
        c.poly([(7, 9), (19, 9), (22, 16), (19, 23), (7, 23)], rgba(chrome))
        c.rect(9, 13, 17, 19, rgba(mid))
        c.poly([(23, 12), (31, 16), (23, 20)], rgba(accent))
        c.poly([(24, 14), (29, 16), (24, 18)], rgba(glow))
        for k in range(3): c.px(10 + k * 3, 16, rgba(accent))
    elif line == "physical":  # punho com espigões
        c.rect(7, 10, 23, 24, rgba(dark)); c.rect(8, 11, 22, 23, rgba(chrome))
        for k in range(4): c.line([(8 + k * 4, 11), (8 + k * 4, 17)], rgba(mid))
        for k in range(3): c.poly([(10 + k * 5, 10), (12 + k * 5, 3), (14 + k * 5, 10)], rgba(accent))
        c.rect(8, 19, 22, 20, rgba(accent)); c.rect(10, 25, 20, 29, rgba(mid))
    elif line == "intellect":  # chip neural
        c.rect(8, 8, 24, 24, rgba(dark)); c.rect(9, 9, 23, 23, rgba(mid))
        c.rect(12, 12, 20, 20, rgba(accent)); c.rect(14, 14, 18, 18, rgba(glow))
        for k in range(4):
            for a, b in (((10 + k * 4, 3), (10 + k * 4, 8)), ((10 + k * 4, 24), (10 + k * 4, 29)), ((3, 10 + k * 4), (8, 10 + k * 4)), ((24, 10 + k * 4), (29, 10 + k * 4))):
                c.line([a, b], rgba(chrome))
    else:  # health: coração com monitor
        c.poly([(16, 27), (4, 14), (5, 8), (10, 5), (16, 10), (22, 5), (27, 8), (28, 14)], rgba(hexc("7a1f3a")))
        c.poly([(16, 25), (6, 14), (7, 9), (10, 7), (16, 12), (22, 7), (25, 9), (26, 14)], rgba(hexc("d8345f")))
        c.line([(3, 17), (10, 17), (12, 12), (15, 21), (18, 15), (20, 17), (29, 17)], rgba(accent), width=1)
        c.px(9, 9, rgba(hexc("ffc0d0")))
    return outline(c.im, INK)


def rarity_frame(name: str) -> Image.Image:
    color = {"common": hexc("b8c4cc"), "uncommon": hexc("43f2b0"), "rare": hexc("5aa8ff"),
             "epic": hexc("c46bff"), "legendary": hexc("ffb347")}[name]
    c = Canvas(36, 36)
    c.d.rectangle((0, 0, 35, 35), fill=rgba(hexc("0a1420"), 220))
    c.d.rectangle((0, 0, 35, 35), outline=rgba(color), width=1)
    c.d.rectangle((2, 2, 33, 33), outline=rgba(color, 90), width=1)
    for x, y in ((0, 0), (31, 0), (0, 31), (31, 31)):
        c.rect(x, y, x + 4, y + 4, rgba(color))
    pips = {"common": 1, "uncommon": 2, "rare": 3, "epic": 4, "legendary": 5}[name]
    for k in range(pips):
        c.rect(6 + k * 5, 33, 8 + k * 5, 34, rgba(mix(color, hexc("ffffff"), 0.4)))
    return c.im


# ---------------------------------------------------------------- saída
def sheet(frames: list[Image.Image]) -> Image.Image:
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for i, frame in enumerate(frames):
        out.alpha_composite(frame, (i * w, 0))
    return out


def build() -> dict[str, Image.Image]:
    out: dict[str, Image.Image] = {}
    for name, rows in WEAPONS.items():
        out[f"assets/arsenal/sprites_v2/{name}.png"] = ascii_sprite(rows)
    for kind in ("scrap_round", "corp_round", "pellet", "turret_round", "pulse_bolt", "rifle_beam", "arc_arrow", "neon_arrow"):
        out[f"assets/arsenal/projectiles/{kind}.png"] = sheet(projectile_frames(kind))
    for kind in ("kinetic", "pulse", "plasma"):
        out[f"assets/arsenal/projectiles/{kind}_impact.png"] = sheet(impact_frames(kind))
    fx = "assets/fx/arsenal/"
    out[fx + "swing_slash.png"] = sheet(swing_frames("slash"))
    out[fx + "swing_smash.png"] = sheet(swing_frames("smash"))
    for kind in ("small", "pulse", "wide", "beam", "arc"):
        out[fx + f"muzzle_{kind}.png"] = sheet(muzzle_frames(kind))
    out[fx + "status_frozen.png"] = sheet(frozen_frames())
    out[fx + "status_burning.png"] = sheet(burning_frames())
    out[fx + "ice_burst.png"] = sheet(burst_frames("ice"))
    out[fx + "fire_burst.png"] = sheet(burst_frames("fire"))
    out[fx + "fire_zone.png"] = sheet(fire_zone_frames())
    out["assets/accessories/ice_grenade_world.png"] = sheet(grenade_frames("ice"))
    out["assets/accessories/fire_grenade_world.png"] = sheet(grenade_frames("fire"))
    out["assets/accessories/portable_turret_world.png"] = sheet(turret_frames())
    for kind in ("ice_grenade", "fire_grenade", "portable_turret"):
        out[f"assets/accessories/{kind}_icon.png"] = accessory_icon(kind)
    for line in ("strength", "speed", "dash", "physical", "intellect", "health"):
        out[f"assets/cyberware/icons/{line}.png"] = cyber_icon(line)
    for name in ("common", "uncommon", "rare", "epic", "legendary"):
        out[f"assets/cyberware/frames/{name}.png"] = rarity_frame(name)
    return out


def main() -> None:
    images = build()
    only = sys.argv[sys.argv.index("--only") + 1].split(",") if "--only" in sys.argv else []
    for rel, im in images.items():
        if only and Path(rel).stem not in only:
            continue
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path, optimize=True)
    if "--preview" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--preview") + 1])
        d.mkdir(parents=True, exist_ok=True)
        tiles = list(images.items())
        scale = 4
        width = 1400
        x = y = row_h = 0
        placed = []
        for rel, im in tiles:
            w, h = im.width * scale, im.height * scale
            if x + w > width:
                x, y, row_h = 0, y + row_h + 8, 0
            placed.append((im, x, y))
            x += w + 8
            row_h = max(row_h, h)
        board = Image.new("RGBA", (width, y + row_h + 8), (24, 28, 38, 255))
        for im, px, py in placed:
            board.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (px, py))
        board.save(d / "arsenal_preview.png")
    print("ok", len(images), "arquivos")


if __name__ == "__main__":
    main()
