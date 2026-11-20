#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

_rds_names() {
  local file name

  file=$(harto_rds_databases_file)
  [ -f "$file" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" != "null" ] || continue
    printf '%s\n' "$name"
  done <<EOF
$(yq eval '.databases // [] | .[].name' "$file" 2>/dev/null || true)
EOF
}

_rds_profiles() {
  local profile

  while IFS= read -r profile; do
    [ -n "$profile" ] || continue
    case "$profile" in
      *[[:space:]]*) continue ;;
    esac
    printf '%s\n' "$profile"
  done <<EOF
$(aws configure list-profiles 2>/dev/null || true)
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
while [ "$i" -lt "$idx" ] && [ "$i" -lt ${#words[@]} ]; do
  case "${words[$i]}" in
    --engine)
      i=$((i + 1))
      if [ "$i" -ge "$idx" ] || [ "$i" -ge ${#words[@]} ]; then
        slot="engine"
        break
      fi
      ;;
    --profile)
      i=$((i + 1))
      if [ "$i" -ge "$idx" ] || [ "$i" -ge ${#words[@]} ]; then
        slot="profile"
        break
      fi
      ;;
    --reader|--writer|--database)
      i=$((i + 1))
      if [ "$i" -ge "$idx" ] || [ "$i" -ge ${#words[@]} ]; then
        slot="value"
        break
      fi
      ;;
    -*)
      ;;
    *)
      pos=$((pos + 1))
      ;;
  esac
  i=$((i + 1))
done

case "$slot" in
  engine)
    printf '%s\n' mysql
    printf '%s\n' postgres
    exit 0
    ;;
  profile)
    _rds_profiles
    exit 0
    ;;
  value)
    exit 0
    ;;
esac

case "$sub" in
  add)
    [ "$pos" -eq 0 ] || exit 0
    printf '%s\n' --engine
    printf '%s\n' --profile
    printf '%s\n' --reader
    printf '%s\n' --writer
    ;;
  remove|profile)
    [ "$pos" -eq 0 ] || exit 0
    _rds_names
    ;;
  token)
    [ "$pos" -eq 0 ] && _rds_names
    printf '%s\n' --write
    printf '%s\n' --print
    ;;
  connect)
    [ "$pos" -eq 0 ] && _rds_names
    printf '%s\n' --write
    printf '%s\n' --database
    ;;
esac
