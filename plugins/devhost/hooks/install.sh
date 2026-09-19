#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_LIB/bootstrap.sh"
harto_config_init

mkdir -p \
  "$HARTO_PLUGIN_CONFIG_DIR" \
  "$HARTO_PLUGIN_STATE_DIR" \
  "$HARTO_PLUGIN_DATA_DIR"
harto_log_info "devhost directories are ready"
