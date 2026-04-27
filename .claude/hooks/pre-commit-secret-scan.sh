#!/usr/bin/env bash
# .claude/hooks/pre-commit-secret-scan.sh
#
# Hooks are DETERMINISTIC. Unlike CLAUDE.md (advisory), hooks fire
# automatically on the configured event and the agent cannot bypass them.
#
# This hook scans for secrets before allowing a commit. It runs the
# regex patterns most-likely to catch the H2 hard-stop class
# (service-role keys, admin secrets, API tokens) and exits non-zero
# (blocks the commit) if any are found.
#
# To install:
#   1. Make this file executable:
#        chmod +x .claude/hooks/pre-commit-secret-scan.sh
#   2. Wire it into .claude/settings.json under "hooks" → "PreToolUse".
#      Per Claude Code's real contract, the matcher filters by tool name
#      only — use the `if` clause to restrict to git commit:
#        {
#          "hooks": {
#            "PreToolUse": [{
#              "matcher": "Bash",
#              "hooks": [{
#                "type": "command",
#                "if": "Bash(git commit*)",
#                "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/pre-commit-secret-scan.sh\""
#              }]
#            }]
#          }
#        }
#   3. (Optional but recommended) Also install as a git pre-commit hook
#      so it fires for non-Claude-Code commits too:
#        ln -sf ../../.claude/hooks/pre-commit-secret-scan.sh .git/hooks/pre-commit

set -euo pipefail

# Patterns to scan for. Add to this list as you encounter new ones.
# Each pattern is a regex; we use `git diff --cached` to check only
# what's about to be committed, not the whole working tree.
PATTERNS=(
    # AWS
    'AKIA[0-9A-Z]{16}'
    'aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}'

    # Generic API keys (high false-positive but high value)
    'api[_-]?key["'\'']?\s*[:=]\s*["'\''][A-Za-z0-9_-]{20,}["'\'']'
    'secret[_-]?key["'\'']?\s*[:=]\s*["'\''][A-Za-z0-9_-]{20,}["'\'']'

    # Stripe
    'sk_live_[0-9a-zA-Z]{24,}'
    'rk_live_[0-9a-zA-Z]{24,}'

    # MercadoPago
    'APP_USR-[0-9]{16,}-[0-9]{6}-[a-f0-9]{32}-[0-9]{8,}'
    'TEST-[0-9]{16,}-[0-9]{6}-[a-f0-9]{32}-[0-9]{8,}'

    # Supabase service role (the H2 classic)
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[A-Za-z0-9_=]{100,}'
    'service_role'

    # OpenAI / Anthropic / Google
    'sk-[A-Za-z0-9]{48}'
    'sk-ant-[A-Za-z0-9_-]{32,}'
    'AIza[0-9A-Za-z_-]{35}'

    # GitHub
    'ghp_[A-Za-z0-9]{36}'
    'gho_[A-Za-z0-9]{36}'
    'ghs_[A-Za-z0-9]{36}'

    # Generic private keys
    '-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----'

    # .env file contents (somebody pasted their .env into a comment)
    '^[A-Z_]{3,}=[\"'\'']?[A-Za-z0-9_-]{15,}[\"'\'']?'
)

# Files that are ALLOWED to contain things matching these patterns
# (e.g., the .env.example file, this hook itself, documentation about
# patterns to avoid). Audit-kit context files and audit reports
# legitimately describe service_role / api_key shapes as DOCUMENTATION
# (the H2 detection pattern); without these excludes the hook
# self-matches the audit kit's own docs and blocks every commit that
# touches .claude/.
ALLOWLIST=(
    '\.env\.example$'
    '\.claude/'
    'audit-report.*\.md$'
    'docs/.*secrets'
    '.gitleaks.toml'
    '.*\.template$'
)

# Get the staged changes
STAGED=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [[ -z "${STAGED}" ]]; then
    exit 0
fi

VIOLATIONS=()

for FILE in ${STAGED}; do
    # Skip allowlisted paths
    SKIP=0
    for ALLOW in "${ALLOWLIST[@]}"; do
        if echo "${FILE}" | grep -qE "${ALLOW}"; then
            SKIP=1
            break
        fi
    done
    [[ ${SKIP} -eq 1 ]] && continue

    # Skip binary files
    if file "${FILE}" 2>/dev/null | grep -q "binary"; then
        continue
    fi

    for PATTERN in "${PATTERNS[@]}"; do
        # Use `git diff --cached` to only check the diff, not the whole file.
        # `-e PATTERN` is mandatory: some patterns start with `---` (like the
        # PEM private-key marker) and grep would otherwise treat them as
        # CLI flags and abort with "unknown option".
        MATCHES=$(git diff --cached "${FILE}" 2>/dev/null | grep -nE -e "${PATTERN}" || true)
        if [[ -n "${MATCHES}" ]]; then
            VIOLATIONS+=("${FILE}: matched pattern: ${PATTERN}")
            VIOLATIONS+=("    ${MATCHES}")
        fi
    done
done

if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
    echo "🛑 COMMIT BLOCKED — secret-pattern detected in staged changes:"
    echo
    for V in "${VIOLATIONS[@]}"; do
        echo "  ${V}"
    done
    echo
    echo "If this is a false positive, you can:"
    echo "  1. Add the path to the ALLOWLIST in this hook"
    echo "  2. Use git commit --no-verify (NOT RECOMMENDED — really verify it's not a secret)"
    echo
    echo "If this IS a secret, do NOT just unstage it. Rotate it. The fact"
    echo "that it was ever in your working tree means it might be in your"
    echo "shell history, your IDE cache, or your reflog."
    exit 1
fi

exit 0
