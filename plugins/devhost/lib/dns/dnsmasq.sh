#!/usr/bin/env bash

harto_dns_conf() {
  printf '%s/dnsmasq/dnsmasq.conf\n' "$HARTO_PLUGIN_DATA_DIR"
}

harto_dns_render() {
  local domain="$1"
  local template dest dir

  template="${HARTO_PLUGIN_DIR}/templates/dnsmasq.conf"
  dest=$(harto_dns_conf)
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  sed "s|__DOMAIN__|${domain}|g" "$template" > "${dest}.tmp"
  mv "${dest}.tmp" "$dest"
}

harto_dns_resolver_path() {
  printf '/etc/resolver/%s\n' "$1"
}

harto_dns_apply() {
  local domain="$1"
  local mode="$2"
  local resolver body

  if [ "$mode" = "none" ]; then
    harto_log_info "DNS mode is none. devhost will not change resolvers."
    return 0
  fi
  if [ "$mode" != "dnsmasq" ]; then
    harto_die "unsupported DNS mode: ${mode}" 1
  fi

  harto_dns_render "$domain"
  resolver=$(harto_dns_resolver_path "$domain")
  if harto_is_dry_run; then
    printf '[dry-run] would write %s\n' "$(harto_dns_conf)" >&2
    printf '[dry-run] would write %s\n' "$resolver" >&2
    return 0
  fi

  harto_run_privileged \
    "Create /etc/resolver so macOS can use a per-domain resolver for ${domain}." \
    mkdir -p /etc/resolver
  body=$(cat "${HARTO_PLUGIN_DIR}/templates/resolver")
  printf '%s\n' "$body" | harto_run_privileged \
    "Write ${resolver} so ${domain} and its subdomains resolve through dnsmasq on 127.0.0.1 port 5353." \
    tee "$resolver" >/dev/null
  harto_log_info "DNS resolver written for ${domain}"
}

harto_dns_remove_resolver() {
  local domain="$1"
  local resolver

  resolver=$(harto_dns_resolver_path "$domain")
  if harto_is_dry_run; then
    printf '[dry-run] would remove %s\n' "$resolver" >&2
    return 0
  fi
  harto_run_privileged \
    "Remove the devhost resolver file ${resolver}. Other resolver files are left in place." \
    rm -f "$resolver"
}

harto_dns_status() {
  local domain mode resolver
  mode=$(harto_devhost_get dns)
  domain=$(harto_devhost_get base_domain)
  printf 'dns=%s\n' "$mode"
  if [ "$mode" != "dnsmasq" ]; then
    return 0
  fi
  resolver=$(harto_dns_resolver_path "$domain")
  if [ -f "$resolver" ]; then
    printf 'resolver=present\n'
  else
    printf 'resolver=missing\n'
  fi
}
