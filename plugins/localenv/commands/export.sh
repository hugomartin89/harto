#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

project_opt=""
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      [ $# -ge 2 ] || harto_die "--project needs a value" 2
      project_opt="$2"
      shift 2
      ;;
    -*) harto_die "unknown option: ${1}" 2 ;;
    *) break ;;
  esac
done
[ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} localenv export [--project NAME] <env>" 2

envname="$1"
harto_localenv_check_env "$envname" || harto_die "environment name must match ^[A-Za-z][A-Za-z0-9_-]*$" 2

project=$(harto_localenv_resolve "$project_opt")
harto_localenv_require_env "$project" "$envname"

harto_localenv_pairs "$project" "$envname" | while IFS= read -r pair; do
  printf 'export %s=%s\n' "${pair%%=*}" "$(printf '%q' "${pair#*=}")"
done
