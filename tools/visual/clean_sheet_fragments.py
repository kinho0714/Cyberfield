"""Remove crop leakage from sprite sheets, one reviewed fragment at a time.

Some sheets were cut from larger generated sources and kept slivers of the
neighbouring pose (a hand, half a torso, a 1 px guide line) at cell edges. Each entry
below names one connected fragment by (min_x, min_y, pixel_count); the tool erases
exactly that component and nothing else, and refuses to run if the sheet no longer
matches (so it is safe to re-run). Effect particles are intentionally NOT listed.

    python3 -I tools/visual/clean_sheet_fragments.py [--check]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repack_wall_slide import components  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
# Reviewed 30/10/2026 against zoomed sheets (docs/AUDITORIA_VISUAL_2026-10-30.md).
LEAKS = {
    "assets/players/jhon/jhon_v2_idle_v2.png": [(158, 33, 14)],
    "assets/players/jhon/jhon_v2_walk_run_v2.png": [
        (232, 40, 11), (304, 11, 12), (304, 35, 42), (304, 57, 24),
        (369, 11, 25), (369, 24, 3), (369, 30, 72), (369, 59, 23),
    ],
    "assets/players/jhon/jhon_v2_hurt_v2.png": [(60, 21, 217), (60, 53, 115), (143, 5, 60)],
    "assets/players/jhon/jhon_v2_wall_climb_v2.png": [(54, 17, 12)],
}


def clean(path: Path, leaks: list[tuple[int, int, int]]) -> tuple[Image.Image, int]:
    image = Image.open(path).convert("RGBA")
    index = {}
    for part in components(image.getchannel("A")):
        key = (min(x for x, _ in part), min(y for _, y in part), len(part))
        index[key] = part
    px = image.load()
    removed = 0
    for leak in leaks:
        part = index.get(leak)
        if part is None:
            continue  # already cleaned
        for x, y in part:
            px[x, y] = (0, 0, 0, 0)
        # Near-invisible antialias residue of the same sliver (alpha <= 16) goes too.
        x0, x1 = min(x for x, _ in part) - 2, max(x for x, _ in part) + 2
        y0, y1 = min(y for _, y in part) - 2, max(y for _, y in part) + 2
        for y in range(max(y0, 0), min(y1 + 1, image.height)):
            for x in range(max(x0, 0), min(x1 + 1, image.width)):
                if 0 < px[x, y][3] <= 16:
                    px[x, y] = (0, 0, 0, 0)
        removed += 1
    return image, removed


def main() -> None:
    check = "--check" in sys.argv
    for relative, leaks in LEAKS.items():
        image, removed = clean(ROOT / relative, leaks)
        if check:
            print(relative, f"{removed} pending" if removed else "clean")
        elif removed:
            image.save(ROOT / relative, optimize=True)
            print(f"cleaned {removed}/{len(leaks)}", relative)
        else:
            print("already clean", relative)


if __name__ == "__main__":
    main()
