"""Repack the wall-slide sheets so each 4-frame cell holds one whole pose.

The source sheets hold 2-3 poses at irregular x positions, but the game slices them
into 4 equal cells (PlayerCharacterVisual: wall_slide = 4 frames), so frames showed
half bodies and, for Jhon, a frame with only a stray 1 px line. This keeps every pose
pixel-identical: it only moves whole poses into centred cells, drops specks that are
not part of a pose, and keeps sheet size and vertical placement unchanged.

    python3 -I tools/visual/repack_wall_slide.py [--check]
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEETS = {
    "jhon": "assets/players/jhon/jhon_v2_wall_slide_v2.png",
    "jackson": "assets/players/jackson/jackson_wall_slide_v1.png",
    "kai": "assets/players/kai/kai_wall_slide_v1.png",
    "spark": "assets/players/spark/spark_wall_slide_v1.png",
}
FRAMES = 4
ALPHA_MIN = 16
POSE_MIN_PIXELS = 200  # anything smaller is a speck, not a body


def components(alpha: Image.Image) -> list[set[tuple[int, int]]]:
    w, h = alpha.size
    px = alpha.load()
    seen: set[tuple[int, int]] = set()
    found = []
    for y in range(h):
        for x in range(w):
            if px[x, y] <= ALPHA_MIN or (x, y) in seen:
                continue
            stack, group = [(x, y)], set()
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                group.add((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny] > ALPHA_MIN:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            found.append(group)
    return found


def poses(image: Image.Image) -> list[tuple[int, int, set]]:
    """Large components are bodies; small ones join a body they overlap on x."""
    parts = components(image.getchannel("A"))
    bodies = [p for p in parts if len(p) >= POSE_MIN_PIXELS]
    result = []
    for body in sorted(bodies, key=lambda p: min(x for x, _ in p)):
        result.append([min(x for x, _ in body), max(x for x, _ in body), set(body)])
    for part in parts:
        if len(part) >= POSE_MIN_PIXELS:
            continue
        x0, x1 = min(x for x, _ in part), max(x for x, _ in part)
        for pose in result:
            if x0 <= pose[1] + 2 and x1 >= pose[0] - 2:  # touches the pose column: effect detail
                pose[2] |= part
                pose[0], pose[1] = min(pose[0], x0), max(pose[1], x1)
                break
        # else: an isolated speck between poses; dropped on purpose
    return [tuple(p) for p in result]


def repack(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    w, h = source.size
    cell = w // FRAMES
    found = poses(source)
    if len(found) == FRAMES and all(x0 // cell == x1 // cell == i for i, (x0, x1, _) in enumerate(found)):
        return source  # already one pose per cell: idempotent
    if len(found) not in (2, 3):
        raise SystemExit(f"{path}: expected 2 or 3 poses, found {len(found)}")
    order = [0, 1, 0, 1] if len(found) == 2 else [0, 1, 2, 1]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src = source.load()
    dst = out.load()
    for frame, pose_index in enumerate(order):
        x0, x1, pixels = found[pose_index]
        width = x1 - x0 + 1
        if width > cell:
            raise SystemExit(f"{path}: pose {pose_index} is {width}px, wider than the {cell}px cell")
        shift = frame * cell + (cell - width) // 2 - x0
        for x, y in pixels:
            dst[x + shift, y] = src[x, y]
    return out


def main() -> None:
    check = "--check" in sys.argv
    for name, relative in SHEETS.items():
        path = ROOT / relative
        result = repack(path)
        if check:
            print(name, "would change" if result.tobytes() != Image.open(path).convert("RGBA").tobytes() else "ok")
        else:
            result.save(path, optimize=True)
            print("repacked", relative)


if __name__ == "__main__":
    main()
