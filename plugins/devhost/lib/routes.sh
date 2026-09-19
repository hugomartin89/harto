#!/usr/bin/env bash

harto_devhost_target_from_port() {
  local port="$1"
  printf '%s\n' "$port" | grep -Eq '^[0-9]+$' || return 1
  [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || return 1
  printf 'http://127.0.0.1:%s\n' "$port"
}

harto_devhost_target_check() {
  local target="$1"

  case "$target" in
    *[[:space:]]*|*[\;\`\$\&\|]*)
      printf 'target contains unsupported characters\n' >&2
      return 1
      ;;
  esac
  if printf '%s\n' "$target" | grep -Eq '^https?://(127\.0\.0\.1|localhost):[0-9]+$'; then
    return 0
  fi
  if printf '%s\n' "$target" | grep -Eq '^https?://[A-Za-z0-9._-]+:[0-9]+$'; then
    harto_log_warn "target ${target} is not a loopback address"
    harto_confirm "Route traffic to ${target}?" || return 1
    return 0
  fi
  printf 'target must be an http origin such as http://127.0.0.1:8080\n' >&2
  return 1
}

harto_devhost_route_count() {
  yq eval '.routes // [] | length' "$(harto_devhost_routes_file)"
}

harto_devhost_route_index() {
  local name="$1"
  local count index found

  count=$(harto_devhost_route_count)
  index=0
  while [ "$index" -lt "$count" ]; do
    found=$(yq eval ".routes[${index}].name" "$(harto_devhost_routes_file)")
    if [ "$found" = "$name" ]; then
      printf '%s\n' "$index"
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

harto_devhost_host_taken() {
  local host="$1"
  local except="${2:-}"
  local count index found_host found_name

  count=$(harto_devhost_route_count)
  index=0
  while [ "$index" -lt "$count" ]; do
    found_host=$(yq eval ".routes[${index}].host" "$(harto_devhost_routes_file)")
    found_name=$(yq eval ".routes[${index}].name" "$(harto_devhost_routes_file)")
    if [ "$found_host" = "$host" ] && [ "$found_name" != "$except" ]; then
      return 0
    fi
    index=$((index + 1))
  done
  return 1
}

harto_devhost_save_route() {
  local name="$1"
  local host="$2"
  local target="$3"
  local file tmp now index created

  file=$(harto_devhost_routes_file)
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  if index=$(harto_devhost_route_index "$name"); then
    created=$(yq eval ".routes[${index}].created_at" "$file")
    NAME="$name" HOST="$host" TARGET="$target" NOW="$now" CREATED="$created" INDEX="$index" \
      yq eval '
        .routes[(env(INDEX) | tonumber)].host = strenv(HOST) |
        .routes[(env(INDEX) | tonumber)].target = strenv(TARGET) |
        .routes[(env(INDEX) | tonumber)].updated_at = strenv(NOW) |
        .routes[(env(INDEX) | tonumber)].created_at = strenv(CREATED)
      ' "$file" > "$tmp"
  else
    NAME="$name" HOST="$host" TARGET="$target" NOW="$now" yq eval '
      .routes += [{
        "name": strenv(NAME),
        "host": strenv(HOST),
        "target": strenv(TARGET),
        "created_at": strenv(NOW),
        "updated_at": strenv(NOW)
      }]
    ' "$file" > "$tmp"
  fi
  mv "$tmp" "$file"
}

harto_devhost_delete_route() {
  local name="$1"
  local file tmp

  file=$(harto_devhost_routes_file)
  tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
  NAME="$name" yq eval 'del(.routes[] | select(.name == strenv(NAME)))' "$file" > "$tmp"
  mv "$tmp" "$file"
}

harto_devhost_rewrite_hosts() {
  local domain="$1"
  local file count index name host tmp

  file=$(harto_devhost_routes_file)
  count=$(harto_devhost_route_count)
  index=0
  while [ "$index" -lt "$count" ]; do
    name=$(yq eval ".routes[${index}].name" "$file")
    host="${name}.${domain}"
    tmp=$(mktemp "$(dirname "$file")/.tmp.XXXXXX")
    HOST="$host" INDEX="$index" yq eval '
      .routes[(env(INDEX) | tonumber)].host = strenv(HOST)
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
    index=$((index + 1))
  done
}

harto_devhost_responding() {
  local host="$1"
  local target="$2"
  local https port scheme

  https=$(harto_devhost_get https)
  if [ "$https" = "mkcert" ]; then
    scheme="https"
    port="443"
  else
    scheme="http"
    port="80"
  fi
  curl -fsS --max-time 2 "$target" >/dev/null 2>&1 || return 1
  curl -fsS --max-time 2 --resolve "${host}:${port}:127.0.0.1" "${scheme}://${host}/" >/dev/null 2>&1
}

harto_devhost_list_routes() {
  local count index name host target configured applied responding

  harto_devhost_ensure_routes_file
  count=$(harto_devhost_route_count)
  if [ "$count" -eq 0 ]; then
    printf 'no routes\n'
    return 0
  fi
  index=0
  while [ "$index" -lt "$count" ]; do
    name=$(yq eval ".routes[${index}].name" "$(harto_devhost_routes_file)")
    host=$(yq eval ".routes[${index}].host" "$(harto_devhost_routes_file)")
    target=$(yq eval ".routes[${index}].target" "$(harto_devhost_routes_file)")
    configured="yes"
    if harto_proxy_host_applied "$host"; then
      applied="yes"
    else
      applied="no"
    fi
    if harto_devhost_responding "$host" "$target"; then
      responding="yes"
    else
      responding="no"
    fi
    printf 'name=%s host=%s target=%s configured=%s applied=%s responding=%s\n' \
      "$name" "$host" "$target" "$configured" "$applied" "$responding"
    index=$((index + 1))
  done
}

harto_devhost_set_domain() {
  local domain="$1"
  local old backup_dir proxy_ok

  harto_devhost_require_config
  harto_devhost_domain_accept "$domain"
  old=$(harto_devhost_get base_domain)
  if [ "$old" = "$domain" ]; then
    harto_log_info "base domain is already ${domain}"
    return 0
  fi

  harto_devhost_ensure_routes_file
  harto_log_info "routes that will change host:"
  harto_devhost_list_routes || true
  if ! harto_confirm "Change the base domain from ${old} to ${domain}?"; then
    harto_die "domain change cancelled" 1
  fi

  if harto_is_dry_run; then
    printf '[dry-run] would update the base domain to %s and regenerate generated files\n' "$domain" >&2
    return 0
  fi

  backup_dir=$(mktemp -d "${TMPDIR:-/tmp}/harto-devhost.XXXXXX")
  cp -R "$HARTO_PLUGIN_CONFIG_DIR" "${backup_dir}/config"
  harto_backup_dir "$HARTO_PLUGIN_CONFIG_DIR" >/dev/null || true

  DOMAIN="$domain" yq eval '.base_domain = strenv(DOMAIN)' "$(harto_devhost_config_file)" > "${backup_dir}/config.yml"
  mv "${backup_dir}/config.yml" "$(harto_devhost_config_file)"
  harto_devhost_rewrite_hosts "$domain"

  proxy_ok=0
  if [ "$(harto_devhost_get https)" = "mkcert" ]; then
    harto_tls_issue "$domain" || proxy_ok=1
  fi
  if [ "$proxy_ok" -eq 0 ]; then
    harto_dns_apply "$domain" "$(harto_devhost_get dns)" || proxy_ok=1
  fi
  if [ "$proxy_ok" -eq 0 ]; then
    harto_proxy_apply || proxy_ok=1
  fi

  if [ "$proxy_ok" -ne 0 ]; then
    harto_log_error "domain change failed. Restoring the previous configuration."
    rm -rf "$HARTO_PLUGIN_CONFIG_DIR"
    mkdir -p "$(dirname "$HARTO_PLUGIN_CONFIG_DIR")"
    cp -R "${backup_dir}/config" "$HARTO_PLUGIN_CONFIG_DIR"
    harto_dns_apply "$old" "$(harto_devhost_get dns)" || true
    harto_proxy_apply || true
    rm -rf "$backup_dir"
    return 1
  fi

  if [ "$old" != "$domain" ] && [ "$(harto_devhost_get dns)" = "dnsmasq" ]; then
    harto_log_warn "The previous resolver file $(harto_dns_resolver_path "$old") is still present."
    if harto_confirm "Remove the previous resolver file for ${old}?"; then
      harto_dns_remove_resolver "$old" || true
    fi
  fi
  rm -rf "$backup_dir"
  harto_log_info "base domain is now ${domain}"
}
