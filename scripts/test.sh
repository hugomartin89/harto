#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

set -- tests/core tests/integration
for dir in plugins/*/tests; do
  [ -d "$dir" ] || continue
  set -- "$@" "$dir"
done
exec bats "$@"
