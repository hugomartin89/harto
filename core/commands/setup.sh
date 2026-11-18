#!/usr/bin/env bash
# harto-summary: Check dependencies and write the shared configuration

harto_cmd_setup_link() {
  local name="$1"
  local dest current

  harto_valid_name "$name" || harto_die "invalid executable name: ${name}" 2
  dest="${HOME}/.local/bin/${name}"

  if harto_is_dry_run; then
    printf '[dry-run] would link %s -> %s\n' "$dest" "$HARTO_ROOT/bin/harto" >&2
    return 0
  fi

  mkdir -p "${HOME}/.local/bin"
  if [ -L "$dest" ]; then
    current=$(readlink "$dest")
    if [ "$current" = "$HARTO_ROOT/bin/harto" ]; then
      harto_log_info "symlink already installed: ${dest}"
      return 0
    fi
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if ! harto_confirm "Replace existing ${dest}?"; then
      harto_die "refusing to replace ${dest}" 1
    fi
  fi
  ln -sfn "$HARTO_ROOT/bin/harto" "$dest"
  harto_log_info "linked ${dest}"
}

harto_cmd_setup() {
  local link_name config

  [ $# -eq 0 ] || harto_die "unexpected arguments" 2
  harto_dep_check_core || exit 1

  if [ -n "${HARTO_LINK_NAME+x}" ]; then
    link_name=$HARTO_LINK_NAME
  elif [ "${HARTO_YES:-0}" = "1" ]; then
    link_name=""
  else
    link_name=$(harto_prompt "Optional symlink name in ~/.local/bin (empty to skip; devx is a common example)" "")
  fi

  if harto_is_dry_run; then
    printf '[dry-run] would create %s\n' "$HARTO_CONFIG_DIR" >&2
    printf '[dry-run] would write core configuration and record version %s\n' "$HARTO_VERSION" >&2
    if [ -n "$link_name" ]; then
      harto_cmd_setup_link "$link_name"
    fi
    return 0
  fi

  harto_config_ensure_dirs
  config=$(harto_config_file)
  if [ ! -f "$config" ]; then
    harto_atomic_write "$config" <<'EOF'
config_version: 1
EOF
  elif ! harto_yaml_valid "$config"; then
    harto_die "core configuration is unreadable: ${config}. It was not overwritten." 1
  fi

  harto_state_ensure
  harto_state_set_core_version "$HARTO_VERSION"

  if [ -n "$link_name" ]; then
    harto_cmd_setup_link "$link_name"
  fi
  harto_log_info "setup complete. Next: ${HARTO_PROG} plugin enable <name>"
}
