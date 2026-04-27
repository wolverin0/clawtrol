# Tambon LLM-Specific Failure Signatures

Three bug patterns appear in LLM-generated code at meaningful frequency
but are essentially **absent** from human-written code (Tambon et al.
2025, "Bugs in Large Language Models: An Empirical Study").

Finding any of these is near-certain evidence of unreviewed AI generation.
Each occurrence is itself a finding (LLM provenance signal) **and** a
correctness defect.

The `audit-tambon-hunt` skill loads this file and runs the detection
passes systematically. The findings carry double weight in the report —
they're both bugs to fix AND signals about how the codebase was made.

---

## Signature 1 — Hallucinated Object

**Definition:** Reference to a function, class, method, import, or
identifier that doesn't exist in any installed dependency or in the
project itself.

**Why it's LLM-specific:** Humans get import errors at write-time
(IDE) or test-time (run-time). They notice, they fix it. LLMs generate
plausible-sounding names confidently — `requests.get_json()`,
`pydantic.ValidatorMixin`, `numpy.linalg.inverse_matrix` — and if no
human runs the code, the broken import ships.

**Common shapes:**

- Methods that don't exist on real classes (`dict.find()`,
  `list.add()`, `pd.DataFrame.fix_dtypes()`)
- Imports of packages that don't exist
  (`from openai import AssistantClient`)
- Functions that mix two real APIs (`stripe.Charge.refund_full()` is a
  blend of `Charge.refund` and other methods)
- Wrong submodule paths (`numpy.random.choice` exists but the model
  writes `numpy.choice`)

**Detection:**

```bash
# Find every import in the project
grep -rEn "^import |^from .* import " src/ --include="*.py" \
  | awk -F: '{print $3}' | sort -u > /tmp/all-imports.txt

# Cross-reference with the dependency manifest
# (stdlib imports are okay; third-party must be in pyproject.toml/requirements.txt)

# For TypeScript:
grep -rEn "^import .* from " src/ --include="*.ts" --include="*.tsx" \
  | awk -F"from " '{print $2}' | sort -u

# Then run the actual type-checker (this is the real detection):
mypy src/ 2>&1 | grep -E "has no attribute|Cannot find"
pyright src/ 2>&1 | grep -E "Cannot access|is not a known"
tsc --noEmit 2>&1 | grep -E "Property .* does not exist|Cannot find"
```

**The output of the type-checker is the signal.** If `mypy` or `tsc`
reports many "has no attribute" / "Cannot find name" errors, those are
likely Hallucinated Objects.

**Severity calibration:**

- In test files only: Medium (broken tests, but bounded blast radius)
- In utility code: High (will throw at runtime when called)
- In auth/payment/delete paths: Critical (will silently break the most
  important code paths)

---

## Signature 2 — Wrong Attribute

**Definition:** Accessing `.foo` on an object that has no `.foo`. This
is a subset of Hallucinated Object but specifically the
"object exists, attribute doesn't" case.

**Why it's LLM-specific:** Same reason as Signature 1 — confidence
without verification. The model knows the object class. It guesses an
attribute name. The guess is wrong but plausible.

**Common shapes:**

- `user.email_address` when the field is `email`
- `request.user_agent` when it's `headers["user-agent"]`
- `response.data` when the framework uses `response.json()`
- `db.connection` when the SQLAlchemy session is `db.session`
- Mixing v1 and v2 API styles (Pydantic `.dict()` on a v2 model that
  uses `.model_dump()`)

**Detection:** Same as Signature 1 — type-checker output. Plus a
specific category:

```bash
# Mixed Pydantic v1/v2 syntax (extremely common)
grep -rEn "\.dict\(\)|\.parse_obj\(|class Config:" src/ --include="*.py" | head -50
grep -rEn "\.model_dump\(|\.model_validate\(|model_config\s*=" src/ --include="*.py" | head -50
# Both present in the same project = drift
```

**Severity:** Same scale as Signature 1.

---

## Signature 3 — Silly Mistake

**Definition:** Logically incoherent code that compiles and may even
run. The Tambon paper documents these as nearly absent from
human-written code because humans notice them while writing.

**Common shapes:**

```python
# Both branches return the same thing
if user.is_admin:
    return data
else:
    return data

# Redundant cast
x: int = int(int(value))

# Dead conditional
if True:
    do_thing()

# Negated tautology
if x is not None or x is None:
    ...

# Self-comparing condition
if user_id == user_id:
    ...

# Loop that runs zero or one time but is written as a loop
for item in [single_item]:
    process(item)

# Setter and getter with no logic, repeated for every field
@property
def name(self):
    return self._name
@name.setter
def name(self, val):
    self._name = val
# (×30 fields, with no transformation logic — just expensive
# property syntax for what should be a dataclass)
```

**Detection:**

```bash
# Both-branches-same-return
# Hard to grep precisely, but look at any function with:
grep -rEnA10 "if .*:" src/ --include="*.py" | \
  grep -B5 -A1 "return" | head -50

# Better: use a linter
ruff check --select=PLR src/  # Pylint Refactor rules
pylint src/ --disable=all --enable=duplicate-code,no-else-return,redundant-condition

# JS/TS:
npx eslint src/ --rule 'no-dupe-else-if: error' --rule 'no-self-compare: error'
```

**The most expensive Silly Mistake category:** Redundant exception
handling.

```python
try:
    return await fetch_user(id)
except Exception as e:
    raise e  # This try/except does nothing
```

```python
try:
    result = compute()
except Exception:
    raise Exception("compute failed")  # Wraps, loses traceback
```

**Severity:** Usually Low individually. But:

- High density of Silly Mistakes is itself a finding (signals AI
  origin and lack of human review)
- A Silly Mistake in a critical path (the if-both-branches-return
  pattern in a payment flow) is High

---

## How to count "density"

A useful aggregate finding: **Tambon Density** = Hallucinated Object +
Wrong Attribute + Silly Mistake findings per 1000 lines of code.

| Density | Interpretation |
|---|---|
| 0–1 per 1000 LoC | Code is reviewed, even if AI-generated |
| 2–5 per 1000 LoC | Light review; some AI patterns slipped through |
| 6–15 per 1000 LoC | Most code is unreviewed AI output |
| >15 per 1000 LoC | Codebase is AI-output-as-shipped, near zero human review |

This number is a signal in the audit's Founder View block: "Your
codebase has 12 LLM-specific bug signatures per 1000 lines, which the
research literature associates with unreviewed AI generation. Even if
the code works today, the maintenance cost is going to be substantial."

---

## How the Tambon hunt produces output

```
TAMBON SIGNATURE HUNT
─────────────────────────────────────
Total LoC scanned: <N>
Scan duration: <elapsed>

Signature 1 — Hallucinated Object: <count>
  Top occurrences (severity-sorted):
    <path:line>  <description>  <severity>
    [up to 10]

Signature 2 — Wrong Attribute: <count>
  Top occurrences:
    [up to 10]

Signature 3 — Silly Mistake: <count>
  Top occurrences:
    [up to 10]

Tambon Density: <findings per 1000 LoC>
Density interpretation: <one of the bands above>

Critical-path findings (in auth/payment/delete code):
  <list — these are the most urgent to fix>
```

The Tambon hunt's findings flow into Domain 13 (Code Integrity &
Coherence) and contribute to its rating.

---

## Why this hunt is mandatory

In the original v3 prompt, this was §0.5 — flagged as "mandatory hunt."
The refactored architecture makes it a dedicated skill so it gets a
clean context window for the analysis. The hunt is mandatory because:

1. The signatures are LLM-specific and absent from human code, so
   finding them is high-signal evidence of generation provenance.
2. They're correctness defects in their own right.
3. They cluster — a codebase with one usually has many.
4. Standard linters catch some but not all (Silly Mistakes especially
   slip past most rule sets).
5. They're the quickest-to-fix findings in the audit, so surfacing them
   early gives the developer high ROI on their first day of remediation.
