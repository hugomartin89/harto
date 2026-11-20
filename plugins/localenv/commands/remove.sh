#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

usage="usage: ${HARTO_PROG} localenv remove [--project NAME] <env> | --project [NAME]"
project_opt=""
project_flag=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      project_flag=1
      if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
        project_opt="$2"
        shift
      fi
      shift
      ;;
    -*) harto_die "unknown option: ${1}" 2 ;;
    *) break ;;
  esac
done

if [ $# -eq 0 ]; then
  [ "$project_flag" -eq 1 ] || harto_die "$usage" 2

  project=$(harto_localenv_resolve "$project_opt")
  if harto_is_dry_run; then
    printf '[dry-run] would remove project %s and all its environments\n' "$project" >&2
    exit 0
  fi
  harto_confirm "Remove project ${project} and all its environments?" || harto_die "remove cancelled" 1
  harto_with_lock localenv-store harto_localenv_remove_project_locked "$project"
  harto_log_info "removed project ${project}"
  exit 0
fi

[ $# -eq 1 ] || harto_die "$usage" 2
envname="$1"
harto_localenv_check_env "$envname" || harto_die "environment name must match ^[A-Za-z][A-Za-z0-9_-]*$" 2

project=$(harto_localenv_resolve "$project_opt")
harto_localenv_require_env "$project" "$envname"
section="${project}.${envname}"

if harto_is_dry_run; then
  printf '[dry-run] would remove environment %s\n' "$section" >&2
  exit 0
fi

harto_confirm "Remove environment ${section} and its variables?" || harto_die "remove cancelled" 1
harto_localenv_apply_env "$project" del-section "$envname"
harto_log_info "removed environment ${section}"
