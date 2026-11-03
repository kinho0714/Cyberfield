"""Private four-seat WSS protocol prototype. No gameplay engine or public admin API.

Only bind loopback. External hosting/tunnel provisioning is a separate user action.
Capabilities authorize possession, not a verified human/account identity.
"""
from __future__ import annotations
import argparse
import asyncio
from dataclasses import dataclass, field
import hashlib
import hmac
import json
import math
import os
from pathlib import Path
import secrets
import ssl
import time
from typing import Any
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

MAX_MESSAGE = 96 * 1024
MAX_SNAPSHOT = 64 * 1024
RECONNECT_SECONDS = 600
INVITE_SECONDS = 600
ACTIONS = {"left", "right", "down", "jump", "attack", "attack_slot_1", "attack_slot_2", "dash", "interact", "heal", "switch_weapon", "gadget_1", "gadget_2"}
AVATARS = {"jhon", "jackson", "kai", "spark"}
NAME_LIMIT = 24
MAX_FRIEND_REQUESTS = 12  # per seat and session; social spam stays bounded


class ProtocolError(Exception):
    pass


def clean_name(value: Any) -> str:
    """Display names only: drop control, bidi and invisible characters, then truncate."""
    if not isinstance(value, str):
        return ""
    kept = []
    for char in value[:256]:
        code = ord(char)
        if code < 32 or code == 127 or 0x80 <= code < 0xA0 or 0x200B <= code <= 0x200F \
                or 0x202A <= code <= 0x202E or 0x2066 <= code <= 0x2069 or code in (0xFEFF, 0x2028, 0x2029):
            continue
        kept.append(char)
    return "".join(kept).strip()[:NAME_LIMIT]


def seat_card(value: Any) -> tuple[str, str]:
    """Optional public card sent in the hello: never an identity, only what others see."""
    if not isinstance(value, dict):
        return "", "jhon"
    avatar = value.get("avatar")
    return clean_name(value.get("name")), avatar if avatar in AVATARS else "jhon"


def social_card(value: Any) -> dict:
    if not isinstance(value, dict) or set(value) - {"public_id", "name", "avatar"}:
        raise ProtocolError("invalid_card")
    public_id = value.get("public_id")
    if not isinstance(public_id, str) or len(public_id) != 16 or any(c not in "0123456789abcdef" for c in public_id):
        raise ProtocolError("invalid_card")
    name, avatar = seat_card(value)
    return {"public_id": public_id, "name": name, "avatar": avatar}


def digest(secret: str) -> str:
    return hashlib.sha256(secret.encode()).hexdigest()


def integer(value: Any, minimum: int, maximum: int) -> bool:
    return type(value) is int and minimum <= value <= maximum


def checked_json(text: str | bytes) -> dict:
    if not isinstance(text, str) or len(text.encode()) > MAX_MESSAGE:
        raise ProtocolError("invalid_message")
    try:
        value = json.loads(text, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, RecursionError):
        raise ProtocolError("invalid_json") from None
    if not isinstance(value, dict) or not isinstance(value.get("op"), str):
        raise ProtocolError("invalid_envelope")
    pending = [(value, 0)]
    visited = 0
    while pending:
        item, depth = pending.pop()
        visited += 1
        if depth > 24 or visited > 8192:
            raise ProtocolError("message_complexity_exceeded")
        if isinstance(item, str):
            try:
                item.encode("utf-8")
            except UnicodeError:
                raise ProtocolError("invalid_unicode") from None
        elif isinstance(item, float) and not math.isfinite(item):
            raise ProtocolError("invalid_number")
        elif isinstance(item, dict):
            pending.extend((v, depth + 1) for pair in item.items() for v in pair)
        elif isinstance(item, list):
            pending.extend((v, depth + 1) for v in item)
    return value


@dataclass
class Seat:
    peer: int
    resume_hash: str
    socket: Any = None
    last_sequence: int = 0
    name: str = ""
    avatar: str = "jhon"
    friend_requests: int = 0


@dataclass
class Room:
    room_id: str
    campaign_id: str
    seats: dict[int, Seat] = field(default_factory=dict)
    invites: dict[str, float] = field(default_factory=dict)
    revision: int = 0
    snapshot: dict = field(default_factory=dict)
    event_ids: set[str] = field(default_factory=set)
    status: str = "lobby"
    deadline: float | None = None
    ever_started: bool = False
    last_checkpoint: float = float("-inf")
    required_players: int = 4
    # (from_peer, to_peer) friend requests awaiting an answer; memory only.
    pending_friends: set = field(default_factory=set)

    def public(self, now: float | None = None) -> dict:
        now = time.monotonic() if now is None else now
        return {"op": "lobby", "room_id": self.room_id, "status": self.status,
                "connected": [p for p, s in self.seats.items() if s.socket is not None],
                "required_players": self.required_players, "revision": self.revision,
                "reconnect_seconds": max(0, int(self.deadline - now)) if self.deadline else 0,
                "roster": [{"peer": p, "name": s.name, "avatar": s.avatar, "connected": s.socket is not None}
                           for p, s in sorted(self.seats.items())]}


class SnapshotStore:
    """Independent relay namespace. Never imports or writes individual campaign saves."""
    def __init__(self, directory: Path):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)

    def write(self, room: Room) -> None:
        payload = json.dumps({"schema_version": 1, "room_id": room.room_id,
                              "campaign_id": room.campaign_id, "revision": room.revision,
                              "snapshot": room.snapshot, "event_ids": sorted(room.event_ids),
                              "required_players": room.required_players, "ever_started": room.ever_started,
                              "checkpoint_wall": time.time(), "suspended": room.status == "suspended",
                              "resume_seats": {str(p): {"resume_hash": seat.resume_hash, "last_sequence": seat.last_sequence} for p, seat in room.seats.items()}},
                             sort_keys=True, separators=(",", ":"), allow_nan=False)
        envelope = json.dumps({"payload": payload, "checksum": digest(payload)})
        if len(envelope.encode()) > MAX_MESSAGE * 2:
            raise ProtocolError("shared_snapshot_too_large")
        folder = self.directory / room.room_id
        folder.mkdir(mode=0o700, exist_ok=True)
        # Same revision can be checkpointed after an event: use unique immutable IDs.
        path = folder / f"{room.revision:012d}_{len(room.event_ids):06d}_{secrets.token_hex(8)}.json"
        temp = path.with_suffix(".tmp")
        with temp.open("x", encoding="utf-8") as file:
            os.chmod(temp, 0o600)
            file.write(envelope)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temp, path)
        # Retain three valid local snapshots; no deletion of other namespaces.
        valid = []
        for item in sorted(folder.glob("*.json")):
            if self.read(item) is not None:
                valid.append(item)
        for item in valid[:-3]:
            item.unlink()

    @staticmethod
    def read(path: Path) -> dict | None:
        try:
            if path.stat().st_size > MAX_MESSAGE * 2:
                return None
            envelope = json.loads(path.read_text())
            if not isinstance(envelope, dict) or not isinstance(envelope.get("payload"), str) or not isinstance(envelope.get("checksum"), str):
                return None
            payload = envelope["payload"]
            if not hmac.compare_digest(digest(payload), envelope["checksum"]):
                return None
            data = json.loads(payload)
            return data if data.get("schema_version") == 1 else None
        except (OSError, ValueError, KeyError, TypeError, RecursionError):
            return None


class Relay:
    def __init__(self, owner_key: str, directory: Path, clock=time.monotonic):
        if len(owner_key) < 32:
            raise ValueError("owner_key_minimum_32_characters")
        self.owner_key = owner_key
        self.rooms: dict[str, Room] = {}
        self.store = SnapshotStore(directory)
        self.clock = clock
        self.max_connections = 12
        self.connections = 0
        self._recover_rooms()

    def _recover_rooms(self) -> None:
        """Resume capabilities are persisted as hashes only; recovered sessions start paused."""
        for folder in sorted(self.store.directory.iterdir()):
            if not folder.is_dir() or len(folder.name) != 32 or any(c not in "0123456789abcdef" for c in folder.name):
                continue
            for path in sorted(folder.glob("*.json"), reverse=True):
                data = self.store.read(path)
                if not data or data.get("room_id") != folder.name:
                    continue
                seats = data.get("resume_seats", {})
                required = data.get("required_players", 4)
                campaign = data.get("campaign_id", "")
                if (not integer(required, 2, 4) or not isinstance(seats, dict) or
                    not 1 <= len(seats) <= required or not isinstance(campaign, str) or
                    len(campaign) != 32 or any(c not in "0123456789abcdef" for c in campaign) or
                    not integer(data.get("revision"), 0, 2**31-1) or not isinstance(data.get("snapshot"), dict)):
                    continue
                valid = True
                recovered = {}
                for peer, saved in seats.items():
                    if (peer not in {"1", "2", "3", "4"} or not isinstance(saved, dict) or
                        not isinstance(saved.get("resume_hash"), str) or len(saved["resume_hash"]) != 64 or
                        any(c not in "0123456789abcdef" for c in saved["resume_hash"]) or
                        not integer(saved.get("last_sequence"), 0, 2**31-1)):
                        valid = False
                        break
                    recovered[int(peer)] = Seat(int(peer), saved["resume_hash"], last_sequence=saved["last_sequence"])
                events = data.get("event_ids", [])
                if (not valid or 1 not in recovered or not isinstance(events, list) or len(events) > 1024 or
                    any(not isinstance(e, str) or not 1 <= len(e) <= 96 for e in events)):
                    continue
                wall = data.get("checkpoint_wall", 0)
                expired = (not isinstance(wall, (int, float)) or not math.isfinite(wall) or
                           time.time() - wall > RECONNECT_SECONDS or bool(data.get("suspended", False)))
                self.rooms[folder.name] = Room(folder.name, campaign, seats=recovered,
                    revision=data["revision"], snapshot=data["snapshot"], event_ids=set(events),
                    status="suspended" if expired else "paused", deadline=self.clock() + RECONNECT_SECONDS,
                    ever_started=bool(data.get("ever_started", False)), required_players=required)
                break
            if len(self.rooms) >= 8:
                break

    async def send(self, socket, data: dict) -> None:
        try:
            await asyncio.wait_for(socket.send(json.dumps(data, separators=(",", ":"), allow_nan=False)), 3)
        except (ConnectionClosed, asyncio.TimeoutError):
            pass

    async def broadcast(self, room: Room, data: dict) -> None:
        await asyncio.gather(*(self.send(s.socket, data) for s in room.seats.values() if s.socket is not None))

    async def handler(self, socket) -> None:
        if self.connections >= self.max_connections:
            await socket.close(1013, "capacity")
            return
        self.connections += 1
        room = None
        seat = None
        tokens = 60.0
        last = self.clock()
        try:
            hello = checked_json(await asyncio.wait_for(socket.recv(), 8))
            room, seat, welcome = self.authorize(hello, socket)
            await self.send(socket, welcome)
            await self.broadcast(room, room.public(self.clock()))
            async for raw in socket:
                now = self.clock()
                tokens = min(60.0, tokens + max(0, now - last) * 40)
                last = now
                if tokens < 1:
                    raise ProtocolError("rate_limited")
                tokens -= 1
                await self.dispatch(room, seat, checked_json(raw))
        except ProtocolError as error:
            await self.send(socket, {"op": "error", "code": str(error)})
            await socket.close(1008, "policy")
        except (ConnectionClosed, asyncio.TimeoutError):
            pass
        except OSError:
            await self.send(socket, {"op": "error", "code": "storage_unavailable"})
            await socket.close(1011, "storage")
        finally:
            self.connections -= 1
            if room is not None and seat is not None and seat.socket is socket:
                seat.socket = None
                if room.status != "suspended":
                    room.status = "paused" if room.ever_started else "lobby"
                    if room.deadline is None:
                        room.deadline = self.clock() + RECONNECT_SECONDS
                if room.snapshot:
                    try:
                        self.store.write(room)
                    except OSError:
                        pass
                await self.broadcast(room, room.public(self.clock()))

    def authorize(self, message: dict, socket) -> tuple[Room, Seat, dict]:
        op = message.get("op")
        if message.get("protocol", 1) != 1:
            raise ProtocolError("unsupported_protocol")
        supplied = message.get("token", "")
        if not isinstance(supplied, str) or not 32 <= len(supplied) <= 256:
            raise ProtocolError("authorization_required")
        if op == "create":
            if not hmac.compare_digest(supplied, self.owner_key) or len(self.rooms) >= 8:
                raise ProtocolError("not_authorized")
            campaign = message.get("campaign_id", "")
            if not isinstance(campaign, str) or len(campaign) != 32 or any(c not in "0123456789abcdef" for c in campaign):
                raise ProtocolError("invalid_campaign")
            required = message.get("required_players", 4)
            if not integer(required, 2, 4):
                raise ProtocolError("invalid_player_count")
            room = Room(secrets.token_hex(16), campaign, required_players=required)
            resume = secrets.token_urlsafe(32)
            seat = Seat(1, digest(resume), socket, 0, *seat_card(message.get("card")))
            room.seats[1] = seat
            invitations = [secrets.token_urlsafe(32) for _ in range(required - 1)]
            room.invites = {digest(t): self.clock() + INVITE_SECONDS for t in invitations}
            self.rooms[room.room_id] = room
            return room, seat, {"op": "welcome", "peer": 1, "room_id": room.room_id,
                                "resume_token": resume, "invites": invitations, "revision": 0, "campaign_id": room.campaign_id}
        room_id = message.get("room_id")
        if not isinstance(room_id, str) or room_id not in self.rooms:
            raise ProtocolError("not_authorized")
        room = self.rooms[room_id]
        if room.status == "suspended" or (room.deadline is not None and self.clock() >= room.deadline):
            raise ProtocolError("session_suspended")
        hashed = digest(supplied)
        if op == "join":
            expiry = room.invites.get(hashed)
            if expiry is None or self.clock() >= expiry or len(room.seats) >= room.required_players or room.ever_started:
                raise ProtocolError("invite_invalid_or_expired")
            del room.invites[hashed]  # single use, enforced on server
            peer = next(i for i in range(2, 5) if i not in room.seats)
            resume = secrets.token_urlsafe(32)
            seat = Seat(peer, digest(resume), socket, 0, *seat_card(message.get("card")))
            room.seats[peer] = seat
        elif op == "resume":
            seat = next((s for s in room.seats.values() if hmac.compare_digest(s.resume_hash, hashed)), None)
            if seat is None or seat.socket is not None:
                raise ProtocolError("resume_rejected")
            resume = secrets.token_urlsafe(32)  # rotate after successful reconnect
            seat.resume_hash = digest(resume)
            seat.socket = socket
            if "card" in message:
                seat.name, seat.avatar = seat_card(message["card"])
        else:
            raise ProtocolError("authorization_required")
        if len(room.seats) == room.required_players and all(s.socket is not None for s in room.seats.values()):
            room.deadline = None
            room.status = "active" if room.ever_started else "lobby"
        return room, seat, {"op": "welcome", "peer": seat.peer, "room_id": room.room_id,
                            "resume_token": resume, "revision": room.revision,
                            "snapshot": room.snapshot, "status": room.status, "campaign_id": room.campaign_id}

    async def dispatch(self, room: Room, seat: Seat, message: dict) -> None:
        op = message["op"]
        if op == "ping":
            await self.send(seat.socket, {"op": "pong"})
            return
        if op == "leave":
            if room.snapshot:
                self.store.write(room)
            await seat.socket.close(1000, "saved")
            return
        if op in ("friend_request", "friend_response"):
            await self.social(room, seat, op, message)
            return
        if op == "revoke_invites":
            if seat.peer != 1:
                raise ProtocolError("not_authorized")
            room.invites.clear()
            await self.send(seat.socket, {"op": "invites_revoked"})
            return
        if op == "start":
            if seat.peer != 1 or len(room.seats) != room.required_players or not all(s.socket is not None for s in room.seats.values()):
                raise ProtocolError("exactly_four_authorized_connections_required")
            room.status = "active"
            room.ever_started = True
            await self.broadcast(room, {"op": "started", "revision": room.revision})
            return
        if room.status != "active":
            raise ProtocolError("session_paused")
        if op == "input":
            seq = message.get("sequence")
            actions = message.get("actions")
            if seat.peer == 1 or not integer(seq, seat.last_sequence + 1, 2**31 - 1) or not isinstance(actions, dict) or not set(actions) <= ACTIONS or any(type(v) is not bool for v in actions.values()):
                raise ProtocolError("invalid_input")
            seat.last_sequence = seq
            host = room.seats[1].socket
            if host is not None:
                await self.send(host, {"op": "input", "peer": seat.peer, "sequence": seq, "actions": actions})
            return
        if op == "snapshot":
            payload = message.get("state")
            if seat.peer != 1 or not integer(message.get("base_revision"), room.revision, room.revision):
                raise ProtocolError("authority_or_revision_rejected")
            if not isinstance(payload, dict) or not set(payload) <= {"world_state", "player_states", "story_state", "inventory_state"} or any(not isinstance(v, dict) for v in payload.values()):
                raise ProtocolError("invalid_snapshot")
            if len(json.dumps(payload, allow_nan=False).encode()) > MAX_SNAPSHOT:
                raise ProtocolError("snapshot_too_large")
            # Checkpoint the first snapshot and then at most once per two seconds.
            # Network revisions remain monotonic; disconnect/event paths force a checkpoint.
            candidate = Room(room.room_id, room.campaign_id, seats=room.seats, required_players=room.required_players, ever_started=room.ever_started, revision=room.revision + 1,
                             snapshot=payload, event_ids=set(room.event_ids))
            if not room.snapshot or self.clock() - room.last_checkpoint >= 2:
                self.store.write(candidate)
                room.last_checkpoint = self.clock()
            room.revision = candidate.revision
            room.snapshot = payload
            await self.broadcast(room, {"op": "snapshot", "revision": room.revision, "state": payload, "session_id": room.room_id, "campaign_id": room.campaign_id})
            return
        if op == "event":
            event_id = message.get("event_id")
            if seat.peer != 1 or not isinstance(event_id, str) or not 1 <= len(event_id) <= 96 or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_:-" for c in event_id):
                raise ProtocolError("event_rejected")
            if event_id in room.event_ids:
                await self.send(seat.socket, {"op": "event_ack", "event_id": event_id, "duplicate": True})
                return
            if len(room.event_ids) >= 1024:
                raise ProtocolError("event_ledger_full")
            candidate = Room(room.room_id, room.campaign_id, seats=room.seats, required_players=room.required_players, ever_started=room.ever_started, revision=room.revision,
                             snapshot=room.snapshot, event_ids=room.event_ids | {event_id})
            self.store.write(candidate)
            room.event_ids = candidate.event_ids
            await self.broadcast(room, {"op": "event_ack", "event_id": event_id, "duplicate": False})
            return
        raise ProtocolError("unsupported_operation")  # Chat and arbitrary RPCs disabled.

    async def social(self, room: Room, seat: Seat, op: str, message: dict) -> None:
        """Forward a friend request/answer between two connected seats of this room only.

        The relay never stores the social graph; cards are self-declared, not accounts."""
        target = message.get("to")
        if room.status == "suspended" or not integer(target, 1, 4) or target == seat.peer:
            raise ProtocolError("invalid_social_target")
        destination = room.seats.get(target)
        if destination is None or destination.socket is None:
            raise ProtocolError("social_target_offline")
        if op == "friend_request":
            card = social_card(message.get("card"))
            if seat.friend_requests >= MAX_FRIEND_REQUESTS:
                raise ProtocolError("social_rate_limited")
            seat.friend_requests += 1
            room.pending_friends.add((seat.peer, target))
            await self.send(destination.socket, {"op": "friend_request", "from": seat.peer, "card": card})
            return
        accepted = message.get("accepted")
        if type(accepted) is not bool or (target, seat.peer) not in room.pending_friends:
            raise ProtocolError("no_pending_request")
        # A refusal reveals nothing about the person who refused.
        reply = {"op": "friend_response", "from": seat.peer, "accepted": accepted}
        if accepted:
            reply["card"] = social_card(message.get("card"))
        room.pending_friends.discard((target, seat.peer))
        await self.send(destination.socket, reply)

    async def sweep(self) -> None:
        for room in self.rooms.values():
            if room.deadline is not None and self.clock() >= room.deadline and room.status != "suspended":
                room.status = "suspended"
                if room.snapshot:
                    self.store.write(room)
                room.invites.clear()
                await self.broadcast(room, {"op": "suspended", "revision": room.revision})
                for seat in room.seats.values():
                    if seat.socket is not None:
                        await seat.socket.close(1000, "suspended")


async def run(args) -> None:
    key = os.environ.get("CYBERFIELD_HOST_KEY", "")
    relay = Relay(key, args.data_dir)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(args.cert, args.key)
    async with serve(relay.handler, "127.0.0.1", args.port, ssl=context,
                     max_size=MAX_MESSAGE, max_queue=8, compression=None, origins=[None],
                     ping_interval=20, ping_timeout=20, close_timeout=3,
                     open_timeout=8):
        while True:
            await asyncio.sleep(1)
            await relay.sweep()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--port", type=int, default=27842)
    asyncio.run(run(parser.parse_args()))
