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
[ $# -eq 2 ] || harto_die "usage: ${HARTO_PROG} localenv import [--project NAME] <env> <file>" 2

envname="$1"
file="$2"
harto_localenv_check_env "$envname" || harto_die "environment name must match ^[A-Za-z][A-Za-z0-9_-]*$" 2

project=$(harto_localenv_resolve "$project_opt")
parsed=$(harto_localenv_parse_env_file "$file") || exit $?
section="${project}.${envname}"

count=0
replacing=0
existing=$(harto_localenv_pairs "$project" "$envname" || true)
while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  count=$((count + 1))
  key=${line%%=*}
  if printf '%s\n' "$existing" | grep -q "^${key}="; then
    replacing=1
  fi
done <<EOF
$parsed
EOF

if harto_is_dry_run; then
  printf '[dry-run] would import %s variables into %s\n' "$count" "$section" >&2
  exit 0
fi

if [ "$replacing" -eq 1 ]; then
  harto_confirm "Replace existing variables in ${section}?" || harto_die "import cancelled" 1
fi

printf '%s\n' "$parsed" | harto_with_lock localenv-store harto_localenv_import_locked "$project" "$envname"
harto_log_info "imported ${count} variables into ${section}"
