#!/usr/bin/env bash

harto_proxy_caddyfile() {
  printf '%s/caddy/Caddyfile\n' "$HARTO_PLUGIN_DATA_DIR"
}

harto_proxy_last_good() {
  printf '%s/caddy/Caddyfile.last-good\n' "$HARTO_PLUGIN_DATA_DIR"
}

harto_proxy_render() {
  local admin https cert key routes_file count index host target upstream site

  admin=$(harto_devhost_get admin_address)
  https=$(harto_devhost_get https)
  cert="${HARTO_PLUGIN_DATA_DIR}/certs/cert.pem"
  key="${HARTO_PLUGIN_DATA_DIR}/certs/key.pem"
  routes_file=$(harto_devhost_routes_file)

  printf '{\n'
  printf '\tadmin %s\n' "$admin"
  if [ "$https" != "mkcert" ]; then
    printf '\tauto_https off\n'
  fi
  printf '}\n\n'

  if [ ! -f "$routes_file" ]; then
    return 0
  fi

  count=$(yq eval '.routes // [] | length' "$routes_file")
  index=0
  while [ "$index" -lt "$count" ]; do
    host=$(yq eval ".routes[${index}].host" "$routes_file")
    target=$(yq eval ".routes[${index}].target" "$routes_file")
    upstream=${target#http://}
    upstream=${upstream#https://}
    if [ "$https" = "mkcert" ]; then
      site="$host"
    else
      site="http://${host}"
    fi
    printf '%s {\n' "$site"
    printf '\tbind 127.0.0.1\n'
    if [ "$https" = "mkcert" ]; then
      printf '\ttls %s %s\n' "$cert" "$key"
    fi
    printf '\treverse_proxy %s\n' "$upstream"
    printf '}\n\n'
    index=$((index + 1))
  done
}

harto_proxy_validate() {
  local file="$1"
  caddy validate --config "$file" --adapter caddyfile
}

harto_proxy_reload() {
  local admin file
  admin=$(harto_devhost_get admin_address)
  file=$(harto_proxy_caddyfile)
  caddy reload --config "$file" --adapter caddyfile --address "$admin"
}

harto_proxy_admin_body() {
  local admin
  admin=$(harto_devhost_get admin_address)
  curl -fsS --max-time 2 "http://${admin}/config/"
}

harto_proxy_host_applied() {
  local host="$1"
  local body
  body=$(harto_proxy_admin_body 2>/dev/null) || return 1
  printf '%s\n' "$body" | grep -F -q -- "$host"
}

harto_proxy_verify() {
  harto_proxy_admin_body >/dev/null
}

harto_proxy_restore_last_good() {
  local current last
  current=$(harto_proxy_caddyfile)
  last=$(harto_proxy_last_good)
  if [ ! -f "$last" ]; then
    rm -f "$current"
    return 0
  fi
  cp "$last" "$current"
  harto_proxy_reload || true
}

harto_proxy_apply() {
  local current last tmp dir

  current=$(harto_proxy_caddyfile)
  last=$(harto_proxy_last_good)
  dir=$(dirname "$current")
  mkdir -p "$dir"

  if harto_is_dry_run; then
    printf '[dry-run] would render, validate, and reload the devhost Caddyfile\n' >&2
    return 0
  fi

  tmp=$(mktemp "${dir}/.Caddyfile.XXXXXX")
  harto_proxy_render > "$tmp"
  if ! harto_proxy_validate "$tmp"; then
    rm -f "$tmp"
    harto_log_error "generated proxy configuration is invalid. The previous file was kept."
    return 1
  fi

  if [ -f "$current" ]; then
    cp "$current" "$last"
  fi
  mv "$tmp" "$current"

  if ! harto_proxy_reload || ! harto_proxy_verify; then
    harto_log_error "proxy did not load the new configuration. Restoring the last valid file."
    harto_proxy_restore_last_good
    return 1
  fi

  cp "$current" "$last"
  harto_log_info "proxy configuration applied"
}

harto_proxy_status() {
  if harto_proxy_verify >/dev/null 2>&1; then
    printf 'proxy_admin=reachable\n'
  else
    printf 'proxy_admin=unreachable\n'
  fi
}
