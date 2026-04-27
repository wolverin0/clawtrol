# API Catalog

<!--
═══════════════════════════════════════════════════════════════════════════════
WHAT THIS FILE IS

A single-source-of-truth list of every API endpoint in this codebase. The
agent reads this on demand (via `@.claude/context/api-catalog.md`) before
adding new endpoints, to avoid the most common vibe-coding failure mode:
inventing a new endpoint when one already exists.

This is the "labeled pantry" in the kitchen analogy. Don't preload it.
Reference it when relevant.

WHY THIS FILE EXISTS

LLMs cannot see what already exists in your repo unless explicitly told
to look. Without this file, the agent will happily write `/api/profile`
when `/api/users/me` already does the same thing. Six months later you
have three endpoints returning user data, slightly differently, all
needing to be maintained.

HOW TO MAINTAIN IT

Two options:
  (a) Manually update this file every time you add an endpoint. Reliable
      but disciplined.
  (b) Auto-generate from your route definitions. For FastAPI:
      `python -m scripts.generate_api_catalog > .claude/context/api-catalog.md`
      For Express/Next.js, write a similar script.

Option (b) is better. Set up a hook that regenerates this file on every
commit (see .claude/hooks/post-commit-regen-catalog.sh).

WHAT NOT TO PUT HERE

- Implementation details. This is a directory, not the code.
- Internal helper functions. Only HTTP-facing endpoints.
- Frontend routes (those go in a separate `route-catalog.md`).
═══════════════════════════════════════════════════════════════════════════════
-->

## Authentication endpoints

| Method | Path | Auth | Handler | Purpose |
|---|---|---|---|---|
| POST | /auth/login | none | `auth.routes.login` | Issue session cookie from email/password |
| POST | /auth/logout | session | `auth.routes.logout` | Invalidate current session |
| POST | /auth/refresh | refresh_token | `auth.routes.refresh` | Rotate session token |
| GET | /auth/me | session | `auth.routes.current_user` | Return current user (canonical — do not duplicate) |

## User endpoints

| Method | Path | Auth | Handler | Purpose |
|---|---|---|---|---|
| GET | /users/me | session | `users.routes.me` | **Use `/auth/me` instead.** Deprecated. |
| GET | /users/{id} | session + admin | `users.routes.get` | Admin-only user lookup |
| PATCH | /users/{id} | session + (self OR admin) | `users.routes.update` | Update profile fields |
| DELETE | /users/{id} | session + admin | `users.routes.delete` | Soft-delete (sets deleted_at) |

<!--
NOTE THE PATTERN: when you find duplicate endpoints, mark one canonical
and the other deprecated. Eventually delete the deprecated one. Do not
just leave both running.
-->

## [Add your domain endpoints here, one section per resource]

## Webhooks (incoming)

| Method | Path | Auth | Handler | Signature verification | Idempotency |
|---|---|---|---|---|---|
| POST | /webhooks/mercadopago | signature | `payments.webhooks.mercadopago` | ✅ via `x-signature` header | ✅ via `event_id` dedup table |
| POST | /webhooks/stripe | signature | `payments.webhooks.stripe` | ✅ via `Stripe-Signature` header | ✅ via `event_id` dedup table |

<!--
EVERY webhook row MUST show signature verification AND idempotency status.
If either is ❌, that's an audit-worthy finding. The audit prompt will
catch it; this catalog catches it before it ships.
-->

## Background jobs / cron

| Schedule | Handler | Purpose | Idempotent? | Max retries |
|---|---|---|---|---|
| `0 * * * *` | `jobs.invoice_aging.scan` | Mark overdue invoices | ✅ | 3 |
| `*/5 * * * *` | `jobs.outage_detector.scan` | Compare last-seen to threshold | ✅ | unlimited |

## Forbidden endpoint patterns

When asked to add an endpoint, refuse and propose an alternative if it matches:

- ❌ `GET /admin/...` without an admin-role check in the handler
- ❌ Any endpoint that accepts `user_id` from the request body or query string (re-derive from auth)
- ❌ `POST` endpoints that return the full database row (return only the fields the caller needs)
- ❌ Endpoints that take a SQL fragment, ORDER BY column, or sort direction directly from the client
- ❌ Endpoints duplicating one already in this catalog (search before adding)

## Search-before-adding checklist

Before adding a new endpoint:

1. ☐ Read this file end-to-end. Does an endpoint already cover this concern?
2. ☐ `grep -r "<resource_name>" src/routes/` — confirm no parallel implementation
3. ☐ If the existing endpoint is close-but-not-quite, **extend it** instead of writing a new one
4. ☐ If you genuinely need a new endpoint, add it to this catalog in the same commit as the route definition
5. ☐ Confirm the endpoint follows the auth/idempotency/signature rules above

<!-- scaffold:filled 2026-04-27T12:31:51Z -->

## Auto-detected endpoints

Best-effort grep over likely route directories. **Add manually:**
the `Auth` column (which middleware), the `Purpose` column,
and any endpoints the grep missed (programmatic routes,
router.use chains, etc).

| Method | Path | File:line | Auth | Purpose |
|---|---|---|---|---|

