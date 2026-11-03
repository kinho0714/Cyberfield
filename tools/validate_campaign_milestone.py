#!/usr/bin/env python3
"""Read-only repository checks; GDScript runtime checks require an actual Godot."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = sorted((ROOT / "scene/persistence").glob("*.gd")) + sorted((ROOT / "scene/world").glob("*.gd")) + sorted((ROOT / "scene/social").glob("*.gd")) + [
    ROOT / "scene/network/private_session_client.gd",
    ROOT / "scene/network/private_gameplay_bridge.gd", ROOT / "scene/network/gameplay_wire.gd",
    ROOT / "scene/missions/mission_ledger.gd", ROOT / "scene/combat/dash_sequence.gd",
    ROOT / "tests/dash_sequence_smoke_test.gd", ROOT / "tests/gameplay_progression_smoke_test.gd",
    ROOT / "tests/enemy_interruption_smoke_test.gd", ROOT / "tests/gameplay_wire_smoke_test.gd",
    ROOT / "tests/world_persistence_smoke_test.gd", ROOT / "tests/region_routes_smoke_test.gd",
    ROOT / "tests/local_profile_smoke_test.gd", ROOT / "tests/private_transport_smoke_test.gd",
] + [ROOT / p for p in (
        "scene/room_manager.gd", "scene/meta_progression.gd", "scene/dev/dev_mode.gd",
        "tests/campaign_store_smoke_test.gd", "tests/campaign_session_smoke_test.gd",
    )
]
results = []


def result(name, status, detail=""):
    results.append({"check": name, "status": status, "detail": detail})


baseline = json.loads((ROOT / "docs/mundo_saves/private_files_baseline.json").read_text())
for name, digest in baseline.items():
    actual = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
    tracked = subprocess.run(["git", "ls-files", "--error-unmatch", "--", name], cwd=ROOT,
                             capture_output=True).returncode == 0
    result("private_asset:" + name, "PASS" if actual == digest and not tracked else "FAIL")

try:
    from gdtoolkit.parser import parser
except ImportError:
    result("GDScript grammar", "UNAVAILABLE", "Install gdtoolkit outside the repository")
else:
    # gdtoolkit's Android cache fallback is cwd. Keep all its artifacts in temp.
    original_cwd = Path.cwd()
    with tempfile.TemporaryDirectory(prefix="cyberfield_parser_") as temporary:
        os.chdir(temporary)
        parser._cache_dirpath = str(Path(temporary) / "cache")
        try:
            for path in SCRIPTS:
                try:
                    parser.parse(path.read_text())
                    result("grammar:" + str(path.relative_to(ROOT)), "PASS")
                except Exception as error:
                    result("grammar:" + str(path.relative_to(ROOT)), "FAIL", str(error))
        finally:
            os.chdir(original_cwd)

for script in ("mega_pass_priority1_static_test.py", "pass6_hotfix2_static_test.py", "menu_pass6_static_test.py"):
    completed = subprocess.run([sys.executable, "-B", str(ROOT / "tests" / script)], cwd=ROOT,
                               capture_output=True, text=True)
    output = completed.stdout + completed.stderr
    status = "PASS" if completed.returncode == 0 else "UNAVAILABLE" if "No module named 'PIL'" in output else "FAIL"
    result(script, status, output.strip())

completed = subprocess.run(["git", "diff", "--check"], cwd=ROOT, capture_output=True, text=True)
result("git diff --check", "PASS" if completed.returncode == 0 else "FAIL", completed.stdout + completed.stderr)
# This script checks grammar/regressions only. Runtime evidence is produced by
# validate_integrated_expansion.py and private_relay_test.py, not inferred here.
result("Godot runtime", "NOT_RUN_BY_THIS_SCRIPT", "See expansion engine logs; grammar is not compilation")
result("Android physical tests", "PENDING", "suspension, kill/reopen, touch, storage failure")
print(json.dumps(results, indent=2, ensure_ascii=False))
sys.exit(1 if any(r["status"] == "FAIL" for r in results) else 0)
