#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 1 ] || harto_die "usage: ${HARTO_PROG} devhost remove <name>" 2
name="$1"
harto_valid_name "$name" || harto_die "invalid route name: ${name}" 2
harto_devhost_require_config
harto_devhost_ensure_routes_file
harto_devhost_route_index "$name" >/dev/null || harto_die "route not found: ${name}" 1

backup=$(harto_backup_file "$(harto_devhost_routes_file)")
harto_devhost_delete_route "$name"
if ! harto_proxy_apply; then
  if [ -n "$backup" ]; then
    cp "$backup" "$(harto_devhost_routes_file)"
    harto_proxy_apply || true
  fi
  harto_die "remove failed. The previous routes were restored." 1
fi
harto_log_info "removed route ${name}"
