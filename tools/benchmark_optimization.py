#!/usr/bin/env python3
"""Paired CPU/headless benchmarks against frozen isolated copies; never gameplay FPS."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MARKER = "OPTIMIZATION_BENCHMARK "


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repetitions", type=int, default=3, choices=range(1, 6))
    args = parser.parse_args()
    if any(path.resolve() == ROOT for path in (args.before, args.after)) or args.before.resolve() == args.after.resolve():
        parser.error("Two distinct isolated copies are required")
    harnesses = [path / "tests/optimization_benchmark.gd" for path in (args.before, args.after)]
    if not all(path.exists() for path in harnesses) or len({hashlib.sha256(path.read_bytes()).hexdigest() for path in harnesses}) != 1:
        parser.error("Both copies must contain the identical benchmark harness")
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for iteration in range(args.repetitions):
        cases = [("before", args.before), ("after", args.after)]
        if iteration % 2:
            cases.reverse()
        for label, project in cases:
            log_path = args.output / f"{label}-{iteration + 1}.log"
            with log_path.open("w") as stream:
                process = subprocess.Popen([args.godot, "--headless", "--path", str(project), "--script", "res://tests/optimization_benchmark.gd"],
                                           stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
                try:
                    process.wait(timeout=180)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                    raise SystemExit(f"Benchmark timeout: {log_path}")
            log = log_path.read_text(errors="replace")
            lines = [line for line in log.splitlines() if line.startswith(MARKER)]
            if process.returncode or "SCRIPT ERROR:" in log or len(lines) != 1:
                raise SystemExit(f"Benchmark failed: {log_path}")
            result = {"case": label, "iteration": iteration + 1, "metrics": json.loads(lines[0][len(MARKER):])}
            results.append(result)
            print(label, iteration + 1, result["metrics"], flush=True)
    medians = {}
    for label in ("before", "after"):
        records = [record["metrics"] for record in results if record["case"] == label]
        medians[label] = {key: statistics.median(record[key] for record in records) for key in records[0]}
    (args.output / "results.json").write_text(json.dumps({"headless_only": True, "harness_sha256": hashlib.sha256(harnesses[0].read_bytes()).hexdigest(),
                                                       "repetitions": args.repetitions, "medians": medians, "runs": results}, indent=2) + "\n")


if __name__ == "__main__":
    main()
