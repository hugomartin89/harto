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

# One yq read of a plugin manifest. Fields are separated by ASCII unit
# separator so empty values stay empty. The result is reused for the rest of
# this process.
harto_plugin_read() {
  local manifest="$1"
  local us

  [ -f "$manifest" ] || return 1
  us=$(printf '\037')
  US="$us" yq eval '
    [
      "name" + strenv(US) + (.name // ""),
      "description" + strenv(US) + (.description // ""),
      (.platforms // [] | .[] | "platform" + strenv(US) + .),
      (.commands // [] | .[] | [
        "command",
        (.name // ""),
        (.entrypoint // ""),
        (.usage // ""),
        (.usage | tag),
        (.privileged | tag),
        (.json | tag),
        (.privileged // false | tostring),
        (.json // false | tostring),
        (.description // "")
      ] | join(strenv(US))),
      (.hooks // {} | to_entries[] | select(.value != null and .value != "") | "hook" + strenv(US) + .key + strenv(US) + (.value | tostring)),
      (.dependencies // [] | .[] | [
        "dep",
        (.name // ""),
        (.command // ""),
        (.required // false | tostring),
        (.min_version // ""),
        (.install_hint // ""),
        (.install_hint_url // "")
      ] | join(strenv(US)))
    ] | join("\n")
  ' "$manifest" 2>/dev/null
}

harto_plugin_record_for() {
  local manifest="$1"
  local record

  if [ "${_HARTO_PLUGIN_RECORD_FILE:-}" = "$manifest" ]; then
    printf '%s\n' "$_HARTO_PLUGIN_RECORD"
    return 0
  fi
  record=$(harto_plugin_read "$manifest") || return 1
  _HARTO_PLUGIN_RECORD_FILE=$manifest
  _HARTO_PLUGIN_RECORD=$record
  printf '%s\n' "$record"
}

harto_plugin_record_value() {
  local record="$1"
  local key="$2"
  local line kind value

  while IFS= read -r line || [ -n "$line" ]; do
    kind=${line%%$'\037'*}
    [ "$kind" = "$key" ] || continue
    value=${line#*$'\037'}
    printf '%s\n' "$value"
    return 0
  done <<EOF
$record
EOF
  return 1
}

harto_plugin_record_command() {
  local record="$1"
  local command_name="$2"
  local field="$3"
  local line kind cname entry usage utag ptag jtag pval jval desc

  while IFS= read -r line || [ -n "$line" ]; do
    kind=${line%%$'\037'*}
    [ "$kind" = command ] || continue
    IFS=$'\037' read -r kind cname entry usage utag ptag jtag pval jval desc <<EOF
$line
EOF
    [ "$cname" = "$command_name" ] || continue
    case "$field" in
      entrypoint) printf '%s\n' "$entry" ;;
      usage) printf '%s\n' "$usage" ;;
      description) printf '%s\n' "$desc" ;;
      json) printf '%s\n' "$jval" ;;
      privileged) printf '%s\n' "$pval" ;;
      *) return 1 ;;
    esac
    return 0
  done <<EOF
$record
EOF
  return 1
}

harto_plugin_record_hook() {
  local record="$1"
  local hook_name="$2"
  local line kind hook path

  while IFS= read -r line || [ -n "$line" ]; do
    kind=${line%%$'\037'*}
    [ "$kind" = hook ] || continue
    IFS=$'\037' read -r kind hook path <<EOF
$line
EOF
    [ "$hook" = "$hook_name" ] || continue
    printf '%s\n' "$path"
    return 0
  done <<EOF
$record
EOF
  return 1
}

harto_plugin_hook_path() {
  local manifest="$1"
  local hook_name="$2"
  local record path

  record=$(harto_plugin_record_for "$manifest") || return 1
  if ! path=$(harto_plugin_record_hook "$record" "$hook_name"); then
    printf '\n'
    return 0
  fi
  printf '%s\n' "$path"
}

_harto_plugin_tag_ok() {
  local manifest="$1"
  local command_name="$2"
  local field="$3"
  local tag="$4"
  local want="$5"

  if [ "$tag" = "!!null" ] || [ "$tag" = "$want" ]; then
    return 0
  fi
  harto_log_error "command ${command_name} in ${manifest} has an invalid ${field}"
  return 1
}

_harto_plugin_check_command() {
  local dir="$1"
  local manifest="$2"
  local plugin_name="$3"
  local line="$4"
  local kind cname entry usage utag ptag jtag pval jval desc
  local failed=0

  IFS=$'\037' read -r kind cname entry usage utag ptag jtag pval jval desc <<EOF
$line
EOF
  if ! harto_plugin_path_safe "$entry" || [ ! -f "${dir}/${entry}" ]; then
    harto_log_error "plugin ${plugin_name} has an invalid command entrypoint: ${entry}"
    failed=1
  fi
  _harto_plugin_tag_ok "$manifest" "$cname" usage "$utag" '!!str' || failed=1
  _harto_plugin_tag_ok "$manifest" "$cname" privileged "$ptag" '!!bool' || failed=1
  _harto_plugin_tag_ok "$manifest" "$cname" json "$jtag" '!!bool' || failed=1
  return "$failed"
}

_harto_plugin_check_hook() {
  local dir="$1"
  local plugin_name="$2"
  local line="$3"
  local kind hook path

  IFS=$'\037' read -r kind hook path <<EOF
$line
EOF
  case "$hook" in
    install|configure|doctor|upgrade|uninstall|complete) ;;
    *) return 0 ;;
  esac
  if ! harto_plugin_path_safe "$path" || [ ! -f "${dir}/${path}" ]; then
    harto_log_error "plugin ${plugin_name} has an invalid ${hook} hook: ${path}"
    return 1
  fi
}

harto_plugin_check() {
  local dir="$1"
  local record="$2"
  local manifest="${dir}/config.yml"
  local failed=0
  local name description platforms="" os line kind

  name=$(harto_plugin_record_value "$record" name || true)
  description=$(harto_plugin_record_value "$record" description || true)
  if [ "$(basename "$dir")" != "$name" ] || ! harto_plugin_validate_name "$name"; then
    harto_log_error "plugin name must match its directory and match ^[a-z][a-z0-9-]*$: ${dir}"
    failed=1
  fi
  if [ -z "$description" ] || [ "$description" = "null" ]; then
    harto_log_error "plugin ${name} is missing a description"
    failed=1
  fi

  os=$(harto_platform_os)
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    kind=${line%%$'\037'*}
    case "$kind" in
      platform) platforms="${platforms}${line#*$'\037'}"$'\n' ;;
      command) _harto_plugin_check_command "$dir" "$manifest" "$name" "$line" || failed=1 ;;
      hook) _harto_plugin_check_hook "$dir" "$name" "$line" || failed=1 ;;
    esac
  done <<EOF
$record
EOF

  if [ -n "$platforms" ]; then
    if ! printf '%s\n' "$platforms" | grep -qx "$os"; then
      harto_log_error "plugin ${name} does not support ${os}"
      failed=1
    fi
  fi
  return "$failed"
}

harto_plugin_validate() {
  local dir="$1"
  local manifest record

  manifest="${dir}/config.yml"
  if ! record=$(harto_plugin_record_for "$manifest"); then
    harto_log_error "invalid plugin manifest: ${manifest}"
    return 1
  fi
  harto_plugin_check "$dir" "$record"
}

harto_plugin_command_field() {
  local manifest="$1"
  local command_name="$2"
  local field="$3"
  local record value

  record=$(harto_plugin_record_for "$manifest") || return 1
  value=$(harto_plugin_record_command "$record" "$command_name" "$field" || true)
  printf '%s\n' "$value"
}

harto_plugin_print_commands() {
  local plugin="$1"
  local record="$2"
  local line kind cname entry usage utag ptag jtag pval jval desc title

  while IFS= read -r line || [ -n "$line" ]; do
    kind=${line%%$'\037'*}
    [ "$kind" = command ] || continue
    IFS=$'\037' read -r kind cname entry usage utag ptag jtag pval jval desc <<EOF
$line
EOF
    title="${plugin} ${cname}"
    [ -z "$usage" ] || title="${title} ${usage}"
    harto_help_entry "$title" "$desc"
  done <<EOF
$record
EOF
}

_harto_json_string() {
  local value="$1"

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

_harto_json_bool() {
  case "$1" in
    true|false) printf '%s' "$1" ;;
    *) printf 'false' ;;
  esac
}

harto_plugin_help_json() {
  local record="$1"
  local name description commands="" line kind
  local cname entry usage utag ptag jtag pval jval desc entry_json

  name=$(harto_plugin_record_value "$record" name || true)
  description=$(harto_plugin_record_value "$record" description || true)
  while IFS= read -r line || [ -n "$line" ]; do
    kind=${line%%$'\037'*}
    [ "$kind" = command ] || continue
    IFS=$'\037' read -r kind cname entry usage utag ptag jtag pval jval desc <<EOF
$line
EOF
    entry_json=$(printf '{"name":%s,"description":%s,"usage":%s,"privileged":%s,"json":%s}' \
      "$(_harto_json_string "$cname")" \
      "$(_harto_json_string "$desc")" \
      "$(_harto_json_string "$usage")" \
      "$(_harto_json_bool "$pval")" \
      "$(_harto_json_bool "$jval")")
    commands="${commands}${commands:+,}${entry_json}"
  done <<EOF
$record
EOF
  printf '{"name":%s,"description":%s,"commands":[%s]}' \
    "$(_harto_json_string "$name")" \
    "$(_harto_json_string "$description")" \
    "$commands"
}

harto_plugin_command_entry() {
  local name="$1"
  local command_name="$2"
  local manifest entry

  manifest=$(harto_plugin_manifest "$name") || return 1
  entry=$(harto_plugin_command_field "$manifest" "$command_name" entrypoint) || return 1
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
  local sub entry dir record

  dir=$(harto_plugin_dir "$name") || harto_die "plugin not found: ${name}" 1
  harto_plugin_validate "$dir" || harto_die "plugin ${name} failed validation" 1

  if [ $# -eq 0 ]; then
    harto_output_text_only "${name}"
    harto_plugin_print_help "$name"
    return 0
  fi

  sub="$1"
  shift
  record=$(harto_plugin_record_for "${dir}/config.yml") || harto_die "plugin ${name} failed validation" 1
  entry=$(harto_plugin_record_command "$record" "$sub" entrypoint) || harto_die "unknown command: ${name} ${sub}" 2
  if [ -z "$entry" ] || [ "$entry" = "null" ]; then
    harto_die "unknown command: ${name} ${sub}" 2
  fi
  if harto_output_is_json && [ "$(harto_plugin_record_command "$record" "$sub" json || true)" != "true" ]; then
    harto_die "${name} ${sub} does not support --json" 2
  fi
  harto_plugin_run "$name" "$entry" "$@"
}

harto_plugin_print_help() {
  local name="$1"
  local manifest record description

  manifest=$(harto_plugin_manifest "$name") || return 1
  record=$(harto_plugin_record_for "$manifest") || return 1
  description=$(harto_plugin_record_value "$record" description || true)
  printf '%s - %s\n\n' "$(harto_paint 1 1 "$name")" "$(harto_paint 1 2 "$description")"
  printf 'Commands:\n\n'
  harto_plugin_print_commands "$name" "$record"
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

  hook=$(harto_plugin_hook_path "$manifest" install)
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
  hook=$(harto_plugin_hook_path "$manifest" uninstall)

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
    description=$(harto_plugin_record_value "$(harto_plugin_record_for "${dir}/config.yml")" description || true)
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
  hook=$(harto_plugin_hook_path "$manifest" doctor)
  if [ -n "$hook" ] && [ "$hook" != "null" ]; then
    harto_plugin_run "$name" "$hook" || true
  fi
  return "$dep_status"
}
