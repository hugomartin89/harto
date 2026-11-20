#!/usr/bin/env bash

harto_plugin_validate_name() {
  harto_valid_name "$1"
}

harto_plugin_dir() {
  local name="$1"

  harto_plugin_validate_name "$name" || return 1
  if [ -f "$HARTO_ROOT/plugins/${name}/config.yml" ]; then
    printf '%s\n' "$HARTO_ROOT/plugins/${name}"
    return 0
  fi
  if [ -f "${HARTO_DATA_DIR}/plugins/${name}/config.yml" ]; then
    printf '%s\n' "${HARTO_DATA_DIR}/plugins/${name}"
    return 0
  fi
  return 1
}

harto_plugin_manifest() {
  local dir
  dir=$(harto_plugin_dir "$1") || return 1
  printf '%s/config.yml\n' "$dir"
}

harto_plugin_each_dir() {
  local root dir
  for root in "$HARTO_ROOT/plugins" "${HARTO_DATA_DIR}/plugins"; do
    [ -d "$root" ] || continue
    for dir in "$root"/*; do
      [ -d "$dir" ] || continue
      [ -f "$dir/config.yml" ] || continue
      printf '%s\n' "$dir"
    done
  done
}

harto_plugin_path_safe() {
  local rel="$1"
  case "$rel" in
    /*|../*|*/../*|*/..|*..*) return 1 ;;
  esac
  printf '%s\n' "$rel" | grep -Eq '^[a-zA-Z0-9._/-]+$'
}

harto_plugin_validate() {
  local dir="$1"
  local manifest name description count index entry hook os listed
  local failed=0

  manifest="${dir}/config.yml"
  if ! harto_yaml_valid "$manifest"; then
    harto_log_error "invalid plugin manifest: ${manifest}"
    return 1
  fi

  name=$(yq eval '.name // ""' "$manifest")
  description=$(yq eval '.description // ""' "$manifest")

  if [ "$(basename "$dir")" != "$name" ] || ! harto_plugin_validate_name "$name"; then
    harto_log_error "plugin name must match its directory and match ^[a-z][a-z0-9-]*$: ${dir}"
    failed=1
  fi
  if [ -z "$description" ] || [ "$description" = "null" ]; then
    harto_log_error "plugin ${name} is missing a description"
    failed=1
  fi

  os=$(harto_platform_os)
  listed=$(yq eval '.platforms // [] | length' "$manifest")
  if [ "$listed" -gt 0 ]; then
    if ! OS="$os" yq eval '.platforms // [] | map(select(. == strenv(OS))) | .[0] // ""' "$manifest" | grep -qx "$os"; then
      harto_log_error "plugin ${name} does not support ${os}"
      failed=1
    fi
  fi

  count=$(yq eval '.commands // [] | length' "$manifest")
  index=0
  while [ "$index" -lt "$count" ]; do
    entry=$(yq eval ".commands[${index}].entrypoint // \"\"" "$manifest")
    if ! harto_plugin_path_safe "$entry" || [ ! -f "${dir}/${entry}" ]; then
      harto_log_error "plugin ${name} has an invalid command entrypoint: ${entry}"
      failed=1
    fi
    _harto_plugin_field_tag "$manifest" "$index" usage '!!str' || failed=1
    _harto_plugin_field_tag "$manifest" "$index" privileged '!!bool' || failed=1
    _harto_plugin_field_tag "$manifest" "$index" json '!!bool' || failed=1
    index=$((index + 1))
  done

  for hook in install configure doctor upgrade uninstall; do
    entry=$(yq eval ".hooks.${hook} // \"\"" "$manifest")
    if [ -z "$entry" ] || [ "$entry" = "null" ]; then
      continue
    fi
    if ! harto_plugin_path_safe "$entry" || [ ! -f "${dir}/${entry}" ]; then
      harto_log_error "plugin ${name} has an invalid ${hook} hook: ${entry}"
      failed=1
    fi
  done

  return "$failed"
}

_harto_plugin_field_tag() {
  local manifest="$1"
  local index="$2"
  local field="$3"
  local want="$4"
  local tag command_name

  tag=$(yq eval ".commands[${index}].${field} | tag" "$manifest")
  if [ "$tag" = "!!null" ] || [ "$tag" = "$want" ]; then
    return 0
  fi
  command_name=$(yq eval ".commands[${index}].name" "$manifest")
  harto_log_error "command ${command_name} in ${manifest} has an invalid ${field}"
  return 1
}

harto_plugin_command_field() {
  local manifest="$1"
  local command_name="$2"
  local field="$3"

  CMD="$command_name" yq eval ".commands[] | select(.name == strenv(CMD)) | .${field} // \"\"" "$manifest"
}

harto_plugin_command_line() {
  local plugin="$1"
  local manifest="$2"
  local index="$3"
  local command_name usage

  command_name=$(yq eval ".commands[${index}].name" "$manifest")
  usage=$(yq eval ".commands[${index}].usage // \"\"" "$manifest")
  printf '  %s %s' "$plugin" "$command_name"
  [ -z "$usage" ] || printf ' %s' "$usage"
  printf '\n    %s\n' "$(yq eval ".commands[${index}].description" "$manifest")"
}

harto_plugin_command_entry() {
  local name="$1"
  local command_name="$2"
  local manifest entry

  manifest=$(harto_plugin_manifest "$name") || return 1
  entry=$(CMD="$command_name" yq eval '.commands[] | select(.name == strenv(CMD)) | .entrypoint' "$manifest")
  if [ -z "$entry" ] || [ "$entry" = "null" ]; then
    return 1
  fi
  printf '%s\n' "$entry"
}

harto_plugin_summary() {
  local file="$1"
  sed -n 's/^# harto-summary: //p' "$file" | head -n 1
}

harto_command_output() {
  local file="$1"
  sed -n 's/^# harto-output: //p' "$file" | head -n 1
}

harto_plugin_run() {
  local name="$1"
  local rel="$2"
  shift 2
  local dir script

  dir=$(harto_plugin_dir "$name") || harto_die "plugin not found: ${name}" 1
  harto_plugin_path_safe "$rel" || harto_die "refusing plugin path: ${rel}" 1
  script="${dir}/${rel}"
  [ -f "$script" ] || harto_die "plugin file not found: ${rel}" 1
  case "$script" in
    "${dir}/"*) ;;
    *) harto_die "plugin path escapes ${name}: ${rel}" 1 ;;
  esac

  (
    export HARTO_PLUGIN_DIR="$dir"
    export HARTO_PLUGIN_CONFIG_DIR="${HARTO_CONFIG_DIR}/plugins/${name}"
    export HARTO_PLUGIN_STATE_DIR="${HARTO_STATE_DIR}/plugins/${name}"
    export HARTO_PLUGIN_DATA_DIR="${HARTO_DATA_DIR}/plugins/${name}"
    export HARTO_LIB HARTO_ROOT HARTO_PROG
    export HARTO_CONFIG_DIR HARTO_STATE_DIR HARTO_DATA_DIR
    export HARTO_YES HARTO_DRY_RUN HARTO_DEBUG
    export HARTO_NONINTERACTIVE HARTO_OUTPUT HARTO_INVOCATION
    exec bash "$script" "$@"
  )
}

harto_plugin_dispatch() {
  local name="$1"
  shift
  local sub entry dir

  dir=$(harto_plugin_dir "$name") || harto_die "plugin not found: ${name}" 1
  harto_plugin_validate "$dir" || harto_die "plugin ${name} failed validation" 1

  if [ $# -eq 0 ]; then
    harto_output_text_only "${name}"
    harto_plugin_print_help "$name"
    return 0
  fi

  sub="$1"
  shift
  entry=$(harto_plugin_command_entry "$name" "$sub") || harto_die "unknown command: ${name} ${sub}" 2
  if harto_output_is_json && [ "$(harto_plugin_command_field "${dir}/config.yml" "$sub" json)" != "true" ]; then
    harto_die "${name} ${sub} does not support --json" 2
  fi
  harto_plugin_run "$name" "$entry" "$@"
}

harto_plugin_print_help() {
  local name="$1"
  local manifest count index description

  manifest=$(harto_plugin_manifest "$name") || return 1
  description=$(yq eval '.description // ""' "$manifest")
  printf '%s - %s\n' "$name" "$description"
  printf '\nCommands:\n'
  count=$(yq eval '.commands // [] | length' "$manifest")
  index=0
  while [ "$index" -lt "$count" ]; do
    harto_plugin_command_line "$name" "$manifest" "$index"
    index=$((index + 1))
  done
}

harto_plugin_run_migrations() {
  local name="$1"
  local dir file base id rel

  dir=$(harto_plugin_dir "$name") || return 1
  [ -d "${dir}/migrations" ] || return 0

  if ! harto_is_dry_run; then
    harto_state_prepare_plugin "$name"
  fi
  for file in "${dir}/migrations"/[0-9][0-9][0-9][0-9]-*.sh; do
    [ -f "$file" ] || continue
    base=$(basename "$file")
    id=${base%%-*}
    if [ -f "$(harto_state_file)" ] && harto_state_migration_applied "$name" "$id"; then
      harto_log_debug "migration ${base} already applied"
      continue
    fi
    if harto_is_dry_run; then
      printf '[dry-run] would run migration %s\n' "$base" >&2
      continue
    fi
    if [ -d "${HARTO_CONFIG_DIR}/plugins/${name}" ]; then
      harto_backup_dir "${HARTO_CONFIG_DIR}/plugins/${name}" >/dev/null || true
    fi
    rel="migrations/${base}"
    harto_log_info "running migration ${name} ${base}"
    harto_plugin_run "$name" "$rel"
    harto_state_add_migration "$name" "$id"
  done
}

harto_plugin_in_repository() {
  local name="$1"

  harto_plugin_validate_name "$name" || return 1
  [ -f "$HARTO_ROOT/plugins/${name}/config.yml" ]
}

harto_plugin_setup_command() {
  local name="$1"
  local entry

  entry=$(harto_plugin_command_entry "$name" setup) || {
    harto_log_info "plugin ${name} has no setup command"
    return 0
  }
  harto_log_info "running setup for ${name}"
  if ! harto_plugin_run "$name" "$entry"; then
    harto_die "setup failed for ${name}. Run: ${HARTO_PROG} ${name} setup" 1
  fi
}

harto_plugin_enable() {
  local name dir manifest hook

  [ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} plugin enable <name>" 2
  name="$1"
  harto_dep_check_core || return 1
  if ! harto_plugin_in_repository "$name"; then
    harto_die "plugin ${name} is not in this repository. A plugin from a git URL will use: ${HARTO_PROG} plugin install <git-url>" 1
  fi
  dir="$HARTO_ROOT/plugins/${name}"
  harto_plugin_validate "$dir" || return 1
  manifest="${dir}/config.yml"
  harto_dep_check_manifest "$manifest" || return 1

  if harto_state_plugin_active "$name"; then
    harto_log_info "plugin ${name} is already active"
    return 0
  fi

  if harto_is_dry_run; then
    printf '[dry-run] would enable plugin %s\n' "$name" >&2
    printf '[dry-run] would run setup for %s\n' "$name" >&2
    return 0
  fi

  hook=$(yq eval '.hooks.install // ""' "$manifest")
  if [ -n "$hook" ] && [ "$hook" != "null" ]; then
    harto_plugin_run "$name" "$hook"
  fi
  harto_plugin_run_migrations "$name"
  harto_state_prepare_plugin "$name"
  harto_log_info "enabled plugin ${name}"
  harto_plugin_setup_command "$name"
}

harto_plugin_install() {
  local source

  [ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} plugin install <git-url>" 2
  source="$1"
  if harto_plugin_in_repository "$source"; then
    harto_die "plugin ${source} is already in this repository. Run: ${HARTO_PROG} plugin enable ${source}" 1
  fi
  harto_die "plugin install is not available yet. It will clone a plugin from a git repository URL." 1
}

harto_plugin_disable() {
  local name dir manifest hook

  [ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} plugin disable <name>" 2
  name="$1"
  dir=$(harto_plugin_dir "$name") || harto_die "plugin not found: ${name}" 1
  manifest="${dir}/config.yml"
  hook=$(yq eval '.hooks.uninstall // ""' "$manifest")

  if harto_is_dry_run; then
    printf '[dry-run] would disable plugin %s\n' "$name" >&2
    if [ -n "$hook" ] && [ "$hook" != "null" ]; then
      harto_plugin_run "$name" "$hook"
    fi
    printf '[dry-run] would remove %s from the active state\n' "$name" >&2
    return 0
  fi

  if ! harto_confirm "Disable plugin ${name}?"; then
    harto_die "disable cancelled" 1
  fi
  if [ -n "$hook" ] && [ "$hook" != "null" ]; then
    harto_plugin_run "$name" "$hook"
  fi
  if [ -f "$(harto_state_file)" ]; then
    harto_state_remove_plugin "$name"
  fi
  harto_log_info "disabled plugin ${name}"
}

harto_plugin_cmd_list() {
  local dir name installed description seen
  seen=" "

  [ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} plugin list" 2
  printf 'NAME\tACTIVE\tDESCRIPTION\n'
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name=$(basename "$dir")
    case "$seen" in
      *" ${name} "*) continue ;;
    esac
    seen="${seen}${name} "
    if ! harto_plugin_validate "$dir"; then
      printf '%s\tinvalid\tmanifest validation failed\n' "$name"
      continue
    fi
    description=$(yq eval '.description' "${dir}/config.yml")
    if harto_state_plugin_active "$name"; then
      installed="yes"
    else
      installed="no"
    fi
    printf '%s\t%s\t%s\n' "$name" "$installed" "$description"
  done <<EOF
$(harto_plugin_each_dir)
EOF
}

harto_plugin_cmd_info() {
  local name="$1"
  local dir manifest

  [ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} plugin info <name>" 2
  dir=$(harto_plugin_dir "$name") || harto_die "plugin not found: ${name}" 1
  harto_plugin_validate "$dir" || return 1
  manifest="${dir}/config.yml"
  yq eval '.' "$manifest"
  printf '\nDependency status:\n'
  harto_dep_check_manifest "$manifest" || true
}

harto_plugin_doctor_one() {
  local name="$1"
  local dir manifest hook dep_status

  dir=$(harto_plugin_dir "$name") || {
    harto_log_warn "plugin not found: ${name}"
    return 0
  }
  if ! harto_plugin_validate "$dir"; then
    harto_log_warn "plugin ${name} failed validation"
    return 0
  fi
  manifest="${dir}/config.yml"
  dep_status=0
  harto_dep_check_manifest "$manifest" >/dev/null 2>&1 || dep_status=1
  hook=$(yq eval '.hooks.doctor // ""' "$manifest")
  if [ -n "$hook" ] && [ "$hook" != "null" ]; then
    harto_plugin_run "$name" "$hook" || true
  fi
  return "$dep_status"
}
