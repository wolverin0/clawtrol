---
name: review-security
description: Use when the user asks for a security review, security audit, or "is this safe to deploy?" Also use proactively before any push to production or before adding endpoints that touch authentication, payments, or user data. Hunts the H1-H8 hard stops from the technical due diligence audit.
---

# Skill: Security Review

This skill runs the security-relevant subset of the technical due
diligence audit. It is NOT a substitute for a real penetration test or a
human security engineer for code that handles money, health data, or
PII at scale.

## Hard stops — find any of these, raise the alarm immediately

These are the H1-H8 conditions from the audit prompt. Each is a **CRITICAL
STOP** — fix before anything else ships.

### H1 — Row-level access control disabled on user-data tables

For Supabase / Postgres:
```sql
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE schemaname IN ('public', 'auth')
  AND rowsecurity = false;
```
Any row returned with PII or user data is a CRITICAL STOP.

For other DBs, check whether your access control happens at the DB layer
(good), the app layer with proper enforcement (acceptable), or "we trust
the queries" (CRITICAL).

### H2 — Service-role / admin keys reachable from the client

```bash
# Find any reference to known-dangerous secret names in client code
grep -rn "SERVICE_ROLE\|SERVICE_KEY\|ADMIN_KEY\|MASTER_KEY\|PRIVATE_KEY" \
  src/client/ src/components/ src/pages/ public/ static/ 2>/dev/null

# In Next.js, check for secrets prefixed with NEXT_PUBLIC_ that should not be
grep -rn "NEXT_PUBLIC_.*\(SECRET\|KEY\|TOKEN\)" src/

# In Vite, check VITE_
grep -rn "VITE_.*\(SECRET\|KEY\|TOKEN\)" src/
```

### H3 — Any data-mutation endpoint with no auth check

For each POST/PUT/PATCH/DELETE handler, trace whether an auth dependency
is actually wired. The pattern "auth middleware exists but isn't called
on this route" is one of the most common AI-generated bugs (B1 from the
audit's blind-spot list).

```bash
grep -rn "@app\.\(post\|put\|patch\|delete\)\|router\.\(post\|put\|patch\|delete\)" src/routes/
```

For each match, open the file and verify the handler has either:
- A `Depends(get_current_user)` parameter (FastAPI)
- A middleware in the router chain that requires auth
- An explicit comment stating "this endpoint is intentionally public"

If none, that's a CRITICAL STOP.

### H4 — `.env` in git history

```bash
git log --all --full-history -- .env 2>/dev/null
git log --all --full-history -- .env.local 2>/dev/null
git log --all --full-history -- .env.production 2>/dev/null

# Find any committed file that looks like a secrets file
git log --all --diff-filter=A --name-only \
  | grep -iE "\.env|secrets?\.|credentials?\." \
  | sort -u
```

If anything returns, even one historical commit, that's a CRITICAL STOP.
The secrets are exposed forever — git history cannot be unwound on a
public repo. Recommendation: rotate every secret, then `git filter-repo`
to scrub history.

### H5 — Webhooks with no signature verification

```bash
# Find webhook endpoints
grep -rn "webhook\|callback" src/routes/ src/handlers/

# For each, verify it calls a signature-verification function before
# processing the payload. Patterns:
grep -rn "verify_signature\|verify_webhook\|stripe\.Webhook\|mercadopago.*signature" src/
```

If a webhook handler accesses `request.body` or processes events before
verifying the signature, that's a CRITICAL STOP.

### H6 — User-controlled HTML rendering

```bash
grep -rn "dangerouslySetInnerHTML\|v-html=\|\.innerHTML\s*=\|\.outerHTML\s*=" src/
```

For each match, trace whether the rendered content can come from user
input. If yes, and there's no DOMPurify / sanitize-html / equivalent,
that's a CRITICAL STOP.

### H7 — SQL with string concatenation or f-strings using user input

```bash
# Python:
grep -rn 'f".*SELECT\|f".*INSERT\|f".*UPDATE\|f".*DELETE' src/
grep -rn 'execute(.*\+\|execute(.*%' src/

# JS/TS:
grep -rn 'query.*\${.*}\|query.*\+.*request\|query.*\+.*req\.\|query.*\+.*params' src/
```

Every match is a potential SQL injection. Verify the variable in the
query is NOT user-controlled. If it is, CRITICAL STOP.

### H8 — Hardcoded admin checks / temporary auth bypasses

```bash
grep -rn "admin@\|hardcoded\|TEMP\|TODO.*auth\|bypass.*auth\|skip.*auth" src/
grep -rn "if.*email.*=.*['\"].*@.*['\"]" src/
grep -rn "if.*role.*==.*['\"]admin['\"]" src/
```

Each match needs eyeballs. Hardcoded admin emails, "temporary" bypasses
left in code, and `if (user.email === 'me@company.com')` patterns are
all CRITICAL stops.

## Standard checks (after hard stops)

Once hard stops are clean, run through:

### Authentication / authorization

- ☐ Every protected route enforces auth at the server, not just hides UI
- ☐ Tokens are httpOnly cookies, not `localStorage`
- ☐ Sessions invalidate on logout (server-side, not just clearing the cookie)
- ☐ Password reset tokens expire and are single-use
- ☐ No IDOR — users cannot access other users' resources by changing IDs

### Input validation

- ☐ Every endpoint validates input with a schema (Pydantic / Zod / Joi)
- ☐ Server-side validation matches or exceeds client-side
- ☐ File uploads check type AND size AND scan content
- ☐ User-supplied URLs in redirects are on an allowlist

### CORS / CSRF

- ☐ CORS is not `*` if `credentials: true`
- ☐ CSRF protection is in place for cookie-based auth (SameSite=lax minimum)
- ☐ State-changing GETs do not exist (every mutation is POST/PUT/PATCH/DELETE)

### Rate limiting / abuse

- ☐ Login endpoint rate-limits brute-force
- ☐ Password-reset endpoint rate-limits enumeration
- ☐ AI/LLM endpoints rate-limit per user (cost protection)
- ☐ Webhooks rate-limit replay attempts

### Data exposure

- ☐ API responses don't include `password_hash`, `internal_id`, or raw DB rows
- ☐ Error responses don't leak stack traces to clients in production
- ☐ Logs don't include secrets (search for the word "password" in logs)

## Output format

For each finding:

```
SECURITY FINDING #N
─────────────────────────────────────
Severity:        Critical | High | Medium | Low
Exploitability:  EXPLOITABLE-NOW | EXPLOITABLE-LOW-EFFORT | BAD-PRACTICE | UNKNOWN
Hard-stop class: H1-H8 if applicable, otherwise "none"

Evidence:
  path/file.ext:start-end

What's wrong:
  [one paragraph, plain English]

Why it matters:
  [one sentence — what breaks, for whom, when]

Fix:
  [concrete change with before/after pattern]

Verification:
  [exact command to confirm the fix worked]
```

## Anti-patterns to refuse

- ❌ Do not produce a security review without running the actual greps
  shown above. A security review without evidence is theater.
- ❌ Do not rate-limit findings as "Medium" if they're H1-H8. Hard stops
  are Critical, full stop.
- ❌ Do not claim "looks secure" without listing what you actually checked.
  If you didn't check something, say so.
- ❌ Do not propose a fix you haven't reasoned through. Saying "add a
  signature verification" is not a fix — show the code.

## When this skill is done

You should have produced:
1. A list of any H1-H8 hard stops with evidence
2. Standard-check findings, severity-tagged
3. Concrete fix recommendations for each finding
4. The verification commands the user can run after applying fixes
