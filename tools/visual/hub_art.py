"""Cyberfield hub — Casa Jhon stages 0-3, Missão Visual 02 (01/11/2026).

Original composition for the hub the game actually loads (scene/casa_jhon_hub.tscn,
2560x768, floor top y=643). Drawn at native 1280x384 and shown at 2x by
scene/casa_jhon_presentation.gd. Zones follow the scene's anchors:
  main entry 64 | domestic core 512 | historic column 768 | MetaTerminal 960 |
  RunPortal 1120 | workshop core 1344 | spark slot 2240   (screen x)

ESCALA (corrigida em 01/11): o Jhon tem ~95 px no mundo = ~47 px nesta arte nativa.
Tudo é medido contra ele (JHON abaixo): porta 1,3x, bancada/balcão 0,5x, geladeira 1x,
racks 1,1x, pé-direito ~3,4x. A versão anterior desenhava os móveis 2-2,5x maiores.
Acima do teto (y < CEIL) fica o andar de cima em corte (depósito/laje), fora do alcance
do pulo duplo, para a casa não parecer feita para gigantes.

A janela da sala tem só moldura e vidro escuro aqui: a paisagem da Cidade Baixa, o
parallax e a chuva são desenhados em tempo real por scene/fx/hub_window_view.gd, que usa
as tiras window_*.png geradas por este script.

Outputs:
    assets/environment/hub/hub_stage{N}_back.png    1280x384 room (opaque)
    assets/environment/hub/hub_stage{N}_lights.png  1280x384 additive light layer
    assets/environment/hub/window_{sky,far,mid,near}.png  paisagem da janela (tiras sem emenda)

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
JHON = 47                              # altura do Jhon nesta arte (95 px de mundo / 2)
CEIL = 158                             # teto do térreo (~3,4 Jhon acima do piso)
SLAB = 12                              # espessura da laje
WOOD, WOOD2, WOOD_D = hexc("3a2a2a"), hexc("46322e"), hexc("241a1c")
PANEL, PANEL2, SEAM = hexc("1c2440"), hexc("222c4c"), hexc("0e1428")
DARK, METAL, METAL_HI = hexc("12141c"), hexc("3a4256"), hexc("6a7690")
CYAN, MAG, AMBER, GREEN, WHITE = hexc("4fe3f0"), hexc("ff4fb4"), hexc("ffb347"), hexc("54f0a0"), hexc("e8f6ff")
CONCRETE, CONCRETE_D = hexc("2a2830"), hexc("1a1820")
HOME_END = 600                         # warm home on the left, lab on the right
# Janela da sala (nativo). hub_window_view.gd usa WINDOW * 2 em coordenadas de mundo.
WINDOW = (100, 182, 150, 104)          # x, y, largura, altura -> mundo (200, 364, 300, 208)


def h(units: float) -> int:
    """Altura em pixels nativos a partir de múltiplos do Jhon."""
    return round(JHON * units)


# ---------------------------------------------------------------- estrutura
def wall(c: Canvas, lights: Canvas):
    for x in range(0, W):                                              # back wall materials
        home = x < HOME_END
        col = (WOOD if (x // 12) % 2 else WOOD2) if home else (PANEL if (x // 24) % 2 else PANEL2)
        c.rect(x, CEIL, x, FLOOR - 1, rgba(col))
    for x in range(0, HOME_END, 12):
        c.rect(x, CEIL, x, FLOOR - 1, rgba(WOOD_D))
    for x in range(HOME_END, W, 24):
        c.rect(x, CEIL, x, FLOOR - 1, rgba(SEAM))
    for y in range(CEIL + 40, FLOOR, 30):
        c.rect(HOME_END, y, W - 1, y, rgba(SEAM))
    c.rect(0, FLOOR - h(0.22), HOME_END, FLOOR - 1, rgba(mix(WOOD, DARK, 0.4)))     # rodapé de madeira
    c.rect(0, FLOOR - h(0.22) - 1, HOME_END, FLOOR - h(0.22) - 1, rgba(hexc("6a4a3a")))
    c.rect(HOME_END, FLOOR - 5, W - 1, FLOOR - 1, rgba(SEAM))
    lights.rect(HOME_END, FLOOR - 4, W - 1, FLOOR - 4, rgba(CYAN, 110))
    c.rect(HOME_END - 2, CEIL, HOME_END + 2, FLOOR - 1, rgba(DARK))             # divisória casa/lab


def upper_storey(c: Canvas, lights: Canvas):
    """Andar de cima em corte: depósito escuro e laje. Fundo, não plataforma."""
    c.vgradient(0, 0, W - 1, CEIL - SLAB - 1, [(0.0, hexc("08070c")), (1.0, hexc("141219"))], steps=6)
    rnd = random.Random(901)
    for x in range(0, W, 96):                                                  # pilares do prédio
        c.rect(x, 0, x + 7, CEIL - SLAB, rgba(CONCRETE_D))
        c.rect(x + 1, 0, x + 1, CEIL - SLAB, rgba(hexc("2e2a34")))
    for y in (34, 40):                                                         # tubulação do prédio
        c.rect(0, y, W - 1, y + 2, rgba(hexc("24262e")))
        c.rect(0, y, W - 1, y, rgba(hexc("3a3e4a")))
    floor_y = CEIL - SLAB                                                      # piso do depósito
    # casa: caixa d'água, caixas, varal e uma janela basculante pequena
    c.ellipse(40, floor_y - 44, 96, floor_y - 34, rgba(hexc("1e2a30")))
    c.rect(40, floor_y - 40, 96, floor_y - 2, rgba(hexc("1a242a")))
    c.rect(44, floor_y - 30, 92, floor_y - 29, rgba(hexc("2a3840")))
    c.rect(36, floor_y - 2, 100, floor_y - 1, rgba(METAL))
    for bx, bw, bh in ((130, 22, 16), (154, 18, 12), (140, 16, 10), (300, 26, 18), (330, 18, 14)):
        y = floor_y - bh - (10 if (bx, bw) == (140, 16) else 0)
        c.rect(bx, y, bx + bw, y + bh, rgba(hexc("3a2c24")))
        c.rect(bx, y, bx + bw, y, rgba(hexc("4e3c30")))
        c.rect(bx + bw // 2, y, bx + bw // 2, y + bh, rgba(hexc("2a2018")))
    c.line([(196, 70), (276, 74)], rgba(hexc("2a2830")))                        # varal
    for k, col in enumerate((hexc("3a2440"), hexc("24343a"), hexc("3a3424"))):
        c.rect(206 + k * 22, 72 + k, 220 + k * 22, 92 + k, rgba(col))
    c.rect(420, 60, 470, 84, rgba(hexc("0e0c16")))                              # basculante
    c.rect(422, 62, 468, 82, rgba(hexc("1a1430")))
    lights.rect(424, 64, 466, 64, rgba(MAG, 40))
    # lab: duto, eletrocalha e transformador recuperado
    c.rect(HOME_END + 10, 52, W - 20, 70, rgba(hexc("1c2230")))
    for x in range(HOME_END + 10, W - 20, 30):
        c.rect(x, 52, x + 1, 70, rgba(hexc("12161e")))
    c.rect(HOME_END + 10, 100, W - 20, 103, rgba(METAL))
    for x in range(HOME_END + 30, W - 20, 70):
        for k in range(3):
            c.rect(x + k * 6, 96, x + k * 6 + 3, 99, rgba(rnd.choice([hexc("2a3a6a"), hexc("5a2a4a"), hexc("2a5a4a")])))
    c.rect(1040, floor_y - 30, 1080, floor_y - 1, rgba(hexc("20242c")))
    for k in range(4):
        c.rect(1044 + k * 9, floor_y - 26, 1048 + k * 9, floor_y - 4, rgba(hexc("2c3240")))
    lights.px(1060, floor_y - 34, rgba(GREEN))
    haze = Image.new("RGBA", (W, floor_y), rgba(hexc("06050c"), 120))          # névoa: fica no fundo
    c.im.alpha_composite(haze, (0, 0))
    # laje entre os andares (concreto com vigas aparentes)
    c.rect(0, CEIL - SLAB, W - 1, CEIL - 1, rgba(CONCRETE))
    c.rect(0, CEIL - SLAB, W - 1, CEIL - SLAB, rgba(hexc("3e3a46")))
    c.rect(0, CEIL - 2, W - 1, CEIL - 1, rgba(CONCRETE_D))
    for x in range(20, W, 64):
        c.rect(x, CEIL - SLAB + 3, x + 2, CEIL - 3, rgba(CONCRETE_D))
    for x in range(0, W, 7):
        if rnd.random() < 0.3:
            c.px(x, CEIL - SLAB + 2 + rnd.randint(0, 6), rgba(hexc("36323e")))


def ceiling_fixtures(c: Canvas, lights: Canvas):
    for py in (CEIL + 2,):                                                     # tubo sob a laje
        c.rect(0, py, W - 1, py + 1, rgba(METAL))
        c.rect(0, py, W - 1, py, rgba(METAL_HI))


# ---------------------------------------------------------------- janela
def window(c: Canvas, lights: Canvas):
    x0, y0, w, wh = WINDOW
    c.rect(x0 - 4, y0 - 4, x0 + w + 3, y0 + wh + 5, rgba(hexc("2a2026")))      # caixilho
    c.rect(x0 - 2, y0 - 2, x0 + w + 1, y0 + wh + 1, rgba(DARK))
    c.rect(x0, y0, x0 + w - 1, y0 + wh - 1, rgba(hexc("0a0818")))              # vidro (coberto em jogo)
    c.rect(x0 - 6, y0 + wh + 2, x0 + w + 5, y0 + wh + 5, rgba(hexc("5a4038")))  # peitoril
    c.rect(x0 - 6, y0 + wh + 2, x0 + w + 5, y0 + wh + 2, rgba(hexc("7a5a48")))
    lights.im.alpha_composite(pk.radial((w + 60, 70), MAG, power=1.6, max_alpha=30, steps=24), (x0 - 30, y0 + wh - 10))
    for x in range(x0 + 6, x0 + w - 6, 18):                                     # luz da cidade no piso
        lights.rect(x, FLOOR - 3, x + 10, FLOOR - 2, rgba(MAG, 24))


# ---------------------------------------------------------------- casa
def home(c: Canvas, lights: Canvas):
    c.rect(6, FLOOR - h(1.32), 32, FLOOR - 1, rgba(DARK))                      # porta (main_entry)
    c.rect(9, FLOOR - h(1.32) + 3, 29, FLOOR - 1, rgba(hexc("2a2030")))
    c.rect(11, FLOOR - h(1.32) + 6, 27, FLOOR - h(0.75), rgba(hexc("32283a")))
    c.rect(25, FLOOR - h(0.6), 26, FLOOR - h(0.55), rgba(METAL_HI))            # maçaneta
    lights.rect(30, FLOOR - h(0.8), 31, FLOOR - h(0.72), rgba(GREEN))           # leitor da fechadura
    window(c, lights)
    sofa_x, sofa_w = 112, 60                                                   # sofá-cama sob a janela
    c.rect(sofa_x, FLOOR - h(0.26), sofa_x + sofa_w, FLOOR - 1, rgba(hexc("4a3046")))
    c.rect(sofa_x, FLOOR - h(0.42), sofa_x + sofa_w, FLOOR - h(0.26), rgba(hexc("5a3a54")))
    c.rect(sofa_x - 4, FLOOR - h(0.34), sofa_x + 2, FLOOR - 1, rgba(hexc("3a2436")))
    c.rect(sofa_x + sofa_w - 2, FLOOR - h(0.34), sofa_x + sofa_w + 4, FLOOR - 1, rgba(hexc("3a2436")))
    c.rect(sofa_x + 6, FLOOR - h(0.40), sofa_x + 18, FLOOR - h(0.30), rgba(hexc("c8b8c8")))  # travesseiro
    c.rect(sofa_x + 30, FLOOR - h(0.30), sofa_x + 52, FLOOR - h(0.24), rgba(hexc("3a5a6a")))  # cobertor
    c.rect(184, FLOOR - h(0.34), 202, FLOOR - 1, rgba(WOOD_D))                 # caixote-mesinha
    c.rect(186, FLOOR - h(0.34), 200, FLOOR - h(0.34), rgba(hexc("5a4030")))
    c.rect(188, FLOOR - h(0.40), 192, FLOOR - h(0.34) - 1, rgba(hexc("6a5a4a")))  # caneca
    c.rect(196, FLOOR - h(0.66), 197, FLOOR - h(0.34) - 1, rgba(METAL))        # luminária
    c.rect(193, FLOOR - h(0.72), 201, FLOOR - h(0.66), rgba(AMBER))
    lights.im.alpha_composite(pk.radial((60, 50), AMBER, power=1.5, max_alpha=110, steps=24), (167, FLOOR - h(0.95)))
    kx, kw = 250, 84                                                           # cozinha: balcão 0,5 Jhon
    top = FLOOR - h(0.5)
    c.rect(kx, top, kx + kw, FLOOR - 1, rgba(hexc("2a2e38")))
    c.rect(kx - 1, top - 2, kx + kw + 1, top, rgba(hexc("6a7080")))
    for x in range(kx + 3, kx + kw - 4, 14):
        c.rect(x, top + 3, x + 11, FLOOR - 3, rgba(hexc("232630")))
        c.rect(x + 9, top + 8, x + 9, top + 12, rgba(METAL_HI))
    c.rect(kx + 8, top - 6, kx + 16, top - 3, rgba(hexc("8a8a8a")))            # panela
    c.rect(kx + 52, top - 4, kx + 66, top - 3, rgba(METAL))                    # fogareiro
    lights.rect(kx + 55, top - 5, kx + 63, top - 5, rgba(hexc("ff6a3d"), 160))
    ux = kx + 4                                                                # armário alto
    c.rect(ux, FLOOR - h(1.62), ux + 56, FLOOR - h(1.22), rgba(hexc("2e3240")))
    c.rect(ux + 28, FLOOR - h(1.62), ux + 28, FLOOR - h(1.22), rgba(DARK))
    for hx in (ux + 24, ux + 31):
        c.rect(hx, FLOOR - h(1.30), hx + 1, FLOOR - h(1.26), rgba(METAL_HI))
    fx = kx + kw + 4                                                           # geladeira: 1 Jhon
    c.rect(fx, FLOOR - h(1.0), fx + 22, FLOOR - 1, rgba(hexc("4a5262")))
    c.rect(fx, FLOOR - h(0.62), fx + 22, FLOOR - h(0.62), rgba(DARK))
    c.rect(fx + 19, FLOOR - h(0.92), fx + 19, FLOOR - h(0.70), rgba(METAL_HI))
    c.rect(fx + 3, FLOOR - h(0.55), fx + 9, FLOOR - h(0.48), rgba(hexc("e8d080")))  # bilhete
    lights.rect(fx + 3, FLOOR - h(0.95), fx + 5, FLOOR - h(0.95), rgba(CYAN))
    c.rect(kx + 40, CEIL, kx + 40, FLOOR - h(1.95), rgba(DARK))                 # pendente
    c.rect(kx + 34, FLOOR - h(1.95), kx + 46, FLOOR - h(1.88), rgba(hexc("8a5a2a")))
    lights.im.alpha_composite(pk.cone(90, h(1.4), AMBER, max_alpha=55), (kx - 5, FLOOR - h(1.88)))
    sx = 404                                                                   # prateleiras da sala
    for y in (FLOOR - h(1.18), FLOOR - h(0.86)):
        c.rect(sx, y, sx + 34, y + 1, rgba(WOOD_D))
    rnd = random.Random(811)
    for row, y in enumerate((FLOOR - h(1.18), FLOOR - h(0.86))):
        x = sx + 1
        while x < sx + 32:
            bh = rnd.randint(5, 9)
            c.rect(x, y - bh, x + 2, y - 1, rgba(rnd.choice([hexc("6a3a3a"), hexc("3a5a6a"), hexc("6a6a3a"), hexc("4a3a6a")])))
            x += 4


def historic_column(c: Canvas, lights: Canvas):
    cx = 384
    c.rect(cx - 10, CEIL, cx + 10, FLOOR - 1, rgba(hexc("4a4048")))            # coluna estrutural
    c.rect(cx - 10, CEIL, cx - 9, FLOOR - 1, rgba(hexc("6a5a66")))
    c.rect(cx - 13, CEIL, cx + 13, CEIL + 6, rgba(hexc("2a2430")))
    c.rect(cx - 13, FLOOR - 7, cx + 13, FLOOR - 1, rgba(hexc("2a2430")))
    by = FLOOR - h(1.25)                                                       # quadro de memórias, altura dos olhos
    c.rect(cx - 9, by, cx + 9, by + 18, rgba(hexc("6a5440")))
    rnd = random.Random(821)
    for _ in range(6):
        px_, py = rnd.randint(cx - 8, cx + 4), rnd.randint(by + 1, by + 14)
        c.rect(px_, py, px_ + 3, py + 3, rgba(rnd.choice([hexc("e8e0d0"), hexc("c8d8e8"), hexc("e8d080")])))
        c.px(px_ + 1, py, rgba(MAG))
    c.line([(cx - 6, by + 4), (cx + 4, by + 10), (cx - 3, by + 15)], rgba(hexc("c03a3a")))
    lights.im.alpha_composite(pk.radial((44, 36), AMBER, power=1.6, max_alpha=55, steps=24), (cx - 22, by - 8))


def terminal(c: Canvas, lights: Canvas):
    cx = 480                                                                  # MetaTerminal (tela 960)
    desk = FLOOR - h(0.44)
    c.rect(cx - 30, desk, cx + 30, FLOOR - 1, rgba(hexc("1e2438")))           # mesa 0,44 Jhon
    c.rect(cx - 32, desk - 2, cx + 32, desk, rgba(METAL_HI))
    c.rect(cx - 27, desk + 4, cx - 8, FLOOR - 3, rgba(hexc("262c44")))        # gaveteiro / gabinete
    lights.rect(cx - 24, desk + 7, cx - 22, desk + 7, rgba(GREEN))
    for i, (mx, my, mw, mh) in enumerate(((cx - 26, desk - 14, 14, 10), (cx - 9, desk - 18, 18, 14), (cx + 12, desk - 14, 14, 10))):
        c.rect(mx - 1, my - 1, mx + mw, my + mh, rgba(DARK))                  # monitores reaproveitados
        scr = [CYAN, CYAN, MAG][i]
        lights.rect(mx, my, mx + mw - 1, my + mh - 1, rgba(scr, 90))
        for k in range(2):
            lights.rect(mx + 2, my + 2 + k * 4, mx + 2 + (k * 5 + i * 3) % (mw - 4), my + 2 + k * 4, rgba(scr))
        c.rect(mx + mw // 2, my + mh, mx + mw // 2, desk - 3, rgba(METAL))
    c.rect(cx - 5, desk - 3, cx + 5, desk - 2, rgba(hexc("2a3048")))          # teclado
    c.line([(cx + 28, desk), (cx + 34, FLOOR - 1)], rgba(DARK))               # cabos ao chão
    lights.im.alpha_composite(pk.radial((90, 60), CYAN, power=1.5, max_alpha=70, steps=24), (cx - 45, desk - 40))
    pk.text(lights, cx - 7, desk - 27, "META", rgba(CYAN))


def portal(c: Canvas, lights: Canvas):
    cx, base = 560, FLOOR                                                     # RunPortal (tela 1120)
    ring = h(1.4)                                                              # anel 1,4 Jhon
    c.poly([(cx - 34, base), (cx - 28, base - 6), (cx + 28, base - 6), (cx + 34, base)], rgba(METAL))
    c.rect(cx - 28, base - 6, cx + 28, base - 5, rgba(METAL_HI))
    top = base - 6 - ring
    c.ellipse(cx - ring // 2 - 4, top - 2, cx + ring // 2 + 4, base - 4, rgba(DARK))
    c.ellipse(cx - ring // 2, top + 2, cx + ring // 2, base - 8, rgba(hexc("0a0a18")))
    mid_y = (top + base - 6) // 2
    for r, col, a in ((ring // 2 - 1, CYAN, 230), (ring // 2 - 5, MAG, 170), (ring // 2 - 9, CYAN, 90)):
        lights.d.ellipse((cx - r, mid_y - r, cx + r, mid_y + r), outline=rgba(col, a), width=2)
    lights.im.alpha_composite(pk.radial((ring + 10, ring + 10), CYAN, power=1.2, max_alpha=60, steps=24), (cx - ring // 2 - 5, top - 5))
    for side in (-1, 1):                                                       # pilares com cabos
        px_ = cx + side * (ring // 2 + 10)
        c.rect(px_ - 3, base - h(1.1), px_ + 3, base - 1, rgba(METAL))
        lights.rect(px_ - 1, base - h(1.05), px_, base - 4, rgba(MAG if side < 0 else CYAN, 200))
    pk.text(lights, cx - 5, top - 10, "RUN", rgba(MAG))


def workshop(c: Canvas, lights: Canvas):
    cx = 672                                                                  # oficina (tela 1344)
    top = FLOOR - h(0.5)
    c.rect(cx - 44, top, cx + 44, top + 3, rgba(hexc("5a5040")))              # bancada 0,5 Jhon
    c.rect(cx - 41, top + 3, cx - 37, FLOOR - 1, rgba(DARK)); c.rect(cx + 37, top + 3, cx + 41, FLOOR - 1, rgba(DARK))
    c.rect(cx - 37, top + 13, cx + 37, top + 14, rgba(DARK))
    c.rect(cx - 34, top + 15, cx - 16, FLOOR - 2, rgba(hexc("3a3428")))       # caixa de peças sob a bancada
    c.rect(cx - 6, top + 15, cx + 14, FLOOR - 2, rgba(hexc("2a3240")))
    pb = FLOOR - h(1.45)                                                       # painel de ferramentas
    c.rect(cx - 40, pb, cx + 40, pb + 24, rgba(hexc("3a3430")))
    for tx in range(cx - 36, cx + 36, 6):
        c.rect(tx, pb + 3, tx, pb + 9 + (tx % 5) * 2, rgba(METAL_HI))
    for k in range(3):
        c.rect(cx + 20 + k * 6, pb + 14, cx + 23 + k * 6, pb + 21, rgba(hexc("6a3a2a") if k % 2 else hexc("2a4a6a")))
    c.rect(cx - 30, top - 3, cx - 22, top - 1, rgba(METAL))                   # morsa
    c.rect(cx - 28, top - 7, cx - 24, top - 3, rgba(METAL_HI))
    c.rect(cx + 18, top - 14, cx + 21, top - 1, rgba(METAL))                   # braço robótico pequeno
    c.line([(cx + 19, top - 14), (cx + 10, top - 20), (cx + 2, top - 16)], rgba(METAL_HI), width=2)
    lights.px(cx + 1, top - 16, rgba(CYAN))
    c.rect(cx - 12, top - 6, cx + 2, top - 1, rgba(hexc("3a4a5a")))           # peça de robô
    lights.px(cx - 8, top - 4, rgba(AMBER))
    c.rect(cx, CEIL, cx, pb - 12, rgba(DARK))                                  # luminária de oficina
    c.rect(cx - 12, pb - 12, cx + 10, pb - 9, rgba(METAL))
    lights.im.alpha_composite(pk.cone(110, h(1.5), WHITE, max_alpha=30), (cx - 55, pb - 9))


def lab(c: Canvas, lights: Canvas):
    rnd = random.Random(831)
    for rx in (752, 772, 792):                                                 # racks 1,1 Jhon
        top = FLOOR - h(1.1)
        c.rect(rx, top, rx + 17, FLOOR - 1, rgba(hexc("161c30")))
        c.rect(rx + 1, top + 1, rx + 16, FLOOR - 2, rgba(hexc("1e2848")))
        for ry in range(top + 3, FLOOR - 4, 5):
            c.rect(rx + 3, ry, rx + 14, ry + 2, rgba(SEAM))
            for lx in range(rx + 4, rx + 14, 3):
                if rnd.random() < 0.4:
                    lights.px(lx, ry + 1, rgba(rnd.choice([CYAN, GREEN, MAG])))
    cx, cy = 900, FLOOR - h(1.65)                                              # anel holográfico de parede
    c.ellipse(cx - 18, cy - 18, cx + 18, cy + 18, rgba(DARK))
    lights.d.ellipse((cx - 15, cy - 15, cx + 15, cy + 15), outline=rgba(CYAN), width=2)
    lights.d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), outline=rgba(CYAN, 150))
    lights.d.arc((cx - 5, cy - 5, cx + 5, cy + 5), 40, 300, fill=rgba(WHITE), width=1)
    lights.im.alpha_composite(pk.radial((80, 80), CYAN, power=1.5, max_alpha=45, steps=24), (cx - 40, cy - 40))
    tx = 960                                                                   # tanque de espécime 1,05 Jhon
    top = FLOOR - h(1.05)
    c.rect(tx - 2, top - 4, tx + 24, top, rgba(METAL))
    c.rect(tx, top, tx + 22, FLOOR - 6, rgba(hexc("2a3660")))
    for y in range(top + 4, FLOOR - 8):
        lights.rect(tx + 3, y, tx + 19, y, rgba(GREEN, 40 + int(20 * math.sin(y / 4))))
    c.ellipse(tx + 6, top + 12, tx + 16, top + 34, rgba(hexc("1a1028")))
    c.rect(tx - 2, FLOOR - 6, tx + 24, FLOOR - 1, rgba(METAL))
    for k in range(3):                                                         # cabos pendentes
        c.line([(1000 + k * 7, CEIL), (1008 + k * 5, CEIL + 50), (1003 + k * 6, CEIL + 96)], rgba(DARK))
    for x in range(HOME_END + 20, W, 90):                                      # luminárias tubulares
        c.rect(x, CEIL + 4, x + 40, CEIL + 6, rgba(METAL))
        lights.rect(x + 1, CEIL + 7, x + 39, CEIL + 7, rgba(MAG if (x // 90) % 3 == 0 else WHITE, 220))
    for wx in (1062, 1178):                                                    # monitores de parede
        my = FLOOR - h(1.55)
        c.rect(wx - 1, my, wx + 30, my + 20, rgba(DARK))
        lights.rect(wx, my + 1, wx + 29, my + 19, rgba(MAG if wx == 1062 else CYAN, 60))
        pts = [(wx + 2 + k * 3, my + 14 - rnd.randint(0, 10)) for k in range(9)]
        lights.line(pts, rgba(MAG if wx == 1062 else CYAN))


def lab_density(c: Canvas, lights: Canvas):
    rnd = random.Random(841)
    sx = 840                                                                   # estante de equipamentos 0,95 Jhon
    rows = (FLOOR - h(0.95), FLOOR - h(0.62), FLOOR - h(0.30))
    for y in rows:
        c.rect(sx, y, sx + 64, y + 1, rgba(METAL))
        for k in range(rnd.randint(4, 6)):
            bx = sx + 3 + k * 10
            bh = rnd.randint(5, 11)
            c.rect(bx, y - bh, bx + 6, y - 1, rgba(rnd.choice([hexc("2a3660"), hexc("3a3050"), hexc("1e3a48")])))
            if rnd.random() < 0.5:
                lights.px(bx + 2, y - bh + 2, rgba(rnd.choice([CYAN, GREEN, MAG])))
    c.rect(sx, rows[0], sx + 1, FLOOR - 1, rgba(METAL)); c.rect(sx + 63, rows[0], sx + 64, FLOOR - 1, rgba(METAL))
    for i, px_ in enumerate((1036, 1043, 1050)):                               # feixe de tubos
        c.rect(px_, CEIL, px_ + 4, FLOOR - 1, rgba(mix(METAL, DARK, i * 0.2)))
        c.rect(px_, CEIL, px_, FLOOR - 1, rgba(METAL_HI))
        for fy in range(CEIL + 20 + i * 13, FLOOR, 50):
            c.rect(px_ - 1, fy, px_ + 5, fy + 2, rgba(hexc("4a5268")))
    for vx in (720, 1206):                                                     # dutos de ventilação
        c.rect(vx, CEIL + 12, vx + 22, CEIL + 26, rgba(SEAM))
        for vy in range(CEIL + 14, CEIL + 26, 3):
            c.rect(vx + 2, vy, vx + 20, vy, rgba(hexc("2a3660")))
    for wx, word in ((736, "LAB 0"), (1150, "ALTA TENSAO")):                   # avisos de parede
        y = CEIL + 34
        c.rect(wx - 3, y - 3, wx + pk.text_width(word) + 2, y + 7, rgba(DARK))
        pk.text(lights, wx, y, word, rgba(AMBER if "TENSAO" in word else CYAN, 220))
    cx = 1110                                                                  # bancada de implantes (cyberware)
    top = FLOOR - h(0.5)
    c.rect(cx - 30, top, cx - 8, top + 2, rgba(METAL_HI))
    c.rect(cx - 28, top + 2, cx - 26, FLOOR - 1, rgba(DARK)); c.rect(cx - 12, top + 2, cx - 10, FLOOR - 1, rgba(DARK))
    c.rect(cx - 25, top - 5, cx - 15, top - 1, rgba(hexc("3a2a3a")))           # braço protético na bancada
    lights.rect(cx - 22, top - 4, cx - 18, top - 4, rgba(MAG))
    c.line([(cx - 19, CEIL), (cx - 19, top - 14)], rgba(DARK))                 # lupa articulada
    c.ellipse(cx - 24, top - 16, cx - 14, top - 10, rgba(METAL))
    lights.px(cx - 19, top - 13, rgba(WHITE))


def spark_slot(c: Canvas, lights: Canvas):
    cx = 1120                                                                 # spark_slot_anchor (tela 2240)
    top = FLOOR - h(0.9)
    c.rect(cx + 2, top, cx + 34, FLOOR - 1, rgba(hexc("10142a")))              # nicho
    c.rect(cx, top - 3, cx + 36, top, rgba(METAL))
    c.rect(cx + 8, FLOOR - 6, cx + 28, FLOOR - 1, rgba(METAL))                # berço de carga
    lights.rect(cx + 9, FLOOR - 7, cx + 27, FLOOR - 7, rgba(CYAN))
    for side in (0, 1):
        x = cx + 4 + side * 28
        c.line([(x, top + 2), (cx + 12 + side * 12, top + 24), (cx + 10 + side * 16, FLOOR - 6)], rgba(DARK))
    lights.im.alpha_composite(pk.radial((60, 60), CYAN, power=1.4, max_alpha=55, steps=24), (cx - 12, top - 6))
    pk.text(lights, cx + 9, top + 4, "SPRK", rgba(CYAN, 200))


def side_walls(c: Canvas, lights: Canvas):
    """Paredes externas de alvenaria em toda a altura (escalada de parede fica crível)."""
    for x0, x1 in ((0, 4), (W - 5, W - 1)):
        c.rect(x0, 0, x1, FLOOR - 1, rgba(CONCRETE))
        for y in range(4, FLOOR, 9):
            c.rect(x0, y, x1, y, rgba(CONCRETE_D))


def floor(c: Canvas, lights: Canvas):
    for x in range(W):
        home_side = x < HOME_END
        c.rect(x, FLOOR, x, FLOOR + 5, rgba((WOOD2 if (x // 16) % 2 else WOOD) if home_side else (PANEL2 if (x // 16) % 2 else PANEL)))
    for x in range(0, HOME_END, 16):
        c.rect(x, FLOOR + 1, x, FLOOR + 5, rgba(WOOD_D))
    for x in range(HOME_END, W, 16):
        c.rect(x, FLOOR + 1, x, FLOOR + 5, rgba(SEAM))
    c.rect(0, FLOOR, HOME_END - 1, FLOOR, rgba(hexc("e0b088")))                # borda iluminada do piso
    c.rect(HOME_END, FLOOR, W - 1, FLOOR, rgba(hexc("8ff6ff")))
    c.rect(0, FLOOR + 6, W - 1, H - 1, rgba(CONCRETE_D))                        # laje do piso em corte
    for x in range(30, W, 64):
        c.rect(x, FLOOR + 8, x + 3, H - 1, rgba(hexc("121018")))
    c.rect(0, FLOOR + 14, W - 1, FLOOR + 15, rgba(hexc("24222c")))
    fade = Canvas(W, H)
    for y in range(FLOOR + 10, H):
        fade.rect(0, y, W - 1, y, rgba(DARK, int(200 * (y - FLOOR - 10) / (H - FLOOR - 10))))
    c.im.alpha_composite(fade.im)


# ---- House stages 1-3 (MetaProgression.house_stage): cumulative upgrades over stage 0.

def stage1_repairs(c: Canvas, lights: Canvas):
    """1 — Reparos: a casa ganha vida e o lab se organiza."""
    for x in range(36, 590):                                                   # varal de luzes sob a laje
        y = CEIL + 8 + int(6 * math.sin((x - 36) / 554 * math.pi * 5) ** 2)
        c.px(x, y, rgba(DARK))
        if x % 12 == 0:
            lights.rect(x, y + 1, x + 1, y + 2, rgba(AMBER if (x // 12) % 3 else MAG))
    lights.im.alpha_composite(pk.radial((600, 30), AMBER, power=1.8, max_alpha=22, steps=24), (0, CEIL + 2))
    pk.text(lights, 9, FLOOR - h(1.32) - 9, "JHON", rgba(AMBER, 230))          # neon sobre a porta
    c.rect(104, FLOOR + 1, 180, FLOOR + 4, rgba(hexc("5a2a44")))                 # tapete
    for x in range(108, 178, 5):
        c.px(x, FLOOR + 2, rgba(hexc("c86a8a")))
    c.rect(226, FLOOR - h(0.24), 236, FLOOR - 1, rgba(hexc("6a3a2a")))         # vaso com planta
    c.rect(224, FLOOR - h(0.26), 238, FLOOR - h(0.24), rgba(hexc("8a4a32")))
    base = FLOOR - h(0.26)
    for k, (lx, ly) in enumerate(((220, base - 16), (231, base - 22), (240, base - 14), (224, base - 8), (238, base - 6))):
        c.poly([(231, base), (lx, ly), (lx + (3 if k % 2 else -3), ly + 5)], rgba(hexc("2e6a3a") if k % 2 else hexc("3e8a4a")))
    c.rect(608, CEIL + 9, 1272, CEIL + 11, rgba(METAL))                         # eletrocalha do lab
    for k, col in enumerate((hexc("2a3a6a"), hexc("5a2a4a"), hexc("2a5a4a"))):
        c.rect(608, CEIL + 12 + k, 1272, CEIL + 12 + k, rgba(col))
    lights.rect(600, CEIL + 2, 600, FLOOR - 2, rgba(MAG, 170))                  # costura neon da divisória
    lights.im.alpha_composite(pk.radial((30, 200), MAG, power=1.4, max_alpha=26, steps=24), (585, CEIL))
    x0, y0, w, wh = 616, FLOOR - h(1.6), 34, 28                                # painel holográfico de blueprint
    lights.rect(x0, y0, x0 + w, y0 + wh, rgba(CYAN, 26))
    for gx in range(x0, x0 + w + 1, 7):
        lights.rect(gx, y0, gx, y0 + wh, rgba(CYAN, 50))
    for gy in range(y0, y0 + wh + 1, 7):
        lights.rect(x0, gy, x0 + w, gy, rgba(CYAN, 50))
    lights.line([(x0 + 5, y0 + 22), (x0 + 12, y0 + 12), (x0 + 22, y0 + 15), (x0 + 28, y0 + 6)], rgba(WHITE))
    c.rect(x0 + 15, y0 + wh + 2, x0 + 19, y0 + wh + 4, rgba(METAL))


def stage2_operations(c: Canvas, lights: Canvas):
    """2 — Base operacional: depósito vira sala de drones, mapa, cabeçote do portal, segundo tanque."""
    deck = CEIL - SLAB - 1
    for x in range(700, 1272, 140):                                            # luzes do depósito de cima
        c.rect(x, 20, x + 10, 22, rgba(METAL_HI))
        lights.rect(x + 1, 23, x + 9, 23, rgba(MAG))
        lights.im.alpha_composite(pk.cone(60, 40, MAG, max_alpha=26), (x - 25, 23))
    dx = 820                                                                   # drone na base de cima
    c.ellipse(dx - 10, deck - 10, dx + 10, deck - 1, rgba(hexc("2a3048")))
    c.rect(dx - 15, deck - 8, dx + 15, deck - 7, rgba(METAL_HI))
    lights.rect(dx - 2, deck - 6, dx + 2, deck - 5, rgba(CYAN))
    c.rect(dx - 20, deck, dx + 20, deck, rgba(CYAN))
    mx, my, mw, mh = 446, FLOOR - h(1.95), 68, 36                              # mapa da cidade sobre o terminal
    c.rect(mx - 2, my - 2, mx + mw + 1, my + mh + 1, rgba(DARK))
    c.rect(mx, my, mx + mw - 1, my + mh - 1, rgba(hexc("0a1424")))
    for gx in range(mx, mx + mw, 6):
        lights.rect(gx, my, gx, my + mh - 1, rgba(CYAN, 22))
    for gy in range(my, my + mh, 6):
        lights.rect(mx, gy, mx + mw - 1, gy, rgba(CYAN, 22))
    route = [(mx + 8, my + 28), (mx + 24, my + 20), (mx + 40, my + 24), (mx + 58, my + 10)]
    lights.line(route, rgba(CYAN, 170), width=1)
    for (px_, py), col in zip(route, (MAG, AMBER, CYAN, hexc("ff2a6d"))):
        lights.rect(px_ - 1, py - 1, px_ + 1, py + 1, rgba(col))
    pk.text(lights, mx + 3, my + 3, "MAPA", rgba(CYAN, 200))
    lights.im.alpha_composite(pk.radial((100, 70), CYAN, power=1.6, max_alpha=28, steps=24), (mx - 16, my - 17))
    hy = FLOOR - h(1.62)                                                       # cabeçote do portal
    c.rect(520, hy, 600, hy + 5, rgba(DARK))
    c.rect(520, hy, 600, hy, rgba(METAL_HI))
    for k, x in enumerate(range(524, 598, 8)):
        lights.rect(x, hy + 2, x + 4, hy + 3, rgba(MAG if k % 2 else CYAN, 220))
    c.rect(40, FLOOR - h(2.6), 80, FLOOR - h(1.75), rgba(DARK))                 # pôster neon
    c.rect(42, FLOOR - h(2.6) + 2, 78, FLOOR - h(1.75) - 2, rgba(hexc("2a1040")))
    lights.d.rectangle((41, FLOOR - h(2.6) + 1, 79, FLOOR - h(1.75) - 1), outline=rgba(MAG, 200))
    pb, pt = FLOOR - h(1.75) - 6, FLOOR - h(2.6) + 8
    lights.line([(48, pb), (60, pt), (72, pb)], rgba(CYAN, 180))
    tx = 990                                                                   # segundo tanque (robô)
    top = FLOOR - h(1.05)
    c.rect(tx - 2, top - 4, tx + 24, top, rgba(METAL))
    c.rect(tx, top, tx + 22, FLOOR - 6, rgba(hexc("2a3660")))
    for y in range(top + 4, FLOOR - 8):
        lights.rect(tx + 3, y, tx + 19, y, rgba(CYAN, 34 + int(18 * math.sin(y / 5))))
    c.rect(tx + 7, top + 10, tx + 15, top + 20, rgba(hexc("1a2038")))
    c.rect(tx + 9, top + 20, tx + 13, top + 40, rgba(hexc("1a2038")))
    lights.rect(tx + 9, top + 13, tx + 13, top + 13, rgba(CYAN))
    c.rect(tx - 2, FLOOR - 6, tx + 24, FLOOR - 1, rgba(METAL))


def stage3_headquarters(c: Canvas, lights: Canvas):
    """3 — Quartel Cyberfield: letreiro no depósito, exotraje, coluna de energia, menu neon."""
    word, sc = "CYBERFIELD", 3                                                 # letreiro no andar de cima
    wx = 930 - pk.text_width(word, sc) // 2
    wy = 112
    c.rect(wx - 6, wy - 5, wx + pk.text_width(word, sc) + 5, wy + 5 * sc + 4, rgba(DARK))
    for dx_, col in ((1, MAG), (0, CYAN)):
        pk.text(lights, wx + dx_, wy + dx_, word, rgba(col, 255 if dx_ == 0 else 150), scale=sc)
    lights.im.alpha_composite(pk.radial((pk.text_width(word, sc) + 80, 60), MAG, power=1.5, max_alpha=36, steps=24), (wx - 40, wy - 20))
    gx = 1236                                                                  # exotraje no pórtico (1,15 Jhon)
    top = FLOOR - h(1.25)
    c.rect(gx - 6, top, gx - 4, FLOOR - 1, rgba(METAL)); c.rect(gx + 30, top, gx + 32, FLOOR - 1, rgba(METAL))
    c.rect(gx - 6, top - 2, gx + 32, top, rgba(METAL_HI))
    armour = hexc("3a4460")
    c.rect(gx + 9, top + 6, gx + 17, top + 14, rgba(armour))                   # capacete
    lights.rect(gx + 10, top + 9, gx + 16, top + 10, rgba(CYAN))
    c.poly([(gx + 3, top + 15), (gx + 23, top + 15), (gx + 20, top + 32), (gx + 6, top + 32)], rgba(armour))
    lights.rect(gx + 11, top + 21, gx + 15, top + 24, rgba(MAG))
    for ax in (gx, gx + 23):
        c.rect(ax, top + 16, ax + 3, top + 36, rgba(mix(armour, DARK, 0.3)))
    for lx in (gx + 7, gx + 14):
        c.rect(lx, top + 32, lx + 4, FLOOR - 3, rgba(mix(armour, DARK, 0.2)))
        c.rect(lx - 1, FLOOR - 3, lx + 5, FLOOR - 1, rgba(METAL))
    lights.im.alpha_composite(pk.radial((60, 90), CYAN, power=1.6, max_alpha=26, steps=24), (gx - 17, top - 10))
    rx = 1136                                                                  # coluna de energia sobre o nicho do Spark
    c.rect(rx - 4, CEIL, rx + 4, FLOOR - h(0.9) - 4, rgba(DARK))
    c.rect(rx - 3, CEIL, rx + 3, FLOOR - h(0.9) - 4, rgba(hexc("142040")))
    lights.rect(rx - 1, CEIL, rx, FLOOR - h(0.9) - 4, rgba(CYAN, 170))
    for y in range(CEIL + 10, FLOOR - h(0.9) - 8, 18):
        lights.rect(rx - 2, y, rx + 1, y + 2, rgba(WHITE, 220))
    c.rect(258, FLOOR - h(1.12), 286, FLOOR - h(0.98), rgba(DARK))              # menu neon da cozinha
    pk.text(lights, 260, FLOOR - h(1.12) + 2, "RAMEN", rgba(MAG, 230))


STAGES = (stage1_repairs, stage2_operations, stage3_headquarters)


def build(stage: int = 0):
    back, lights = Canvas(W, H), Canvas(W, H)
    upper_storey(back, lights)
    wall(back, lights)
    ceiling_fixtures(back, lights)
    home(back, lights)
    historic_column(back, lights)
    terminal(back, lights)
    portal(back, lights)
    workshop(back, lights)
    lab(back, lights)
    lab_density(back, lights)
    spark_slot(back, lights)
    for extra in STAGES[:stage]:
        extra(back, lights)
    side_walls(back, lights)
    floor(back, lights)
    return back.im, lights.im


# ---------------------------------------------------------------- paisagem da janela
WIN_W = 320                            # largura das tiras (sem emenda), nativo


def _skyline(width, height, seed, base_col, light_cols, min_w, max_w, min_h, max_h, light_p, details, floors=0.0, rim=None):
    """Silhuetas sem emenda. light_p = janelas soltas; floors = chance de um andar inteiro aceso."""
    c = Canvas(width, height, wrap=True)
    rnd = random.Random(seed)
    x = 0
    while x < width:
        bw = rnd.randint(min_w, max_w)
        bh = rnd.randint(min_h, max_h)
        top = height - bh
        c.rect(x, top, x + bw - 1, height - 1, rgba(base_col))
        if rim is not None:                                                    # borda iluminada pela névoa
            c.rect(x, top, x + bw - 1, top, rgba(rim))
        if floors > 0.0:
            for wy in range(top + 3, height - 2, 3):
                if rnd.random() < floors:
                    col = rnd.choice(light_cols)
                    for wx in range(x + 1, x + bw - 1, 2):
                        if rnd.random() < 0.8:
                            c.px(wx, wy, rgba(col, 170))
        if details and rnd.random() < 0.5:                                     # antenas / caixas d'água
            ax = x + rnd.randint(1, max(1, bw - 2))
            c.rect(ax, top - rnd.randint(3, 8), ax, top - 1, rgba(base_col))
        if details and rnd.random() < 0.3:
            c.rect(x + 1, top - 3, x + min(bw - 2, 5), top - 1, rgba(mix(base_col, hexc("000000"), 0.2)))
        for wy in range(top + 2, height - 1, 3):
            for wx in range(x + 1, x + bw - 1, 2):
                if rnd.random() < light_p:
                    c.px(wx, wy, rgba(rnd.choice(light_cols), rnd.choice((150, 200, 255))))
        x += bw + rnd.randint(0, 2)
    return c.im


def window_strips():
    sky = Canvas(WIN_W, 104, wrap=True)
    sky.vgradient(0, 0, WIN_W - 1, 103, [(0.0, hexc("07061a")), (0.45, hexc("1e0f3a")), (0.8, hexc("4a1a4e")), (1.0, hexc("7a2a5a"))], steps=5)
    rnd = random.Random(951)
    for _ in range(6):                                                         # faixas de nuvem iluminadas pela cidade
        cx, cy, half = rnd.randint(0, WIN_W - 1), rnd.randint(20, 48), rnd.randint(18, 40)
        sky.rect(cx - half, cy, cx + half, cy + 1, rgba(hexc("3a1e4c")))
        sky.rect(cx - half + 6, cy + 2, cx + half - 6, cy + 2, rgba(hexc("4a2456")))
    # perspectiva atmosférica: longe = claro e arroxeado; perto = escuro, poucas luzes
    far = _skyline(WIN_W, 72, 961, hexc("3a2252"), [hexc("ff8ad0"), hexc("8ff0ff")], 7, 16, 28, 66, 0.02, False, 0.0, hexc("5a3470"))
    mid = _skyline(WIN_W, 82, 971, hexc("1e1434"), [AMBER, CYAN, MAG], 12, 24, 30, 70, 0.025, True, 0.14, hexc("33224e"))
    near = Canvas(WIN_W, 104, wrap=True)                                       # prédio vizinho + passarela
    near.im.alpha_composite(_skyline(WIN_W, 104, 981, hexc("08060e"), [AMBER, MAG], 24, 44, 26, 62, 0.015, True, 0.05))
    for x0 in range(0, WIN_W, 160):                                            # letreiros (luz própria em jogo)
        near.rect(x0 + 18, 30, x0 + 20, 70, rgba(hexc("0a0812")))
    near.rect(0, 88, WIN_W - 1, 90, rgba(hexc("1a1622")))                     # passarela elevada
    near.rect(0, 88, WIN_W - 1, 88, rgba(hexc("3a2a44")))
    for x in range(0, WIN_W, 8):
        near.rect(x, 84, x, 88, rgba(hexc("1a1622")))
    return {"window_sky": sky.im, "window_far": far, "window_mid": mid, "window_near": near.im}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    frames = []
    for stage in range(4):
        back, lights = build(stage)
        back.save(OUT / f"hub_stage{stage}_back.png", optimize=True)
        lights.save(OUT / f"hub_stage{stage}_lights.png", optimize=True)
        frame = pk.up(back, 2)
        pk.add_blend(frame, pk.up(lights, 2), (0, 0))
        frames.append(frame)
    for name, im in window_strips().items():
        im.save(OUT / f"{name}.png", optimize=True)
    if "--preview" in sys.argv:
        d = Path(sys.argv[sys.argv.index("--preview") + 1])
        d.mkdir(parents=True, exist_ok=True)
        # Jhon na escala real do jogo (folha 56x72 exibida a 1,5x no mundo de 2x).
        jh = Image.open(ROOT / "assets/players/jhon/jhon_v2_idle_v2.png").convert("RGBA").crop((0, 0, 56, 72))
        jh = jh.resize((84, 108), Image.NEAREST)
        for stage, frame in enumerate(frames):
            for x in (160, 700, 1344, 2100):
                frame.alpha_composite(jh, (x - 42, 643 - 103))
            frame.save(d / f"hub_stage{stage}_full.png")
        board = Image.new("RGBA", (1280, 4 * 384), (0, 0, 0, 255))
        for stage, frame in enumerate(frames):
            board.alpha_composite(frame.resize((1280, 384), Image.NEAREST), (0, stage * 384))
        board.save(d / "hub_stages_overview.png")
    print("ok hub stages 0-3 + window strips")


if __name__ == "__main__":
    main()
