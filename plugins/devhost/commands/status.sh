#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} devhost status" 2
harto_devhost_require_config
printf 'base_domain=%s\n' "$(harto_devhost_get base_domain)"
harto_proxy_status
harto_dns_status
harto_tls_status
harto_service_status
