"""Actual loopback TLS/WebSocket transport tests; not four-player gameplay tests."""
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

SPEC = importlib.util.spec_from_file_location("cyberfield_private_relay", Path(__file__).resolve().parents[1] / "tools/private_coop/relay.py")
relay_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = relay_module
SPEC.loader.exec_module(relay_module)


class RelayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cyberfield_relay_test_")
        self.path = Path(self.temporary.name)
        cert, key = self.path / "cert.pem", self.path / "key.pem"
        subprocess.run([os.environ.get("CYBERFIELD_OPENSSL", "openssl"), "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-keyout", str(key), "-out", str(cert), "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1"], check=True, capture_output=True)
        server_tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server_tls.load_cert_chain(cert, key)
        self.client_tls = ssl.create_default_context(cafile=str(cert))
        self.owner_key = secrets.token_urlsafe(32)
        self.now = 1000.0
        self.relay = relay_module.Relay(self.owner_key, self.path / "snapshots", clock=lambda: self.now)
        self.server = await serve(self.relay.handler, "127.0.0.1", 0, ssl=server_tls, max_size=relay_module.MAX_MESSAGE, max_queue=8, compression=None)
        self.url = f"wss://127.0.0.1:{self.server.sockets[0].getsockname()[1]}"
        self.clients = []

    async def asyncTearDown(self):
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

    async def until(self, socket, operation):
        for _ in range(30):
            value = json.loads(await asyncio.wait_for(socket.recv(), 4))
            if value["op"] == operation:
                return value
        self.fail("expected protocol response absent")

    async def four(self):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32})
        welcome = await self.until(host, "welcome")
        guests, tokens = [], []
        for invitation in welcome["invites"]:
            guest = await self.client({"op": "join", "room_id": welcome["room_id"], "token": invitation})
            response = await self.until(guest, "welcome")
            guests.append(guest)
            tokens.append(response["resume_token"])
        await host.send(json.dumps({"op": "start"}))
        await self.until(host, "started")
        for guest in guests:
            await self.until(guest, "started")
        return host, guests, tokens, welcome

    async def test_four_authorized_tls_connections_and_authority(self):
        host, guests, tokens, welcome = await self.four()
        self.assertEqual(len(self.relay.rooms[welcome["room_id"]].seats), 4)
        await guests[0].send(json.dumps({"op": "input", "sequence": 1, "actions": {"right": True}, "peer": 1}))
        forwarded = await self.until(host, "input")
        self.assertEqual(forwarded["peer"], 2)  # declared sender was ignored
        await host.send(json.dumps({"op": "event", "event_id": "fixture:reward:1"}))
        self.assertFalse((await self.until(host, "event_ack"))["duplicate"])
        await host.send(json.dumps({"op": "event", "event_id": "fixture:reward:1"}))
        self.assertTrue((await self.until(host, "event_ack"))["duplicate"])
        payload = {"world_state": {"fixture": 1}, "player_states": {str(i): {"health": 10} for i in range(1, 5)}, "story_state": {}, "inventory_state": {}}
        await host.send(json.dumps({"op": "snapshot", "base_revision": 0, "state": payload}))
        self.assertEqual((await self.until(host, "snapshot"))["revision"], 1)
        for guest in guests:
            self.assertEqual((await self.until(guest, "snapshot"))["state"], payload)
        await guests[0].send(json.dumps({"op": "snapshot", "base_revision": 1, "state": payload}))
        self.assertEqual((await self.until(guests[0], "error"))["code"], "authority_or_revision_rejected")
        await guests[0].wait_closed()
        resumed = await self.client({"op": "resume", "room_id": welcome["room_id"], "token": tokens[0]})
        response = await self.until(resumed, "welcome")
        self.assertEqual(response["peer"], 2)
        self.assertNotEqual(response["resume_token"], tokens[0])
        self.assertEqual(response["snapshot"], payload)
        self.assertEqual(self.relay.rooms[welcome["room_id"]].revision, 1)
        files = sorted((self.path / "snapshots" / welcome["room_id"]).glob("*.json"))
        self.assertTrue(files)
        disk_text = "".join(p.read_text() for p in files)
        self.assertNotIn(self.owner_key, disk_text)
        self.assertNotIn(welcome["resume_token"], disk_text)
        self.assertTrue(all(token not in disk_text for token in welcome["invites"]))
        self.assertEqual(relay_module.SnapshotStore.read(files[-1])["snapshot"], payload)
        files[-1].write_text("broken disposable snapshot")
        self.assertIsNone(relay_module.SnapshotStore.read(files[-1]))

    async def test_invites_single_use_and_exact_four(self):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32})
        welcome = await self.until(host, "welcome")
        message = {"op": "join", "room_id": welcome["room_id"], "token": welcome["invites"][0]}
        guest = await self.client(message)
        await self.until(guest, "welcome")
        replay = await self.client(message)
        self.assertEqual((await self.until(replay, "error"))["code"], "invite_invalid_or_expired")
        await host.send(json.dumps({"op": "start"}))
        self.assertEqual((await self.until(host, "error"))["code"], "exactly_four_authorized_connections_required")

    async def test_host_loss_timeout_and_backup(self):
        host, guests, tokens, welcome = await self.four()
        payload = {"world_state": {"fixture": 2}, "player_states": {}, "story_state": {}, "inventory_state": {}}
        await host.send(json.dumps({"op": "snapshot", "base_revision": 0, "state": payload}))
        await self.until(host, "snapshot")
        await host.close()
        await host.wait_closed()
        await asyncio.sleep(0.05)
        room = self.relay.rooms[welcome["room_id"]]
        self.assertEqual(room.status, "paused")
        resumed_host = await self.client({"op": "resume", "room_id": room.room_id, "token": welcome["resume_token"]})
        response = await self.until(resumed_host, "welcome")
        self.assertEqual(response["peer"], 1)
        self.assertEqual(room.status, "active")
        await resumed_host.close()
        await resumed_host.wait_closed()
        await asyncio.sleep(0.05)
        self.assertEqual(room.status, "paused")
        self.now += 601
        await self.relay.sweep()
        self.assertEqual(room.status, "suspended")
        self.assertEqual(room.snapshot, payload)
        self.assertTrue(list((self.path / "snapshots" / room.room_id).glob("*.json")))

    async def test_rate_limit(self):
        host = await self.client({"op": "create", "token": self.owner_key, "campaign_id": "a" * 32})
        await self.until(host, "welcome")
        for _ in range(61):
            await host.send(json.dumps({"op": "ping"}))
        for _ in range(65):
            response = json.loads(await asyncio.wait_for(host.recv(), 4))
            if response["op"] == "error":
                self.assertEqual(response["code"], "rate_limited")
                break
        else:
            self.fail("rate limit not enforced")

    async def test_godot_wss_client(self):
        launcher = os.environ.get("CYBERFIELD_GODOT")
        project = os.environ.get("CYBERFIELD_TEST_PROJECT")
        if not launcher or not project:
            self.skipTest("Godot isolated test launcher not configured")
        fixture = self.path / "fixture.json"
        output = self.path / "godot_invites.json"
        output.touch(mode=0o600)
        fixture.write_text(json.dumps({"cert": str(self.path / "cert.pem"), "url": self.url,
                                       "token": self.owner_key, "output": str(output),
                                       "backup_root": str(self.path / "received")}))
        fixture.chmod(0o600)
        process = await asyncio.create_subprocess_exec(launcher, "--headless", "--path", project,
            "--script", "res://tests/private_transport_smoke_test.gd", "--", str(fixture),
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
        try:
            invitation_data = None
            for _ in range(400):
                if output.stat().st_size:
                    invitation_data = json.loads(output.read_text())
                    break
                if process.returncode is not None:
                    break
                await asyncio.sleep(0.05)
            self.assertIsNotNone(invitation_data, "Godot did not receive welcome")
            guests = []
            for token in invitation_data["invites"]:
                guest = await self.client({"op": "join", "room_id": invitation_data["room_id"], "token": token})
                await self.until(guest, "welcome")
                guests.append(guest)
            for guest in guests:
                await self.until(guest, "snapshot")
            await guests[0].send(json.dumps({"op": "input", "sequence": 1, "actions": {"right": True}}))
            raw, _ = await asyncio.wait_for(process.communicate(), 30)
            self.assertEqual(process.returncode, 0, raw.decode(errors="replace"))
            self.assertIn("PRIVATE_TRANSPORT_REPORT failures=0", raw.decode())
        finally:
            if process.returncode is None:
                process.kill()
                await process.wait()

    async def test_unauthorized_and_invalid_messages(self):
        bad = await self.client({"op": "create", "token": secrets.token_urlsafe(32), "campaign_id": "a" * 32})
        self.assertEqual((await self.until(bad, "error"))["code"], "not_authorized")
        for raw in ['[]', '{bad', '{"op":"ping","number":NaN}', '{"op":"ping","number":1e999}', json.dumps({'op': 'join', 'token': '\ud800'})]:
            with self.assertRaises(relay_module.ProtocolError):
                relay_module.checked_json(raw)
        with self.assertRaises(relay_module.ProtocolError):
            relay_module.checked_json(b'binary not accepted')
        with self.assertRaises(relay_module.ProtocolError):
            relay_module.checked_json('x' * (relay_module.MAX_MESSAGE + 1))
        socket = await connect(self.url, ssl=self.client_tls, compression=None)
        self.clients.append(socket)
        await socket.send('{bad')
        self.assertEqual((await self.until(socket, "error"))["code"], "invalid_json")


if __name__ == "__main__":
    unittest.main(verbosity=2)
