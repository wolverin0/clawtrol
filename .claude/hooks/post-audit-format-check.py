#!/usr/bin/env python3
"""
post-audit-format-check.py

Post-emit guard that validates the audit report's overall shape after
it's written. Different from the pre-emit check (which validates
findings); this one validates that the structural pieces are present
and consistent.

Wired into .claude/settings.json (per Claude Code's real hook contract —
the matcher only filters by tool name; this hook reads stdin to get the
file path from tool_input.file_path or tool_response.filePath):

  "PostToolUse": [
    {
      "matcher": "Write",
      "hooks": [{"type": "command",
                 "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/post-audit-format-check.py\""}]
    }
  ]

stdin payload (verified against code.claude.com/docs/en/hooks):

  {
    "session_id": "...",
    "cwd": "/abs/path",
    "hook_event_name": "PostToolUse",
    "tool_name": "Write",
    "tool_input": {"file_path": "/abs/path", "content": "..."},
    "tool_response": {"filePath": "/abs/path", "success": true}
  }

Validates:
  1. Verdict block is present and uses one of the five exact verdict strings
  2. Verdict matches the severity census (no soft-pedal)
  3. All 13 domain sections are present
  4. Severity census numbers add up
  5. R1-R7 self-attestation block is present
  6. If hard stops were found, the verdict is 🛑
  7. If EXPLOITABLE-NOW is in any finding, verdict is 🔴 or 🛑

Exit codes:
  0 — Report shape OK
  1 — Report has structural issues (warnings printed to stderr)

Note: this is a warning, not a block. The pre-emit check is the hard
gate. This post-emit check helps the auditor see what's structurally
wrong so they can fix the next iteration.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path


VALID_VERDICTS = [
    "🛑 DO NOT LAUNCH UNTIL HARD STOPS RESOLVED",
    "🔴 BLOCK LAUNCH — fix EXPLOITABLE-NOW findings before any production traffic",
    "🟠 FIX BEFORE LAUNCH — multiple critical issues; estimate days-to-weeks",
    "🟡 SHIPPABLE WITH PLAN — significant tech debt; schedule remediation sprint",
    "🟢 ACCEPTABLE — routine cleanup; no launch-blockers",
]


SEVERITY_RE = re.compile(r"\bSeverity:\s*(Critical|High|Medium|Low)\b", re.IGNORECASE)
EXPLOIT_RE = re.compile(r"\bExploitability:\s*(EXPLOITABLE-NOW)\b")
HARD_STOP_FOUND_RE = re.compile(
    r"H[1-9]\b.*?(?:FOUND \(|^Status:\s*FOUND)", re.MULTILINE | re.DOTALL
)
DOMAIN_HEADER_RE = re.compile(r"DOMAIN\s+(\d+):\s*", re.IGNORECASE)


def find_verdict(text: str) -> str | None:
    """Return the verdict string if present, else None."""
    for v in VALID_VERDICTS:
        if v in text:
            return v
    return None


def count_severities(text: str) -> Counter:
    """Count the severities of findings."""
    return Counter(m.group(1).capitalize() for m in SEVERITY_RE.finditer(text))


def count_domain_headers(text: str) -> set[int]:
    """Return the set of domain numbers that have section headers."""
    return {int(m.group(1)) for m in DOMAIN_HEADER_RE.finditer(text)}


def has_attestation(text: str) -> bool:
    """Check if the seven-rules attestation block is present."""
    if "SEVEN RULES OBSERVED" not in text and "rules observed" not in text.lower():
        return False
    rule_lines = sum(1 for r in ("R1", "R2", "R3", "R4", "R5", "R6", "R7") if r in text)
    return rule_lines >= 6  # Allow one to be missing if section was truncated honestly


def main() -> int:
    # Real Claude Code contract: payload arrives on stdin as JSON.
    # Backward compat: if a path is passed as argv[1] (legacy / manual smoke test),
    # honor it. Otherwise read stdin.
    report_path: Path | None = None

    if len(sys.argv) >= 2 and sys.argv[1]:
        report_path = Path(sys.argv[1])
    else:
        try:
            payload = json.loads(sys.stdin.read())
        except json.JSONDecodeError:
            return 0  # Can't parse — fall through silently

        # Only act on Write of audit reports
        tool_name = payload.get("tool_name", "")
        if tool_name != "Write":
            return 0

        tool_input = payload.get("tool_input") or {}
        tool_response = payload.get("tool_response") or {}
        path_str = (
            tool_input.get("file_path")
            or tool_response.get("filePath")
            or ""
        )
        if "audit-report" not in path_str.lower():
            return 0
        report_path = Path(path_str)

    if not report_path or not report_path.exists():
        return 0

    text = report_path.read_text(encoding="utf-8", errors="replace")

    issues: list[str] = []

    # 1. Verdict block present and valid
    verdict = find_verdict(text)
    if verdict is None:
        issues.append(
            "No valid verdict string found. The report must contain ONE of the "
            "five verdict strings exactly. See @.claude/context/audit-triage-rubric.md."
        )

    # 2. Severity census makes sense
    sev_counts = count_severities(text)
    total_findings = sum(sev_counts.values())

    # 3. All 13 domain sections present
    domains_present = count_domain_headers(text)
    expected_domains = set(range(1, 14))
    missing_domains = expected_domains - domains_present
    if missing_domains:
        # Two valid ways to disclose missing domains honestly:
        #  (a) [AUDIT TRUNCATED: <reason>] — ran out of budget mid-run
        #  (b) [AUDIT COMPLETE: N of 13 domains audited, M SKIPPED per scope]
        #      — intentional scoped audit (e.g. /audit --priority-domains=1,8,13)
        # If neither marker is present, the audit is silently incomplete.
        truncation_ok = "[AUDIT TRUNCATED" in text
        scoped_complete_ok = bool(
            re.search(
                r"\[AUDIT COMPLETE:\s*\d+\s+of\s+13\s+domains?\s+audited",
                text,
                re.IGNORECASE,
            )
        )
        if not (truncation_ok or scoped_complete_ok):
            issues.append(
                f"Missing domain sections: {sorted(missing_domains)}. "
                "Either include all 13, OR emit one of:\n"
                "    [AUDIT TRUNCATED: <reason>]                                    (ran out of budget)\n"
                "    [AUDIT COMPLETE: N of 13 domains audited, M SKIPPED per scope]  (intentional scoped audit)"
            )

    # 4. R1-R7 attestation present
    if not has_attestation(text):
        issues.append(
            "Missing or incomplete R1-R7 self-attestation block. The report "
            "must close with the seven-rules attestation."
        )

    # 5. Verdict consistency — hard stops force 🛑
    has_hard_stop = bool(HARD_STOP_FOUND_RE.search(text))
    if has_hard_stop and verdict and not verdict.startswith("🛑"):
        issues.append(
            "Inconsistent verdict: report shows hard-stop findings but verdict "
            f"is not 🛑 DO NOT LAUNCH. Got: {verdict}"
        )

    # 6. Verdict consistency — EXPLOITABLE-NOW forces 🔴 or 🛑
    has_exploitable_now = bool(EXPLOIT_RE.search(text))
    if (
        has_exploitable_now
        and verdict
        and not (verdict.startswith("🛑") or verdict.startswith("🔴"))
    ):
        issues.append(
            "Inconsistent verdict: report shows EXPLOITABLE-NOW findings but "
            f"verdict is not 🛑 or 🔴. Got: {verdict}"
        )

    # 7. Verdict consistency — many Criticals force 🟠 or worse
    if (
        sev_counts.get("Critical", 0) >= 3
        and verdict
        and verdict.startswith(("🟡", "🟢"))
    ):
        issues.append(
            f"Inconsistent verdict: {sev_counts['Critical']} Critical findings "
            f"present but verdict is {verdict[:2]}. Per the triage rubric, "
            f"≥3 Criticals require 🟠 FIX BEFORE LAUNCH or worse."
        )

    # Report
    if issues:
        print(
            f"⚠️  Audit report shape check found {len(issues)} structural issue(s):",
            file=sys.stderr,
        )
        print("", file=sys.stderr)
        for i, issue in enumerate(issues, 1):
            print(f"  {i}. {issue}", file=sys.stderr)
            print("", file=sys.stderr)
        print(
            f"Report file: {report_path}",
            file=sys.stderr,
        )
        print(
            "Severity census: "
            + ", ".join(f"{k}={v}" for k, v in sev_counts.most_common())
            + f" (total={total_findings})",
            file=sys.stderr,
        )
        print(
            f"Domains present: {sorted(domains_present)}",
            file=sys.stderr,
        )
        print(
            f"Verdict: {verdict or 'NONE'}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
