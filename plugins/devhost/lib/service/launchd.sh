#!/usr/bin/env bash

harto_service_domain() {
  printf 'gui/%s\n' "$(id -u)"
}

harto_service_caddy_label() {
  printf 'harto.devhost.caddy\n'
}

harto_service_dns_label() {
  printf 'harto.devhost.dnsmasq\n'
}

harto_service_caddy_plist() {
  printf '%s/Library/LaunchAgents/%s.plist\n' "$HOME" "$(harto_service_caddy_label)"
}

harto_service_dns_plist() {
  printf '%s/Library/LaunchAgents/%s.plist\n' "$HOME" "$(harto_service_dns_label)"
}

harto_service_render() {
  local template="$1"
  local dest="$2"
  local run_at_load="$3"
  local caddy_bin dns_bin conf caddyfile log_dir

  caddy_bin=$(command -v caddy)
  dns_bin=$(command -v dnsmasq || true)
  conf=$(harto_dns_conf)
  caddyfile=$(harto_proxy_caddyfile)
  log_dir="${HARTO_PLUGIN_DATA_DIR}/logs"
  mkdir -p "$log_dir" "$(dirname "$dest")"

  sed \
    -e "s|__CADDY__|${caddy_bin}|g" \
    -e "s|__DNSMASQ__|${dns_bin}|g" \
    -e "s|__CADDYFILE__|${caddyfile}|g" \
    -e "s|__CONF__|${conf}|g" \
    -e "s|__LOG_DIR__|${log_dir}|g" \
    -e "s|__RUN_AT_LOAD__|${run_at_load}|g" \
    "$template" > "${dest}.tmp"
  mv "${dest}.tmp" "$dest"
  if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$dest" >/dev/null
  fi
}

harto_service_explain() {
  local dns_mode="$1"
  local autostart="$2"

  harto_log_info "devhost will install a user LaunchAgent at $(harto_service_caddy_plist)"
  harto_log_info "It runs Caddy from the devhost Caddyfile, bound to 127.0.0.1, and restarts it after a crash."
  harto_log_info "It does not listen on a public interface."
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_log_info "devhost will install a user LaunchAgent at $(harto_service_dns_plist)"
    harto_log_info "It runs dnsmasq on 127.0.0.1 port 5353 for the selected base domain."
  fi
  if [ "$autostart" = "true" ]; then
    harto_log_info "The services will be loaded now and at login."
  else
    harto_log_info "The services will not start until you run: ${HARTO_PROG} devhost up"
  fi
}

harto_service_install() {
  local dns_mode="$1"
  local autostart="$2"
  local run_at_load="false"

  if [ "$autostart" = "true" ]; then
    run_at_load="true"
  fi
  harto_service_explain "$dns_mode" "$autostart"
  if ! harto_confirm "Install these LaunchAgents?"; then
    harto_die "service installation declined" 1
  fi
  if harto_is_dry_run; then
    printf '[dry-run] would write %s\n' "$(harto_service_caddy_plist)" >&2
    if [ "$dns_mode" = "dnsmasq" ]; then
      printf '[dry-run] would write %s\n' "$(harto_service_dns_plist)" >&2
    fi
    return 0
  fi

  harto_service_render \
    "${HARTO_PLUGIN_DIR}/templates/caddy.plist" \
    "$(harto_service_caddy_plist)" \
    "$run_at_load"
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_service_render \
      "${HARTO_PLUGIN_DIR}/templates/dnsmasq.plist" \
      "$(harto_service_dns_plist)" \
      "$run_at_load"
  fi
  harto_log_info "LaunchAgents written"
}

harto_service_bootstrap() {
  local label="$1"
  local plist="$2"
  local domain

  domain=$(harto_service_domain)
  if harto_is_dry_run; then
    printf '[dry-run] would bootstrap %s %s\n' "$domain" "$plist" >&2
    return 0
  fi
  launchctl bootout "${domain}/${label}" >/dev/null 2>&1 || true
  launchctl bootstrap "$domain" "$plist"
}

harto_service_up() {
  local dns_mode
  dns_mode=$(harto_devhost_get dns)
  [ -f "$(harto_service_caddy_plist)" ] || harto_die "Caddy LaunchAgent is missing. Run setup first." 1
  harto_service_bootstrap "$(harto_service_caddy_label)" "$(harto_service_caddy_plist)"
  if [ "$dns_mode" = "dnsmasq" ]; then
    [ -f "$(harto_service_dns_plist)" ] || harto_die "dnsmasq LaunchAgent is missing. Run setup first." 1
    harto_service_bootstrap "$(harto_service_dns_label)" "$(harto_service_dns_plist)"
  fi
  harto_log_info "services started"
}

harto_service_bootout() {
  local label="$1"
  local domain
  domain=$(harto_service_domain)
  if harto_is_dry_run; then
    printf '[dry-run] would bootout %s/%s\n' "$domain" "$label" >&2
    return 0
  fi
  launchctl bootout "${domain}/${label}" >/dev/null 2>&1 || true
}

harto_service_down() {
  local dns_mode
  dns_mode=$(harto_devhost_get dns)
  harto_service_bootout "$(harto_service_caddy_label)"
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_service_bootout "$(harto_service_dns_label)"
  fi
  harto_log_info "services stopped"
}

harto_service_print() {
  local label="$1"
  local domain output
  domain=$(harto_service_domain)
  if output=$(launchctl print "${domain}/${label}" 2>&1); then
    printf '%s=running\n' "$label"
    return 0
  fi
  printf '%s=stopped\n' "$label"
  harto_log_debug "$output"
  return 0
}

harto_service_status() {
  local dns_mode
  dns_mode=$(harto_devhost_get dns)
  harto_service_print "$(harto_service_caddy_label)"
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_service_print "$(harto_service_dns_label)"
  fi
}
