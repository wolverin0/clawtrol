# Architecture Decisions

<!--
═══════════════════════════════════════════════════════════════════════════════
WHAT THIS FILE IS

A running log of architectural choices and the reasoning behind them. ADR =
Architecture Decision Record. One entry per decision. Newest at the top.

WHY THIS FILE EXISTS

The model has no memory of why you chose Supabase over Postgres-on-Oracle, or
why you decided NOT to use Redis even though it would speed up X. Without
this file, the next session will "helpfully" suggest reverting the very
decisions you carefully made — because the alternative is more common in
training data.

Every time the agent surprises you by suggesting a change you already
considered and rejected, add a new ADR. Future-you will thank present-you.

FORMAT

Each ADR has the same shape:
  - Decision (one sentence, present tense)
  - Date
  - Status (active / superseded by ADR-XXX)
  - Context (what we were deciding between)
  - Reasoning (why we chose this)
  - Tradeoffs (what we're explicitly accepting)
  - Triggers for revisiting (what would change our minds)

KEEP IT SHORT
  3-5 sentences per section. ADRs are not essays.
═══════════════════════════════════════════════════════════════════════════════
-->

## ADR-005: Use Supabase for auth, not custom JWT

- **Date:** 2025-08-12
- **Status:** Active

**Context:** We needed user auth. Options were (a) Supabase Auth, (b) custom JWT with our own user table, (c) Auth0/Clerk.

**Reasoning:** Supabase Auth ships with row-level-security (RLS) integration we need anyway. Custom JWT means we have to reimplement password reset, email verification, OAuth. Auth0 adds a vendor + cost we don't need at our scale.

**Tradeoffs:** Tied to Supabase. Migrating later means rebuilding auth.

**Triggers for revisiting:** If we leave Supabase, or if we hit Supabase Auth limits (currently fine to ~10k users on the free tier).

---

## ADR-004: PostgreSQL only, no Redis (for now)

- **Date:** 2025-07-01
- **Status:** Active

**Context:** We considered adding Redis for caching and rate limiting. Postgres can do both at our current scale.

**Reasoning:** Adding Redis means a second persistence layer to monitor, back up, and reason about. Postgres `LISTEN/NOTIFY` handles our pub-sub case. Postgres advisory locks handle our queue dedup. We're at <100 req/s; the perf headroom is enormous.

**Tradeoffs:** If our QPS jumps 10×, we'll need to revisit. Some patterns are awkward in Postgres that would be one line in Redis.

**Triggers for revisiting:** Sustained >500 req/s, or session-store latency p95 >100ms.

---

## ADR-003: All async, no sync DB calls

- **Date:** 2025-06-22
- **Status:** Active

**Context:** Mixing `asyncio` with sync DB drivers (psycopg2) causes thread-pool exhaustion under load.

**Reasoning:** Standardizing on `asyncpg` (via SQLAlchemy 2.0 async) means one execution model. Easier to reason about, easier to test, no event-loop blocking.

**Tradeoffs:** Some libraries we'd otherwise use are sync-only and we have to find async alternatives or wrap them.

**Triggers for revisiting:** If we ever need to call out to a sync-only library that's load-bearing.

---

## ADR-002: No `localStorage` for auth tokens

- **Date:** 2025-06-15
- **Status:** Active

**Context:** Many AI-generated examples store JWT in localStorage. This is XSS-exploitable.

**Reasoning:** httpOnly cookies cannot be read by JS, so XSS can't steal them. Auth state lives server-side; the cookie is opaque.

**Tradeoffs:** Slightly more work for SPA state management. CSRF needs separate handling (we use SameSite=lax + double-submit pattern).

**Triggers for revisiting:** Never.

---

## ADR-001: Soft-delete with `deleted_at`, never hard-delete user data

- **Date:** 2025-06-01
- **Status:** Active

**Context:** Hard deletes break foreign-key history. We need GDPR-style erasure occasionally but most "deletes" are user-initiated mistakes.

**Reasoning:** `deleted_at` timestamp on every user-data table. All read queries filter `WHERE deleted_at IS NULL`. A separate `gdpr_erase_user(user_id)` function handles legal erasure cases.

**Tradeoffs:** Every read query has to filter. If a query forgets, deleted data leaks. We mitigate with a Postgres view per table that pre-filters; the agent should query the view, not the raw table.

**Triggers for revisiting:** If we hit performance issues from the filter.

<!--
═══════════════════════════════════════════════════════════════════════════════
TEMPLATE FOR NEW ADRs

## ADR-XXX: [One-sentence decision]

- **Date:** YYYY-MM-DD
- **Status:** Active | Superseded by ADR-YYY

**Context:** What were we deciding between?

**Reasoning:** Why did we pick this?

**Tradeoffs:** What are we accepting in exchange?

**Triggers for revisiting:** What would make us reconsider?
═══════════════════════════════════════════════════════════════════════════════
-->
