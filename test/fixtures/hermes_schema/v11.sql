PRAGMA user_version = 11;
CREATE TABLE sessions (id TEXT PRIMARY KEY, title TEXT, source TEXT, model TEXT, started_at REAL, ended_at REAL, message_count INTEGER);
CREATE TABLE messages (id INTEGER PRIMARY KEY, session_id TEXT, timestamp REAL, role TEXT, content TEXT, token_count INTEGER, finish_reason TEXT);
INSERT INTO sessions VALUES ('session-11', 'Private title', 'cli', 'model-11', 1000, 1002, 2);
INSERT INTO messages VALUES (1, 'session-11', 1001, 'user', 'secret_token=hidden', 4, NULL);
INSERT INTO messages VALUES (2, 'session-11', 1002, 'assistant', 'Bearer should-not-leak-123456789', 6, 'stop');
