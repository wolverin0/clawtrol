#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REVISION="${1:-$(git -C "$ROOT_DIR" rev-parse HEAD)}"
IMAGE_REPOSITORY="${CLAWTROL_IMAGE_REPOSITORY:-ghcr.io/wolverin0/clawtrol}"

if [[ ! "$REVISION" =~ ^[0-9a-f]{40}$ ]]; then
  echo "revision must be the exact 40-character lowercase Git SHA" >&2
  exit 64
fi

if [[ "$(git -C "$ROOT_DIR" rev-parse HEAD)" != "$REVISION" ]]; then
  echo "requested revision is not the checked-out HEAD" >&2
  exit 65
fi

if ! git -C "$ROOT_DIR" diff --quiet || ! git -C "$ROOT_DIR" diff --cached --quiet; then
  echo "refusing to build a release image from a dirty worktree" >&2
  exit 66
fi

IMAGE="${IMAGE_REPOSITORY}:${REVISION}"
docker build \
  --pull \
  --build-arg "APP_REVISION=${REVISION}" \
  --label "org.opencontainers.image.revision=${REVISION}" \
  --tag "$IMAGE" \
  "$ROOT_DIR"

LABEL_REVISION="$(docker image inspect "$IMAGE" --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}')"
ENV_REVISION="$(docker image inspect "$IMAGE" --format '{{ range .Config.Env }}{{ println . }}{{ end }}' |
  sed -n 's/^APP_REVISION=//p')"

if [[ "$LABEL_REVISION" != "$REVISION" || "$ENV_REVISION" != "$REVISION" ]]; then
  echo "built image revision metadata does not match the tested Git SHA" >&2
  exit 67
fi

printf '%s\n' "$IMAGE"
