#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

answer() {
  local provided="$1"
  local is_set="$2"
  local prompt="$3"
  local fallback="$4"
  local hint="${5:-}"

  if [ "$is_set" = "yes" ]; then
    printf '%s\n' "$provided"
    return 0
  fi
  if [ "${HARTO_YES:-0}" = "1" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi
  harto_prompt "$prompt" "$fallback" "$hint"
}

harto_dep_check_core || exit 1
harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/config.yml" || exit 1

if [ -n "${HARTO_DEVHOST_DOMAIN+x}" ]; then
  domain=$(answer "$HARTO_DEVHOST_DOMAIN" yes "" "")
else
  domain=$(answer "" no "Base domain (examples: local.test, dev.test)" "" HARTO_DEVHOST_DOMAIN)
fi
[ -n "$domain" ] || harto_die "base domain is required. Set HARTO_DEVHOST_DOMAIN." 2
harto_devhost_domain_accept "$domain"

harto_log_info "Suggested reverse proxy: caddy (https://caddyserver.com)"
if [ -n "${HARTO_DEVHOST_PROXY+x}" ]; then
  proxy=$(answer "$HARTO_DEVHOST_PROXY" yes "" "")
else
  proxy=$(answer "" no "Reverse proxy" "caddy" HARTO_DEVHOST_PROXY)
fi
if [ "$proxy" != "caddy" ]; then
  harto_die "unsupported proxy: ${proxy}. The available proxy is caddy." 1
fi

if [ -n "${HARTO_DEVHOST_ADMIN+x}" ]; then
  admin=$(answer "$HARTO_DEVHOST_ADMIN" yes "" "")
else
  admin=$(answer "" no "Proxy admin address bound to loopback" "127.0.0.1:2019" HARTO_DEVHOST_ADMIN)
fi
harto_devhost_admin_check "$admin" || harto_die "admin address must look like 127.0.0.1:2019" 1
if ! harto_devhost_admin_free "${admin##*:}"; then
  harto_die "admin port ${admin##*:} is already in use" 1
fi

if [ -n "${HARTO_DEVHOST_DNS+x}" ]; then
  dns=$(answer "$HARTO_DEVHOST_DNS" yes "" "")
else
  dns=$(answer "" no "DNS mode: dnsmasq or none" "dnsmasq" HARTO_DEVHOST_DNS)
fi
case "$dns" in
  dnsmasq|none) ;;
  *) harto_die "DNS mode must be dnsmasq or none" 1 ;;
esac

if [ -n "${HARTO_DEVHOST_HTTPS+x}" ]; then
  https=$(answer "$HARTO_DEVHOST_HTTPS" yes "" "")
else
  https=$(answer "" no "HTTPS mode: mkcert or off" "mkcert" HARTO_DEVHOST_HTTPS)
fi
case "$https" in
  mkcert|off) ;;
  *) harto_die "HTTPS mode must be mkcert or off" 1 ;;
esac
if [ "$https" = "mkcert" ]; then
  harto_tls_require_mkcert || exit 1
fi

if [ -n "${HARTO_DEVHOST_AUTOSTART+x}" ]; then
  autostart=$(answer "$HARTO_DEVHOST_AUTOSTART" yes "" "")
else
  autostart=$(answer "" no "Start services at login? yes or no" "no" HARTO_DEVHOST_AUTOSTART)
fi
case "$autostart" in
  yes|true) autostart="true" ;;
  no|false) autostart="false" ;;
  *) harto_die "autostart must be yes or no" 1 ;;
esac

harto_engine_report

ca_consent="false"
if [ "$https" = "mkcert" ]; then
  if harto_devhost_configured && [ "$(harto_devhost_get ca_consent)" = "true" ]; then
    ca_consent="true"
    harto_log_info "local certificate authority consent is already recorded"
  else
    harto_tls_install_ca
    ca_consent="true"
  fi
fi

if harto_is_dry_run; then
  harto_service_explain "$dns" "$autostart"
  printf '[dry-run] would write devhost configuration for %s\n' "$domain" >&2
  printf '[dry-run] setup did not change configuration\n' >&2
  exit 0
fi

previous=""
if harto_devhost_configured; then
  previous=$(harto_devhost_get base_domain)
fi

mkdir -p "$HARTO_PLUGIN_CONFIG_DIR" "$HARTO_PLUGIN_DATA_DIR"
tmp=$(mktemp "${HARTO_PLUGIN_CONFIG_DIR}/.tmp.XXXXXX")
DOMAIN="$domain" ADMIN="$admin" DNS="$dns" HTTPS="$https" AUTO="$autostart" CA="$ca_consent" \
  yq eval -n '
    .base_domain = strenv(DOMAIN) |
    .proxy = "caddy" |
    .admin_address = strenv(ADMIN) |
    .dns = strenv(DNS) |
    .https = strenv(HTTPS) |
    .autostart = (strenv(AUTO) == "true") |
    .ca_consent = (strenv(CA) == "true")
  ' > "$tmp"
mv "$tmp" "$(harto_devhost_config_file)"
harto_devhost_ensure_routes_file

if [ -n "$previous" ] && [ "$previous" != "$domain" ]; then
  harto_devhost_rewrite_hosts "$domain"
fi

if [ "$https" = "mkcert" ]; then
  harto_tls_issue "$domain"
fi
harto_dns_apply "$domain" "$dns"
harto_proxy_apply
harto_service_install "$dns" "$autostart"
if [ "$autostart" = "true" ]; then
  harto_service_up
fi

harto_log_info "devhost configured for ${domain}"
