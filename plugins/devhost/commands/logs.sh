#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} devhost logs" 2
harto_devhost_require_config
log_file="${HARTO_PLUGIN_DATA_DIR}/logs/caddy.err.log"
if [ ! -f "$log_file" ]; then
  harto_die "no proxy log at ${log_file}" 1
fi
tail -n 50 "$log_file"
