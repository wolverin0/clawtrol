#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIDECAR_TEST_DIR="$ROOT_DIR/test/sidecar"
mapfile -t MIRROR_TESTS < <(
  find "$ROOT_DIR/test" -type f -name '*_test.rb' |
    grep -Ei 'hermes.*mirror|mirror.*hermes' |
    sort
)

if [[ ${#MIRROR_TESTS[@]} -eq 0 ]]; then
  echo "Hermes mirror gate requires at least one dedicated mirror test file" >&2
  exit 1
fi

if [[ ! -d "$SIDECAR_TEST_DIR" ]] ||
  ! find "$SIDECAR_TEST_DIR" -type f -name 'test_*.py' -print -quit | grep -q .; then
  echo "Hermes mirror gate requires dedicated Python sidecar tests" >&2
  exit 1
fi

RELATIVE_TESTS=()
for test_file in "${MIRROR_TESTS[@]}"; do
  RELATIVE_TESTS+=("${test_file#"$ROOT_DIR/"}")
done

cd "$ROOT_DIR"
bin/rails test "${RELATIVE_TESTS[@]}"
python3 -m unittest discover -s test/sidecar -p 'test_*.py'
