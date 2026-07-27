from __future__ import annotations

import argparse
import importlib.util
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "script" / "hermes_clawtrol_logger.py"
SPEC = importlib.util.spec_from_file_location("hermes_mirror_sidecar", SCRIPT)
sidecar = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
sys.modules[SPEC.name] = sidecar
SPEC.loader.exec_module(sidecar)


class HermesMirrorSidecarTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp.name)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def database_from_fixture(self, version: int) -> Path:
        database = self.temp_path / f"state-{version}.db"
        sql = (ROOT / "test" / "fixtures" / "hermes_schema" / f"v{version}.sql").read_text()
        connection = sqlite3.connect(database)
        connection.executescript(sql)
        connection.close()
        return database

    def test_supported_schema_fixtures_are_read_with_timestamp_and_id_cursor(self) -> None:
        for version in sorted(sidecar.SUPPORTED_SCHEMAS):
            with self.subTest(version=version):
                source = sidecar.ProfileSource(f"profile-{version}", self.database_from_fixture(version))
                batch = sidecar.read_profile_batch(source, sidecar.Cursor(), 100)
                self.assertEqual(version, batch.schema)
                self.assertEqual([1, 2], [item["id"] for item in batch.messages])
                self.assertEqual(1002, batch.cursor.timestamp)
                self.assertEqual(2, batch.cursor.message_id)
                replay = sidecar.read_profile_batch(source, batch.cursor, 100)
                self.assertEqual([], replay.messages)

    def test_database_connection_is_query_only(self) -> None:
        database = self.database_from_fixture(23)
        with sidecar.open_readonly(database, 100) as connection:
            with self.assertRaises(sqlite3.OperationalError):
                connection.execute("INSERT INTO sessions (id) VALUES ('mutated')")

    def test_unsupported_schema_fails_closed(self) -> None:
        database = self.temp_path / "unsupported.db"
        connection = sqlite3.connect(database)
        connection.executescript(
            "PRAGMA user_version=99; CREATE TABLE sessions(id TEXT);"
            "CREATE TABLE messages(id INTEGER, session_id TEXT, timestamp REAL);"
        )
        connection.close()
        source = sidecar.ProfileSource("unsupported", database)
        with self.assertRaisesRegex(sidecar.MirrorError, "unsupported Hermes schema 99"):
            sidecar.read_profile_batch(source, sidecar.Cursor(), 100)

    def test_metadata_only_event_excludes_content_and_tool_data(self) -> None:
        counters = sidecar.Counters()
        event = sidecar.event_payload(
            "primary",
            {
                "id": 1,
                "timestamp": 1001,
                "role": "assistant",
                "content": "Bearer should-not-leak-123456789",
                "tool_calls": {"api_key": "hidden"},
            },
            False,
            counters,
        )
        serialized = json.dumps(event)
        self.assertEqual("Hermes assistant message", event["message"])
        self.assertNotIn("should-not-leak", serialized)
        self.assertNotIn("tool_calls", serialized)

    def test_excerpt_opt_in_recursively_redacts(self) -> None:
        counters = sidecar.Counters()
        cleaned = sidecar.redact(
            {
                "nested": [{"api_key": "hidden"}],
                "text": "Authorization: Bearer should-not-leak-123456789",
            },
            counters,
        )
        serialized = json.dumps(cleaned)
        self.assertNotIn("hidden", serialized)
        self.assertNotIn("should-not-leak", serialized)
        self.assertGreaterEqual(counters.redactions, 2)

    def test_all_profile_mapping_is_rejected(self) -> None:
        with self.assertRaises(argparse.ArgumentTypeError):
            sidecar.parse_profile_mapping(f"ALL={self.temp_path / 'state.db'}")

    def test_atomic_json_replaces_complete_document(self) -> None:
        path = self.temp_path / "state" / "health.json"
        sidecar.atomic_json(path, {"status": "ok", "cursor": {"message_id": 2}})
        self.assertEqual("ok", json.loads(path.read_text())["status"])
        self.assertEqual([], list(path.parent.glob("*.tmp")))


if __name__ == "__main__":
    unittest.main()
