#!/usr/bin/env python3
"""Run actual Godot tests against a separately prepared test copy, never real saves."""
import argparse
import json
import os
import signal
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TESTS = {
    "biome_visual_theme_smoke_test.gd": "BIOME_VISUAL_THEME_SMOKE_TEST_OK",
    "loading_transition_smoke_test.gd": "LOADING_TRANSITION_REPORT failures=0",
    "integration_session_lifecycle_smoke_test.gd": "INTEGRATION_LIFECYCLE_REPORT failures=0",
    "social_menu_smoke_test.gd": "SOCIAL_MENU_REPORT failures=0",
    "social_profile_smoke_test.gd": "SOCIAL_PROFILE_REPORT failures=0",
    "focused_stabilization_input_audio_test.gd": "FOCUSED_STABILIZATION_INPUT_AUDIO_TEST_OK",
    "phase8_lan_lobby_touch_smoke_test.gd": "PHASE8_LAN_LOBBY_TOUCH_SMOKE_TEST_PASSED",
    "android_touch_hud_modal_hotfix_smoke_test.gd": "ANDROID_TOUCH_HUD_MODAL_HOTFIX_SMOKE_TEST_OK",
    "visual_pass3_smoke_test.gd": "VISUAL_PASS3_SMOKE_TEST_OK",
    "dash_sequence_smoke_test.gd": "DASH_SEQUENCE_REPORT failures=0",
    "enemy_interruption_smoke_test.gd": "ENEMY_INTERRUPTION_REPORT failures=0",
    "gameplay_progression_smoke_test.gd": "GAMEPLAY_PROGRESSION_REPORT failures=0",
    "gameplay_wire_smoke_test.gd": "GAMEPLAY_WIRE_REPORT failures=0",
    "jhon_design_b_animation_smoke_test.gd": "JHON_B_REPORT failures=0",
    "arsenal_expansion_smoke_test.gd": "ARSENAL_REPORT failures=0",
    "campaign_store_smoke_test.gd": "CAMPAIGN_STORE_REPORT failures=0",
    "campaign_session_smoke_test.gd": "CAMPAIGN_SESSION_REPORT failures=0",
    "world_persistence_smoke_test.gd": "WORLD_PERSISTENCE_REPORT failures=0",
    "region_routes_smoke_test.gd": "REGION_ROUTES_REPORT failures=0",
    "local_profile_smoke_test.gd": "LOCAL_PROFILE_REPORT failures=0",
    "dev_mode_smoke_test.gd": "DEV_MODE_REPORT failures=0",
    "exploration_routes_smoke_test.gd": "EXPLORATION_REPORT failures=0",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Godot executable or local launcher")
    parser.add_argument("--project", type=Path, required=True, help="Isolated test project copy with imported resources")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--only", action="append", choices=TESTS, help="Retest affected suites; default runs all")
    args = parser.parse_args()
    if args.project.resolve() == ROOT.resolve() or not (args.project / "project.godot").is_file():
        parser.error("Provide an isolated copy; this runner refuses the original workspace")
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    selected = {name: TESTS[name] for name in args.only} if args.only else TESTS
    for script, marker in selected.items():
        log_path = args.output / (script + ".log")
        timed_out = False
        with log_path.open("w") as stream:
            process = subprocess.Popen([args.godot, "--headless", "--path", str(args.project), "--script", "res://tests/" + script],
                                       stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                process.wait(timeout=180)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
        log = log_path.read_text(errors="replace")
        if timed_out:
            log += "\nTEST_TIMEOUT: no pass claimed; process group terminated\n"
        passed = not timed_out and process.returncode == 0 and marker in log and "SCRIPT ERROR:" not in log
        result = {"test": script, "passed": passed, "exit_code": process.returncode,
                  "engine_warnings": "ERROR:" in log or "WARNING:" in log, "log": script + ".log"}
        if timed_out:
            result["error"] = "timeout"
        (args.output / (script + ".log")).write_text(log)
        results.append(result)
        print(script, "PASS" if result["passed"] else "FAIL", flush=True)
    (args.output / "engine-results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(r["passed"] for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
