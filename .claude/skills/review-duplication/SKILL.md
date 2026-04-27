---
name: review-duplication
description: Use when the user asks to find duplicate code, redundant logic, or "things implemented in multiple places." Also use proactively when working in an area of the codebase that feels suspicious — multiple utility files, inconsistent naming, parallel implementations. Hunts the Type-1 through Type-4 code-clone patterns from the LLM-failure-mode research.
---

# Skill: Hunt Code Duplication

This skill hunts the duplication patterns that make vibe-coded apps
unmaintainable around month three. Based on Liu et al. 2025's taxonomy of
LLM repetition patterns and the §13 hunts from the technical due diligence
audit prompt.

## What you're hunting

Four types of duplicates, in increasing difficulty to detect:

- **Type-1:** Exact copies (same text, modulo whitespace). Easy.
- **Type-2:** Same code with renamed variables or constants. Medium.
- **Type-3:** Same logic with statements added/removed/modified. Hard.
- **Type-4:** Different syntax, same semantic. Hardest. Requires understanding intent.

You also hunt these structural problems:

- Multiple endpoints serving overlapping purposes (`/api/users/me` AND `/api/profile`)
- Multiple validation libraries, HTTP clients, date libraries, state managers coexisting
- Multiple "utility" files (`utils.ts` + `helpers.ts` + `lib.ts`) covering the same concern
- Inline reimplementation of utilities that exist elsewhere
- Comment blocks duplicated alongside duplicated code (a strong AI-generation signal)

## Step 1 — Sweep for the obvious (Type-1 and Type-2)

Tools to use, in order:

```bash
# If `jscpd` is available (works for many languages):
npx jscpd src/ --threshold 5 --min-lines 5

# Or for Python specifically:
pylint --disable=all --enable=duplicate-code src/

# If neither is available, do a structural grep:
# Find function definitions and count by name across the repo
grep -rn "^def \|^function \|^export function " src/ \
  | sort -k2 \
  | uniq -c -f 1 \
  | sort -rn \
  | head -20
```

Report each cluster with: file paths, line ranges, what it does, and
which copy looks canonical (most-referenced or in the most central
module).

## Step 2 — Multiple "utility" files (Frankenstein signature)

```bash
find src/ -type f \( -name "utils.*" -o -name "helpers.*" -o -name "lib.*" -o -name "common.*" -o -name "shared.*" \) | sort
```

For each, list the function names it exports. Cross-reference: are any
two of those files exporting overlapping functionality?

This is one of the strongest signals of vibe-coded debt. AI tools default
to "I'll put this in utils" without checking what's already there.

## Step 3 — Endpoint duplication

Open the API catalog (`@.claude/context/api-catalog.md` if it exists).
Look for endpoints that:

- Return the same shape of data from different paths (`/users/me` AND `/auth/me` AND `/profile`)
- Have similar names with different verbs or paths
- Are explicitly marked deprecated (means a previous attempt at consolidation that didn't finish)

If no API catalog exists, that's itself a finding — recommend creating
one. Then walk the routes directory:

```bash
grep -rn "@app\.\(get\|post\|put\|patch\|delete\)\|router\.\(get\|post\|put\|patch\|delete\)" src/routes/
```

## Step 4 — Multiple libraries doing the same job

Read `requirements.txt` / `pyproject.toml` / `package.json` and look for
known clusters:

| If you see... | And... | It's a duplicate-purpose finding |
|---|---|---|
| `requests` | `httpx` or `aiohttp` | Two HTTP clients |
| `lodash` | `ramda` or native JS array methods | Two functional libraries |
| `moment` | `date-fns` or `dayjs` or `luxon` | Two date libraries |
| `redux` | `zustand` or `jotai` | Two state managers |
| `axios` | `fetch` (used heavily) | Two HTTP styles |
| `marshmallow` | `pydantic` | Two validators |
| `express` | `fastify` or `koa` | Two web frameworks (very bad) |

For each cluster found, identify which one is canonical (more files
import it) and recommend retiring the other.

## Step 5 — Comment-code drift

Find functions where the docstring/comment doesn't match the code. A
simple heuristic: read every function comment and ask whether the next
20 lines do what the comment claims.

This is the spec-vs-code drift pattern from the audit prompt. Especially
common signature: `def validate_email(email)` whose body just checks
`@` is in the string but the docstring says "validates RFC 5322 format."

## Step 6 — Hallucinated references

```bash
# Imports of modules not in any dependency manifest
# Pseudocode — adjust per language

# Python:
grep -rh "^from \|^import " src/ \
  | awk '{print $2}' \
  | sort -u \
  | while read mod; do
      # Check if first-party (local) or third-party
      # If third-party, is it in requirements.txt / pyproject.toml?
      # If neither, that's a potential hallucination
    done
```

Flag any imports of packages that aren't in the manifest. Some will be
false positives (stdlib, transitive imports); the rest are bugs waiting
to happen.

Also check method calls on objects: are there `.foo()` calls on types
that don't have a `.foo()` method? Static type-checkers (`mypy`,
`pyright`, `tsc`) catch most of these. If the project has none
configured, that's a finding.

## Step 7 — Report format

For each duplication finding, produce:

```
DUPLICATION FINDING #N
─────────────────────────────────────
Type:        [Type-1 | Type-2 | Type-3 | Type-4 | Endpoint | Library | Utility-file | Comment-drift | Hallucinated-ref]
Locations:
  - path/file1.ext:start-end  [marked CANONICAL or DEPRECATE]
  - path/file2.ext:start-end  [marked CANONICAL or DEPRECATE]
  - path/file3.ext:start-end  [marked CANONICAL or DEPRECATE]

What it does:  [one sentence]

Bug-amplification risk:
  HIGH | MEDIUM | LOW — [why; e.g., "all 3 copies handle payments,
  fix in one stays broken in others"]

Recommended consolidation:
  [Which file to keep. Which to delete. What changes are needed elsewhere
   to point at the canonical version.]

Estimated effort:
  Trivial (<2h) | Small (2-8h) | Medium (1-3d) | Large (1-2w)
```

## Step 8 — Triage

After listing all findings, group by:

- **Fix this week** — Trivial, high bug-amplification risk
- **Fix before launch** — Anything in payment, auth, or delete paths
- **Schedule for cleanup sprint** — Everything else

Do NOT attempt to fix everything in one pass. The agent can introduce
new bugs while consolidating duplicates if the change is too large.
Recommend smallest-first.

## Anti-patterns to refuse

- ❌ Don't fix duplicates by deleting one without checking which is canonical
- ❌ Don't introduce a 4th "canonical" implementation when the user asked you to consolidate
- ❌ Don't mark something a duplicate without showing the line-by-line evidence
- ❌ Don't claim "no duplicates found" without showing the search commands you ran

## When this skill is done

You should have produced:

1. A list of every duplication finding with paths, line ranges, and types
2. A recommendation per finding (canonical + delete)
3. A triage grouping
4. The exact commands the user can run to verify your findings independently
