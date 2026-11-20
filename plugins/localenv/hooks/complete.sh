#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

_localenv_projects() {
  local line name

  [ -f "$(harto_localenv_index_file)" ] || return 0
  while IFS= read -r line; do
    name=${line%%=*}
    [ -n "$name" ] || continue
    printf '%s\n' "$name"
  done <<EOF
$(harto_localenv_projects 2>/dev/null || true)
EOF
}

_localenv_envs() {
  local project="$1"
  local names

  [ -n "$project" ] || return 0
  names=$(harto_localenv_env_names "$project" 2>/dev/null) || true
  [ -n "$names" ] || return 0
  printf '%s\n' "$names"
}

_localenv_vars() {
  local project="$1"
  local envname="$2"
  local line key pairs

  [ -n "$project" ] && [ -n "$envname" ] || return 0
  pairs=$(harto_localenv_pairs "$project" "$envname" 2>/dev/null) || true
  [ -n "$pairs" ] || return 0
  while IFS= read -r line; do
    key=${line%%=*}
    [ -n "$key" ] || continue
    printf '%s\n' "$key"
  done <<EOF
$pairs
EOF
}

_localenv_project() {
  local explicit="$1"

  if [ -n "$explicit" ]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  [ -f "$(harto_localenv_index_file)" ] || return 0
  harto_localenv_project_for_cwd 2>/dev/null || true
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
explicit=""
args=()
while [ "$i" -lt "$idx" ] && [ "$i" -lt ${#words[@]} ]; do
  case "${words[$i]}" in
    --project)
      i=$((i + 1))
      if [ "$i" -ge "$idx" ] || [ "$i" -ge ${#words[@]} ]; then
        slot="project"
        break
      fi
      explicit=${words[$i]}
      ;;
    --plain|--encrypt)
      ;;
    -*)
      ;;
    *)
      args[${#args[@]}]=${words[$i]}
      pos=$((pos + 1))
      ;;
  esac
  i=$((i + 1))
done

if [ "$slot" = "project" ]; then
  _localenv_projects
  exit 0
fi

project=$(_localenv_project "$explicit")

case "$sub" in
  init)
    [ "$pos" -eq 0 ] || exit 0
    printf '%s\n' --plain
    printf '%s\n' --encrypt
    ;;
  which|list)
    [ "$pos" -eq 0 ] || exit 0
    printf '%s\n' --project
    ;;
  set|get|unset)
    case "$pos" in
      0)
        printf '%s\n' --project
        _localenv_envs "$project"
        ;;
      1)
        _localenv_vars "$project" "${args[0]:-}"
        ;;
    esac
    ;;
  import|start|show|export|remove|exec)
    case "$pos" in
      0)
        printf '%s\n' --project
        _localenv_envs "$project"
        ;;
    esac
    ;;
esac
