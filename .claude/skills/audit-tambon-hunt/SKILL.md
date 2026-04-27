---
name: audit-tambon-hunt
description: Hunt the three Tambon LLM-failure-mode signatures (Hallucinated Object, Wrong Attribute, Silly Mistake) across an audit scope. Use during the audit pipeline AFTER hard-stops and BEFORE blind-spots. Output: counts per signature, top occurrences, density per 1000 LoC. Findings flow into Domain 13 (Code Integrity).
---

# Skill: Audit Tambon Hunt

This skill detects the three LLM-specific bug patterns documented in
Tambon et al. 2025 — patterns that are nearly absent from human-written
code. Finding them is double signal: each occurrence is a correctness
defect AND evidence of unreviewed AI generation.

The full taxonomy and detection guidance is in
`@.claude/context/audit-tambon-signatures.md`. Load it before starting.

## Process

### Pre-flight

```
view @.claude/context/audit-rules.md
view @.claude/context/audit-tambon-signatures.md
```

### Phase 1 — Static type-check (the heavy lifter)

The single most effective Tambon detector is a strict type-checker. Run
the appropriate one(s):

```bash
# Python
which mypy &>/dev/null && mypy --strict src/ 2>&1 | tee /tmp/mypy.log
which pyright &>/dev/null && pyright src/ 2>&1 | tee /tmp/pyright.log

# TypeScript
which tsc &>/dev/null && tsc --noEmit --strict 2>&1 | tee /tmp/tsc.log

# If nothing is installed, that's a finding in its own right —
# "no static type checking configured." Continue with grep-based hunts.
```

Filter the output for the relevant error categories:

- **mypy:** `has no attribute`, `Module has no attribute`, `is not defined`
- **pyright:** `Cannot access attribute`, `is not a known attribute`,
  `is not defined`
- **tsc:** `Property '...' does not exist`, `Cannot find name`,
  `has no exported member`

Each unique error of those classes is a candidate Tambon finding.
Verify by reading the cited path:line — sometimes type-checker output
points at a real Tambon, sometimes at a missing type stub for a real
library. Distinguish:

- "Cannot find module X" where X is a real package = missing types,
  not Tambon
- "Property foo does not exist on type Bar" where Bar is a real class
  and foo is misspelled = Tambon (Wrong Attribute)
- "Module X has no attribute foo" where X is a real package = could be
  Hallucinated Object OR a recent API change. Cross-reference with the
  pinned version in the manifest.

### Phase 2 — Silly Mistake hunt

Static type checkers don't catch most Silly Mistakes. Use linters:

```bash
# Python
ruff check --select=PLR src/ 2>&1 | tee /tmp/ruff.log
pylint src/ --disable=all \
    --enable=duplicate-code,no-else-return,redundant-condition,unnecessary-pass \
    2>&1 | tee /tmp/pylint.log

# JS/TS
npx eslint src/ \
    --rule 'no-dupe-else-if: error' \
    --rule 'no-self-compare: error' \
    --rule 'no-constant-condition: error' \
    --rule 'no-useless-return: error' \
    2>&1 | tee /tmp/eslint.log
```

For patterns the linter doesn't catch (e.g., both branches of an if
returning the same thing), use grep heuristics:

```bash
# Both-branch-returns-same — heuristic
# Find functions where the same identifier is returned in both branches
grep -rEnA15 "if .*:\s*$" src/ --include="*.py" | \
  awk '/return / { print prev "\n" $0 } { prev = $0 }' | \
  uniq -d
```

### Phase 3 — Mixed-version-API hunt (Wrong Attribute, common case)

Pydantic v1/v2 mixing is endemic in vibe-coded Python:

```bash
# v1 patterns
grep -rEn "\.dict\(\)|\.parse_obj\(|class Config:" src/ --include="*.py"

# v2 patterns
grep -rEn "\.model_dump\(|\.model_validate\(|model_config\s*=" src/ --include="*.py"

# Both present in same project = Wrong Attribute waiting to happen
```

SQLAlchemy 1.x/2.x mixing is also common:

```bash
# 1.x async style (deprecated)
grep -rEn "create_async_engine.*sessionmaker.*class_=AsyncSession" src/

# 2.x async style (correct)
grep -rEn "async_sessionmaker" src/
```

### Phase 4 — Manual confirmation pass

The static analysis surfaces candidates. For each candidate that's NOT
obviously a false positive, read the actual code to confirm (R2):

1. Open the file at the cited line
2. Verify the pattern is real
3. Classify as Hallucinated Object / Wrong Attribute / Silly Mistake
4. Assess severity:
   - Test file only: Medium
   - Utility code: High
   - Critical-flow code (auth/payment/delete): Critical

Drop candidates that turn out to be:
- Type stub gaps (real library, missing types)
- Intentional dead code (clearly marked with comment)
- Test fixtures that look weird but are deliberate

## Output format

```
═══════════════════════════════════════════════════════════════════════
  TAMBON SIGNATURE HUNT
═══════════════════════════════════════════════════════════════════════

Scan scope:  <path>
Total LoC:   <N>

Tooling used:
  Static type checker: <mypy / pyright / tsc / NONE — finding>
  Linter:             <ruff / pylint / eslint / NONE — finding>

────────────────────────────────────────────────────────────────────────
SIGNATURE 1 — Hallucinated Object
────────────────────────────────────────────────────────────────────────

Total occurrences: <N>

Top occurrences (severity-sorted):
  F-T1.1 — <path:line>
    Pattern:        <what was hallucinated>
    Severity:       Critical | High | Medium
    Evidence:
      <the exact code line>
    Fix:            <one sentence>

  F-T1.2 — <path:line>
    [same shape]

  [Up to 10 top findings; if more, append]
  [+ <N> additional Hallucinated Object findings — see appendix]

────────────────────────────────────────────────────────────────────────
SIGNATURE 2 — Wrong Attribute
────────────────────────────────────────────────────────────────────────

Total occurrences: <N>

[Same shape]

────────────────────────────────────────────────────────────────────────
SIGNATURE 3 — Silly Mistake
────────────────────────────────────────────────────────────────────────

Total occurrences: <N>

[Same shape]

────────────────────────────────────────────────────────────────────────
TAMBON DENSITY
────────────────────────────────────────────────────────────────────────

Total signatures:    <H + W + S>
Total LoC:           <N>
Density:             <total / N * 1000> per 1000 LoC

Density band:
  [ ] 0–1 per 1000 LoC: code is reviewed
  [ ] 2–5 per 1000 LoC: light review
  [ ] 6–15 per 1000 LoC: most code unreviewed
  [ ] >15 per 1000 LoC: AI-as-shipped

Critical-path findings (in auth/payment/delete code):
  <count> findings
  [list each with path:line if any]

────────────────────────────────────────────────────────────────────────
INTERPRETATION
────────────────────────────────────────────────────────────────────────

[2-3 sentences. Density band → what it implies about the codebase →
recommended response. Examples:]

"Tambon density of 8.3/kLoC places this codebase in the 'most code is
unreviewed AI output' band. Combined with the 4 Critical findings in
the auth path, this suggests a substantial portion of the
authentication code was generated and never line-reviewed by a human."

"Tambon density of 0.4/kLoC indicates the code has been line-reviewed
thoroughly. The 2 occurrences are isolated and don't cluster in any
specific module."

[SECTION COMPLETE: audit-tambon-hunt]
```

## What this skill does NOT do

- Fix the findings (that's the dev's job, with /audit-fix)
- Run the code (audit is read-only)
- Speculate about which model generated the code (irrelevant; the
  density band is what matters)
- Skip occurrences in test files (test code matters too — broken tests
  give false confidence)

## Failure modes to refuse

- ❌ Reporting Tambon density without running a type-checker (the
  density number requires the static analysis)
- ❌ Counting type-checker errors that are actually missing-stub issues
  as Tambon findings
- ❌ Calling something "Hallucinated Object" without verifying the
  package/method actually doesn't exist (R2 — quote before cite)
- ❌ Producing a 50-finding list of trivial Silly Mistakes that
  obscures the 3 real Critical-path Hallucinated Objects (severity sort
  matters)
