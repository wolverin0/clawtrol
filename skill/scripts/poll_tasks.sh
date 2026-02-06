#!/bin/bash
# Poll for assigned tasks from ClawTrol
# Usage: ./poll_tasks.sh [--status STATUS] [--board BOARD_ID]

set -e

# Check required env vars
if [ -z "$CLAWTROL_URL" ] || [ -z "$CLAWTROL_TOKEN" ]; then
  echo "Error: CLAWTROL_URL and CLAWTROL_TOKEN must be set" >&2
  exit 1
fi

# Defaults
STATUS=""
BOARD_ID=""
ASSIGNED="true"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --status)
      STATUS="$2"
      shift 2
      ;;
    --board)
      BOARD_ID="$2"
      shift 2
      ;;
    --all)
      ASSIGNED=""
      shift
      ;;
    -h|--help)
      echo "Usage: poll_tasks.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --status STATUS   Filter by status (inbox, up_next, in_progress, in_review, done)"
      echo "  --board BOARD_ID  Filter by board ID"
      echo "  --all             Show all tasks, not just assigned ones"
      echo "  -h, --help        Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Build query string
QUERY=""
if [ -n "$ASSIGNED" ]; then
  QUERY="?assigned=$ASSIGNED"
fi
if [ -n "$STATUS" ]; then
  if [ -n "$QUERY" ]; then
    QUERY="${QUERY}&status=$STATUS"
  else
    QUERY="?status=$STATUS"
  fi
fi
if [ -n "$BOARD_ID" ]; then
  if [ -n "$QUERY" ]; then
    QUERY="${QUERY}&board_id=$BOARD_ID"
  else
    QUERY="?board_id=$BOARD_ID"
  fi
fi

# Make request
RESPONSE=$(curl -s "$CLAWTROL_URL/api/v1/tasks$QUERY" \
  -H "Authorization: Bearer $CLAWTROL_TOKEN" \
  -H "X-Agent-Name: ${AGENT_NAME:-Agent}" \
  -H "X-Agent-Emoji: ${AGENT_EMOJI:-🤖}")

# Check if jq is available for pretty output
if command -v jq &> /dev/null; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
