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
[ $# -eq 3 ] || harto_die "usage: ${HARTO_PROG} localenv set [--project NAME] <env> <var> <value>" 2

envname="$1"
var="$2"
value="$3"
harto_localenv_check_env "$envname" || harto_die "environment name must match ^[A-Za-z][A-Za-z0-9_-]*$" 2
harto_localenv_check_var "$var" || harto_die "variable name must match ^[A-Za-z_][A-Za-z0-9_]*$" 2
case "$value" in
  *$'\n'*) harto_die "the value must be a single line" 2 ;;
esac

project=$(harto_localenv_resolve "$project_opt")
section="${project}.${envname}"

exists=0
if harto_localenv_var_get "$project" "$envname" "$var" >/dev/null 2>&1; then
  exists=1
fi

if harto_is_dry_run; then
  printf '[dry-run] would set %s in %s\n' "$var" "$section" >&2
  exit 0
fi

if [ "$exists" -eq 1 ]; then
  harto_confirm "Replace ${var} in ${section}?" || harto_die "set cancelled" 1
fi
harto_localenv_apply_env "$project" set-var "$envname" "$var" "$value"
harto_log_info "set ${var} in ${section}"
