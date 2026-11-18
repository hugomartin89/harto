#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

name=""
mode="read"
print_token=0

while [ $# -gt 0 ]; do
  case "$1" in
    --write)
      mode="write"
      shift
      ;;
    --print)
      print_token=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      harto_die "unknown option: ${1}" 2
      ;;
    *)
      [ -z "$name" ] || harto_die "unexpected argument: ${1}" 2
      name="$1"
      shift
      ;;
  esac
done

[ $# -eq 0 ] || harto_die "unexpected arguments" 2
[ -n "$name" ] || harto_die "usage: ${HARTO_PROG} rds token <name> [--write] [--print]" 2

lines=$(harto_rds_endpoint "$name" "$mode")
host=$(printf '%s\n' "$lines" | sed -n '1p')
port=$(printf '%s\n' "$lines" | sed -n '2p')
user=$(printf '%s\n' "$lines" | sed -n '3p')
profile=$(printf '%s\n' "$lines" | sed -n '5p')
region=$(printf '%s\n' "$lines" | sed -n '6p')
if harto_is_dry_run; then
  printf '[dry-run] would generate a database auth token for %s\n' "$name" >&2
  exit 0
fi

token=$(harto_rds_auth_token "$profile" "$region" "$host" "$port" "$user")
if [ "$print_token" -eq 1 ]; then
  printf '%s\n' "$token"
  harto_log_info "token printed. It expires in 15 minutes."
else
  harto_rds_copy_token "$token"
fi
