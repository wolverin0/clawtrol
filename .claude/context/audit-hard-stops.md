# Hard Stops Catalog — H1 through H9

Nine conditions that, if present, force the audit verdict to **CRITICAL —
DO NOT LAUNCH** regardless of any other findings. A single H-class
finding is worse than ten Mediums.

The hard-stops audit runs FIRST, before any domain skill. If a hard stop
is found, the orchestrator emits the `🛑 HARD STOP` block at the top of
the report and may proceed with domain audits, but the verdict is locked.

This file is loaded by the `audit-hard-stops` skill. Each entry includes
the detection commands so the audit is reproducible — the reader can run
the same commands and get the same result.

---

## H1 — Row-level access control disabled on user data

**What it is:** Tables containing user data are accessible without RLS
(Postgres) or equivalent app-level enforcement. Any authenticated user
(or, with a leaked anon key, anyone) can read any row.

**Why it's a hard stop:** Single biggest data-breach vector in
Supabase / PostgREST stacks. The default-permissive Postgres pattern is
"if you can connect, you can read everything," and many vibe-coded apps
ship with it.

**Detection — Postgres / Supabase:**

```sql
-- Run against the audited database
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname IN ('public', 'auth')
  AND rowsecurity = false;
```

Any returned row in a table containing user data = H1.

**Detection — non-Postgres:**

Look for the auth-enforcement layer. If it's "we trust the queries"
(every query in the app must remember to filter by user_id), that's H1
unless every single query is verified to do so.

**Evidence to capture:**
- Specific tables found
- Whether RLS is disabled or no policies exist (subtly different)
- Any policy that exists but is `USING (true)` (no-op policy = same as
  no policy)

---

## H2 — Service role / admin secrets reachable from the client

**What it is:** Admin keys (Supabase `service_role`, Stripe `sk_live_*`,
AWS root, MercadoPago access tokens) are bundled into client code, in
public env vars (`NEXT_PUBLIC_*`, `VITE_*`, `PUBLIC_*`), or accessible
via an unauthenticated API endpoint.

**Why it's a hard stop:** Possession of the service role key bypasses
all RLS, all rate limits, all auth. One leaked key = total compromise.

**Detection commands:**

```bash
# Find any reference to known-dangerous secret names in client code
grep -rn "SERVICE_ROLE\|SERVICE_KEY\|ADMIN_KEY\|MASTER_KEY" \
  src/client/ src/components/ src/pages/ public/ static/ 2>/dev/null

# Next.js: secrets prefixed with NEXT_PUBLIC_ are bundled to the browser
grep -rn "NEXT_PUBLIC_.*\(SECRET\|KEY\|TOKEN\|PRIVATE\)" src/

# Vite
grep -rn "VITE_.*\(SECRET\|KEY\|TOKEN\|PRIVATE\)" src/

# SvelteKit / Astro
grep -rn "PUBLIC_.*\(SECRET\|KEY\|TOKEN\|PRIVATE\)" src/

# Find references to service-role-shaped JWTs in source files.
# Supabase service_role keys are JWTs that contain `service_role` in payload.
# IMPORTANT: exclude .claude/ and any kit-staging dir — this file itself
# contains the example pattern, so an unfiltered grep self-matches the
# kit's own docs and false-flags H2. Same for node_modules / .next / .git.
grep -rn 'eyJhbGciOi.*service_role' . \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.next \
  --exclude-dir=.claude --exclude-dir=_kits-staging --exclude-dir=docs/audit \
  2>/dev/null
```

**Evidence to capture:**
- File path + line of the reference
- The env var name (do NOT include the actual value in the report)
- Where the var is read (server-only? bundled to client?)

---

## H3 — Data-mutation endpoint with no authentication check

**What it is:** A POST/PUT/PATCH/DELETE endpoint that performs
side effects without verifying the caller is authenticated.

**Why it's a hard stop:** Anyone on the internet can mutate the data.
This is the B1 blind-spot ("auth present but not wired") in its most
severe form.

**Detection — generic approach:**

```bash
# 1. Find every mutation endpoint
grep -rEn "@(app|router)\.(post|put|patch|delete)" src/ \
  --include="*.py" --include="*.ts" --include="*.js"

# Or for Express:
grep -rEn "(app|router)\.(post|put|patch|delete)" src/ \
  --include="*.ts" --include="*.js"
```

For each match, **read the handler** and confirm:
- A dependency / middleware / decorator enforces auth, AND
- The auth check actually runs before the side effect, AND
- The check uses the request token (not a body field, not a query param)

**The trap to avoid:** auth middleware exists in `middleware/auth.py` but
is never imported into the route chain. The endpoint LOOKS auth-protected
in the file structure but isn't actually wired. This is one of the most
common AI-generated bugs.

**Evidence to capture:**
- Endpoint method + path
- Handler file:line
- The exact reason no auth runs (no middleware? middleware not in chain?
  middleware checks but doesn't enforce?)

---

## H4 — Secrets in git history

**What it is:** A `.env`, `.env.local`, `secrets.yaml`, `credentials.json`,
or any file containing real secrets has ever been committed to the repo,
even if subsequently removed.

**Why it's a hard stop:** Git history is forever. Once committed to a
public repo, the secret is leaked permanently — `git filter-repo` cannot
unwound a clone. Even on private repos, every former contributor has the
secret.

**Detection commands:**

```bash
# Check for secret-shaped filenames in history
git log --all --diff-filter=A --name-only \
  | grep -iE "(\.env|secrets?\.|credentials?\.|\.pem$|\.key$|id_rsa)" \
  | sort -u

# Specifically check the canonical names
for f in .env .env.local .env.production .env.development \
         secrets.yml secrets.yaml secrets.json credentials.json \
         id_rsa id_dsa serviceAccount.json; do
    if git log --all --full-history -- "$f" 2>/dev/null | grep -q "commit"; then
        echo "FOUND IN HISTORY: $f"
    fi
done

# Use git-secrets or trufflehog if available
which trufflehog && trufflehog filesystem --no-update . 2>/dev/null
which gitleaks  && gitleaks detect --no-banner 2>/dev/null
```

**Evidence to capture:**
- File path
- First commit SHA where it appeared
- Whether the secrets in that file are still valid (cannot tell from
  inside the repo — needs runtime access — mark as `[UNVERIFIED]` if so,
  but the file in history is itself the H4)

**Recommended action in the finding:** Rotate every secret in the file
immediately. Then `git filter-repo` to scrub history (or accept the leak
and move on if rotation is sufficient).

---

## H5 — Webhooks without signature verification

**What it is:** Webhook endpoints (Stripe, MercadoPago, GitHub, Twilio,
WhatsApp Business API, anything that has signed payloads) that process
the body before verifying the signature.

**Why it's a hard stop:** An attacker can forge events. For payment
webhooks, this means fake `payment.succeeded` events that mark unpaid
orders as paid. For auth webhooks, fake user-creation. For anything with
side effects, total compromise of the event stream.

**Detection:**

```bash
# Find webhook endpoints
grep -rEn "webhook|callback" src/ --include="*.py" --include="*.ts" --include="*.js" | \
  grep -E "@(app|router)\.(post|put)|router\.post|app\.post"

# For each, read the handler and verify a signature check happens
# BEFORE any side effect. Common patterns to look for:
grep -rn "verify_signature\|verifyWebhook\|stripe\.Webhook\|hmac\." src/

# MercadoPago specific:
grep -rn "x-signature\|x-request-id" src/

# Stripe specific:
grep -rn "Stripe-Signature\|constructEvent" src/

# GitHub specific:
grep -rn "X-Hub-Signature\|X-Hub-Signature-256" src/

# WhatsApp Business API specific:
grep -rn "X-Hub-Signature-256" src/
```

**The pattern that's H5:**

```python
@app.post("/webhooks/stripe")
async def webhook(request: Request):
    payload = await request.json()  # ← reading body before verification
    if payload.get("type") == "payment.succeeded":
        await mark_invoice_paid(payload["data"]["id"])  # ← side effect
    # ... signature check appears later or not at all
```

**The pattern that's safe:**

```python
@app.post("/webhooks/stripe")
async def webhook(request: Request):
    body_bytes = await request.body()
    sig_header = request.headers.get("stripe-signature")
    try:
        event = stripe.Webhook.construct_event(body_bytes, sig_header, WEBHOOK_SECRET)
    except stripe.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="invalid signature")
    # ... side effects happen only AFTER successful construct_event
```

---

## H6 — User-controlled HTML rendering without sanitization

**What it is:** Any code path that renders user-supplied content as raw
HTML using `dangerouslySetInnerHTML`, `v-html`, `innerHTML =`,
`outerHTML =`, or template literals into a non-sanitized DOM.

**Why it's a hard stop:** Stored XSS. An attacker injects a script tag in
their profile bio, support ticket, or comment, and every viewer's
browser executes it. Session theft, action-on-behalf, full account
takeover.

**Detection:**

```bash
# React
grep -rn "dangerouslySetInnerHTML" src/ --include="*.tsx" --include="*.jsx" --include="*.ts" --include="*.js"

# Vue
grep -rn "v-html=" src/ --include="*.vue"

# Vanilla JS
grep -rEn "\.innerHTML\s*=|\.outerHTML\s*=|insertAdjacentHTML\(" src/

# Svelte
grep -rEn "\{@html\b" src/ --include="*.svelte"
```

For each match, trace the value:
- Where does the rendered string come from?
- Is there a `DOMPurify.sanitize()` / `sanitize-html` / equivalent
  before it reaches the renderer?
- If the source is user-controlled and there's no sanitizer = H6

**Important:** A `dangerouslySetInnerHTML` of a hardcoded string (e.g., a
static SVG) is fine. The finding requires user-controlled input.

---

## H7 — SQL with string concatenation or f-strings using user input

**What it is:** SQL queries built by string-formatting with values that
came from the request.

**Why it's a hard stop:** SQL injection. The most well-understood
vulnerability class with the worst impact (full DB read/write).

**Detection:**

```bash
# Python f-strings in SQL contexts
grep -rEn 'f"[^"]*\b(SELECT|INSERT|UPDATE|DELETE)\b' src/ --include="*.py"
grep -rEn "f'[^']*\b(SELECT|INSERT|UPDATE|DELETE)\b" src/ --include="*.py"

# Python % formatting in SQL
grep -rEn '"\s*%\s*\(' src/ --include="*.py" | grep -iE "(SELECT|INSERT|UPDATE|DELETE)"

# Python concatenation in SQL
grep -rEn 'execute\(.*\+.*\)' src/ --include="*.py"

# JS/TS template literals in SQL
grep -rEn 'query\s*\(\s*`[^`]*\$\{' src/ --include="*.ts" --include="*.js"

# JS/TS concat in SQL
grep -rEn '\bquery\s*\([^)]*\+\s*req\.' src/
```

For each match, trace whether the interpolated value is user-controlled.

**The pattern that's H7:**

```python
async def search(name: str):
    return await db.execute(f"SELECT * FROM users WHERE name = '{name}'")
```

**The pattern that's safe (parameterized):**

```python
async def search(name: str):
    return await db.execute("SELECT * FROM users WHERE name = :name", {"name": name})
```

---

## H8 — Hardcoded admin checks or temporary auth bypasses

**What it is:** Authorization decisions based on hardcoded strings,
"temporary" bypasses left in code, or backdoor patterns.

**Why it's a hard stop:** Privilege escalation. The hardcoded admin email
becomes admin if anyone signs up with that email. The "TEMP: bypass auth
for testing" comment from six months ago is still in production. The
backdoor is exploited.

**Detection:**

```bash
# Hardcoded admin checks
grep -rEn "if.*[\"'][^\"']*@[^\"']*[\"']" src/ --include="*.py" --include="*.ts" --include="*.js" | \
  grep -iE "admin|email"

grep -rEn "(role|email|user)\s*[!=]==?\s*[\"']admin" src/

# "Temporary" markers
grep -rEnB1 -A2 "TEMP:|TODO.*auth|XXX.*auth|FIXME.*auth|HACK:" src/
grep -rEn "bypass.*auth|skip.*auth|disable.*auth" src/
grep -rEn "if\s+\(?\s*(true|1|debug|DEV)\s*\)?\s*\{" src/

# Backdoor-shaped patterns
grep -rEn "magic.*number|secret.*key.*==|backdoor" src/
```

For each match, read the surrounding lines and assess whether it
constitutes a real bypass.

**Common false positives to skip:**
- `is_admin` boolean checks against the user object (not hardcoded)
- Tests that mock an admin user (unless the test runs in production)
- Comments about a fixed bug (`// fixed: was bypassing auth`)

**Real H8 examples:**

```python
# Real H8
if user.email == "founder@startup.com":
    user.is_admin = True

# Real H8
if request.headers.get("X-Internal") == "yes-please":
    skip_auth = True

# Real H8
# TEMP: testing without auth, remove before prod
return next()  # auth middleware bypass
```

---

## H9 — Test asserts buggy current behavior, not spec, on a critical flow

**What it is:** A test that mocks dependencies so completely that it
just confirms the code does what it does — not what it should do — AND
that test is the only safety net for a critical flow (payments, auth,
deletes, data export).

**Why it's a hard stop:** This is the worst failure mode in the Tambon
research findings. The test passes. The CI is green. The team trusts the
test. The code is broken. When the bug surfaces in production, the team
is shocked because "the tests pass."

**Detection — heuristic:**

```bash
# Find tests for critical-flow modules
find . -path "*/tests/*payment*" -o -path "*/tests/*auth*" -o \
       -path "*/tests/*delete*" -o -path "*/tests/*billing*" 2>/dev/null

# For each, look for the anti-patterns:
grep -rn "patch\|mock\|MagicMock\|when(" tests/ --include="*.py" --include="*.ts"
```

**The anti-patterns that signal H9:**

1. Test mocks the function under test (mock returns the expected output;
   real function is never called)
2. Test asserts the SQL string sent, not the database state after
3. Every external dependency mocked — no integration test exists
4. Test was written by AI alongside the code in the same session

**The test below is H9:**

```python
def test_process_payment():
    with patch("payments.charge_card") as mock_charge:
        mock_charge.return_value = {"status": "success"}
        result = process_payment(amount=100)
        assert result["status"] == "success"  # ← asserts the mock, not behavior
```

That test passes whether `process_payment` actually charges the card or
just throws the input on the floor. The mock makes the assertion vacuous.

**Action for H9:** Find the critical flow's actual behavior. Write an
integration test that exercises the real path (test DB, test Stripe key,
real network). Mark the AI-written test as inadequate but keep it for
unit-level coverage.

---

## How the hard-stops audit produces output

For each H1-H9 condition checked:

```
HARD STOP CHECK: H<N> — <name>
Status: NOT FOUND | FOUND | UNABLE TO CHECK (and why)

If FOUND:
  Evidence:
    <path:line> — <one-line description>
    [additional locations]
  Detection commands run:
    <the exact commands the auditor ran>
  Recommended remediation:
    <one paragraph, concrete>
  Verification after fix:
    <command the developer can run to confirm fixed>
```

If ANY hard stop is FOUND, the orchestrator prepends to the final report:

```
🛑 HARD STOP — DO NOT LAUNCH / DO NOT ACQUIRE WITHOUT REMEDIATION

The following hard-stop conditions are present in this codebase:
  - H<N>: <one-line summary>  evidence: <path:line>
  - H<N>: <one-line summary>  evidence: <path:line>
  ...

These conditions cause real damage on day-one of production. The audit's
domain-by-domain findings below assume these will be fixed before launch;
many domain ratings would shift if these were resolved.

Total time to remediate hard stops: estimated <X-Y> developer-days.
```

The hard-stops report is non-negotiable. The model cannot soften it,
re-rank it as "Medium," or omit it.
