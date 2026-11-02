"""Importador de spritesheets oficiais de personagens (02/11/2026).

Converte folhas produzidas externamente (alta resolução, fundo branco/quadriculado ou
RGBA) em folhas de jogo, SEM redesenhar o personagem:

  1. fundo: flood fill a partir das bordas apagando tons claros e pouco saturados;
     remove o halo claro deixado pelo antisserrilhado contra o branco;
  2. alfa binário (pixel art: sem semitransparência);
  3. quadros: componentes conectados atribuídos à célula mais próxima (poses que
     invadem a célula vizinha não são cortadas); fragmentos minúsculos descartados;
  4. escala por folha medida pela LARGURA DA CABEÇA (cabelo), que não muda com a
     postura — as folhas vieram em tamanhos diferentes;
  5. pés numa linha de base comum e posição horizontal constante por folha
     (preserva o deslocamento desenhado pelo artista dentro da animação);
     folhas aéreas centralizam cada quadro verticalmente no corpo;
  6. redução com alfa pré-multiplicado + paleta única por personagem;
  7. âncora da mão (ponto mais à frente na altura do peito) para armas separadas.

Saídas: assets/players/<id>/<set>/<id>_<anim>.png (células W×H, pés na última linha)
e entities/character_animation_sets.gd (dados para PlayerCharacterVisual).

    python3 -I tools/visual/character_sheet_import.py <pasta_com_os_PNG_originais> [--preview DIR]
"""
from __future__ import annotations

import hashlib
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

# ---------------------------------------------------------------- configuração
# Jhon Jhones — Design B (pacote Cyberfield_Jhon_Sprites_Aprovadas.zip, manifesto 02/11).
# frames: quadros na folha; mode: ground|air|jump|land; head: quadros usados para medir a
# cabeça (None = todos); hand: calcula âncora da mão.
JHON_B = {
    "character": "jhon",
    "set": "design_b",
    "cell": (160, 100),           # mundo a 1,0x; pés na última linha
    "head_target": 34.0,          # largura da cabeça em px de jogo (Jhon ≈ 95 px de altura)
    "palette": 56,
    "sheets": {
        "idle": {"file": "jhon_idle.png", "frames": 8, "mode": "ground", "fps": 8.0, "loop": True},
        "walk": {"file": "jhon_walk.png", "frames": 8, "mode": "ground", "fps": 10.0, "loop": True},
        "run": {"file": "jhon_run.png", "frames": 8, "mode": "ground", "fps": 13.0, "loop": True, "head": [0, 7]},
        "jump": {"file": "jhon_jump.png", "frames": 8, "mode": "jump", "fps": 14.0, "loop": False},
        "fall": {"file": "jhon_fall.png", "frames": 8, "mode": "air", "fps": 12.0, "loop": False},
        "land": {"file": "jhon_land.png", "frames": 8, "mode": "land", "fps": 28.0, "loop": False, "head": [4, 5, 6, 7]},
        "dash": {"file": "jhon_dash_roll.png", "frames": 8, "mode": "ground", "fps": 40.0, "loop": False, "head": [0, 6, 7]},
        "hurt": {"file": "jhon_hurt.png", "frames": 8, "mode": "ground", "fps": 24.0, "loop": False, "head": [0, 6, 7]},
        "downed": {"file": "jhon_downed.png", "frames": 8, "mode": "ground", "fps": 10.0, "loop": False, "head": [0, 1]},
        "get_up": {"file": "jhon_get_up.png", "frames": 8, "mode": "ground", "fps": 14.0, "loop": False, "head": [6, 7]},
        "aim_pistol": {"file": "jhon_aim_pistol.png", "frames": 8, "mode": "ground", "fps": 8.0, "loop": True, "hand": True},
        "aim_rifle": {"file": "jhon_aim_rifle.png", "frames": 8, "mode": "ground", "fps": 8.0, "loop": True, "hand": True},
        "aim_bow": {"file": "jhon_aim_bow.png", "frames": 8, "mode": "ground", "fps": 8.0, "loop": True, "hand": True},
        "shoot_pistol": {"file": "jhon_shoot_pistol.png", "frames": 8, "mode": "ground", "fps": 30.0, "loop": False, "hand": True},
        "shoot_rifle": {"file": "jhon_shoot_rifle.png", "frames": 8, "mode": "ground", "fps": 30.0, "loop": False, "hand": True},
        "shoot_bow": {"file": "jhon_shoot_bow.png", "frames": 8, "mode": "ground", "fps": 24.0, "loop": False, "hand": True},
        "reload_pistol": {"file": "jhon_reload_pistol.png", "frames": 8, "mode": "ground", "fps": 8.0, "loop": False, "hand": True},
        "melee_ready_impact": {"file": "jhon_melee_ready_impact.png", "frames": 8, "mode": "ground", "fps": 12.0, "loop": False},
        "melee_punch_01": {"file": "jhon_melee_punch_01.png", "frames": 8, "mode": "ground", "fps": 30.0, "loop": False},
    },
    # Inconsistências do pacote: arquivo presente mas NÃO integrado (motivo registrado).
    "rejected": {
        "reload_rifle": ("jhon_reload_rifle.png", "a folha mostra o Jhon desabando até o chão (variação de DOWNED), não uma recarga"),
    },
}

SETS = [JHON_B]


# ---------------------------------------------------------------- etapas
def _is_light(p, floor=200, spread=24):
    r, g, b = p[0], p[1], p[2]
    return min(r, g, b) >= floor and max(r, g, b) - min(r, g, b) <= spread


def remove_background(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        p = px[x, y]
        if p[3] >= 30 and not _is_light(p):
            continue
        px[x, y] = (0, 0, 0, 0)
        if x > 0: q.append((x - 1, y))
        if x < w - 1: q.append((x + 1, y))
        if y > 0: q.append((x, y - 1))
        if y < h - 1: q.append((x, y + 1))
    for _ in range(2):                                   # halo claro do antisserrilhado
        kill = []
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                p = px[x, y]
                if p[3] and _is_light(p, 170, 40):
                    if not (px[x - 1, y][3] and px[x + 1, y][3] and px[x, y - 1][3] and px[x, y + 1][3]):
                        kill.append((x, y))
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
    return im


def binarize(im: Image.Image, cut=128) -> Image.Image:
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r, g, b, a.point(lambda v: 255 if v >= cut else 0)))


def components(im: Image.Image, min_size=80):
    a = im.getchannel("A")
    w, h = im.size
    data = a.load()
    label = [0] * (w * h)
    comps = []
    for y in range(h):
        for x in range(w):
            if data[x, y] == 0 or label[y * w + x]:
                continue
            cid = len(comps) + 1
            q = deque([(x, y)])
            label[y * w + x] = cid
            xs = ys = n = 0
            x0, y0, x1, y1 = x, y, x, y
            pts = []
            while q:
                cx, cy = q.popleft()
                pts.append((cx, cy))
                n += 1; xs += cx; ys += cy
                x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and data[nx, ny] and not label[ny * w + nx]:
                            label[ny * w + nx] = cid
                            q.append((nx, ny))
            comps.append({"n": n, "cx": xs / n, "cy": ys / n, "box": (x0, y0, x1 + 1, y1 + 1), "pts": pts})
    return [c for c in comps if c["n"] >= min_size]


def split_frames(im: Image.Image, count: int):
    """Uma imagem por célula (mesmo tamanho da folha), com os componentes da célula."""
    cell_w = im.width / count
    frames = [Image.new("RGBA", im.size) for _ in range(count)]
    src = im.load()
    for comp in components(im):
        k = min(count - 1, max(0, int(comp["cx"] // cell_w)))
        dst = frames[k].load()
        for x, y in comp["pts"]:
            dst[x, y] = src[x, y]
    return frames, cell_w


def head_width(frame: Image.Image):
    bb = frame.getbbox()
    if not bb:
        return 0
    h = bb[3] - bb[1]
    band = frame.crop((bb[0], bb[1] + int(h * 0.06), bb[2], bb[1] + int(h * 0.16))).getbbox()
    return (band[2] - band[0]) if band else 0


def torso_x(frame: Image.Image):
    """Coluna média dos pixels na faixa do tronco (para alinhar a folha ao centro)."""
    bb = frame.getbbox()
    h = bb[3] - bb[1]
    band = frame.crop((bb[0], bb[1] + int(h * 0.30), bb[2], bb[1] + int(h * 0.62)))
    a = band.getchannel("A").load()
    xs = [x for y in range(band.height) for x in range(band.width) if a[x, y]]
    xs.sort()
    return bb[0] + xs[len(xs) // 2] if xs else (bb[0] + bb[2]) / 2


def downscale(frame: Image.Image, factor: float) -> Image.Image:
    w, h = max(1, round(frame.width * factor)), max(1, round(frame.height * factor))
    return binarize(frame.convert("RGBa").resize((w, h), Image.BOX).convert("RGBA"))


def drop_specks(cell: Image.Image, keep_min=14) -> Image.Image:
    """Depois da redução: apaga fragmentos soltos (sobras do recorte) menores que keep_min px."""
    cleaned = cell.copy()
    px = cleaned.load()
    for comp in components(cell, min_size=1):
        if comp["n"] < keep_min:
            for x, y in comp["pts"]:
                px[x, y] = (0, 0, 0, 0)
    return cleaned


def hand_anchor(cell: Image.Image, baseline: int):
    """Ponto mais à frente (direita) na altura do peito: onde a arma é empunhada."""
    a = cell.getchannel("A").load()
    best = None
    for y in range(baseline - 72, baseline - 40):
        for x in range(cell.width - 1, -1, -1):
            if a[x, y]:
                if best is None or x > best[0]:
                    best = (x, y)
                break
    return best


def build_set(cfg: dict, source: Path, preview: Path | None):
    cw, ch = cfg["cell"]
    out_dir = ROOT / "assets/players" / cfg["character"] / cfg["set"]
    out_dir.mkdir(parents=True, exist_ok=True)
    processed = {}
    sources = {}
    for name, sheet in cfg["sheets"].items():
        path = source / sheet["file"]
        sources[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        im = binarize(remove_background(Image.open(path)))
        frames, cell_w = split_frames(im, sheet["frames"])
        picks = sheet.get("head") or range(len(frames))
        widths = sorted(head_width(frames[i]) for i in picks if frames[i].getbbox())
        factor = cfg["head_target"] / widths[len(widths) // 2]
        # deslocamento horizontal constante por folha: média do tronco relativo à célula
        offsets = [torso_x(f) - (k + 0.5) * cell_w for k, f in enumerate(frames) if f.getbbox()]
        offsets.sort()
        sheet_offset = offsets[len(offsets) // 2]
        ground = max(f.getbbox()[3] for f in frames if f.getbbox())
        processed[name] = (frames, cell_w, factor, sheet_offset, ground)
    # paleta única do personagem (a partir das folhas já reduzidas)
    reduced = {}
    for name, (frames, cell_w, factor, sheet_offset, ground) in processed.items():
        mode = cfg["sheets"][name]["mode"]
        cells = []
        for k, frame in enumerate(frames):
            cell = Image.new("RGBA", (cw, ch))
            bb = frame.getbbox()
            if bb:
                small = downscale(frame.crop(bb), factor)
                anchor_x = (k + 0.5) * cell_w + sheet_offset
                x = round(cw / 2 + (bb[0] - anchor_x) * factor)
                if mode == "air" or (mode == "jump" and k >= 3):
                    y = round(ch - 1 - 47 - small.height / 2)          # centro do corpo
                elif mode == "land":
                    y = ch - small.height                               # pés no chão quadro a quadro
                else:
                    y = round(ch - (ground - bb[1]) * factor)
                cell.alpha_composite(small, (max(0, min(cw - small.width, x)), max(0, min(ch - small.height, y))))
            cells.append(drop_specks(cell))
        reduced[name] = cells
    strip = Image.new("RGBA", (cw * 8, ch * len(reduced)))
    for row, cells in enumerate(reduced.values()):
        for k, cell in enumerate(cells):
            strip.alpha_composite(cell, (k * cw, row * ch))
    palette_src = strip.convert("RGB").quantize(colors=cfg["palette"], method=Image.Quantize.MEDIANCUT)
    meta = {}
    for name, cells in reduced.items():
        sheet = Image.new("RGBA", (cw * len(cells), ch))
        hands = []
        for k, cell in enumerate(cells):
            alpha = cell.getchannel("A")
            rgb = cell.convert("RGB").quantize(palette=palette_src, dither=Image.Dither.NONE).convert("RGB")
            final = Image.merge("RGBA", (*rgb.split(), alpha))
            sheet.alpha_composite(final, (k * cw, 0))
            if cfg["sheets"][name].get("hand"):
                hand = hand_anchor(final, ch - 1)
                hands.append((hand[0] - cw / 2, hand[1] - ch / 2) if hand else None)
        file = "%s_%s.png" % (cfg["character"], name)
        sheet.save(out_dir / file, optimize=True)
        s = cfg["sheets"][name]
        meta[name] = {"file": file, "frames": len(cells), "fps": s["fps"], "loop": s["loop"], "hands": hands,
                      "scale_from_source": round(processed[name][2], 4), "source_sha256": sources[name]}
    if preview is not None:
        preview.mkdir(parents=True, exist_ok=True)
        board = Image.new("RGBA", (cw * 8, ch * len(meta)), (34, 40, 54, 255))
        for row, name in enumerate(meta):
            board.alpha_composite(Image.open(out_dir / meta[name]["file"]), (0, row * ch))
            for k in range(8):
                board.paste((255, 80, 80, 255), (k * cw, row * ch + ch - 1, k * cw + cw, row * ch + ch))
        board.resize((board.width * 2, board.height * 2), Image.NEAREST).save(preview / ("%s_%s_board.png" % (cfg["character"], cfg["set"])))
    return meta


def write_gd(all_meta: list[tuple[dict, dict]]):
    lines = [
        "extends RefCounted",
        "## GERADO por tools/visual/character_sheet_import.py — não editar à mão.",
        "## Conjuntos de animação por personagem: células com os pés na última linha, exibidas",
        "## na escala indicada; hands = âncora da mão por quadro (relativa ao centro da célula,",
        "## olhando para a direita) para armas desenhadas separadamente do corpo.",
        "",
        "const SETS := {",
    ]
    for cfg, meta in all_meta:
        cw, ch = cfg["cell"]
        lines.append('\t&"%s": {' % cfg["character"])
        lines.append('\t\t"dir": "res://assets/players/%s/%s/",' % (cfg["character"], cfg["set"]))
        lines.append('\t\t"scale": 1.0,')
        lines.append('\t\t"cell": Vector2(%d, %d),' % (cw, ch))
        lines.append('\t\t"anims": {')
        for name, m in meta.items():
            hands = ", ".join("Vector2(%.1f, %.1f)" % h if h else "Vector2.ZERO" for h in m["hands"])
            lines.append('\t\t\t&"%s": {"file": "%s", "frames": %d, "fps": %.1f, "loop": %s, "hands": [%s]},'
                         % (name, m["file"], m["frames"], m["fps"], "true" if m["loop"] else "false", hands))
        lines.append("\t\t},")
        rejected = cfg.get("rejected", {})
        lines.append('\t\t"rejected": [%s],' % ", ".join('&"%s"' % r for r in rejected))
        lines.append("\t},")
    lines.append("}")
    (ROOT / "entities/character_animation_sets.gd").write_text("\n".join(lines) + "\n")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    source = Path(sys.argv[1])
    preview = Path(sys.argv[sys.argv.index("--preview") + 1]) if "--preview" in sys.argv else None
    all_meta = []
    report = []
    for cfg in SETS:
        meta = build_set(cfg, source, preview)
        all_meta.append((cfg, meta))
        for name, m in meta.items():
            report.append("%s %s: %d quadros, escala %.4f, fonte sha256 %s" % (cfg["character"], name, m["frames"], m["scale_from_source"], m["source_sha256"][:16]))
        for name, (file, why) in cfg.get("rejected", {}).items():
            report.append("%s %s: NÃO integrado (%s: %s)" % (cfg["character"], name, file, why))
    write_gd(all_meta)
    print("\n".join(report))


if __name__ == "__main__":
    main()
