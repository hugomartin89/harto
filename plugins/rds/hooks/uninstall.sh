#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

harto_log_info "rds disable removes the local catalog and the downloaded CA bundle."
harto_log_info "It does not change the AWS config file or the VPN."

remove_path() {
  local path="$1"
  if harto_is_dry_run; then
    printf '[dry-run] would remove %s\n' "$path" >&2
    return 0
  fi
  [ -e "$path" ] || return 0
  rm -rf "$path"
}

remove_path "$(harto_rds_ca_file)"
remove_path "$HARTO_PLUGIN_CONFIG_DIR"
