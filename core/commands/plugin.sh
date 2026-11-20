#!/usr/bin/env bash
# harto-summary: List, inspect, enable, and upgrade plugins

harto_cmd_plugin() {
  local sub

  [ $# -ge 1 ] || harto_die "usage: ${HARTO_PROG} plugin list|info|enable|install|disable|upgrade|doctor" 2
  sub="$1"
  shift

  case "$sub" in
    list)
      harto_dep_check_core || return 1
      harto_plugin_cmd_list "$@"
      ;;
    info)
      harto_dep_check_core || return 1
      harto_plugin_cmd_info "$@"
      ;;
    enable)
      harto_plugin_enable "$@"
      ;;
    install)
      harto_plugin_install "$@"
      ;;
    disable)
      harto_dep_check_core || return 1
      harto_plugin_disable "$@"
      ;;
    upgrade)
      harto_plugin_upgrade "$@"
      ;;
    doctor)
      harto_cmd_plugin_doctor "$@"
      ;;
    *)
      harto_die "unknown plugin command: ${sub}" 2
      ;;
  esac
}

harto_cmd_plugin_doctor() {
  local name

  # shellcheck source=/dev/null
  . "$HARTO_ROOT/core/commands/doctor.sh"

  if [ $# -eq 0 ]; then
    harto_cmd_doctor
    return
  fi
  [ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} plugin doctor [name]" 2
  name="$1"
  harto_dep_check_core || true
  harto_plugin_doctor_one "$name" || true
}

harto_plugin_upgrade() {
  local name="$1"
  local dir manifest hook

  [ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} plugin upgrade <name>" 2
  harto_dep_check_core || return 1
  dir=$(harto_plugin_dir "$name") || harto_die "plugin not found: ${name}" 1
  harto_plugin_validate "$dir" || return 1
  manifest="${dir}/config.yml"
  harto_dep_check_manifest "$manifest" || return 1

  if ! harto_state_plugin_active "$name"; then
    harto_die "plugin ${name} is not active. Run: ${HARTO_PROG} plugin enable ${name}" 1
  fi

  harto_upgrade_repo "$dir"
  harto_plugin_run_migrations "$name"
  hook=$(harto_plugin_hook_path "$manifest" upgrade)
  if [ -n "$hook" ] && [ "$hook" != "null" ] && ! harto_is_dry_run; then
    harto_plugin_run "$name" "$hook"
  fi
  if harto_is_dry_run; then
    printf '[dry-run] would upgrade plugin %s\n' "$name" >&2
    return 0
  fi
  harto_log_info "upgraded plugin ${name}"
}

harto_complete_plugin() {
  local idx="$1"
  shift
  local -a words=()
  local cmd_at sub_at sub name_at

  if [ "$#" -gt 0 ]; then
    words=("$@")
  fi
  cmd_at=$(harto_completion_command_index "${words[@]+"${words[@]}"}") || return 0
  sub_at=$((cmd_at + 1))
  if [ "$idx" -eq "$sub_at" ]; then
    printf '%s\n' list info enable install disable upgrade doctor
    return 0
  fi
  [ "$idx" -gt "$sub_at" ] || return 0
  [ "$sub_at" -lt ${#words[@]} ] || return 0
  sub=${words[$sub_at]}
  name_at=$((sub_at + 1))
  [ "$idx" -eq "$name_at" ] || return 0
  case "$sub" in
    enable) _harto_complete_plugin_names repo ;;
    info|disable|upgrade|doctor) _harto_complete_plugin_names all ;;
  esac
}

_harto_complete_plugin_names() {
  local mode="$1"
  local dir name seen

  seen=" "
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name=$(basename "$dir")
    case "$seen" in
      *" ${name} "*) continue ;;
    esac
    seen="${seen}${name} "
    if [ "$mode" = "repo" ] && ! harto_plugin_in_repository "$name"; then
      continue
    fi
    harto_completion_candidate "$name" "$(harto_plugin_description "$name")"
  done <<EOF
$(harto_plugin_each_dir)
EOF
}
