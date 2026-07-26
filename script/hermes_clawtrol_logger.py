#!/usr/bin/env python3
"""Mirror Hermes sessions into ClawTrol as logging-only tasks.

Read-only against Hermes: this script never calls Hermes or changes its runtime.
It polls ~/.hermes/state.db, creates/updates ClawTrol tasks via API, and appends
runtime events through existing ClawTrol hooks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

DEFAULT_STATE_DB = Path.home() / ".hermes" / "state.db"
DEFAULT_MAP_PATH = Path.home() / ".hermes" / "clawtrol-logger" / "state.json"
DEFAULT_BASE_URL = "http://127.0.0.1:4001/api/v1"
MAX_EVENT_CHARS = 1800
MAX_DESCRIPTION_CHARS = 20_000


def load_env_files() -> None:
    for path in [Path.home() / ".openclaw" / ".env", Path.home() / "clawdeck" / ".env", Path.home() / ".hermes" / ".env"]:
        if not path.exists():
            continue
        for raw in path.read_text(errors="ignore").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def request_json(method: str, url: str, token_header: str, token: str, payload: dict[str, Any] | None, dry_run: bool) -> dict[str, Any]:
    if dry_run:
        return {"dry_run": True, "method": method, "url": url, "payload": payload}
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header(token_header, token)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            return json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {url} failed HTTP {e.code}: {body[:500]}") from e


def load_map(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"sessions": {}}
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return {"sessions": {}}


def save_map(path: Path, state: dict[str, Any], dry_run: bool) -> None:
    if dry_run:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True))
    tmp.replace(path)


def fetch_sessions(db_path: Path, session_id: str | None, since_epoch: float, sources: set[str]) -> list[dict[str, Any]]:
    con = sqlite3.connect(str(db_path))
    con.row_factory = sqlite3.Row
    params: list[Any] = []
    where = []
    if session_id:
        where.append("id = ?")
        params.append(session_id)
    else:
        where.append("started_at >= ?")
        params.append(since_epoch)
        if sources:
            where.append("source in (%s)" % ",".join("?" for _ in sources))
            params.extend(sorted(sources))
    sql = "select * from sessions where " + " and ".join(where) + " order by started_at asc"
    return [dict(r) for r in con.execute(sql, params)]


def fetch_messages(db_path: Path, session_id: str, after_id: int = 0) -> list[dict[str, Any]]:
    con = sqlite3.connect(str(db_path))
    con.row_factory = sqlite3.Row
    rows = con.execute(
        "select id, role, content, tool_calls, tool_name, timestamp, token_count, finish_reason from messages where session_id = ? and id > ? order by id asc",
        (session_id, after_id),
    ).fetchall()
    return [dict(r) for r in rows]


def text_excerpt(value: Any, limit: int = 220) -> str:
    text = str(value or "").replace("\r", " ").strip()
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1].rstrip() + "…"


def session_title(session: dict[str, Any], messages: list[dict[str, Any]]) -> str:
    title = text_excerpt(session.get("title"), 180)
    if title:
        return f"[Hermes] {title}"
    first_user = next((m for m in messages if m.get("role") == "user"), None)
    return "[Hermes] " + (text_excerpt(first_user.get("content") if first_user else session.get("id"), 180) or session["id"])


def build_description(session: dict[str, Any], messages: list[dict[str, Any]]) -> str:
    first_user = next((m for m in messages if m.get("role") == "user"), {})
    last_assistant = next((m for m in reversed(messages) if m.get("role") == "assistant" and m.get("content")), {})
    lines = [
        "## Hermes Session Log",
        "",
        f"Session: `{session['id']}`",
        f"Source: `{session.get('source') or 'unknown'}`",
        f"Model: `{session.get('billing_provider') or 'unknown'}/{session.get('model') or 'unknown'}`",
        f"Messages: `{session.get('message_count') or 0}` · Tool calls: `{session.get('tool_call_count') or 0}`",
        f"Tokens: input `{session.get('input_tokens') or 0}` / output `{session.get('output_tokens') or 0}` / reasoning `{session.get('reasoning_tokens') or 0}`",
        f"Cost: `{session.get('estimated_cost_usd') if session.get('estimated_cost_usd') is not None else 'n/a'}`",
        f"Status: `{'ended' if session.get('ended_at') else 'running'}`",
        "",
        "### First user message",
        "",
        text_excerpt(first_user.get("content"), 4000) or "(none)",
        "",
        "### Latest assistant output",
        "",
        text_excerpt(last_assistant.get("content"), 4000) or "(none yet)",
    ]
    return "\n".join(lines)[:MAX_DESCRIPTION_CHARS]


def task_payload(session: dict[str, Any], messages: list[dict[str, Any]]) -> dict[str, Any]:
    model = str(session.get("model") or "hermes")[:120]
    return {
        "task": {
            "name": session_title(session, messages),
            "description": build_description(session, messages),
            "status": "in_review" if session.get("ended_at") else "in_progress",
            "model": model,
            "agent_session_id": session["id"],
            "origin_session_id": session["id"],
            "origin_session_key": f"hermes:{session['id']}",
            "tags": ["hermes", "logging", str(session.get("source") or "unknown")],
        }
    }


def event_from_message(session_id: str, msg: dict[str, Any]) -> dict[str, Any]:
    role = msg.get("role") or "unknown"
    tool_name = msg.get("tool_name")
    event_type = "tool_call" if tool_name or msg.get("tool_calls") else f"message.{role}"
    content = msg.get("content") or tool_name or msg.get("tool_calls") or ""
    return {
        "run_id": session_id,
        "seq": int(msg["id"]),
        "source": "hermes_state_db",
        "level": "info",
        "event_type": event_type,
        "message": text_excerpt(content, MAX_EVENT_CHARS),
        "created_at": msg.get("timestamp"),
        "payload": {
            "hermes_message_id": msg.get("id"),
            "role": role,
            "tool_name": tool_name,
            "token_count": msg.get("token_count"),
            "finish_reason": msg.get("finish_reason"),
        },
    }


def stable_uuid(text: str) -> str:
    h = hashlib.md5(text.encode("utf-8")).hexdigest()
    return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


def sync(args: argparse.Namespace) -> int:
    load_env_files()
    api_token = os.environ.get("CLAWTROL_API_TOKEN")
    if not api_token:
        raise SystemExit("Missing CLAWTROL_API_TOKEN")

    db_path = Path(args.db).expanduser()
    state_path = Path(args.state).expanduser()
    state = load_map(state_path)
    session_map = state.setdefault("sessions", {})
    base = args.base_url.rstrip("/")
    since = time.time() - args.lookback_hours * 3600
    sources = {s.strip() for s in args.sources.split(",") if s.strip()}
    sessions = fetch_sessions(db_path, args.session_id, since, sources)
    changed = 0

    for session in sessions:
        sid = session["id"]
        info = session_map.setdefault(sid, {})
        messages = fetch_messages(db_path, sid)
        if not messages and not args.include_empty:
            continue

        payload = task_payload(session, messages)
        if info.get("task_id"):
            task_id = info["task_id"]
            request_json("PATCH", f"{base}/tasks/{task_id}", "Authorization", f"Bearer {api_token}", payload, args.dry_run)
        else:
            created = request_json("POST", f"{base}/tasks", "Authorization", f"Bearer {api_token}", payload, args.dry_run)
            task_id = created.get("id") or created.get("task", {}).get("id") or created.get("task_id")
            if args.dry_run:
                task_id = f"dry-{sid}"
            if not task_id:
                raise RuntimeError(f"Could not resolve task id from create response for {sid}: {created}")
            info["task_id"] = task_id
            changed += 1

        after_id = int(info.get("last_message_id") or 0)
        new_messages = fetch_messages(db_path, sid, after_id)
        events = [event_from_message(sid, m) for m in new_messages]
        if events:
            request_json(
                "POST",
                f"{base}/tasks/{task_id}/log_events",
                "Authorization",
                f"Bearer {api_token}",
                {
                    "session_id": sid,
                    "run_id": sid,
                    "events": events,
                },
                args.dry_run,
            )
            info["last_message_id"] = max(int(m["id"]) for m in new_messages)
            changed += len(events)

        if session.get("ended_at") and not info.get("completion_logged"):
            request_json(
                "POST",
                f"{base}/tasks/{task_id}/log_events",
                "Authorization",
                f"Bearer {api_token}",
                {
                    "session_id": sid,
                    "run_id": sid,
                    "events": [{
                        "run_id": sid,
                        "seq": int(info.get("last_message_id") or 0) + 1,
                        "event_type": "final_summary",
                        "source": "hermes_state_db",
                        "level": "info",
                        "message": f"Hermes session ended: {sid}",
                        "payload": {"ended_at": session.get("ended_at"), "completion_run_id": stable_uuid(sid)},
                    }],
                },
                args.dry_run,
            )
            info["completion_logged"] = True
            changed += 1

        info["last_seen_at"] = time.time()
        info["source"] = session.get("source")
        info["title"] = session.get("title")

    save_map(state_path, state, args.dry_run)
    if args.verbose or args.dry_run:
        print(json.dumps({"sessions_seen": len(sessions), "changes": changed, "dry_run": args.dry_run}, indent=2))
    return 0


def self_test() -> int:
    assert text_excerpt(" a\n b  c ", 20) == "a b c"
    assert stable_uuid("abc") == stable_uuid("abc")
    s = {"id": "sess1", "source": "telegram", "model": "gpt", "billing_provider": "codex", "message_count": 1, "tool_call_count": 0}
    m = [{"id": 1, "role": "user", "content": "hello", "timestamp": 1.0}]
    assert task_payload(s, m)["task"]["agent_session_id"] == "sess1"
    assert event_from_message("sess1", {"id": 2, "role": "assistant", "content": "ok"})["event_type"] == "message.assistant"
    print("self-test ok")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Mirror Hermes sessions to ClawTrol for logging only")
    parser.add_argument("--db", default=str(DEFAULT_STATE_DB))
    parser.add_argument("--state", default=str(DEFAULT_MAP_PATH))
    parser.add_argument("--base-url", default=os.environ.get("CLAWTROL_BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--lookback-hours", type=float, default=6)
    parser.add_argument("--sources", default="telegram,cron,cli")
    parser.add_argument("--session-id")
    parser.add_argument("--include-empty", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    return sync(args)


if __name__ == "__main__":
    raise SystemExit(main())
