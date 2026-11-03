"""Loopback TLS tests (03/11) for the private relay's social layer, invite revocation and
a session of FOUR real Godot clients (host + three guests). Not synchronized gameplay.

Godot cases need CYBERFIELD_GODOT (launcher) and CYBERFIELD_TEST_PROJECT (isolated,
imported copy); without them they are SKIPPED, never reported as passed.
"""
import asyncio
import importlib.util
import json
import os
from pathlib import Path
import secrets
import ssl
import subprocess
import sys
import tempfile
import unittest
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve

SPEC = importlib.util.spec_from_file_location("cyberfield_private_relay_social", Path(__file__).resolve().parents[1] / "tools/private_coop/relay.py")
relay_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = relay_module
SPEC.loader.exec_module(relay_module)


def card(public_id, name="Jogador", avatar="kai"):
    return {"public_id": public_id, "name": name, "avatar": avatar}


class RelaySocialTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cyberfield_relay_social_", dir=os.environ.get("CYBERFIELD_TEST_TMP"))
        self.path = Path(self.temporary.name)
        cert, key = self.path / "cert.pem", self.path / "key.pem"
        subprocess.run([os.environ.get("CYBERFIELD_OPENSSL", "openssl"), "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-keyout", str(key), "-out", str(cert), "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1"], check=True, capture_output=True)
        server_tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server_tls.load_cert_chain(cert, key)
        self.client_tls = ssl.create_default_context(cafile=str(cert))
        self.owner_key = secrets.token_urlsafe(32)
        self.relay = relay_module.Relay(self.owner_key, self.path / "snapshots")
        self.server = await serve(self.relay.handler, "127.0.0.1", 0, ssl=server_tls, max_size=relay_module.MAX_MESSAGE, max_queue=8, compression=None)
        self.url = f"wss://127.0.0.1:{self.server.sockets[0].getsockname()[1]}"
        self.sweeper = asyncio.create_task(self._sweep())
        self.clients = []

    async def _sweep(self):
        while True:
            await asyncio.sleep(1)
            await self.relay.sweep()

    async def asyncTearDown(self):
        self.sweeper.cancel()
        for socket in self.clients:
            await socket.close()
        self.server.close()
        await self.server.wait_closed()
        self.temporary.cleanup()

    async def client(self, message):
        socket = await connect(self.url, ssl=self.client_tls, compression=None)
        self.clients.append(socket)
        await socket.send(json.dumps(message))
        return socket

    async def until(self, socket, operation, attempts=40):
        for _ in range(attempts):
            value = json.loads(await asyncio.wait_for(socket.recv(), 4))
            if value["op"] == operation:
                return value
        self.fail(f"expected {operation} absent")

    async def lobby(self, names=("Host", "Dani", "Rafa", "Lu")):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32, "card": {"name": names[0], "avatar": "jhon"}})
        welcome = await self.until(host, "welcome")
        guests = []
        for index, invitation in enumerate(welcome["invites"]):
            guest = await self.client({"op": "join", "room_id": welcome["room_id"], "token": invitation, "card": {"name": names[index + 1], "avatar": "kai"}})
            await self.until(guest, "welcome")
            guests.append(guest)
        return host, guests, welcome

    async def test_roster_is_sanitized_and_has_no_ids(self):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32,
                                  "card": {"name": "Ki‮nho\n​" + "x" * 40, "avatar": "<script>", "public_id": "f" * 16}})
        await self.until(host, "welcome")
        lobby = await self.until(host, "lobby")
        self.assertEqual(lobby["roster"], [{"peer": 1, "name": ("Kinho" + "x" * 40)[:24], "avatar": "jhon", "connected": True}])
        self.assertNotIn("f" * 16, json.dumps(lobby))

    async def test_friend_request_accept_and_private_refusal(self):
        host, guests, welcome = await self.lobby()
        dani, rafa, lu = guests
        await dani.send(json.dumps({"op": "friend_request", "to": 3, "card": card("2" * 16, "Dani")}))
        request = await self.until(rafa, "friend_request")
        self.assertEqual(request["from"], 2)
        self.assertEqual(request["card"], card("2" * 16, "Dani"))
        await rafa.send(json.dumps({"op": "friend_response", "to": 2, "accepted": True, "card": card("3" * 16, "Rafa", "spark")}))
        answer = await self.until(dani, "friend_response")
        self.assertEqual(answer, {"op": "friend_response", "from": 3, "accepted": True, "card": card("3" * 16, "Rafa", "spark")})
        await lu.send(json.dumps({"op": "friend_request", "to": 2, "card": card("4" * 16, "Lu")}))
        await self.until(dani, "friend_request")
        await dani.send(json.dumps({"op": "friend_response", "to": 4, "accepted": False, "card": card("2" * 16, "Dani")}))
        refusal = await self.until(lu, "friend_response")
        self.assertEqual(refusal, {"op": "friend_response", "from": 2, "accepted": False})
        self.assertNotIn("2" * 16, json.dumps(refusal))
        room = self.relay.rooms[welcome["room_id"]]
        self.assertEqual(room.pending_friends, set())
        disk = "".join(p.read_text() for p in (self.path / "snapshots").rglob("*.json"))
        self.assertNotIn("2" * 16, disk)  # relay never stores the social graph

    async def test_unsolicited_or_repeated_response_is_rejected(self):
        host, guests, _ = await self.lobby()
        await guests[1].send(json.dumps({"op": "friend_response", "to": 4, "accepted": True, "card": card("3" * 16)}))
        self.assertEqual((await self.until(guests[1], "error"))["code"], "no_pending_request")

    async def test_social_target_and_card_validation(self):
        host, guests, _ = await self.lobby()
        cases = [
            ({"op": "friend_request", "to": 2, "card": card("2" * 16)}, guests[0], "invalid_social_target"),
            ({"op": "friend_request", "to": 2, "card": card("A" * 16)}, guests[1], "invalid_card"),
            ({"op": "friend_request", "to": 2, "card": {**card("4" * 16), "player_id": "x"}}, guests[2], "invalid_card"),
            ({"op": "friend_request", "to": 9, "card": card("1" * 16)}, host, "invalid_social_target"),
        ]
        for message, socket, code in cases:
            await socket.send(json.dumps(message))
            self.assertEqual((await self.until(socket, "error"))["code"], code)

    async def test_offline_target_and_social_rate_limit(self):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32})
        welcome = await self.until(host, "welcome")
        guest = await self.client({"op": "join", "room_id": welcome["room_id"], "token": welcome["invites"][0]})
        await self.until(guest, "welcome")
        await guest.send(json.dumps({"op": "friend_request", "to": 3, "card": card("2" * 16)}))
        self.assertEqual((await self.until(guest, "error"))["code"], "social_target_offline")
        second = await self.client({"op": "join", "room_id": welcome["room_id"], "token": welcome["invites"][1]})
        await self.until(second, "welcome")
        for _ in range(relay_module.MAX_FRIEND_REQUESTS):
            await host.send(json.dumps({"op": "friend_request", "to": 3, "card": card("1" * 16)}))
            await self.until(second, "friend_request")
        await host.send(json.dumps({"op": "friend_request", "to": 3, "card": card("1" * 16)}))
        self.assertEqual((await self.until(host, "error"))["code"], "social_rate_limited")

    async def test_host_revokes_unused_invites(self):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32})
        welcome = await self.until(host, "welcome")
        guest = await self.client({"op": "join", "room_id": welcome["room_id"], "token": welcome["invites"][0]})
        await self.until(guest, "welcome")
        await guest.send(json.dumps({"op": "revoke_invites"}))
        self.assertEqual((await self.until(guest, "error"))["code"], "not_authorized")
        await host.send(json.dumps({"op": "revoke_invites"}))
        await self.until(host, "invites_revoked")
        late = await self.client({"op": "join", "room_id": welcome["room_id"], "token": welcome["invites"][1]})
        self.assertEqual((await self.until(late, "error"))["code"], "invite_invalid_or_expired")

    async def test_four_real_godot_clients(self):
        launcher = os.environ.get("CYBERFIELD_GODOT")
        project = os.environ.get("CYBERFIELD_TEST_PROJECT")
        if not launcher or not project:
            self.skipTest("Godot isolated test launcher not configured")
        exchange = self.path / "exchange"
        exchange.mkdir(mode=0o700)
        fixture = self.path / "fixture.json"
        fixture.write_text(json.dumps({"cert": str(self.path / "cert.pem"), "url": self.url,
                                       "token": self.owner_key, "dir": str(exchange)}))
        fixture.chmod(0o600)
        processes = []
        logs_paths = [exchange / f"seat_{seat}.log" for seat in (1, 2, 3, 4)]
        try:
            for seat in (1, 2, 3, 4):
                with logs_paths[seat - 1].open("wb") as log_file:
                    processes.append(await asyncio.create_subprocess_exec(launcher, "--headless", "--path", project,
                        "--script", "res://tests/private_session_peer_smoke_test.gd", "--", str(fixture), str(seat),
                        stdout=log_file, stderr=asyncio.subprocess.STDOUT))
                if seat == 1:
                    for _ in range(600):
                        if (exchange / "invites.json").exists() or processes[0].returncode is not None:
                            break
                        await asyncio.sleep(0.05)
            try:
                await asyncio.wait_for(asyncio.gather(*(p.wait() for p in processes)), 180)
            except asyncio.TimeoutError:
                pass
            logs = [path.read_text(errors="replace") for path in logs_paths]
            keep = os.environ.get("CYBERFIELD_KEEP_LOGS")
            if keep:
                # Evidence only: logs carry no secrets (asserted below), results carry public IDs.
                Path(keep).mkdir(parents=True, exist_ok=True)
                for path in logs_paths + sorted(exchange.glob("result_*.json")):
                    (Path(keep) / path.name).write_bytes(path.read_bytes())
            summary = "\n".join(f"--- seat {seat} (rc={p.returncode})\n" + "\n".join(line for line in log.splitlines() if "ERROR" in line or "REPORT" in line)[-1500:]
                                for seat, (p, log) in enumerate(zip(processes, logs), start=1))
            for seat, (process, log) in enumerate(zip(processes, logs), start=1):
                self.assertEqual(process.returncode, 0, summary)
                self.assertIn(f"PRIVATE_PEER_REPORT seat={seat} failures=0", log)
            results = {seat: json.loads((exchange / f"result_{seat}.json").read_text()) for seat in (1, 2, 3, 4)}
            self.assertEqual(results[2]["friends"], [results[3]["public_id"]])
            self.assertEqual(results[3]["friends"], [results[2]["public_id"]])
            self.assertEqual(results[4]["friends"], [])
            self.assertEqual(results[1]["friends"], [])
            self.assertEqual(len({r["public_id"] for r in results.values()}), 4)
            room = next(iter(self.relay.rooms.values()))
            self.assertEqual(room.pending_friends, set())
            self.assertTrue(room.ever_started)
            for log in logs:
                self.assertNotIn(self.owner_key, log)
                self.assertNotIn("SCRIPT ERROR", log)
        finally:
            for process in processes:
                if process.returncode is None:
                    process.kill()
                    await process.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)
