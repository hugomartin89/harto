#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

if ! command -v parallel >/dev/null 2>&1; then
  printf 'GNU parallel is required to run the tests.\n' >&2
  printf 'install: brew install parallel\n' >&2
  exit 1
fi

jobs=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
case "$jobs" in
  ''|*[!0-9]*) jobs=1 ;;
esac

set -- tests/core tests/integration
for dir in plugins/*/tests; do
  [ -d "$dir" ] || continue
  set -- "$@" "$dir"
done
if [ "$jobs" -gt 1 ]; then
  exec bats --jobs "$jobs" "$@"
fi
exec bats "$@"
