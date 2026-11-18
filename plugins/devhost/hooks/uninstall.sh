#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

remove_path() {
  local path="$1"
  local reason="$2"

  if harto_is_dry_run; then
    printf '[dry-run] would remove %s\n' "$path" >&2
    return 0
  fi
  if [ ! -e "$path" ]; then
    return 0
  fi
  harto_log_info "$reason"
  rm -rf "$path"
}

harto_log_info "devhost disable removes the Caddy and dnsmasq LaunchDaemons, proxy config, and dnsmasq config."
harto_log_info "It does not remove Caddy, dnsmasq, Colima, the mkcert authority, or unrelated files."

if harto_devhost_configured; then
  harto_service_down || true
fi

harto_service_remove_caddy
harto_service_remove_dns
remove_path "${HARTO_PLUGIN_DATA_DIR}/caddy" "Removing the generated Caddyfile."
remove_path "${HARTO_PLUGIN_DATA_DIR}/dnsmasq" "Removing the generated dnsmasq config."
remove_path "${HARTO_PLUGIN_DATA_DIR}/logs" "Removing devhost logs."

if harto_devhost_configured && [ "$(harto_devhost_get dns)" = "dnsmasq" ]; then
  domain=$(harto_devhost_get base_domain)
  if harto_confirm "Remove the resolver file for ${domain}?"; then
    harto_dns_remove_resolver "$domain" || true
  else
    harto_log_info "left the resolver file in place"
  fi
fi

if [ -d "${HARTO_PLUGIN_DATA_DIR}/certs" ]; then
  if harto_confirm "Remove devhost certificates under ${HARTO_PLUGIN_DATA_DIR}/certs? The certificate authority is kept."; then
    remove_path "${HARTO_PLUGIN_DATA_DIR}/certs" "Removing devhost certificates."
  else
    harto_log_info "left devhost certificates in place"
  fi
fi

if harto_is_dry_run; then
  printf '[dry-run] would remove %s\n' "$HARTO_PLUGIN_CONFIG_DIR" >&2
else
  remove_path "$HARTO_PLUGIN_CONFIG_DIR" "Removing devhost configuration."
fi
