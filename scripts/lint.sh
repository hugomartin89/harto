#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

files=()
while IFS= read -r file; do
  [ -n "$file" ] || continue
  files+=("$file")
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

[ "${#files[@]}" -gt 0 ] || exit 0
exec shellcheck --shell=bash --severity=warning "${files[@]}"
