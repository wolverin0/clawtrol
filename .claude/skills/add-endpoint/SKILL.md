---
name: add-endpoint
description: Use when the user wants to add a new API endpoint, route, or handler. Enforces the "search before adding" discipline that prevents duplicate endpoints — the most common vibe-coding failure mode. Activate any time the request mentions adding a route, endpoint, handler, controller, or HTTP method.
---

# Skill: Add an API Endpoint

This skill enforces the discipline that prevents you from adding the 4th
endpoint that returns user data when 3 already exist.

## Phase 1 — Search before adding (MANDATORY, do not skip)

Before writing any code, do all four:

1. **Read the API catalog.** Open `@.claude/context/api-catalog.md` and read it
   end-to-end. Does an existing endpoint cover this concern? If yes, STOP.
   Either use it, or extend it. Do not write a parallel endpoint.

2. **Grep for similar handlers.** Search `src/routes/` and `src/handlers/` for
   keywords related to the resource:
   ```
   grep -ri "<resource_name>" src/routes/
   grep -ri "<verb_or_action>" src/routes/
   ```
   Read every hit before proceeding.

3. **Check the deprecated list.** Some endpoints in `api-catalog.md` are
   marked deprecated (have a "use X instead" note). If your concern matches
   one of those, the user probably wants the canonical endpoint extended,
   not a fresh one.

4. **Confirm with the user if anything is ambiguous.** Specifically ask:
   - Is this a new resource, or a new operation on an existing resource?
   - Should this be public, auth-required, or admin-only?
   - Is there a similar endpoint already that you want me to extend instead?

   Do not guess on any of these. Ask.

## Phase 2 — Design checklist

Before writing the route, confirm each:

- ☐ Path follows REST conventions: `/<resource>` (collection), `/<resource>/{id}` (item)
- ☐ HTTP method matches semantics: GET (read), POST (create), PATCH (partial update), PUT (full replace), DELETE
- ☐ Auth requirement is explicit and matches similar endpoints in the catalog
- ☐ Input validation uses our project's standard validator (Pydantic v2 in this repo)
- ☐ Output schema does NOT include sensitive fields (password_hash, internal_id, raw db row)
- ☐ Error responses follow the project's standard error shape
- ☐ The endpoint's effect is idempotent if it's GET/PUT/DELETE; non-idempotent if POST/PATCH
- ☐ User identity comes from the auth token, NOT from the request body or query string
- ☐ If the endpoint reads from the DB, it filters `deleted_at IS NULL` (or queries the soft-delete view)
- ☐ Rate limiting is applied (or explicitly noted as not needed)

## Phase 3 — Implementation pattern

Follow the existing pattern in `src/routes/`. Specifically:

1. Define the request/response schemas with Pydantic
2. Implement the handler in `src/services/<resource>.py` (business logic)
3. Wire the route in `src/routes/<resource>.py` (HTTP concerns only)
4. Add the route to the router in `src/main.py` if a new router

Do NOT inline business logic in the route handler. Routes are thin; services are fat.

## Phase 4 — Update the catalog (MANDATORY)

In the same commit as the route, update `.claude/context/api-catalog.md` with
the new endpoint's row. If you don't, the next session won't know it exists,
and someone will eventually duplicate it.

## Phase 5 — Tests

Write at least three tests:

1. **Happy path:** valid input, expected output
2. **Auth failure:** call without auth, expect 401
3. **Validation failure:** malformed input, expect 4xx with structured error

Bonus tests:

- IDOR test: try to access another user's resource, expect 403/404
- Empty/null/oversized input tests (the AI-generated test suites that pass
  but never exercised these cases is the "asserting the same mistake twice"
  failure mode from the audit prompt)

## Phase 6 — Verification

Before declaring done:

- ☐ Run the tests: `pytest tests/routes/test_<resource>.py`
- ☐ Run the full test suite: `pytest`
- ☐ Manually curl the endpoint with a real auth token
- ☐ Manually curl WITHOUT a token and confirm 401
- ☐ Verify the api-catalog.md update is in your diff

## Anti-patterns to refuse

If the user asks for any of these, push back before implementing:

- ❌ Endpoint that takes `user_id` from the request body — re-derive from auth
- ❌ Endpoint that returns `SELECT *` of a row — return only needed fields
- ❌ Endpoint without rate limiting on a write or expensive operation
- ❌ Endpoint that bypasses signature verification on a webhook
- ❌ Adding a 4th endpoint that does what 3 existing endpoints already do
