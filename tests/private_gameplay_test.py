"""Two real Godot processes with the project's game scene over actual loopback WSS/TLS."""
import asyncio
import json
import os
import signal
import unittest
from private_relay_test import RelayTests


class PrivateGameplayTests(RelayTests):
    async def test_two_real_godot_gameplay_clients(self):
        await self.exercise(2)

    async def test_four_real_godot_gameplay_clients(self):
        await self.exercise(4)

    async def test_integrated_menu_two_godot_clients(self):
        await self.exercise(2, True)

    async def test_integrated_menu_four_godot_clients(self):
        await self.exercise(4, True, simulated_peers=True)

    async def exercise(self, count, integrated=False, simulated_peers=False):
        launcher = os.environ.get("CYBERFIELD_GODOT")
        project = os.environ.get("CYBERFIELD_TEST_PROJECT")
        if not launcher or not project:
            self.skipTest("isolated Godot launcher required")
        output = self.path / "invitation.json"
        output.touch(mode=0o600)
        processes = []
        streams = {}

        async def launch(role, token, room_id="", peer=1):
            fixture = self.path / f"{role}.json"
            fixture.write_text(json.dumps({"role": role, "token": token, "room_id": room_id, "peer": peer, "count": count, "integrated": integrated,
                "social_expected": not simulated_peers, "reconnect_test": simulated_peers and peer == 2,
                "url": self.url, "cert": str(self.path / "cert.pem"), "root": str(self.path / role),
                "output": str(output)}))
            fixture.chmod(0o600)
            logfile = self.path / f"{role}.log"
            stream = logfile.open("w")
            script = "res://tests/private_gameplay_simulated_peer.gd" if simulated_peers and role != "host" else "res://tests/private_gameplay_client.gd"
            process = await asyncio.create_subprocess_exec(launcher, "--headless", "--path", project,
                "--script", script, "--", str(fixture),
                stdout=stream, stderr=asyncio.subprocess.STDOUT, start_new_session=True)
            streams[role] = (stream, logfile)
            processes.append(process)
            return process

        try:
            host = await launch("host", self.owner_key)
            for _ in range(1800):
                if output.stat().st_size or host.returncode is not None:
                    break
                await asyncio.sleep(0.05)
            if not output.stat().st_size:
                if host.returncode is not None:
                    await host.wait()
                    self.fail(streams["host"][1].read_text())
                self.fail("Godot host did not authorize")
            invitation = json.loads(output.read_text())
            members = [("host", host)]
            for peer, token in enumerate(invitation["tokens"], 2):
                role = f"guest{peer}"
                members.append((role, await launch(role, token, invitation["room_id"], peer)))
            for _ in range(1800):
                if all((self.path / f"{name}.ready").exists() for name, _ in members):
                    break
                if any(process.returncode is not None for _, process in members):
                    break
                await asyncio.sleep(0.05)
            (self.path / "release").write_text("release")
            for name, process in members:
                await asyncio.wait_for(process.wait(), 120)
                streams[name][0].flush()
                text = streams[name][1].read_text()
                print(f"GODOT_{name.upper()}_OUTPUT\n{text}", flush=True)
                self.assertEqual(process.returncode, 0, text)
                self.assertNotIn("SCRIPT ERROR", text)
                self.assertNotIn("Can't find overlapping bodies", text)
                expected_report = f"SIMULATED_GAMEPLAY_REPORT role={name} failures=0" if simulated_peers and name != "host" else f"PRIVATE_GAMEPLAY_REPORT role={name} failures=0"
                self.assertIn(expected_report, text)
        finally:
            for stream, logfile in streams.values():
                stream.close()
            for process in processes:
                if process.returncode is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    await asyncio.wait_for(process.wait(), 5)


if __name__ == "__main__":
    unittest.main(verbosity=2)
