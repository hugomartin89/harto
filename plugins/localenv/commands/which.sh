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
[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} localenv which [--project NAME]" 2

project=$(harto_localenv_resolve "$project_opt")
path=$(harto_localenv_project_path "$project")

if harto_output_is_json; then
  printf 'name=%s\npath=%s\n' "$project" "$path" | harto_localenv_json object
else
  printf '%s\t%s\n' "$project" "$path"
fi
