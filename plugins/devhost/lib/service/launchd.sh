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
  printf '/Library/LaunchDaemons/%s.plist\n' "$(harto_service_caddy_label)"
}

harto_service_caddy_source() {
  printf '%s/launchd/%s.plist\n' "$HARTO_PLUGIN_DATA_DIR" "$(harto_service_caddy_label)"
}

harto_service_caddy_legacy_plist() {
  printf '%s/Library/LaunchAgents/%s.plist\n' "$HOME" "$(harto_service_caddy_label)"
}

harto_service_dns_plist() {
  printf '/Library/LaunchDaemons/%s.plist\n' "$(harto_service_dns_label)"
}

harto_service_dns_source() {
  printf '%s/launchd/%s.plist\n' "$HARTO_PLUGIN_DATA_DIR" "$(harto_service_dns_label)"
}

harto_service_dns_legacy_plist() {
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

  harto_log_info "devhost will install a system LaunchDaemon at $(harto_service_caddy_plist)"
  harto_log_info "Caddy runs as root so it can listen on 127.0.0.1 ports 80 and 443. It does not listen on a public interface."
  harto_log_info "A user LaunchAgent for Caddy is removed when this daemon is installed. macOS does not allow that agent to bind those ports."
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_log_info "devhost will install a system LaunchDaemon at $(harto_service_dns_plist)"
    harto_log_info "dnsmasq runs as root so it can listen on 127.0.0.1 port 53. It answers only the selected base domain."
    harto_log_info "A user LaunchAgent for dnsmasq is removed when this daemon is installed."
  fi
  if [ "$autostart" = "true" ]; then
    if [ "$dns_mode" = "dnsmasq" ]; then
      harto_log_info "Caddy and dnsmasq will start now and at boot."
    else
      harto_log_info "Caddy will start now and at boot."
    fi
  else
    harto_log_info "The services will not start until you run: ${HARTO_PROG} devhost up"
  fi
}

harto_service_retire_user_caddy() {
  local legacy

  legacy=$(harto_service_caddy_legacy_plist)
  if harto_is_dry_run; then
    printf '[dry-run] would remove the user LaunchAgent %s\n' "$legacy" >&2
    return 0
  fi
  launchctl bootout "$(harto_service_domain)/$(harto_service_caddy_label)" >/dev/null 2>&1 || true
  if [ -f "$legacy" ]; then
    rm -f "$legacy"
    harto_log_info "removed the user LaunchAgent for Caddy"
  fi
}

harto_service_publish_caddy() {
  local source dest run_at_load

  source=$(harto_service_caddy_source)
  dest=$(harto_service_caddy_plist)
  if harto_is_dry_run; then
    printf '[dry-run] would install %s\n' "$dest" >&2
    harto_service_retire_user_caddy
    return 0
  fi
  run_at_load="false"
  if [ "$(harto_devhost_get autostart)" = "true" ]; then
    run_at_load="true"
  fi
  mkdir -p "$(dirname "$source")" "${HARTO_PLUGIN_DATA_DIR}/logs"
  touch "${HARTO_PLUGIN_DATA_DIR}/logs/caddy.out.log" "${HARTO_PLUGIN_DATA_DIR}/logs/caddy.err.log"
  harto_service_render \
    "${HARTO_PLUGIN_DIR}/templates/caddy.plist" \
    "$source" \
    "$run_at_load"
  if [ ! -f "$dest" ] || ! cmp -s "$source" "$dest"; then
    harto_run_privileged \
      "Create $(dirname "$dest") for the Caddy system service." \
      mkdir -p "$(dirname "$dest")"
    harto_run_privileged \
      "Install ${dest} so Caddy can listen on 127.0.0.1 ports 80 and 443." \
      install -m 644 "$source" "$dest"
  fi
  harto_service_retire_user_caddy
}

harto_service_retire_user_dns() {
  local legacy

  legacy=$(harto_service_dns_legacy_plist)
  if harto_is_dry_run; then
    printf '[dry-run] would remove the user LaunchAgent %s\n' "$legacy" >&2
    return 0
  fi
  launchctl bootout "$(harto_service_domain)/$(harto_service_dns_label)" >/dev/null 2>&1 || true
  if [ -f "$legacy" ]; then
    rm -f "$legacy"
    harto_log_info "removed the user LaunchAgent for dnsmasq"
  fi
}

harto_service_publish_dns() {
  local source dest run_at_load

  source=$(harto_service_dns_source)
  dest=$(harto_service_dns_plist)
  if harto_is_dry_run; then
    printf '[dry-run] would install %s\n' "$dest" >&2
    harto_service_retire_user_dns
    return 0
  fi
  run_at_load="false"
  if [ "$(harto_devhost_get autostart)" = "true" ]; then
    run_at_load="true"
  fi
  mkdir -p "$(dirname "$source")" "${HARTO_PLUGIN_DATA_DIR}/logs"
  touch "${HARTO_PLUGIN_DATA_DIR}/logs/dnsmasq.out.log" "${HARTO_PLUGIN_DATA_DIR}/logs/dnsmasq.err.log"
  harto_service_render \
    "${HARTO_PLUGIN_DIR}/templates/dnsmasq.plist" \
    "$source" \
    "$run_at_load"
  if [ ! -f "$dest" ] || ! cmp -s "$source" "$dest"; then
    harto_run_privileged \
      "Create $(dirname "$dest") for the dnsmasq system service." \
      mkdir -p "$(dirname "$dest")"
    harto_run_privileged \
      "Install ${dest} so dnsmasq can listen on 127.0.0.1 port 53." \
      install -m 644 "$source" "$dest"
  fi
  harto_service_retire_user_dns
}

harto_service_install() {
  local dns_mode="$1"
  local autostart="$2"

  harto_service_explain "$dns_mode" "$autostart"
  if ! harto_confirm "Install these services?"; then
    harto_die "service installation declined" 1
  fi
  if harto_is_dry_run; then
    printf '[dry-run] would install %s\n' "$(harto_service_caddy_plist)" >&2
    if [ "$dns_mode" = "dnsmasq" ]; then
      printf '[dry-run] would install %s\n' "$(harto_service_dns_plist)" >&2
    fi
    return 0
  fi

  harto_service_publish_caddy
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_service_publish_dns
  fi
  harto_log_info "services installed"
}

harto_service_caddy_bootout() {
  harto_service_system_bootout "$(harto_service_caddy_label)" \
    "Stop the Caddy system service $(harto_service_caddy_label)."
}

harto_service_dns_bootout() {
  harto_service_system_bootout "$(harto_service_dns_label)" \
    "Stop the dnsmasq system service $(harto_service_dns_label)."
}

harto_service_system_bootout() {
  local label="$1"
  local reason="$2"
  if harto_is_dry_run; then
    printf '[dry-run] would bootout system/%s\n' "$label" >&2
    return 0
  fi
  if ! launchctl print "system/${label}" >/dev/null 2>&1; then
    return 0
  fi
  harto_run_privileged "$reason" launchctl bootout "system/${label}" || true
}

harto_service_caddy_start() {
  harto_service_system_start "$(harto_service_caddy_label)" "$(harto_service_caddy_plist)" \
    "Load the Caddy system service so it can listen on 127.0.0.1 ports 80 and 443."
}

harto_service_dns_start() {
  harto_service_system_start "$(harto_service_dns_label)" "$(harto_service_dns_plist)" \
    "Load the dnsmasq system service so it can listen on 127.0.0.1 port 53."
}

harto_service_system_start() {
  local label="$1"
  local plist="$2"
  local reason="$3"
  if harto_is_dry_run; then
    printf '[dry-run] would bootstrap system %s\n' "$plist" >&2
    return 0
  fi
  harto_service_system_bootout "$label" "Stop the system service ${label}."
  harto_run_privileged "$reason" launchctl bootstrap system "$plist"
  if [ "$(harto_devhost_get autostart)" != "true" ]; then
    harto_run_privileged \
      "Start the system service ${label}." \
      launchctl kickstart -k "system/${label}"
  fi
}

harto_service_up() {
  local dns_mode
  dns_mode=$(harto_devhost_get dns)
  harto_service_publish_caddy
  harto_service_caddy_start
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_dns_apply "$(harto_devhost_get base_domain)" dnsmasq
    harto_service_publish_dns
    harto_service_dns_start
  fi
  harto_log_info "services started"
}

harto_service_down() {
  local dns_mode
  dns_mode=$(harto_devhost_get dns)
  harto_service_caddy_bootout
  harto_service_retire_user_caddy
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_service_dns_bootout
    harto_service_retire_user_dns
  fi
  harto_log_info "services stopped"
}

harto_service_remove_caddy() {
  local dest legacy source
  dest=$(harto_service_caddy_plist)
  legacy=$(harto_service_caddy_legacy_plist)
  source=$(harto_service_caddy_source)
  if harto_is_dry_run; then
    printf '[dry-run] would remove %s\n' "$dest" >&2
    printf '[dry-run] would remove %s\n' "$legacy" >&2
    return 0
  fi
  harto_run_privileged \
    "Remove the Caddy LaunchDaemon ${dest}." \
    rm -f "$dest"
  rm -f "$legacy" "$source"
}

harto_service_remove_dns() {
  local dest legacy source
  dest=$(harto_service_dns_plist)
  legacy=$(harto_service_dns_legacy_plist)
  source=$(harto_service_dns_source)
  if harto_is_dry_run; then
    printf '[dry-run] would remove %s\n' "$dest" >&2
    printf '[dry-run] would remove %s\n' "$legacy" >&2
    return 0
  fi
  harto_run_privileged \
    "Remove the dnsmasq LaunchDaemon ${dest}." \
    rm -f "$dest"
  rm -f "$legacy" "$source"
}

harto_service_print() {
  local domain="$1"
  local label="$2"
  local output
  if output=$(launchctl print "${domain}/${label}" 2>&1) \
    && printf '%s\n' "$output" | grep -q 'state = running'; then
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
  harto_service_print system "$(harto_service_caddy_label)"
  if [ "$dns_mode" = "dnsmasq" ]; then
    harto_service_print system "$(harto_service_dns_label)"
  fi
}
