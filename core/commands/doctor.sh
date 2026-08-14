#!/usr/bin/env bash
# harto-summary: Report the environment without changing it

harto_cmd_doctor() {
  local issues=0 name

  [ $# -eq 0 ] || harto_die "unexpected arguments" 2

  printf 'harto: %s\n' "$HARTO_VERSION"
  printf 'root: %s\n' "$HARTO_ROOT"
  printf 'program: %s\n' "$HARTO_PROG"
  printf 'os: %s\n' "$(harto_platform_os)"
  printf 'arch: %s\n' "$(harto_platform_arch)"
  printf 'config: %s\n' "$HARTO_CONFIG_DIR"
  printf 'state: %s\n' "$HARTO_STATE_DIR"
  printf 'data: %s\n' "$HARTO_DATA_DIR"

  if ! harto_platform_is_darwin; then
    printf 'warn: operating system is not supported\n'
    issues=$((issues + 1))
  fi
  if ! harto_dep_check_core; then
    issues=$((issues + 1))
  fi

  if harto_dep_yq_ok; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      if ! harto_plugin_doctor_one "$name"; then
        issues=$((issues + 1))
      fi
    done <<EOF
$(harto_plugin_each_dir | sed 's|.*/||' | awk '!seen[$0]++')
EOF
  fi

  printf 'issues: %s\n' "$issues"
}
