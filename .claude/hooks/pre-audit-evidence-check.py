#!/usr/bin/env python3
"""
pre-audit-evidence-check.py

Deterministic guard that refuses to let an audit finding ship without
the evidence the seven rules require. Runs as a pre-emit hook so the
model literally cannot bypass it.

Wired into .claude/settings.json (per Claude Code's real hook contract —
the matcher only filters by tool name; this hook does its own path filter
on tool_input.file_path so non-audit Write/Edit calls pass through):

  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [{"type": "command",
                 "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/pre-audit-evidence-check.py\""}]
    }
  ]

stdin payload (verified against code.claude.com/docs/en/hooks):

  {
    "session_id": "...",
    "cwd": "/abs/path",
    "hook_event_name": "PreToolUse",
    "tool_name": "Write" | "Edit",
    "tool_input": {
      "file_path": "/abs/path/to/file",
      "content": "..."         # Write
      | "new_string": "..."    # Edit (new content)
      | "old_string": "..."    # Edit (the search target — irrelevant here)
    }
  }

Validates:

  R1 — Every finding cites path:line.
  R2 — Every cited path:line should have been read in this audit run.
       (Heuristic: if path doesn't exist on disk, that's a quote-before-cite
       violation.)
  R4 — Every Critical/High security finding has an exploitability tag.
  R6 — Every domain section ends with [SECTION COMPLETE: ...] or
       [SECTION SKIPPED: ...].

Exit codes:
  0 — Report passes the guard. Emit allowed.
  1 — Report fails. Emit blocked. stderr explains which rule.

This is intentionally strict. False positives are better than letting a
sloppy report ship.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────

# A finding starts with "F-" followed by an ID like "F-1.3" or "F-H1.1"
FINDING_BLOCK = re.compile(
    r"F-(?:H?\d+|T\d|B\d+)\.(\d+)\s*[—\-]\s*",
    re.MULTILINE,
)

# A path:line citation: at least one slash, an extension, and :digits.
# Permissive char class so paths with dynamic-route segments survive:
#   - Next.js: src/app/api/[id]/route.ts:5
#   - Path aliases: @/components/Button.tsx:10
#   - Trailing line range: lib/db.ts:5-10
PATH_LINE = re.compile(
    r"([A-Za-z0-9_./@\-\[\]]+\.[a-zA-Z0-9]{1,6}):(\d+(?:-\d+)?)",
)

# Severity tag inside a finding
SEVERITY = re.compile(r"\bSeverity:\s*(Critical|High|Medium|Low)\b", re.IGNORECASE)

# Exploitability tag
EXPLOITABILITY = re.compile(
    r"\bExploitability:\s*(EXPLOITABLE-NOW|EXPLOITABLE-LOW-EFFORT|BAD-PRACTICE|UNKNOWN)\b",
)

# Section completion marker
SECTION_COMPLETE = re.compile(
    r"\[SECTION (?:COMPLETE|SKIPPED):\s*[^\]]+\]",
)

# Domain header
DOMAIN_HEADER = re.compile(r"DOMAIN\s+(\d+):\s+", re.IGNORECASE)


# ─────────────────────────────────────────────────────────────────────
# Checks
# ─────────────────────────────────────────────────────────────────────


def split_findings(text: str) -> list[tuple[str, int]]:
    """Yield (finding_block, start_offset) for each finding in the report."""
    matches = list(FINDING_BLOCK.finditer(text))
    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        blocks.append((text[start:end], start))
    return blocks


def check_R1_evidence(text: str) -> list[str]:
    """Every finding must contain at least one path:line citation."""
    violations = []
    for block, offset in split_findings(text):
        if "[UNVERIFIED" in block or "[INFERRED" in block:
            continue  # Acceptable per R1
        if not PATH_LINE.search(block):
            preview = block.split("\n")[0][:80]
            violations.append(
                f"R1 violation: finding has no path:line citation\n"
                f"  Finding: {preview}"
            )
    return violations


def check_R2_paths_exist(text: str, repo_root: Path) -> list[str]:
    """Every cited path should exist on disk (quote-before-cite proxy)."""
    violations = []
    cited = set()
    for m in PATH_LINE.finditer(text):
        path = m.group(1)
        # Skip cross-platform false positives
        if path.startswith(("http://", "https://", "git://")):
            continue
        # Skip paths that look like in-prompt references
        if path.startswith("@.claude/") or path.startswith("@."):
            continue
        cited.add(path)

    for path in cited:
        candidate = repo_root / path
        # Tolerate case-sensitivity issues and best-effort matches
        if not candidate.exists():
            # Try common roots
            for prefix in ("src", "app", "lib", "."):
                if (repo_root / prefix / path).exists():
                    break
            else:
                violations.append(
                    f"R2 violation: cited path does not exist: {path}\n"
                    f"  Either you cited a path you didn't read, or the path "
                    f"is malformed."
                )
    return violations


def check_R4_exploitability(text: str) -> list[str]:
    """Every Critical/High security finding must have an exploitability tag."""
    violations = []
    for block, _ in split_findings(text):
        sev = SEVERITY.search(block)
        if not sev:
            continue
        if sev.group(1).lower() not in ("critical", "high"):
            continue
        # Only enforce on findings that are clearly security-related.
        # Heuristic: presence of words.
        is_security = any(
            kw in block.lower()
            for kw in (
                "auth",
                "secret",
                "token",
                "rls",
                "injection",
                "xss",
                "csrf",
                "idor",
                "exploit",
                "privilege",
            )
        )
        if not is_security:
            continue
        if not EXPLOITABILITY.search(block):
            preview = block.split("\n")[0][:80]
            violations.append(
                f"R4 violation: Critical/High security finding has no "
                f"exploitability tag\n"
                f"  Finding: {preview}"
            )
    return violations


def check_R6_section_markers(text: str) -> list[str]:
    """Every domain section must end with [SECTION COMPLETE: ...]."""
    violations = []
    domain_headers = list(DOMAIN_HEADER.finditer(text))
    if not domain_headers:
        return []  # Not a domain-by-domain report, skip
    completion_markers = list(SECTION_COMPLETE.finditer(text))
    if len(completion_markers) < len(domain_headers):
        violations.append(
            f"R6 violation: {len(domain_headers)} domain sections present "
            f"but only {len(completion_markers)} [SECTION COMPLETE/SKIPPED] "
            f"markers found. Each domain must explicitly close."
        )
    return violations


def check_truncation_honesty(text: str) -> list[str]:
    """If the report claims AUDIT COMPLETE, no domains can be truncated."""
    violations = []
    has_truncation = "[AUDIT TRUNCATED" in text or "[REPORT TRUNCATED" in text
    has_complete = "[AUDIT COMPLETE" in text
    if has_truncation and has_complete:
        violations.append(
            "R6 violation: report contains BOTH [AUDIT TRUNCATED] and "
            "[AUDIT COMPLETE] — pick one. If anything was truncated, the "
            "audit is not complete."
        )
    return violations


# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────


def main() -> int:
    # Claude Code passes the proposed tool call as JSON on stdin.
    # Real contract: top-level keys include tool_name, tool_input, cwd.
    try:
        payload = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        # If we can't parse, fall through. Better to under-block than break pipeline.
        return 0

    # Only act on Write/Edit (matcher in settings.json should already filter,
    # but be defensive in case settings include other tools)
    tool_name = payload.get("tool_name", "")
    if tool_name not in ("Write", "Edit"):
        return 0

    tool_input = payload.get("tool_input") or {}
    path = tool_input.get("file_path", "") or ""

    # Path filter: only enforce on audit reports. Anything else passes.
    # Defensive: also accept paths that contain "audit-report" anywhere.
    if "audit-report" not in path.lower():
        return 0

    # Pull the proposed content. For Write it's `content`; for Edit it's `new_string`.
    content = tool_input.get("content") or tool_input.get("new_string") or ""
    if not content:
        return 0

    # Resolve the project root for path-existence checks.
    # Order: CLAUDE_PROJECT_DIR env var (set by Claude Code), payload.cwd, $PWD.
    repo_root = Path(
        os.environ.get("CLAUDE_PROJECT_DIR")
        or payload.get("cwd")
        or os.getcwd()
    )

    violations: list[str] = []
    violations.extend(check_R1_evidence(content))
    violations.extend(check_R2_paths_exist(content, repo_root))
    violations.extend(check_R4_exploitability(content))
    violations.extend(check_R6_section_markers(content))
    violations.extend(check_truncation_honesty(content))

    if violations:
        print("🛑 AUDIT REPORT BLOCKED — rule violations detected:", file=sys.stderr)
        print("", file=sys.stderr)
        for v in violations[:20]:
            print(f"  • {v}", file=sys.stderr)
            print("", file=sys.stderr)
        if len(violations) > 20:
            print(
                f"  ... and {len(violations) - 20} more violations.",
                file=sys.stderr,
            )
        print("", file=sys.stderr)
        print(
            "Fix the violations above and re-emit. The audit report cannot "
            "ship with these issues. The seven-rule enforcement is "
            "deterministic — there is no override.",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
