#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

if harto_is_dry_run; then
  printf '[dry-run] would create %s\n' "$HARTO_PLUGIN_CONFIG_DIR" >&2
  exit 0
fi

mkdir -p "$HARTO_PLUGIN_CONFIG_DIR"
chmod 700 "$HARTO_PLUGIN_CONFIG_DIR"
harto_log_info "localenv directories are ready"
