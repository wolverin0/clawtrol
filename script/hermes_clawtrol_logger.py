#!/usr/bin/env python3
"""Read-only Hermes state.db to scoped ClawTrol mirror sidecar.

Hermes databases are opened read-only and never modified. Cursor and health
state live in a separate ClawTrol-owned directory. Message content and tool
arguments/results are excluded unless excerpt mirroring is explicitly enabled.
"""
from __future__ import annotations

import argparse
import contextlib
import json
import os
import random
import re
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterator

SUPPORTED_SCHEMAS = frozenset({11, 14, 17, 22, 23})
DEFAULT_STATE_DIR = Path("/var/lib/clawtrol-hermes-mirror")
DEFAULT_BASE_URL = "http://127.0.0.1:4001/api/v1/mirrors/hermes"
SENSITIVE_KEYS = re.compile(
    r"(?:authorization|cookie|secret|token|password|api[_-]?key|tool_(?:args|result|calls))",
    re.IGNORECASE,
)
SENSITIVE_VALUES = (
    re.compile(r"\b(?:sk|ghp|github_pat|xox[baprs])[-_A-Za-z0-9]{12,}\b"),
    re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{8,}"),
)


class MirrorError(RuntimeError):
    """A fail-closed mirror error safe to report after redaction."""


@dataclass(frozen=True)
class ProfileSource:
    name: str
    database: Path


@dataclass
class Cursor:
    timestamp: Any = 0
    message_id: Any = 0

    @classmethod
    def from_dict(cls, value: dict[str, Any] | None) -> "Cursor":
        value = value or {}
        return cls(value.get("timestamp", 0), value.get("message_id", 0))

    def to_dict(self) -> dict[str, Any]:
        return {"timestamp": self.timestamp, "message_id": self.message_id}


@dataclass
class Counters:
    sessions: int = 0
    events: int = 0
    completions: int = 0
    duplicates: int = 0
    redactions: int = 0

    def to_dict(self) -> dict[str, int]:
        return vars(self).copy()


@dataclass
class ProfileBatch:
    schema: int
    sessions: dict[str, dict[str, Any]]
    messages: list[dict[str, Any]]
    cursor: Cursor


@dataclass
class Settings:
    sources: list[ProfileSource]
    state_dir: Path
    base_url: str
    token: str | None
    dry_run: bool
    include_excerpts: bool
    expected_schema: int | None
    hermes_commit: str
    hermes_version: str
    poll_seconds: float
    once: bool
    busy_timeout_ms: int
    board_id: int
    health: dict[str, Any] = field(default_factory=dict)


def parse_profile_mapping(raw: str) -> ProfileSource:
    name, separator, database = raw.partition("=")
    if not separator or not re.fullmatch(r"[A-Za-z0-9._-]{1,64}", name):
        raise argparse.ArgumentTypeError("profile mapping must be PROFILE=/absolute/state.db")
    if name.casefold() == "all":
        raise argparse.ArgumentTypeError("ALL is an aggregator and cannot be mirrored")
    path = Path(database).expanduser()
    if not path.is_absolute():
        raise argparse.ArgumentTypeError("state.db path must be absolute")
    return ProfileSource(name=name, database=path)


def redact(value: Any, counters: Counters) -> Any:
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for key, nested in value.items():
            if SENSITIVE_KEYS.search(str(key)):
                cleaned[str(key)] = "[REDACTED]"
                counters.redactions += 1
            else:
                cleaned[str(key)] = redact(nested, counters)
        return cleaned
    if isinstance(value, list):
        return [redact(item, counters) for item in value]
    if not isinstance(value, str):
        return value
    cleaned = value
    for pattern in SENSITIVE_VALUES:
        cleaned, count = pattern.subn("[REDACTED]", cleaned)
        counters.redactions += count
    return cleaned[:2000]


@contextlib.contextmanager
def open_readonly(database: Path, busy_timeout_ms: int) -> Iterator[sqlite3.Connection]:
    if not database.is_file():
        raise MirrorError(f"state database is unavailable: {database}")
    uri = f"file:{urllib.parse.quote(database.as_posix())}?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=busy_timeout_ms / 1000, isolation_level=None)
    connection.row_factory = sqlite3.Row
    try:
        connection.execute("PRAGMA query_only = ON")
        connection.execute(f"PRAGMA busy_timeout = {int(busy_timeout_ms)}")
        connection.execute("BEGIN")
        yield connection
        connection.execute("COMMIT")
    except BaseException:
        with contextlib.suppress(sqlite3.Error):
            connection.execute("ROLLBACK")
        raise
    finally:
        connection.close()


def schema_version(connection: sqlite3.Connection, expected: int | None) -> int:
    version = int(connection.execute("PRAGMA user_version").fetchone()[0])
    if version not in SUPPORTED_SCHEMAS:
        raise MirrorError(f"unsupported Hermes schema {version}")
    if expected is not None and version != expected:
        raise MirrorError(f"live schema {version} does not match verified schema {expected}")
    for table in ("sessions", "messages"):
        if not connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
        ).fetchone():
            raise MirrorError(f"schema {version} is missing {table}")
    return version


def available_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {str(row["name"]) for row in connection.execute(f"PRAGMA table_info({table})")}


def selected_columns(available: set[str], candidates: tuple[str, ...]) -> str:
    return ", ".join(column for column in candidates if column in available)


def read_profile_batch(
    source: ProfileSource,
    cursor: Cursor,
    busy_timeout_ms: int,
    expected_schema: int | None = None,
) -> ProfileBatch:
    with open_readonly(source.database, busy_timeout_ms) as connection:
        version = schema_version(connection, expected_schema)
        message_columns = available_columns(connection, "messages")
        required = {"id", "session_id", "timestamp"}
        if not required.issubset(message_columns):
            raise MirrorError(f"schema {version} lacks required message cursor columns")
        fields = selected_columns(
            message_columns,
            ("id", "session_id", "timestamp", "role", "content", "token_count", "finish_reason"),
        )
        rows = connection.execute(
            f"""SELECT {fields} FROM messages
                WHERE timestamp > ? OR (timestamp = ? AND id > ?)
                ORDER BY timestamp ASC, id ASC""",
            (cursor.timestamp, cursor.timestamp, cursor.message_id),
        ).fetchall()
        messages = [dict(row) for row in rows]
        sessions = read_sessions(connection, {str(row["session_id"]) for row in rows})
    next_cursor = Cursor(cursor.timestamp, cursor.message_id)
    if messages:
        next_cursor = Cursor(messages[-1]["timestamp"], messages[-1]["id"])
    return ProfileBatch(version, sessions, messages, next_cursor)


def read_sessions(
    connection: sqlite3.Connection, session_ids: set[str]
) -> dict[str, dict[str, Any]]:
    if not session_ids:
        return {}
    columns = available_columns(connection, "sessions")
    if "id" not in columns:
        raise MirrorError("sessions table lacks id")
    fields = selected_columns(
        columns,
        ("id", "title", "source", "model", "started_at", "ended_at", "message_count"),
    )
    placeholders = ",".join("?" for _ in session_ids)
    rows = connection.execute(
        f"SELECT {fields} FROM sessions WHERE id IN ({placeholders})", tuple(sorted(session_ids))
    ).fetchall()
    found = {str(row["id"]): dict(row) for row in rows}
    missing = session_ids - found.keys()
    if missing:
        raise MirrorError(f"messages reference {len(missing)} missing sessions")
    return found


class ApiClient:
    def __init__(self, base_url: str, token: str | None, dry_run: bool):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.dry_run = dry_run

    def post(self, endpoint: str, payload: dict[str, Any]) -> dict[str, Any]:
        if self.dry_run:
            return {"dry_run": True, "created": len(payload.get("events", [])), "duplicates": 0}
        data = json.dumps(payload, separators=(",", ":")).encode()
        request = urllib.request.Request(f"{self.base_url}/{endpoint}", data=data, method="POST")
        request.add_header("Authorization", f"Bearer {self.token}")
        request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.loads(response.read().decode() or "{}")
        except urllib.error.HTTPError as error:
            error.read()
            raise MirrorError(f"ClawTrol {endpoint} returned HTTP {error.code}") from error


def session_payload(
    profile: str, session: dict[str, Any], board_id: int
) -> dict[str, Any]:
    session_id = str(session["id"])
    return {
        "profile": profile,
        "session_id": session_id,
        "title": f"[Hermes:{profile}] {session_id}"[:500],
        "brief": f"Passive Hermes metadata mirror for profile {profile}, session {session_id}.",
        "board_id": board_id,
    }


def event_payload(
    profile: str,
    message: dict[str, Any],
    include_excerpts: bool,
    counters: Counters,
) -> dict[str, Any]:
    role = str(message.get("role") or "unknown")
    payload: dict[str, Any] = {
        "hermes_message_id": message["id"],
        "role": role,
        "token_count": message.get("token_count"),
        "finish_reason": message.get("finish_reason"),
    }
    message_text = f"Hermes {role} message"
    if include_excerpts and message.get("content"):
        message_text = redact(str(message["content"]), counters)
    return {
        "seq": int(message["id"]),
        "timestamp": timestamp_iso8601(message["timestamp"]),
        "event_type": f"message.{role}",
        "level": "info",
        "message": message_text,
        "payload": redact(payload, counters),
    }


def timestamp_iso8601(value: Any) -> str:
    if isinstance(value, (int, float)):
        return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(value))
    text = str(value)
    if re.fullmatch(r"\d+(?:\.\d+)?", text):
        return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(float(text)))
    return text


def group_messages(messages: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for message in messages:
        grouped.setdefault(str(message["session_id"]), []).append(message)
    return grouped


def mirror_batch(
    client: ApiClient,
    source: ProfileSource,
    batch: ProfileBatch,
    settings: Settings,
    counters: Counters,
) -> None:
    for session_id, messages in group_messages(batch.messages).items():
        session = batch.sessions[session_id]
        client.post("sessions", session_payload(source.name, session, settings.board_id))
        counters.sessions += 1
        events = [
            event_payload(source.name, message, settings.include_excerpts, counters)
            for message in messages
        ]
        response = client.post(
            "events", {"profile": source.name, "session_id": session_id, "events": events}
        )
        counters.events += int(response.get("created", len(events)))
        counters.duplicates += int(response.get("duplicates", 0))
        if session.get("ended_at"):
            completion: dict[str, Any] = {
                "profile": source.name,
                "session_id": session_id,
                "terminal_state": "completed",
                "ended_at": timestamp_iso8601(session["ended_at"]),
            }
            if settings.include_excerpts:
                assistant = next(
                    (item for item in reversed(messages) if item.get("role") == "assistant"),
                    None,
                )
                if assistant and assistant.get("content"):
                    completion["outcome"] = redact(assistant["content"], counters)
            client.post("completions", completion)
            counters.completions += 1


def atomic_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise MirrorError(f"invalid sidecar state file {path.name}") from error


@contextlib.contextmanager
def process_lock(path: Path) -> Iterator[None]:
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a+b")
    try:
        if os.name == "nt":
            import msvcrt

            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl

            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    except (BlockingIOError, OSError) as error:
        raise MirrorError("another mirror sidecar already holds the lock") from error
    finally:
        handle.close()


def safe_error(error: BaseException) -> str:
    counters = Counters()
    return str(redact(str(error), counters))[:500]


def run_cycle(settings: Settings) -> int:
    state_path = settings.state_dir / "cursor.json"
    health_path = settings.state_dir / "health.json"
    state = load_json(state_path)
    client = ApiClient(settings.base_url, settings.token, settings.dry_run)
    profiles_health: dict[str, Any] = {}
    total = Counters()
    for source in settings.sources:
        cursor = Cursor.from_dict(state.get(source.name))
        batch = read_profile_batch(
            source, cursor, settings.busy_timeout_ms, settings.expected_schema
        )
        counters = Counters()
        mirror_batch(client, source, batch, settings, counters)
        if not settings.dry_run:
            state[source.name] = batch.cursor.to_dict()
            atomic_json(state_path, state)
        profiles_health[source.name] = profile_health(batch, counters)
        for key, value in counters.to_dict().items():
            setattr(total, key, getattr(total, key) + value)
    health = {
        "status": "ok",
        "hermes_commit": settings.hermes_commit,
        "hermes_version": settings.hermes_version,
        "profiles": profiles_health,
        "mirrored": total.to_dict(),
        "dry_run": settings.dry_run,
        "last_error": None,
        "checked_at": timestamp_iso8601(time.time()),
    }
    atomic_json(health_path, health)
    return sum(item["lag_seconds"] for item in profiles_health.values())


def profile_health(batch: ProfileBatch, counters: Counters) -> dict[str, Any]:
    latest = batch.cursor.timestamp
    try:
        lag = max(0, int(time.time() - float(latest)))
    except (TypeError, ValueError):
        lag = 0
    return {
        "schema": batch.schema,
        "cursor": batch.cursor.to_dict(),
        "lag_seconds": lag,
        "mirrored": counters.to_dict(),
    }


def validate_settings(settings: Settings) -> None:
    if not settings.sources:
        raise MirrorError("at least one explicit profile-to-state.db mapping is required")
    if not settings.dry_run and not settings.token:
        raise MirrorError("CLAWTROL_HERMES_MIRROR_TOKEN is required")
    if not settings.dry_run and settings.expected_schema is None:
        raise MirrorError("--expected-live-schema is required outside dry-run")
    if not settings.dry_run and settings.hermes_commit.casefold() in {"", "unknown", "main"}:
        raise MirrorError("a pinned --hermes-commit is required outside dry-run")


def settings_from_args(args: argparse.Namespace) -> Settings:
    return Settings(
        sources=args.profile_db,
        state_dir=Path(args.state_dir).expanduser(),
        base_url=args.base_url,
        token=os.environ.get("CLAWTROL_HERMES_MIRROR_TOKEN"),
        dry_run=args.dry_run,
        include_excerpts=args.include_excerpts,
        expected_schema=args.expected_live_schema,
        hermes_commit=args.hermes_commit,
        hermes_version=args.hermes_version,
        poll_seconds=args.poll_seconds,
        once=args.once,
        busy_timeout_ms=args.busy_timeout_ms,
        board_id=args.board_id,
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile-db", action="append", type=parse_profile_mapping, required=True)
    parser.add_argument("--state-dir", default=str(DEFAULT_STATE_DIR))
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--board-id", type=int, default=5)
    parser.add_argument("--expected-live-schema", type=int, choices=sorted(SUPPORTED_SCHEMAS))
    parser.add_argument("--hermes-commit", default="unknown")
    parser.add_argument("--hermes-version", default="unknown")
    parser.add_argument("--busy-timeout-ms", type=int, default=2500)
    parser.add_argument("--poll-seconds", type=float, default=30)
    parser.add_argument("--include-excerpts", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--once", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    settings = settings_from_args(parse_args(argv))
    try:
        validate_settings(settings)
        with process_lock(settings.state_dir / "mirror.lock"):
            failures = 0
            while True:
                try:
                    run_cycle(settings)
                    failures = 0
                    if settings.once:
                        return 0
                    time.sleep(settings.poll_seconds)
                except Exception as error:
                    failures += 1
                    atomic_json(
                        settings.state_dir / "health.json",
                        {
                            "status": "error",
                            "hermes_commit": settings.hermes_commit,
                            "hermes_version": settings.hermes_version,
                            "last_error": safe_error(error),
                            "checked_at": timestamp_iso8601(time.time()),
                        },
                    )
                    if settings.once:
                        raise
                    ceiling = min(300, max(settings.poll_seconds, 2**failures))
                    time.sleep(random.uniform(0, ceiling))
    except Exception as error:
        print(f"mirror failed: {safe_error(error)}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
