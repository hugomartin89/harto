#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

_devhost_routes() {
  local file name

  file=$(harto_devhost_routes_file)
  [ -f "$file" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" != "null" ] || continue
    printf '%s\n' "$name"
  done <<EOF
$(yq eval '.routes // [] | .[].name' "$file" 2>/dev/null || true)
EOF
}

idx="${1:-0}"
shift || true

words=()
if [ "$#" -gt 0 ]; then
  words=("$@")
fi

cmd_at=$(harto_completion_command_index "${words[@]+"${words[@]}"}") || exit 0
sub_at=$((cmd_at + 1))
[ "$sub_at" -lt ${#words[@]} ] || exit 0
sub=${words[$sub_at]}

i=$((sub_at + 1))
pos=0
slot="positional"
args=()
while [ "$i" -lt "$idx" ] && [ "$i" -lt ${#words[@]} ]; do
  case "${words[$i]}" in
    --port|--target)
      i=$((i + 1))
      if [ "$i" -ge "$idx" ] || [ "$i" -ge ${#words[@]} ]; then
        slot="value"
        break
      fi
      ;;
    -*)
      ;;
    *)
      args[${#args[@]}]=${words[$i]}
      pos=$((pos + 1))
      ;;
  esac
  i=$((i + 1))
done

case "$sub" in
  add)
    [ "$slot" = "positional" ] && [ "$pos" -eq 0 ] || exit 0
    _devhost_routes
    printf '%s\n' --port
    printf '%s\n' --target
    ;;
  remove)
    [ "$slot" = "positional" ] && [ "$pos" -eq 0 ] || exit 0
    _devhost_routes
    ;;
  config)
    [ "$slot" = "positional" ] || exit 0
    case "$pos" in
      0)
        printf '%s\n' show
        printf '%s\n' set
        ;;
      1)
        [ "${args[0]:-}" = "set" ] || exit 0
        printf '%s\n' domain
        ;;
    esac
    ;;
esac
