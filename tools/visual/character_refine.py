"""Cyberfield playable characters — presentation refinement (Alpha 0.5.0, dev/visual).

Rebuilds the player sheets in place from the Alpha 0.5.0 originals (git tag alpha-0.5.0),
so it is idempotent. Same files, same sizes, same frame counts: the game loads them through
entities/player_character_visual.gd exactly as before.

Per frame (cell = sheet width / frame count used by the game):
  1. cleanup  — drops slicing leftovers: specks and slivers that touch the cell's side
                edges, tiny far-away specks, baked text labels and stray vertical lines.
                Large or attached effects (dash streaks, slam bursts, sparks) stay.
  2. shadow   — removes the baked ground ellipse some idle sheets carry (the game draws
                no shadow elsewhere, so it popped on and off between states).
  3. rim      — 1px neon rim on the top/back silhouette edge in the character's accent,
                so dark clothing reads against the dark Alpha 0.5.0 scenery.
  4. downed   — lying frames are drawn ~1.6x larger than the standing body; they are
                reduced to standing proportions (mode-preserving resample) and re-seated
                on the floor row.

    python3 -I tools/visual/character_refine.py [--report] [--preview DIR] [character ...]
"""
from __future__ import annotations

import io
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE_REV = "alpha-0.5.0"
ACCENT = {
    "jhon": (79, 214, 255),     # ice cyan — his dash/slam effects
    "jackson": (255, 150, 64),  # amber — his coat and effects
    "kai": (64, 242, 190),      # teal — his jacket trims
    "spark": (255, 214, 72),    # electric yellow — the robot's charge
}
# Frame counts mirror PlayerCharacterVisual._build_definitions.
FRAMES = {"idle": 4, "walk_run": 6, "jump_air_fall": 4, "attack_combo": 6, "dash": 4, "ground_slam": 5,
          "hurt": 2, "downed_death": 3, "revive_ally": 5, "wall_slide": 4, "wall_climb": 4}
RIM_STRENGTH = 0.55


def frame_count(character: str, path: Path) -> int:
    key = next(k for k in FRAMES if k in path.name)
    if key == "attack_combo" and character == "jhon":
        return 5
    return FRAMES[key]


def original(path: Path) -> Image.Image:
    rel = path.relative_to(ROOT).as_posix()
    data = subprocess.run(["git", "-C", str(ROOT), "show", f"{SOURCE_REV}:{rel}"], capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(data)).convert("RGBA")


# ------------------------------------------------------------------ components
def components(mask: np.ndarray):
    """8-connected components: list of (ys, xs) index arrays, largest first."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    found = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        ys, xs = [], []
        while stack:
            y, x = stack.pop()
            ys.append(y)
            xs.append(x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
        found.append((np.array(ys), np.array(xs)))
    found.sort(key=lambda c: -len(c[0]))
    return found


def distance_field(mask: np.ndarray, limit: int = 24) -> np.ndarray:
    """Chebyshev distance (in pixels, capped) from every pixel to the mask."""
    field = np.full(mask.shape, limit, dtype=np.int32)
    grown = mask.copy()
    field[grown] = 0
    for step in range(1, limit):
        nxt = grown.copy()
        nxt[1:] |= grown[:-1]
        nxt[:-1] |= grown[1:]
        nxt[:, 1:] |= nxt[:, :-1].copy()
        nxt[:, :-1] |= nxt[:, 1:].copy()
        field[nxt & ~grown] = step
        grown = nxt
    return field


def bbox_gap(a, b) -> float:
    ay0, ay1, ax0, ax1 = a[0].min(), a[0].max(), a[1].min(), a[1].max()
    by0, by1, bx0, bx1 = b[0].min(), b[0].max(), b[1].min(), b[1].max()
    dx = max(0, max(ax0, bx0) - min(ax1, bx1))
    dy = max(0, max(ay0, by0) - min(ay1, by1))
    return float(max(dx, dy))


def cleanup(cell: np.ndarray) -> tuple[np.ndarray, int]:
    alpha = cell[:, :, 3] > 0
    comps = components(alpha)
    if not comps:
        return cell, 0
    main = comps[0]
    h, w = alpha.shape
    main_mask = np.zeros_like(alpha)
    main_mask[main] = True
    field = distance_field(main_mask)
    removed = 0
    for comp in comps[1:]:
        ys, xs = comp
        area = len(ys)
        gap = float(field[ys, xs].min()) - 1.0
        width, height = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        rgb = cell[ys, xs, :3].astype(float)
        saturation = float(np.mean(rgb.max(axis=1) - rgb.min(axis=1)))
        edge = xs.min() <= 12 or xs.max() >= w - 15
        label = saturation < 40 and (ys.max() < 12 or ys.min() > h - 10) and gap > 4
        line = width <= 2 and height >= 14 and gap > 6
        speck = area < 10 and gap > 14
        sliver = edge and area < 200 and gap > 3
        crown = ys.max() < 6 and area < 30 and gap > 2      # dashes above the head
        if label or line or speck or sliver or crown:
            cell[ys, xs, 3] = 0
            removed += area
    return cell, removed


def drop_ground_shadow(cell: np.ndarray, floor_row: int) -> np.ndarray:
    # The baked puddle: light-blue rows under the boots (the game now draws one contact
    # shadow for every state). Boot pixels are dark and stay.
    band = cell[max(0, floor_row - 2):floor_row + 1]
    rgb = band[:, :, :3].astype(int)
    shadowy = (band[:, :, 3] > 0) & (rgb[:, :, 2] >= 90) & (rgb[:, :, 2] - rgb[:, :, 0] >= 40)
    shadowy |= (band[:, :, 3] > 0) & (band[:, :, 3] < 160)
    band[shadowy, 3] = 0
    return cell


def rim(cell: np.ndarray, accent) -> np.ndarray:
    alpha = cell[:, :, 3] > 127
    up = np.zeros_like(alpha)
    up[1:] = alpha[:-1]
    back = np.zeros_like(alpha)
    back[:, 1:] = alpha[:, :-1]
    edge = alpha & (~up | ~back)            # pixels lit from above or from behind (left)
    colour = np.array(accent, dtype=float)
    rgb = cell[:, :, :3].astype(float)
    rgb[edge] = rgb[edge] * (1.0 - RIM_STRENGTH) + colour * RIM_STRENGTH
    cell[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return cell


def resample_mode(cell: np.ndarray, factor: float) -> np.ndarray:
    """Pixel-art reduction: each target pixel takes the most common opaque source colour."""
    h, w = cell.shape[:2]
    th, tw = max(1, round(h * factor)), max(1, round(w * factor))
    out = np.zeros((th, tw, 4), dtype=np.uint8)
    for ty in range(th):
        y0, y1 = int(ty / factor), max(int(ty / factor) + 1, int((ty + 1) / factor))
        for tx in range(tw):
            x0, x1 = int(tx / factor), max(int(tx / factor) + 1, int((tx + 1) / factor))
            block = cell[y0:y1, x0:x1].reshape(-1, 4)
            opaque = block[block[:, 3] > 127]
            if len(opaque) * 2 < len(block):
                continue
            colours, counts = np.unique(opaque, axis=0, return_counts=True)
            out[ty, tx] = colours[np.argmax(counts)]
    return out


def body_height(sheet: np.ndarray, frames: int) -> int:
    cw = sheet.shape[1] // frames
    heights = []
    for i in range(frames):
        comps = components(sheet[:, i * cw:(i + 1) * cw, 3] > 0)
        if comps:
            heights.append(int(comps[0][0].max() - comps[0][0].min() + 1))
    return int(np.median(heights)) if heights else 0


def floor_row(cell: np.ndarray) -> int:
    rows = np.nonzero((cell[:, :, 3] > 0).any(axis=1))[0]
    return int(rows.max()) if len(rows) else cell.shape[0] - 1


def refine_downed(cell: np.ndarray, standing_height: int) -> np.ndarray:
    comps = components(cell[:, :, 3] > 0)
    if not comps:
        return cell
    ys, xs = comps[0]
    length = xs.max() - xs.min() + 1
    tall = ys.max() - ys.min() + 1
    if length <= tall or standing_height <= 0:
        return cell                         # standing/kneeling frame: untouched
    factor = min(1.0, standing_height * 1.05 / length)
    if factor > 0.92:
        return cell
    floor = floor_row(cell)
    small = resample_mode(cell, factor)
    out = np.zeros_like(cell)
    sh, sw = small.shape[:2]
    sfloor = floor_row(small)
    oy = floor - sfloor
    ox = (cell.shape[1] - sw) // 2
    out[max(0, oy):oy + sh, ox:ox + sw] = small[max(0, -oy):]
    return out


def refine_sheet(character: str, path: Path, standing_height: int, report: list) -> Image.Image:
    sheet = np.array(original(path))
    frames = frame_count(character, path)
    cw = sheet.shape[1] // frames
    removed_total = 0
    for i in range(frames):
        cell = sheet[:, i * cw:(i + 1) * cw].copy()
        cell, removed = cleanup(cell)
        removed_total += removed
        if "idle" in path.name:
            seated = floor_row(cell)
            cell = drop_ground_shadow(cell, seated)
            drop = seated - floor_row(cell)       # keep the boots on the floor line
            if 0 < drop <= 4:
                cell = np.roll(cell, drop, axis=0)
        if "downed" in path.name:
            cell = refine_downed(cell, standing_height)
        cell = rim(cell, ACCENT[character])
        sheet[:, i * cw:(i + 1) * cw] = cell
    report.append(f"{path.name}: {frames}x{cw}px, {removed_total} stray px removed")
    return Image.fromarray(sheet, "RGBA")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    preview = None
    if "--preview" in sys.argv:
        preview = Path(sys.argv[sys.argv.index("--preview") + 1])
        args = [a for a in args if a != str(preview)]
    characters = args or list(ACCENT)
    for character in characters:
        folder = ROOT / "assets/players" / character
        sheets = sorted(folder.glob("*.png"))
        idle = next(p for p in sheets if "idle" in p.name)
        standing = body_height(np.array(original(idle)), 4)
        report: list[str] = []
        refined = {p: refine_sheet(character, p, standing, report) for p in sheets}
        if "--report" in sys.argv:
            print(character, "standing height", standing)
            print("  " + "\n  ".join(report))
        if "--dry-run" not in sys.argv:
            for p, im in refined.items():
                im.save(p, optimize=True)
        if preview is not None:
            preview.mkdir(parents=True, exist_ok=True)
            rows = []
            for p in sheets:
                before, after = original(p), refined[p]
                pair = Image.new("RGBA", (before.width * 2 + 8, 72), (40, 30, 60, 255))
                pair.alpha_composite(before, (0, 0))
                pair.alpha_composite(after, (before.width + 8, 0))
                rows.append(pair.resize((pair.width * 3, 216), Image.NEAREST))
            board = Image.new("RGBA", (max(r.width for r in rows), 220 * len(rows)), (24, 18, 36, 255))
            for i, r in enumerate(rows):
                board.alpha_composite(r, (0, i * 220))
            board.save(preview / f"{character}_before_after.png")
    print("ok", ", ".join(characters))


if __name__ == "__main__":
    main()
