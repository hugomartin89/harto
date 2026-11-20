#!/usr/bin/env bash

harto_upgrade_repo() {
  local dir="$1"
  local top dirty upstream

  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    harto_log_info "not a git checkout: ${dir}"
    return 0
  fi

  top=$(git -C "$dir" rev-parse --show-toplevel)
  dirty=$(git -C "$top" status --porcelain)
  if [ -n "$dirty" ]; then
    harto_log_error "local modifications in ${top} prevent a safe update"
    harto_log_error "commit or stash those changes, then run upgrade again"
    harto_log_error "harto will not reset or overwrite local work"
    return 1
  fi

  upstream=$(git -C "$top" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -z "$upstream" ]; then
    harto_log_info "no upstream branch for ${top}; source update skipped"
    return 0
  fi

  if harto_is_dry_run; then
    printf '[dry-run] would fast-forward %s from %s\n' "$top" "$upstream" >&2
    return 0
  fi

  if ! git -C "$top" fetch --ff-only; then
    harto_log_error "git fetch failed for ${top}"
    return 1
  fi
  if ! git -C "$top" merge --ff-only "$upstream"; then
    harto_log_error "fast-forward of ${top} failed. Resolve the divergence manually."
    return 1
  fi
  harto_log_info "fast-forwarded ${top}"
}

harto_upgrade_installed_plugins() {
  local name manifest hook dir

  [ -f "$(harto_state_file)" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    dir=$(harto_plugin_dir "$name") || {
      harto_log_warn "installed plugin is missing from disk: ${name}"
      continue
    }
    if [ "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)" != "$(git -C "$HARTO_ROOT" rev-parse --show-toplevel 2>/dev/null || true)" ]; then
      harto_upgrade_repo "$dir"
    fi
    harto_plugin_validate "$dir"
    harto_plugin_run_migrations "$name"
    manifest="${dir}/config.yml"
    hook=$(harto_plugin_hook_path "$manifest" upgrade)
    if [ -n "$hook" ] && [ "$hook" != "null" ] && ! harto_is_dry_run; then
      harto_plugin_run "$name" "$hook"
    fi
  done <<EOF
$(harto_state_plugin_names)
EOF
}

harto_upgrade_all() {
  harto_dep_check_core || return 1
  harto_upgrade_repo "$HARTO_ROOT"
  harto_upgrade_installed_plugins
}
