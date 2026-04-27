---
name: add-dependency
description: Use when the user wants to add a new library, package, or dependency. Enforces the discipline that prevents framework version drift — the "AI assumes you're on version 15, generates code for 16.5" failure mode documented in the LLM failure-mode research.
---

# Skill: Add a Dependency

LLMs default to suggesting whatever package is most-mentioned in their
training data. That's rarely the right choice for *your* repo. This skill
enforces the discipline of checking what's already installed and pinning
exact versions.

## Phase 1 — Read the manifest first (MANDATORY)

Open `@.claude/context/dependencies.md` and `package.json` /
`requirements.txt` / `pyproject.toml` / equivalent.

Specifically check:

1. **Is there already a dependency that solves this concern?**
   The dependencies.md file lists "Do NOT use instead" — packages we've
   explicitly rejected. Cross-reference your suggestion against that list.

2. **Are we in a known cluster?**
   If we already have `httpx`, do not add `requests` or `aiohttp`.
   If we already have `pydantic`, do not add `marshmallow`.
   If we already have a state library, do not add a second.

3. **What major version are we on?**
   If we're on Pydantic 2.x and you suggest Pydantic 1.x patterns, that's
   a bug. The dependencies.md "Version compatibility traps" section lists
   the specific ones for this repo.

## Phase 2 — Justify the addition

Before installing, the user (and the agent) should be able to answer:

- ☐ What does this package do that we cannot do with what's already installed?
- ☐ Is the package actively maintained? (Check last release date — if >12 months stale, find an alternative.)
- ☐ How many maintainers? (1 maintainer = bus-factor risk.)
- ☐ How many weekly/monthly downloads? (<1k/week = niche, treat as risky.)
- ☐ Is there a less heavy alternative? (Don't pull in lodash for one function.)
- ☐ Does it have native dependencies? (Native deps complicate Docker builds and Vercel deployment.)

If any of these don't have a good answer, push back on adding the dependency.

## Phase 3 — Pin the exact version

```bash
# Python (with uv or pip):
uv add "fastapi==0.115.0"   # exact version, no caret/tilde
# NOT: uv add "fastapi>=0.115" or "fastapi~=0.115"

# Node:
npm install --save-exact fastify@4.27.0
# NOT: npm install fastify  (defaults to ^)
```

Floating versions are a vibe-coding debt amplifier. Two months later, the
same `npm install` produces a different lockfile, code subtly stops
working, and nobody knows why.

## Phase 4 — Update dependencies.md (MANDATORY)

In the same commit as the install, add a row to
`.claude/context/dependencies.md`:

```markdown
| <package> | <exact-version> | <one-sentence purpose> | <what NOT to confuse it with> |
```

If the package replaces an existing one, mark the old one as
"To be removed: <ticket-or-date>" in the same file.

## Phase 5 — Verify it works in YOUR runtime

Don't trust that "the docs say it works." Run:

```bash
# Confirm import in our actual runtime
python -c "import <package>; print(<package>.__version__)"

# Or for Node:
node -e "console.log(require('<package>').version)"

# Run the affected test suite
pytest -k "<feature using the new package>"
```

## Phase 6 — Document any version compatibility traps

If during installation you discover a known compatibility issue (e.g.,
"works with Python 3.11 but not 3.12"), add a line to dependencies.md
under "Version compatibility traps" so the next session knows.

## Anti-patterns to refuse

- ❌ Adding a dependency without checking if an existing one already covers it
- ❌ Installing with floating versions (`^`, `~`, `>=`)
- ❌ Adding a 2nd HTTP client / 2nd ORM / 2nd date library
- ❌ Adding a package without updating dependencies.md
- ❌ Suggesting code that uses a version of a package different from what's installed

## Special case — upgrading

When upgrading a dependency:

1. Read the changelog for breaking changes (every `MAJOR` and any flagged
   `MINOR`).
2. Update both the manifest and dependencies.md.
3. If the upgrade has breaking API changes, also update the "Version
   compatibility traps" section.
4. Run the FULL test suite, not just the parts you think it affects.
   Dependency upgrades have a habit of breaking things you didn't expect.

## Special case — removing

When removing:

1. Confirm no remaining imports of the package: `grep -rn "<package>" src/`
2. Remove from manifest
3. Remove from dependencies.md
4. Remove any "To be removed" notes referring to it
5. Run the full test suite

## When this skill is done

You should have:
1. Confirmed no existing dependency covered the concern (or extended an existing one)
2. Pinned the exact version in the manifest
3. Updated dependencies.md
4. Verified the package imports and the test suite passes
