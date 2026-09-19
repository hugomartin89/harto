#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_LIB/bootstrap.sh"
harto_config_init

harto_log_info "devhost code is current. Existing configuration was not rewritten."
harto_log_info "Run: ${HARTO_PROG} devhost doctor"
