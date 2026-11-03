"""Offline validation/checkpoint microbenchmark. Does not measure gameplay or internet capacity."""
import json
import platform
import resource
import secrets
import tempfile
import time
from pathlib import Path
from relay import Room, Seat, SnapshotStore, checked_json, digest


def main():
    message = json.dumps({"op": "input", "sequence": 1, "actions": {"right": True, "dash": False}})
    iterations = 10000
    start = time.perf_counter()
    for _ in range(iterations):
        checked_json(message)
    parse_seconds = time.perf_counter() - start
    with tempfile.TemporaryDirectory(prefix="cyberfield_benchmark_") as temporary:
        store = SnapshotStore(Path(temporary))
        room = Room("f" * 32, "a" * 32, required_players=4)
        for peer in range(1, 5):
            room.seats[peer] = Seat(peer, digest(secrets.token_urlsafe(32)))
        room.snapshot = {"fixture": "x" * 32000}
        start = time.perf_counter()
        for revision in range(20):
            room.revision = revision
            store.write(room)
        checkpoint_seconds = time.perf_counter() - start
    print(json.dumps({"kind": "offline_microbenchmark_not_gameplay", "architecture": platform.machine(),
        "parse_messages": iterations, "parse_seconds": parse_seconds,
        "checkpoint_count": 20, "checkpoint_mean_ms": checkpoint_seconds * 1000 / 20,
        "process_peak_rss_kib": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}, indent=2))


if __name__ == "__main__":
    main()
