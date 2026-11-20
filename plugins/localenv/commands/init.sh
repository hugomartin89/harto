#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

name=""
mode=""
while [ $# -gt 0 ]; do
  case "$1" in
    --plain)
      [ -z "$mode" ] || harto_die "use either --plain or --encrypt, not both" 2
      mode=plain
      shift
      ;;
    --encrypt)
      [ -z "$mode" ] || harto_die "use either --plain or --encrypt, not both" 2
      mode=encrypted
      shift
      ;;
    -*) harto_die "unknown option: ${1}" 2 ;;
    *)
      [ -z "$name" ] || harto_die "unexpected argument: ${1}" 2
      name="$1"
      shift
      ;;
  esac
done
[ -n "$name" ] || harto_die "usage: ${HARTO_PROG} localenv init <name> [--plain|--encrypt]" 2
harto_localenv_check_project "$name" || harto_die "project name must match ^[A-Za-z][A-Za-z0-9_-]*$" 2

path=$(pwd -P)
case "$path" in
  *$'\n'*) harto_die "the directory path contains a newline" 1 ;;
esac

if harto_is_dry_run; then
  printf '[dry-run] would register project %s at %s (%s)\n' "$name" "$path" "${mode:-default}" >&2
  exit 0
fi

harto_with_lock localenv-store harto_localenv_init_locked "$name" "$path" "$mode"
