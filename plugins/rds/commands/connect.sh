#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

name=""
mode="read"
database=""

while [ $# -gt 0 ]; do
  case "$1" in
    --write)
      mode="write"
      shift
      ;;
    --database)
      [ $# -ge 2 ] || harto_die "--database needs a value" 2
      database="$2"
      shift 2
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
[ -n "$name" ] || harto_die "usage: ${HARTO_PROG} rds connect <name> [--write] [--database NAME]" 2
if [ -n "$database" ]; then
  harto_rds_check_database "$database" || harto_die "invalid database name: ${database}" 2
fi

lines=$(harto_rds_endpoint "$name" "$mode")
host=$(printf '%s\n' "$lines" | sed -n '1p')
port=$(printf '%s\n' "$lines" | sed -n '2p')
user=$(printf '%s\n' "$lines" | sed -n '3p')
engine=$(printf '%s\n' "$lines" | sed -n '4p')
profile=$(printf '%s\n' "$lines" | sed -n '5p')
region=$(printf '%s\n' "$lines" | sed -n '6p')
if harto_is_dry_run; then
  printf '[dry-run] would connect to %s\n' "$name" >&2
  exit 0
fi

token=$(harto_rds_auth_token "$profile" "$region" "$host" "$port" "$user")
harto_rds_connect_client "$engine" "$host" "$port" "$user" "$token" "$database"
