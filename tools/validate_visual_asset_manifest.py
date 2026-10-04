"""Offline import gate, Python stdlib only. Never runs in Godot or rewrites assets."""
import argparse
import hashlib
import json
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATEGORIES = {"characters", "enemies", "weapons", "projectiles", "biomes", "hub",
              "props", "interactables", "ui", "portraits", "effects", "backgrounds"}


def png_info(path):
    """Verify PNG chunks and decode RGBA8 rows to confirm actual transparency."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    offset, compressed, header = 8, bytearray(), None
    ended = False
    while offset + 12 <= len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        end = offset + 12 + length
        if end > len(data) or zlib.crc32(kind + payload) != struct.unpack_from(">I", data, end - 4)[0]:
            raise ValueError("truncated PNG or invalid CRC")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            ended = True
            break
        offset = end
    if header is None or not ended:
        raise ValueError("missing PNG header/end")
    width, height, bits, color, compression, filtering, interlace = header
    if bits != 8 or color != 6 or compression or filtering or interlace:
        raise ValueError("technical master must be noninterlaced 8-bit RGBA PNG")
    if not 0 < width <= 16384 or not 0 < height <= 16384 or width * height > 67108864:
        raise ValueError("invalid or excessive PNG dimensions")
    rows = zlib.decompress(compressed)
    stride = width * 4
    if len(rows) != (stride + 1) * height:
        raise ValueError("invalid PNG decoded length")
    previous = bytearray(stride)
    transparent = False
    for y in range(height):
        start = y * (stride + 1)
        filter_type = rows[start]
        row = bytearray(rows[start + 1:start + 1 + stride])
        if filter_type not in range(5):
            raise ValueError("invalid PNG filter")
        for x in range(stride):
            a = row[x - 4] if x >= 4 else 0
            b = previous[x]
            c = previous[x - 4] if x >= 4 else 0
            if filter_type == 1:
                predictor = a
            elif filter_type == 2:
                predictor = b
            elif filter_type == 3:
                predictor = (a + b) // 2
            elif filter_type == 4:
                p = a + b - c
                distances = (abs(p - a), abs(p - b), abs(p - c))
                predictor = (a, b, c)[distances.index(min(distances))]
            else:
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        transparent = transparent or any(alpha < 255 for alpha in row[3::4])
        previous = row
    return width, height, transparent


def validate(manifest, root=ROOT):
    errors, seen = [], set()
    assets = manifest.get("assets") if isinstance(manifest, dict) else None
    if not isinstance(assets, list) or not assets:
        return ["manifest requires a nonempty assets array"]
    for index, item in enumerate(assets):
        prefix = f"assets[{index}]"
        try:
            if not isinstance(item, dict):
                raise ValueError("entry must be an object")
            id = item.get("id", "")
            if not isinstance(id, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", id) or id in seen:
                raise ValueError("invalid or duplicate stable technical ID")
            seen.add(id)
            if item.get("category") not in CATEGORIES:
                raise ValueError("unknown category")
            if item.get("stage") != "runtime" or item.get("runtime_approved") is not True:
                raise ValueError("concept/technical masters require explicit runtime approval")
            for field in ("source", "version", "intended_runtime_use"):
                if not isinstance(item.get(field), str) or not item[field].strip():
                    raise ValueError(f"missing {field}")
            relative = item.get("path", "").removeprefix("res://")
            path = (root / relative).resolve()
            if not path.is_relative_to((root / "assets").resolve()) or path.suffix.lower() != ".png":
                raise ValueError("runtime PNG must be inside project assets/")
            width, height, alpha = png_info(path)
            if item.get("dimensions") != [width, height]:
                raise ValueError("declared dimensions differ from PNG")
            if not isinstance(item.get("requires_transparency"), bool):
                raise ValueError("requires_transparency must be explicit")
            if item["requires_transparency"] and not alpha:
                raise ValueError("RGBA channel exists but contains no transparency")
            for approval in ("no_embedded_text", "no_concept_border", "no_accidental_matte"):
                if item.get(approval) is not True:
                    raise ValueError(f"human visual review must confirm {approval}")
            if "frame_count" in item or item["category"] in {"characters", "enemies", "projectiles"}:
                count, cell = item.get("frame_count"), item.get("cell_size")
                if type(count) is not int or count < 1 or not isinstance(cell, list) or len(cell) != 2:
                    raise ValueError("explicit frame_count and cell_size required")
                if any(type(n) is not int or n <= 0 for n in cell):
                    raise ValueError("invalid cell_size")
                if width % cell[0] or height % cell[1] or count > (width // cell[0]) * (height // cell[1]):
                    raise ValueError("sheet dimensions/count do not fit consistent cells")
            if item["category"] in {"characters", "enemies", "weapons", "props", "projectiles", "interactables"}:
                pivot = item.get("pivot")
                if not isinstance(pivot, list) or len(pivot) != 2 or any(type(n) not in (int, float) for n in pivot):
                    raise ValueError("explicit numeric pixel pivot required")
                if item.get("facing") not in {"left", "right", "front", "none"}:
                    raise ValueError("explicit facing required")
            if item["category"] in {"characters", "enemies"} and type(item.get("baseline")) not in (int, float):
                raise ValueError("explicit pixel baseline required")
            if item["category"] in {"weapons", "props"}:
                if not item.get("anchor") or type(item.get("world_scale")) not in (int, float) or item["world_scale"] <= 0:
                    raise ValueError("anchor and positive world_scale required")
            if item["category"] == "ui":
                safe, padding = item.get("safe_bounds"), item.get("padding")
                if not isinstance(safe, list) or len(safe) != 4 or not isinstance(padding, list) or len(padding) != 4:
                    raise ValueError("UI safe_bounds [x,y,w,h] and padding [l,t,r,b] required")
                if any(type(n) not in (int, float) or n < 0 for n in safe + padding) or safe[0] + safe[2] > width or safe[1] + safe[3] > height:
                    raise ValueError("invalid UI safe_bounds/padding")
            if item.get("sha256") and hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
                raise ValueError("checksum mismatch")
        except (ValueError, OSError, TypeError, AttributeError, struct.error, zlib.error) as error:
            errors.append(f"{prefix}: {error}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        errors = validate(json.loads(args.manifest.read_text(encoding="utf-8-sig")))
    except (OSError, ValueError) as error:
        errors = [str(error)]
    for error in errors:
        print(error)
    if not errors:
        print("VISUAL_ASSET_MANIFEST_OK (human review declarations still require inspection)")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
