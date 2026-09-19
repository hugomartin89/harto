#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} devhost doctor" 2

if ! harto_devhost_configured; then
  printf 'warn: devhost is not configured\n'
  harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/plugin.yml" || true
  exit 0
fi

harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/plugin.yml" || true
printf 'base_domain=%s\n' "$(harto_devhost_get base_domain)"
harto_proxy_status || true
harto_dns_status || true
harto_tls_status || true
harto_service_status || true
if [ -f "$(harto_devhost_routes_file)" ]; then
  harto_devhost_list_routes || true
fi
exit 0
