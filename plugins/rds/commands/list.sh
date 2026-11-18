#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} rds list" 2
if harto_output_is_json; then
  harto_rds_list_databases | harto_output_records array
else
  harto_rds_list_databases
fi
