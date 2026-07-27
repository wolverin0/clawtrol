#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-}"

if [[ ! "$IMAGE" =~ :([0-9a-f]{40})$ ]]; then
  echo "usage: RESTORED_DATABASE_URL=... RESTORED_DB_ISOLATION_ACK=yes $0 <repository:40-char-sha>" >&2
  exit 64
fi

: "${RESTORED_DATABASE_URL:?Set RESTORED_DATABASE_URL to the isolated restored production dump}"
: "${RESTORED_DB_ISOLATION_ACK:?Set RESTORED_DB_ISOLATION_ACK=yes after confirming this is not production}"

if [[ "$RESTORED_DB_ISOLATION_ACK" != "yes" ]]; then
  echo "RESTORED_DB_ISOLATION_ACK must equal yes" >&2
  exit 65
fi

if [[ -n "${PRODUCTION_DATABASE_URL:-}" && "$RESTORED_DATABASE_URL" == "$PRODUCTION_DATABASE_URL" ]]; then
  echo "refusing to run the restore gate against PRODUCTION_DATABASE_URL" >&2
  exit 66
fi

REVISION="${BASH_REMATCH[1]}"
IMAGE_REVISION="$(docker image inspect "$IMAGE" --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}')"
if [[ "$IMAGE_REVISION" != "$REVISION" ]]; then
  echo "image revision label does not match its SHA tag" >&2
  exit 67
fi

export DATABASE_URL="$RESTORED_DATABASE_URL"
DOCKER_ENV=(
  --env DATABASE_URL
  --env RAILS_ENV=production
  --env SECRET_KEY_BASE
  --env APP_BASE_URL
  --env ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
  --env ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
  --env ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
)
DOCKER_NETWORK=()
if [[ -n "${MIGRATION_DOCKER_NETWORK:-}" ]]; then
  DOCKER_NETWORK=(--network "$MIGRATION_DOCKER_NETWORK")
fi

docker run --rm "${DOCKER_NETWORK[@]}" "${DOCKER_ENV[@]}" "$IMAGE" \
  bundle exec rails db:migrate
docker run --rm "${DOCKER_NETWORK[@]}" "${DOCKER_ENV[@]}" "$IMAGE" \
  bundle exec rails db:abort_if_pending_migrations

printf 'restored-database migration gate passed for %s\n' "$REVISION"
