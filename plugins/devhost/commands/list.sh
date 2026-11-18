#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} devhost list" 2
harto_devhost_require_config
if harto_output_is_json; then
  harto_devhost_list_routes | harto_output_records array
else
  harto_devhost_list_routes
fi
