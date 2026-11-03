#!/usr/bin/env python3
"""Read-only audit of tracked assets. A missing literal reference never authorizes deletion."""
import argparse
import hashlib
import json
from collections import defaultdict
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def audit():
    names = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    sources = []
    for name in names:
        path = ROOT / name
        if path.is_file() and not name.startswith(("docs/", "tests/", "tools/")) and path.suffix in {".gd", ".tscn", ".tres", ".godot", ".json", ".cfg"}:
            sources.append((name, path.read_text(errors="replace")))
    groups = defaultdict(list)
    entries = []
    for name in names:
        path = ROOT / name
        if not name.startswith("assets/") or not path.is_file() or path.suffix in {".import", ".uid"}:
            continue
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        groups[digest].append(name)
        references = [source for source, text in sources if name in text]
        entries.append({"path": name, "bytes": len(data), "sha256": digest,
                        "classification": "em_uso_referencia_literal" if references else "uso_incerto_dinamico_ou_artistico",
                        "runtime_literal_references": references, "removed": False})
    duplicates = [paths for paths in groups.values() if len(paths) > 1]
    return {"scope": "tracked assets only; private untracked assets excluded", "tracked_asset_count": len(entries),
            "total_bytes": sum(entry["bytes"] for entry in entries), "duplicate_content_groups": duplicates,
            "deletions": [], "assets": entries}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps({key: value for key, value in result.items() if key != "assets"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
