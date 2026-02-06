#!/bin/bash
# Complete a task in ClawTrol
# Usage: ./complete_task.sh TASK_ID "output message" [file1,file2,...]

set -e

# Check required env vars
if [ -z "$CLAWTROL_URL" ] || [ -z "$CLAWTROL_TOKEN" ]; then
  echo "Error: CLAWTROL_URL and CLAWTROL_TOKEN must be set" >&2
  exit 1
fi

# Parse arguments
TASK_ID="$1"
OUTPUT="$2"
FILES="$3"

if [ -z "$TASK_ID" ]; then
  echo "Usage: complete_task.sh TASK_ID \"output message\" [file1,file2,...]" >&2
  echo "" >&2
  echo "Arguments:" >&2
  echo "  TASK_ID    The task ID to complete" >&2
  echo "  OUTPUT     Summary of what was accomplished" >&2
  echo "  FILES      Comma-separated list of output file paths (optional)" >&2
  echo "" >&2
  echo "Environment:" >&2
  echo "  CLAWTROL_URL    ClawTrol instance URL" >&2
  echo "  CLAWTROL_TOKEN  API authentication token" >&2
  echo "  AGENT_NAME      Agent display name (optional)" >&2
  echo "  AGENT_EMOJI     Agent emoji (optional)" >&2
  exit 1
fi

if [ -z "$OUTPUT" ]; then
  OUTPUT="Task completed"
fi

# Build JSON payload
if [ -n "$FILES" ]; then
  # Convert comma-separated to JSON array
  FILES_JSON=$(echo "$FILES" | tr ',' '\n' | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//' | sed 's/^/[/;s/$/]/')
  PAYLOAD=$(cat <<EOF
{
  "output": $(echo "$OUTPUT" | jq -Rs .),
  "files": $FILES_JSON
}
EOF
)
else
  PAYLOAD=$(cat <<EOF
{
  "output": $(echo "$OUTPUT" | jq -Rs .)
}
EOF
)
fi

# Make request
RESPONSE=$(curl -s -X POST "$CLAWTROL_URL/api/v1/tasks/$TASK_ID/agent_complete" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: ${AGENT_NAME:-Agent}" \
  -H "X-Agent-Emoji: ${AGENT_EMOJI:-🤖}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Check if jq is available for pretty output
if command -v jq &> /dev/null; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi

# Check for success
if command -v jq &> /dev/null; then
  STATUS=$(echo "$RESPONSE" | jq -r '.status // empty')
  if [ "$STATUS" = "in_review" ]; then
    echo ""
    echo "✅ Task #$TASK_ID completed and moved to in_review"
  fi
fi
