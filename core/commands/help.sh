#!/usr/bin/env bash
# harto-summary: Show available commands

harto_cmd_help() {
  local file summary dir name description count index command_name seen

  [ $# -eq 0 ] || harto_die "unexpected arguments" 2

  printf 'HARTO is a local development toolkit.\n\n'
  printf 'Usage: %s <command> [arguments]\n\n' "$HARTO_PROG"
  printf 'Core commands:\n'
  for file in "$HARTO_ROOT/core/commands"/*.sh; do
    [ -f "$file" ] || continue
    name=$(basename "$file" .sh)
    summary=$(harto_plugin_summary "$file")
    printf '  %s\n    %s\n' "$name" "${summary:-}"
  done

  if ! harto_dep_yq_ok; then
    printf '\nPlugin commands are hidden until yq (mikefarah) >= 4 is installed.\n'
    return 0
  fi

  printf '\nPlugin commands:\n'
  seen=" "
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name=$(basename "$dir")
    case "$seen" in
      *" ${name} "*) continue ;;
    esac
    seen="${seen}${name} "
    if ! harto_plugin_validate "$dir" >/dev/null 2>&1; then
      printf '  %s\n    manifest is invalid\n' "$name"
      continue
    fi
    count=$(yq eval '.commands // [] | length' "${dir}/plugin.yml")
    index=0
    while [ "$index" -lt "$count" ]; do
      command_name=$(yq eval ".commands[${index}].name" "${dir}/plugin.yml")
      description=$(yq eval ".commands[${index}].description" "${dir}/plugin.yml")
      printf '  %s %s\n    %s\n' "$name" "$command_name" "$description"
      index=$((index + 1))
    done
  done <<EOF
$(harto_plugin_each_dir)
EOF
}
