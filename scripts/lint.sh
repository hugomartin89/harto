#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

status=0
while IFS= read -r file; do
  [ -n "$file" ] || continue
  shellcheck --shell=bash --severity=warning "$file" || status=1
done <<EOF
$(find bin core plugins scripts .githooks tests/helpers \
  -type f \
  ! -name '*.yml' \
  ! -name '*.plist' \
  ! -name '*.conf' \
  ! -name 'resolver' \
  ! -name '*.md' \
  ! -name '*.bash')
EOF
exit "$status"
