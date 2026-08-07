#!/usr/bin/env bash

harto_config_init() {
  if [ -z "${HARTO_CONFIG_DIR:-}" ]; then
    HARTO_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/harto"
  fi
  if [ -z "${HARTO_STATE_DIR:-}" ]; then
    HARTO_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/harto"
  fi
  if [ -z "${HARTO_DATA_DIR:-}" ]; then
    HARTO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/harto"
  fi
  export HARTO_CONFIG_DIR HARTO_STATE_DIR HARTO_DATA_DIR
}

harto_config_ensure_dirs() {
  mkdir -p \
    "$HARTO_CONFIG_DIR/plugins" \
    "$HARTO_STATE_DIR/plugins" \
    "$HARTO_STATE_DIR/logs" \
    "$HARTO_STATE_DIR/locks" \
    "$HARTO_DATA_DIR/plugins" \
    "$HARTO_DATA_DIR/backups"
}

harto_config_file() {
  printf '%s/config.yml\n' "$HARTO_CONFIG_DIR"
}

harto_state_file() {
  printf '%s/state.yml\n' "$HARTO_STATE_DIR"
}

harto_yaml_valid() {
  local file="$1"
  [ -f "$file" ] || return 1
  command -v yq >/dev/null 2>&1 || return 1
  yq eval '.' "$file" >/dev/null 2>&1
}

harto_yaml_get() {
  local file="$1"
  local expr="$2"
  local value

  harto_yaml_valid "$file" || harto_die "invalid YAML: ${file}" 1
  value=$(yq eval "$expr" "$file")
  if [ "$value" = "null" ]; then
    printf '\n'
    return 0
  fi
  printf '%s\n' "$value"
}

harto_state_ensure() {
  local file
  harto_config_ensure_dirs
  file=$(harto_state_file)
  if [ ! -f "$file" ]; then
    harto_atomic_write "$file" <<'EOF'
core_version: ""
plugins: {}
EOF
  fi
  if ! harto_yaml_valid "$file"; then
    harto_die "state file is unreadable: ${file}. Move it aside; it was not overwritten." 1
  fi
}

harto_state_core_version() {
  harto_state_ensure
  harto_yaml_get "$(harto_state_file)" '.core_version // ""'
}

harto_state_set_core_version() {
  local version="$1"
  local file tmp

  harto_state_ensure
  file=$(harto_state_file)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  VERSION="$version" yq eval '.core_version = strenv(VERSION)' "$file" > "$tmp"
  mv "$tmp" "$file"
}

harto_state_plugin_version() {
  local name="$1"
  local value

  harto_state_ensure
  value=$(NAME="$name" yq eval '.plugins[strenv(NAME)].version // ""' "$(harto_state_file)")
  if [ "$value" = "null" ]; then
    value=""
  fi
  printf '%s\n' "$value"
}

harto_state_prepare_plugin() {
  local name="$1"
  local file tmp now

  harto_state_ensure
  file=$(harto_state_file)
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  NAME="$name" NOW="$now" yq eval '
    .plugins[strenv(NAME)].version = (.plugins[strenv(NAME)].version // "") |
    .plugins[strenv(NAME)].installed_at = (.plugins[strenv(NAME)].installed_at // strenv(NOW)) |
    .plugins[strenv(NAME)].migrations = (.plugins[strenv(NAME)].migrations // [])
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

harto_state_set_plugin_version() {
  local name="$1"
  local version="$2"
  local file tmp now

  harto_state_prepare_plugin "$name"
  file=$(harto_state_file)
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  NAME="$name" VERSION="$version" NOW="$now" yq eval '
    .plugins[strenv(NAME)].version = strenv(VERSION) |
    .plugins[strenv(NAME)].installed_at = strenv(NOW)
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  harto_log_op "info" "recorded ${name} ${version}"
}

harto_state_migration_applied() {
  local name="$1"
  local id="$2"
  local value

  harto_state_ensure
  value=$(NAME="$name" ID="$id" yq eval '
    .plugins[strenv(NAME)].migrations // [] | map(select(. == strenv(ID))) | .[0] // ""
  ' "$(harto_state_file)")
  [ -n "$value" ] && [ "$value" != "null" ]
}

harto_state_add_migration() {
  local name="$1"
  local id="$2"
  local file tmp

  harto_state_prepare_plugin "$name"
  if harto_state_migration_applied "$name" "$id"; then
    return 0
  fi
  file=$(harto_state_file)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  NAME="$name" ID="$id" yq eval '
    .plugins[strenv(NAME)].migrations += [strenv(ID)]
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

harto_state_remove_plugin() {
  local name="$1"
  local file tmp

  harto_state_ensure
  file=$(harto_state_file)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  NAME="$name" yq eval 'del(.plugins[strenv(NAME)])' "$file" > "$tmp"
  mv "$tmp" "$file"
}

harto_state_plugin_names() {
  harto_state_ensure
  yq eval '.plugins // {} | keys | .[]' "$(harto_state_file)"
}
