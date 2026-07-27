PRAGMA user_version = 17;
CREATE TABLE sessions (id TEXT PRIMARY KEY, title TEXT, source TEXT, model TEXT, started_at REAL, ended_at REAL, message_count INTEGER);
CREATE TABLE messages (id INTEGER PRIMARY KEY, session_id TEXT, timestamp REAL, role TEXT, content TEXT, token_count INTEGER, finish_reason TEXT, tool_name TEXT, tool_calls TEXT);
INSERT INTO sessions VALUES ('session-17', 'Private title', 'cli', 'model-17', 1000, 1002, 2);
INSERT INTO messages (id, session_id, timestamp, role, content, token_count, finish_reason, tool_name, tool_calls) VALUES (1, 'session-17', 1001, 'user', 'secret_token=hidden', 4, NULL, NULL, '{"api_key":"hidden"}');
INSERT INTO messages (id, session_id, timestamp, role, content, token_count, finish_reason, tool_name, tool_calls) VALUES (2, 'session-17', 1002, 'assistant', 'Bearer should-not-leak-123456789', 6, 'stop', NULL, NULL);
