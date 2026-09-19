#!/usr/bin/env bash

if ! declare -F harto_log_info >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "$HARTO_LIB/bootstrap.sh"
  harto_config_init
fi

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/config.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/domain.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/engine.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/proxy/caddy.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/dns/dnsmasq.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/tls/mkcert.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/service/launchd.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/routes.sh"
