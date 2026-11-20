#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

if harto_is_dry_run; then
  printf '[dry-run] would remove %s\n' "$HARTO_PLUGIN_CONFIG_DIR" >&2
  if harto_localenv_key_present; then
    printf '[dry-run] would ask whether to remove the localenv key from the Keychain\n' >&2
  fi
  exit 0
fi

rm -rf "$HARTO_PLUGIN_CONFIG_DIR"
harto_log_info "removed the localenv store"

if harto_localenv_key_present; then
  if harto_confirm "Remove the localenv key from the Keychain? Encrypted stores can no longer be read without it."; then
    harto_localenv_key_delete
    harto_log_info "removed the localenv key from the Keychain"
  else
    harto_log_info "kept the localenv key in the Keychain"
  fi
fi
