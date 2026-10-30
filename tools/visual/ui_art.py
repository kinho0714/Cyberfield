"""Cyberfield holographic UI kit — Operação Renascimento (30/10/2026).

Regenerates every runtime UI texture IN PLACE, with the exact size and 9-slice
margins recorded in the UI manifests, so no layout or input code changes:

    assets/ui/menu_panels/assets/shared/**   (pause, settings, inventory)
    assets/ui/gameplay_hud/assets/**         (HUD, icons, touch controls)

then refreshes the sha256 fields of both used_assets.json files. Corner brackets
always sit inside the 9-slice margins so stretching never deforms them. Icons are
drawn on a 16x16 grid scaled 3x (48 px) or 4x (64 px): the HUD draws 48 px icons at
32 px, and a 3x grid survives that 2/3 reduction cleanly.

    python3 -I tools/visual/ui_art.py [--preview DIR]
"""
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelkit as pk  # noqa: E402
from pixelkit import Canvas, hexc, mix, rgba  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MENU = ROOT / "assets/ui/menu_panels"
HUD = ROOT / "assets/ui/gameplay_hud"
CYAN, MAG, RED, AMBER, GREEN = hexc("39dff2"), hexc("ff4fb4"), hexc("ff3d5f"), hexc("ffb347"), hexc("43f2b0")
FILL, FILL2, DEEP, WHITE = hexc("06111c"), hexc("0b1c2b"), hexc("030a12"), hexc("f2f7ff")


def panel(w, h, margin, accent=CYAN, state="normal", alpha=214, chamfer=True, scan=True):
    """Holographic panel: translucent fill, scanlines, chamfered corner, brackets in the margins."""
    c = Canvas(w, h)
    fill = FILL if state == "normal" else mix(FILL, accent, 0.16)
    cut = max(2, margin // 2) if chamfer else 0
    c.poly([(cut, 0), (w - 1, 0), (w - 1, h - 1 - cut), (w - 1 - cut, h - 1), (0, h - 1), (0, cut)], rgba(fill, alpha))
    if scan:
        for y in range(2, h - 2, 3):                                   # scanlines
            c.rect(2, y, w - 3, y, rgba(mix(fill, accent, 0.10), alpha))
    edge_a = 150 if state == "normal" else 235
    pts = [(cut, 0), (w - 1, 0), (w - 1, h - 1 - cut), (w - 1 - cut, h - 1), (0, h - 1), (0, cut), (cut, 0)]
    c.line(pts, rgba(accent, edge_a))
    if state != "normal":                                              # inner glow line when active
        c.line([(cut + 1, 1), (w - 2, 1)], rgba(accent, 90))
    arm = max(3, margin - 4)
    t = 2 if margin >= 10 else 1
    for (x, y, dx, dy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
        if (x, y) == (0, 0) and cut:
            continue
        if (x, y) == (w - 1, h - 1) and cut:
            continue
        c.rect(min(x, x + dx * arm), min(y, y + dy * (t - 1)), max(x, x + dx * arm), max(y, y + dy * (t - 1)), rgba(accent))
        c.rect(min(x, x + dx * (t - 1)), min(y, y + dy * arm), max(x, x + dx * (t - 1)), max(y, y + dy * arm), rgba(accent))
    if margin >= 14:                                                   # tick marks on the top edge
        for k in range(3):
            c.rect(w - margin + 2 + k * 3 - 12, 3, w - margin + 2 + k * 3 - 12, 4, rgba(accent, 160))
    if state == "selected" or state == "focused":
        c.rect(1, margin // 2, 2, h - 1 - margin // 2, rgba(accent))  # left accent bar (inside margin)
    return c.im


def slider_parts():
    track = Canvas(200, 16)
    track.rect(0, 5, 199, 10, rgba(DEEP, 230)); track.rect(0, 5, 199, 5, rgba(CYAN, 70))
    for x in range(4, 200, 20):
        track.rect(x, 11, x, 13, rgba(CYAN, 90))
    fill = Canvas(200, 16)
    for x in range(1, 199):
        if x % 6 != 5:
            fill.rect(x, 6, x, 9, rgba(mix(hexc("1a7f8f"), CYAN, x / 199)))
    fill.rect(0, 6, 199, 6, rgba(WHITE, 120))
    handle = Canvas(18, 26)
    handle.poly([(9, 0), (17, 8), (17, 17), (9, 25), (0, 17), (0, 8)], rgba(DEEP))
    handle.poly([(9, 2), (15, 9), (15, 16), (9, 23), (2, 16), (2, 9)], rgba(CYAN))
    handle.rect(8, 6, 9, 19, rgba(WHITE))
    return track.im, fill.im, handle.im


# --------------------------------------------------------------------------- icons
def grid_icon(rows, palette, scale, size):
    """rows: 16 strings of 16 chars; palette maps char -> colour. Adds a dark outline."""
    base = Image.new("RGBA", (16, 16))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                base.putpixel((x, y), rgba(palette[ch]))
    outlined = pk.outline(base, DEEP)
    big = outlined.resize((16 * scale, 16 * scale), Image.NEAREST)
    out = Image.new("RGBA", (size, size))
    out.alpha_composite(big, ((size - big.width) // 2, (size - big.height) // 2))
    return out


ICONS = {
    "blade": ([
        "..............ww",
        ".............wcw",
        "............wcw.",
        "...........wcw..",
        "..........wcw...",
        ".........wcw....",
        "........wcw.....",
        ".......wcw......",
        "..m...wcw.......",
        "...m.wcw........",
        "....mcw.........",
        "....mm..........",
        "...m..m.........",
        "..d....m........",
        ".dd.............",
        "dd..............",
    ], {"w": WHITE, "c": CYAN, "m": MAG, "d": hexc("1a7f8f")}),
    "bolt": ([
        "................",
        "...........mm...",
        "..........mmm...",
        ".........mmm....",
        "........mmm.....",
        ".......mmmmmmm..",
        "......mmmmmmm...",
        ".........mmm....",
        "........mmm.....",
        ".......mmm......",
        "......mmm.......",
        ".....mm.........",
        "....m...........",
        "................",
        ".ww..ww..ww.....",
        "................",
    ], {"m": MAG, "w": WHITE}),
    "dash": ([
        "................",
        "................",
        "..c.....c.......",
        "...cc....cc.....",
        "....ccc...ccc...",
        ".....cccc..cccc.",
        "......ccccc.cccc",
        ".......ccccccccw",
        "......ccccc.cccc",
        ".....cccc..cccc.",
        "....ccc...ccc...",
        "...cc....cc.....",
        "..c.....c.......",
        "................",
        "ww..ww..........",
        "................",
    ], {"c": CYAN, "w": WHITE}),
    "jump": ([
        ".......ww.......",
        "......wccw......",
        ".....cccccc.....",
        "....cccccccc....",
        "...ccc.cc.ccc...",
        "..cc...cc...cc..",
        ".......cc.......",
        ".......cc.......",
        "......cccc......",
        ".....cc..cc.....",
        "....cc....cc....",
        "...cc......cc...",
        "................",
        "...wwwwwwwwww...",
        "................",
        "................",
    ], {"c": CYAN, "w": WHITE}),
    "use": ([
        "aa...........aa.",
        "a.....ww.......a",
        "......wcw.......",
        "......wcw.......",
        "......wcwww.....",
        "......wcwcwww...",
        "...ww.wcwcwcww..",
        "...wcwwcccccccw.",
        "....wcccccccccw.",
        "....wcccccccccw.",
        ".....wccccccccw.",
        ".....wcccccccw..",
        "......wccccccw..",
        "a......wwwwww..a",
        "aa...........aa.",
        "................",
    ], {"a": AMBER, "w": WHITE, "c": CYAN}),
    "heal": ([
        "................",
        ".....gggggg.....",
        ".....gwwwwg.....",
        ".....gwwwwg.....",
        ".gggggwwwwggggg.",
        ".gwwwwwwwwwwwwg.",
        ".gwwwwwwwwwwwwg.",
        ".gwwwwwwwwwwwwg.",
        ".gggggwwwwggggg.",
        ".....gwwwwg.....",
        ".....gwwwwg.....",
        ".....gggggg.....",
        "................",
        "...dddddddddd...",
        "................",
        "................",
    ], {"g": GREEN, "w": WHITE, "d": hexc("1f8a62")}),
    "health": ([
        "................",
        "..rrr....rrr....",
        ".rrrrr..rrrrr...",
        "rrwrrrrrrrrrrr..",
        "rwwrrrrrrrrrrr..",
        "rrrrrrrrrrrrrr..",
        "rrrrrrrrrrrrrr..",
        ".rrrrrrrrrrrr...",
        "..rrrrrrrrrr....",
        "...rrrrrrrr.....",
        "....rrrrrr......",
        ".....rrrr.......",
        "......rr........",
        "................",
        "................",
        "................",
    ], {"r": RED, "w": WHITE}),
    "intelligence": ([
        "................",
        "...c..c..c..c...",
        "...c..c..c..c...",
        ".cccccccccccccc.",
        ".c............c.",
        "cc.wwww..cccc.cc",
        ".c.w..w..c..c.c.",
        "cc.w..wwwc..c.cc",
        ".c.wwww..cccc.c.",
        "cc............cc",
        ".c..cccccccc..c.",
        ".cccccccccccccc.",
        "...c..c..c..c...",
        "...c..c..c..c...",
        "................",
        "................",
    ], {"c": CYAN, "w": WHITE}),
    "strength": ([
        "................",
        "...aa.aa.aa.....",
        "..aaaaaaaaaa....",
        "..awaawaawaa....",
        "..aaaaaaaaaaaa..",
        "..aaaaaaaaaaaaa.",
        "..aaaaaaaaaa.aa.",
        "..aaaaaaaaaaaa..",
        "..aaaaaaaaaaa...",
        "...aaaaaaaaa....",
        "...aaaaaaaa.....",
        "....aaaaaa......",
        "....dddddd......",
        "................",
        "................",
        "................",
    ], {"a": AMBER, "w": WHITE, "d": hexc("a8641a")}),
    "money": ([
        "................",
        ".....aaaaaa.....",
        "...aaayyyyaaa...",
        "..aayyyywyyyaa..",
        "..ayyywwwwyyya..",
        ".aayyywyyyyyyaa.",
        ".ayyyywwwwyyyya.",
        ".ayyyyyyywyyyya.",
        ".aayyywwwwyyyaa.",
        "..ayyyywyyyyya..",
        "..aayyyyyyyyaa..",
        "...aaayyyyaaa...",
        ".....aaaaaa.....",
        "................",
        "................",
        "................",
    ], {"a": hexc("c47a1a"), "y": AMBER, "w": WHITE}),
}


def action_frame(accent):
    """88x88 touch action frame: octagonal holo rim around a dark, translucent core."""
    c = Canvas(88, 88)
    k = 18
    outer = [(k, 1), (86 - k, 1), (86, k), (86, 86 - k), (86 - k, 86), (k, 86), (1, 86 - k), (1, k)]
    c.poly(outer, rgba(DEEP, 190))
    inner = [(k + 4, 6), (82 - k, 6), (81, k + 4), (81, 82 - k), (82 - k, 81), (k + 4, 81), (6, 82 - k), (6, k + 4)]
    c.line(inner + [inner[0]], rgba(accent, 90))
    c.line(outer + [outer[0]], rgba(accent), width=2)
    for (x0, y0, x1, y1) in ((k, 1, k + 10, 1), (76 - k, 86, 86 - k, 86)):
        c.rect(min(x0, x1), y0 - (1 if y0 > 1 else 0), max(x0, x1), y0 + (1 if y0 == 1 else 0), rgba(WHITE))
    return c.im


def joystick():
    base = Canvas(210, 210)
    base.ellipse(4, 4, 205, 205, rgba(DEEP, 120))
    base.d.ellipse((4, 4, 205, 205), outline=rgba(CYAN, 170), width=2)
    base.d.ellipse((40, 40, 169, 169), outline=rgba(CYAN, 60), width=1)
    for a in range(0, 360, 15):
        r0, r1 = (92, 101) if a % 90 == 0 else (96, 101)
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        base.line([(105 + ca * r0, 105 + sa * r0), (105 + ca * r1, 105 + sa * r1)], rgba(CYAN, 220 if a % 90 == 0 else 110), width=2 if a % 90 == 0 else 1)
    knob = Canvas(82, 82)
    knob.ellipse(2, 2, 79, 79, rgba(hexc("0e3a48"), 200))
    knob.d.ellipse((2, 2, 79, 79), outline=rgba(CYAN), width=3)
    knob.ellipse(26, 26, 55, 55, rgba(CYAN, 120))
    knob.ellipse(34, 34, 47, 47, rgba(WHITE, 210))
    return base.im, knob.im


def player_frame(critical=False):
    """400x112 HUD plate. Zones match gameplay_hud_presentation.gd: portrait @16,12;
    HP @86,12 (286x24); doses @86,46; icon row @y74."""
    if critical:
        c = Canvas(400, 112)
        c.line([(10, 0), (399, 0), (399, 101), (389, 111), (0, 111), (0, 10), (10, 0)], rgba(RED), width=2)
        for x in range(14, 390, 6):
            c.px(x, 3, rgba(RED, 150))
        return c.im
    im = panel(400, 112, 18, CYAN, alpha=200)
    c = Canvas(400, 112)
    c.im = im
    c.d = __import__("PIL.ImageDraw", fromlist=["Draw"]).Draw(im)
    c.rect(84, 40, 374, 40, rgba(CYAN, 60))                       # divider under the HP bar
    c.rect(6, 68, 393, 68, rgba(CYAN, 45))                         # divider above the icon row
    for i in range(5):
        c.rect(8 + i * 72, 72, 8 + i * 72 + 66, 108, rgba(FILL2, 160))
    return c.im


def portrait_frame():
    c = Canvas(64, 64)
    c.rect(0, 0, 63, 63, rgba(DEEP))
    c.rect(2, 2, 61, 61, rgba(hexc("10283a")))
    c.line([(0, 0), (63, 0), (63, 63), (0, 63), (0, 0)], rgba(CYAN, 150))
    for (x, y, dx, dy) in ((0, 0, 1, 1), (63, 0, -1, 1), (0, 63, 1, -1), (63, 63, -1, -1)):
        c.rect(min(x, x + dx * 9), min(y, y + dy), max(x, x + dx * 9), max(y, y + dy), rgba(CYAN))
        c.rect(min(x, x + dx), min(y, y + dy * 9), max(x, x + dx), max(y, y + dy * 9), rgba(CYAN))
    return c.im


def hp_parts():
    track = Canvas(286, 24)
    track.rect(0, 0, 285, 23, rgba(DEEP, 230))
    for x in range(2, 284, 9):
        track.rect(x, 3, x + 6, 20, rgba(hexc("0e2230")))
    track.line([(0, 0), (285, 0), (285, 23), (0, 23), (0, 0)], rgba(CYAN, 110))
    fill = Canvas(286, 24)
    for x in range(2, 284, 9):
        for xx in range(x, x + 7):
            col = mix(hexc("21a7b8"), hexc("7ff8ff"), xx / 285)
            fill.rect(xx, 3, xx, 20, rgba(col))
        fill.rect(x, 3, x + 6, 4, rgba(WHITE, 200))
        fill.rect(x, 18, x + 6, 20, rgba(mix(hexc("21a7b8"), DEEP, 0.4)))
    return track.im, fill.im


def vignette():
    w, h = 1280, 720
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            d = min(x, w - 1 - x, y * 1.6, (h - 1 - y) * 1.6)
            if d < 150:
                a = (1 - d / 150) ** 2
                a = round(a * 6) / 6
                if y % 3 == 0:
                    a *= 0.7                                           # scanline texture
                px[x, y] = (255, 40, 70, int(170 * a))
    return im


def minimap_frame():
    return panel(250, 105, 18, CYAN, alpha=190)


def pause_button():
    c = Canvas(56, 56)
    c.im = panel(56, 56, 12, CYAN, alpha=200)
    c.d = __import__("PIL.ImageDraw", fromlist=["Draw"]).Draw(c.im)
    return c.im


def build():
    out = {}
    m = MENU / "assets/shared"
    out[m / "pause/pause_side_panel.png"] = panel(280, 390, 18)
    out[m / "pause/pause_row_normal.png"] = panel(240, 48, 10, alpha=150, scan=False)
    out[m / "pause/pause_row_selected.png"] = panel(240, 48, 10, state="selected", alpha=220)
    out[m / "inventory/inventory_panel.png"] = panel(720, 420, 18)
    out[m / "inventory/detail_panel.png"] = panel(320, 250, 16, MAG)
    out[m / "inventory/slot_empty.png"] = panel(112, 96, 10, hexc("2a4a5a"), alpha=150, scan=False)
    out[m / "inventory/slot_normal.png"] = panel(112, 96, 10, alpha=190)
    out[m / "inventory/slot_selected.png"] = panel(112, 96, 10, state="selected", alpha=230)
    out[m / "inventory/tab_normal.png"] = panel(128, 40, 8, alpha=160, scan=False)
    out[m / "inventory/tab_selected.png"] = panel(128, 40, 8, state="selected", alpha=230)
    out[m / "settings/settings_panel.png"] = panel(900, 430, 18)
    out[m / "settings/option_row_normal.png"] = panel(500, 36, 8, alpha=140, scan=False)
    out[m / "settings/option_row_focused.png"] = panel(500, 36, 8, state="focused", alpha=220)
    out[m / "settings/settings_tab_normal.png"] = panel(120, 40, 8, alpha=160, scan=False)
    out[m / "settings/settings_tab_selected.png"] = panel(120, 40, 8, state="selected", alpha=230)
    track, fill, handle = slider_parts()
    out[m / "settings/slider_track.png"], out[m / "settings/slider_fill.png"], out[m / "settings/slider_handle.png"] = track, fill, handle
    h = HUD / "assets"
    out[h / "shared/hud/player_frame.png"] = player_frame()
    out[h / "shared/low_hp/player_frame_critical_accent.png"] = player_frame(True)
    out[h / "shared/hud/portrait_frame.png"] = portrait_frame()
    out[h / "shared/hud/hp_track.png"], out[h / "shared/hud/hp_fill.png"] = hp_parts()
    out[h / "shared/hud/pause_button_frame.png"] = pause_button()
    out[h / "shared/minimap/minimap_frame.png"] = minimap_frame()
    out[h / "shared/low_hp/low_hp_vignette.png"] = vignette()
    for name, key in (("heal_icon", "heal"), ("icon_attr_health", "health"), ("icon_attr_intelligence", "intelligence"),
                      ("icon_attr_strength", "strength"), ("money_icon", "money")):
        out[h / f"shared/icons/{name}.png"] = grid_icon(*ICONS[key], 3, 48)
    for name, key in (("attack1_icon", "blade"), ("attack2_icon", "bolt"), ("dash_icon", "dash"), ("jump_icon", "jump"), ("use_icon", "use")):
        out[h / f"mobile/actions/{name}.png"] = grid_icon(*ICONS[key], 4, 64)
    for name, accent in (("action_frame_cyan", CYAN), ("action_frame_magenta", MAG), ("action_frame_red", RED)):
        out[h / f"mobile/actions/{name}.png"] = action_frame(accent)
    out[h / "mobile/joystick/joystick_base.png"], out[h / "mobile/joystick/joystick_knob.png"] = joystick()
    return out


def main():
    images = build()
    for path, im in images.items():
        old = Image.open(path)
        if old.size != im.size:
            raise SystemExit(f"{path}: size {im.size} differs from the manifest/original {old.size}")
        im.save(path, optimize=True)
    for base in (MENU, HUD):                                           # keep manifests truthful
        manifest = base / "used_assets.json"
        data = json.loads(manifest.read_text())
        entries = data if isinstance(data, list) else data.values()
        for entry in entries:
            entry["sha256"] = hashlib.sha256((base / entry["file"]).read_bytes()).hexdigest()
        manifest.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    if "--preview" in sys.argv:
        preview(Path(sys.argv[sys.argv.index("--preview") + 1]), images)
    print("ok", len(images), "ui textures")


def preview(out_dir: Path, images):
    out_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (1280, 720), (24, 18, 40, 255))
    bg = Image.open(ROOT / "assets/environment/biomes/lower_city/sky.png").resize((1280, 720), Image.NEAREST)
    sheet.alpha_composite(bg)
    h, m = HUD / "assets", MENU / "assets/shared"
    sheet.alpha_composite(images[h / "shared/hud/player_frame.png"], (20, 20))
    sheet.alpha_composite(images[h / "shared/hud/portrait_frame.png"], (36, 32))
    sheet.alpha_composite(images[h / "shared/hud/hp_track.png"], (106, 32))
    fill = images[h / "shared/hud/hp_fill.png"].crop((0, 0, 200, 24))
    sheet.alpha_composite(fill, (106, 32))
    for i, n in enumerate(("heal_icon", "icon_attr_health", "icon_attr_intelligence", "icon_attr_strength", "money_icon")):
        sheet.alpha_composite(images[h / f"shared/icons/{n}.png"].resize((32, 32), Image.NEAREST), (30 + i * 72, 94))
    sheet.alpha_composite(images[m / "pause/pause_side_panel.png"], (460, 20))
    sheet.alpha_composite(images[m / "pause/pause_row_normal.png"], (480, 60))
    sheet.alpha_composite(images[m / "pause/pause_row_selected.png"], (480, 116))
    sheet.alpha_composite(images[m / "pause/pause_row_normal.png"], (480, 172))
    for i, n in enumerate(("slot_empty", "slot_normal", "slot_selected")):
        sheet.alpha_composite(images[m / f"inventory/{n}.png"], (780 + i * 120, 20))
    sheet.alpha_composite(images[m / "settings/option_row_normal.png"], (760, 140))
    sheet.alpha_composite(images[m / "settings/option_row_focused.png"], (760, 186))
    sheet.alpha_composite(images[m / "settings/slider_track.png"], (780, 240))
    sheet.alpha_composite(images[m / "settings/slider_fill.png"].crop((0, 0, 130, 16)), (780, 240))
    sheet.alpha_composite(images[m / "settings/slider_handle.png"], (902, 235))
    for i, (frame, icon) in enumerate((("action_frame_red", "attack1_icon"), ("action_frame_magenta", "attack2_icon"),
                                        ("action_frame_cyan", "dash_icon"), ("action_frame_cyan", "jump_icon"), ("action_frame_cyan", "use_icon"))):
        sheet.alpha_composite(images[h / f"mobile/actions/{frame}.png"], (700 + i * 100, 560))
        sheet.alpha_composite(images[h / f"mobile/actions/{icon}.png"], (712 + i * 100, 572))
    sheet.alpha_composite(images[h / "mobile/joystick/joystick_base.png"], (60, 470))
    sheet.alpha_composite(images[h / "mobile/joystick/joystick_knob.png"], (124, 534))
    sheet.alpha_composite(images[h / "shared/minimap/minimap_frame.png"], (1010, 300))
    sheet.alpha_composite(images[h / "shared/hud/pause_button_frame.png"], (1200, 20))
    sheet.save(out_dir / "ui_kit_preview.png")


if __name__ == "__main__":
    main()
