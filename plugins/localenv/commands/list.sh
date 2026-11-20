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
[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} localenv list [--project NAME]" 2

harto_localenv_require_index

if [ -n "$project_opt" ]; then
  project=$(harto_localenv_resolve "$project_opt")
else
  project=$(harto_localenv_project_for_cwd)
fi

if [ -n "$project" ]; then
  if harto_output_is_json; then
    harto_localenv_env_names "$project" | sed 's/^/name=/' | harto_localenv_json array
  else
    harto_localenv_env_names "$project"
  fi
  exit 0
fi

if harto_output_is_json; then
  harto_localenv_projects | harto_localenv_json object
else
  harto_localenv_projects | while IFS='=' read -r name path; do
    printf '%s\t%s\n' "$name" "$path"
  done
fi
