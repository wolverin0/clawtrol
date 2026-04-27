# AI-to-AI Blind Spots — B1 through B15

These are patterns that look correct to AI reviewers because they share
training-corpus idioms with the code being reviewed. A naive "review
this code" prompt will miss them every time, because the reviewing model
recognizes the *shape* and assumes the *substance*.

This file catalogs each blind spot with the specific check that catches
it. The `audit-blind-spots` skill loads this file and walks through each
B-class systematically.

---

## B1 — Auth present but not wired

**The pattern:** Authentication middleware/decorator exists in the
codebase. It's well-written. It would catch unauthenticated requests
correctly. But the route in question doesn't use it.

**Why AI misses it:** The reviewing model sees the auth middleware in
`middleware/auth.py`, sees the route file, and assumes they're connected
because that's how it works in 99% of training data.

**Detection:**

```bash
# 1. Find the auth middleware/decorator
grep -rEn "def get_current_user|def require_auth|def authenticate" src/ \
  --include="*.py"

# 2. Find every route definition
grep -rEn "@(app|router)\.(get|post|put|patch|delete)" src/ --include="*.py"

# 3. For each route, check whether the handler signature includes a
#    Depends(get_current_user) or equivalent. If not, that's B1.
```

**Evidence shape:**

```
B1 finding — Auth middleware not wired
Middleware: src/middleware/auth.py:get_current_user
Unwired routes (auth missing in handler signature):
  - app/routes/users.py:42  POST /users/{id}/promote — should require admin
  - app/routes/billing.py:78  DELETE /invoices/{id} — should require auth
  - app/routes/admin.py:120  POST /admin/run-job — should require admin
```

---

## B2 — Error handlers returning success

**The pattern:** A `try/except` block catches an exception, but does
nothing with it (or just logs to nowhere) and returns a 200/success
response.

**Why AI misses it:** The structure looks correct. There's error
handling! The reviewer thinks "good defensive coding" without noticing
the side effect was lost.

**Detection:**

```bash
# Python — find except clauses with pass/log-only/swallow
grep -rEnB1 -A5 "except.*:" src/ --include="*.py" | \
  grep -iE "(pass|return\s+(\{|true|None|HttpResponse|.*ok)|continue)"

# Look for the "swallow then 200" pattern
grep -rEnA10 "try:" src/ --include="*.py" | \
  grep -B5 -A2 "return.*200\|status_code=200\|HTTP_200"
```

**The exact pattern:**

```python
try:
    await charge_customer(amount)
    await update_invoice(invoice_id, "paid")
except Exception as e:
    logger.warning(f"payment failed: {e}")  # logs but doesn't raise
    return {"status": "ok"}  # caller has no idea it failed
```

The caller marks the invoice paid in the UI. The customer wasn't
actually charged. Found in production after a week of "free" service.

---

## B3 — Frontend-only pagination

**The pattern:** UI paginates with "Load more" or page numbers. The
backend query returns ALL rows; the frontend slices.

**Why AI misses it:** The frontend looks paginated. The reviewing model
sees `page` and `pageSize` in the API response and assumes the backend
respects them.

**Detection:**

```bash
# Find queries that return everything
grep -rEn "SELECT \*|\.find\(\)\s*\.limit|\.findMany\(\)" src/ \
  --include="*.py" --include="*.ts"

# Look for handlers that take a page param but don't use it
grep -rEn "page:\s*int|page=Query|page=req\." src/ --include="*.py" --include="*.ts"
```

For each handler that accepts pagination params, verify the params
actually reach the DB query as `LIMIT`/`OFFSET` or cursor.

**Why this matters:** Works fine for 100 rows. Catastrophic for
1,000,000. The audit is for "what happens when this scales," not "does
it work today."

---

## B4 — Soft-delete never filtered

**The pattern:** Tables have a `deleted_at` (or `is_deleted`, or
`archived`) column. Queries don't filter on it. Deleted rows show up
in lists, in user-facing data, in admin reports.

**Detection:**

```bash
# Find tables with soft-delete columns
grep -rEn "deleted_at|is_deleted|archived_at\b" src/ --include="*.py" --include="*.ts"

# Find every SELECT and verify it filters when querying tables that have
# a deleted_at column. This typically requires reading each query.
```

The opposite pattern (over-filtering) also exists: a function that
SHOULD return deleted records (admin recovery view) but filters them
out anyway. Both directions are findings.

---

## B5 — Env var existence-only checks

**The pattern:** `if (process.env.STRIPE_KEY)` — checks the variable is
set, but never validates the value is not empty, not a placeholder, not
the test key in production.

**Detection:**

```bash
grep -rEn "if\s*\(?\s*process\.env\.|if\s+os\.environ\.get|if\s+os\.getenv" src/

# Look for placeholder values that shipped
grep -rEn "(your_key_here|YOUR_API_KEY|change_me|placeholder|sk_test_|TODO)" \
  .env.example .env 2>/dev/null
```

The classic case: `STRIPE_KEY=sk_test_...` in production because nobody
caught that the production env file copied the example.

---

## B6 — Single-user connection assumptions

**The pattern:** Code assumes one concurrent user. DB pool size 1.
In-memory session store. Module-level mutable state. Cache that doesn't
key by user.

**Detection:**

```bash
# Module-level mutables
grep -rEn "^(USER|CURRENT|GLOBAL|_state|cache)\s*=\s*\{|^(USER|CURRENT|GLOBAL|_state|cache)\s*=\s*\[" src/

# Tiny connection pools
grep -rEn "pool_size\s*[:=]\s*1\b|max_connections\s*[:=]\s*1\b|maxConnections:\s*1" src/

# In-memory session
grep -rEn "SESSION\s*=\s*\{|sessions\s*=\s*\{|SESSION_STORE\s*=" src/
```

**Why it's a blind spot:** Works fine in dev (one user — you). Falls
over the first time two users do anything at the same time.

---

## B7 — Validation asymmetry

**The pattern:** Frontend validates (zod, react-hook-form, formik),
backend accepts whatever bytes arrive. Or the reverse: backend validates,
but frontend reports success before the call is made.

**Detection:**

```bash
# Find frontend validators
grep -rEn "zod\.|yup\.|Joi\.|validator\." src/

# Find every backend endpoint that takes a body, verify it has a schema
grep -rEn "BaseModel|pydantic|@app\.post|router\.post" src/

# Cross-reference: any endpoint without server-side validation = B7
```

**Worst-case manifestation:** Client validates email format, server
takes the email field as a literal string and inserts it into SQL.

---

## B8 — Authorization gap (IDOR)

**The pattern:** User is authenticated. The endpoint checks "is this a
logged-in user?" but not "does this user own this resource?"

`GET /invoices/{id}` returns the invoice if the user is logged in. Any
user can change the URL and read any other user's invoices.

**Detection:**

```bash
# Endpoints that take an ID param
grep -rEn "/{id}|/<int:id>|/:\w+\b" src/

# For each, read the handler. Look for:
#   - Where does the resource get fetched? (db.get(id))
#   - Is there a user-ownership check? (resource.owner_id == user.id)
# If not, it's B8.
```

**The hard finding:** Endpoint takes user_id from request body or query
string, like `GET /invoices?user_id=42`. That's not authorization at
all; that's "type any number you want." Should be re-derived from the
auth token.

---

## B9 — Dead imports / unreachable utilities

**The pattern:** A `utils/` or `helpers/` directory full of functions
that nothing imports. They were written, copy-pasted, or AI-generated,
then forgotten.

**Detection:**

```bash
# Find every export in utils/
grep -rEn "^export (function|const|class)|^(def |class )" src/utils/ src/helpers/

# For each, search the rest of the codebase for imports
# Anything with zero importers = B9
```

**Why it matters:** Dead code is a maintenance liability. It looks like
shared infrastructure but isn't. Future developers might use it,
discover it's broken (because nothing exercises it), and lose hours.

---

## B10 — Optimistic UI without rollback

**The pattern:** UI updates immediately to show success. The server call
happens in the background. If the server returns an error, there's no
revert path; the UI stays in the success state.

**Detection:**

```bash
# Find optimistic-update patterns
grep -rEn "optimistic|setState.*before|setQuery.*\.setData" src/ --include="*.tsx" --include="*.ts"

# For each, check whether there's an `onError` rollback
```

**Manifestation:** User clicks "Delete." UI removes the item. The DELETE
fails (network, permission). UI never re-shows the item. User refreshes
hours later and is confused.

---

## B11 — Webhook idempotency missing

**The pattern:** Payment / event webhooks process the body without
checking whether they've seen the event before. Provider retries on
network blip = double-charge / double-credit / duplicate work.

**Detection:**

```bash
# Find webhook handlers
grep -rEn "/webhook|webhooks/" src/

# For each, look for an idempotency check
grep -rEn "event_id|deliveryId|idempotency_key" src/

# Look for a dedup table
grep -rEn "webhook_events|processed_events|seen_events" src/
```

**The fix-pattern:** A dedup table keyed on `(provider, event_id)`,
checked atomically in the same transaction as the side effect.

---

## B12 — Stack mixing

**The pattern:** Multiple state libraries (redux + zustand + jotai),
multiple HTTP clients (axios + fetch + ky), multiple auth patterns
(cookies in some routes, JWT in others, session in others), multiple
ORMs.

**Why it's a blind spot:** Each individual choice looks reasonable.
Together they make the codebase a museum of failed migrations.

**Detection:** Read the dependency manifest. Look for clusters:

| Cluster | Watch for |
|---|---|
| HTTP client | `requests` + `httpx`, `axios` + `fetch`, `ky` + others |
| State (FE) | `redux` + `zustand` + `jotai` + `recoil` |
| Date | `moment` + `date-fns` + `dayjs` + `luxon` |
| Validation | `zod` + `yup` + `joi` + `pydantic-v1` + `pydantic-v2` |
| Auth (BE) | cookie-session + JWT + opaque tokens |

---

## B13 — Test mirrors code (Tambon failure mode)

**The pattern:** AI wrote both the implementation and the tests in the
same session. The test mocks every dependency. The assertions confirm
the implementation does what it does — not what the spec requires.

This is one of the most dangerous patterns because it produces high
coverage with zero protection against regressions of intended behavior.

**Detection:** Heuristic, not deterministic. Signals:

- Tests in critical-flow modules (payments, auth) have heavy `patch` /
  `mock` use
- Tests use `MagicMock(return_value=expected)` followed by an assertion
  that the function returned `expected`
- Test file was created in the same commit as the source file
- Test file has no integration test — every test mocks

**Action:** Write a real integration test for at least one path through
the critical flow. Mark the AI-written tests as inadequate but keep them.

---

## B14 — Comment-code drift

**The pattern:** A docstring or comment describes behavior the code
doesn't have. Common after AI-assisted refactoring — the model updates
the implementation but leaves the comment.

**Detection:** Hard to do mechanically. Best approach:

1. Find every public function in the auth/payment/delete paths
2. Read the docstring
3. Read the body
4. Ask: does the body do what the docstring claims?

Spend the most time on functions where the docstring asserts a security
or correctness property ("validates input," "checks authorization,"
"sanitizes HTML"). If the docstring lies, that's the worst case.

---

## B15 — Coverage theater

**The pattern:** Coverage % is high. The tests run lots of lines. But
adversarial inputs are never tested:

- Empty arrays, null fields, undefined values
- Malformed JSON
- Oversized payloads
- Unicode edge cases
- Missing required fields
- Numeric overflow / underflow
- SQL injection inputs
- Path traversal inputs

**Detection:** Read the test files for each domain. Count tests by
category:

| Category | Count expected (per critical endpoint) |
|---|---|
| Happy path | 1+ |
| Auth failure (401) | 1 |
| Authorization failure (403) | 1 |
| Validation failure (400 with bad input) | 2-3 (different bad inputs) |
| Boundary cases (empty, null, oversized) | 2-3 |
| Adversarial input (SQLi, XSS, path traversal) | 1-2 |
| Idempotency / replay | 1 (for webhooks) |

If you see "1 happy path test, 92% coverage" — that's B15. The 92%
covers what the test exercised, which was the success path.

---

## How the blind-spots audit produces output

For each B1-B15:

```
BLIND SPOT: B<N> — <n>
Status: PRESENT | NOT PRESENT | INCONCLUSIVE
If PRESENT:
  Evidence:
    <path:line>  <one-line description>
    [additional locations]
  Severity: Critical | High | Medium | Low
  Exploitability: EXPLOITABLE-NOW | EXPLOITABLE-LOW-EFFORT | BAD-PRACTICE
```

After the systematic walk, the blind-spots report includes a summary:

```
BLIND SPOT SUMMARY
Present: <count> of 15
Critical findings: <list>
High findings: <list>
Most pervasive (appears in many places): <which one>
```
