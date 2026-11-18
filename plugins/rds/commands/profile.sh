#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} rds profile <name>" 2
harto_rds_print_profile "$1"
