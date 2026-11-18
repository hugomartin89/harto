#!/usr/bin/env bash
# harto-summary: Show available commands
# harto-output: json

_harto_help_plugin_dirs() {
  local dir name seen

  seen=" "
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name=$(basename "$dir")
    case "$seen" in
      *" ${name} "*) continue ;;
    esac
    seen="${seen}${name} "
    printf '%s\n' "$dir"
  done <<EOF
$(harto_plugin_each_dir)
EOF
}

_harto_help_json() {
  local file dir core plugins entry

  harto_dep_yq_ok || harto_die "help --json needs yq (mikefarah) >= 4" 1

  core=""
  for file in "$HARTO_ROOT/core/commands"/*.sh; do
    [ -f "$file" ] || continue
    entry=$(NAME=$(basename "$file" .sh) SUMMARY=$(harto_plugin_summary "$file") \
      JSON=$(harto_command_output "$file") \
      yq eval -n -o=json -I=0 '.name = strenv(NAME) | .description = strenv(SUMMARY) | .json = (strenv(JSON) == "json")')
    core="${core}${core:+,}${entry}"
  done

  plugins=""
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    harto_plugin_validate "$dir" >/dev/null 2>&1 || continue
    entry=$(yq eval -o=json -I=0 '{
      "name": .name,
      "description": .description,
      "commands": [(.commands // [])[] | {
        "name": .name,
        "description": .description,
        "usage": (.usage // ""),
        "privileged": (.privileged // false),
        "json": (.json // false)
      }]
    }' "${dir}/plugin.yml")
    plugins="${plugins}${plugins:+,}${entry}"
  done <<EOF
$(_harto_help_plugin_dirs)
EOF

  printf '{"core":[%s],"plugins":[%s]}\n' "$core" "$plugins"
}

harto_cmd_help() {
  local file summary dir name count index

  [ $# -eq 0 ] || harto_die "unexpected arguments" 2

  if harto_output_is_json; then
    _harto_help_json
    return 0
  fi

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
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name=$(basename "$dir")
    if ! harto_plugin_validate "$dir" >/dev/null 2>&1; then
      printf '  %s\n    manifest is invalid\n' "$name"
      continue
    fi
    count=$(yq eval '.commands // [] | length' "${dir}/plugin.yml")
    index=0
    while [ "$index" -lt "$count" ]; do
      harto_plugin_command_line "$name" "${dir}/plugin.yml" "$index"
      index=$((index + 1))
    done
  done <<EOF
$(_harto_help_plugin_dirs)
EOF
}
