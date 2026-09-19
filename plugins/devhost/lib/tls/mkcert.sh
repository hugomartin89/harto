#!/usr/bin/env bash

harto_tls_cert() {
  printf '%s/certs/cert.pem\n' "$HARTO_PLUGIN_DATA_DIR"
}

harto_tls_key() {
  printf '%s/certs/key.pem\n' "$HARTO_PLUGIN_DATA_DIR"
}

harto_tls_require_mkcert() {
  if command -v mkcert >/dev/null 2>&1; then
    return 0
  fi
  harto_log_error "missing dependency mkcert (mkcert)"
  harto_log_error "install: brew install mkcert"
  harto_log_error "official source: https://github.com/FiloSottile/mkcert"
  return 1
}

harto_tls_install_ca() {
  harto_log_warn "This installs a local certificate authority and changes which certificates macOS trusts."
  harto_log_warn "The command is: mkcert -install. Undo it later with: mkcert -uninstall."
  if ! harto_confirm "Install the local certificate authority into the macOS trust store?"; then
    harto_die "certificate authority installation declined" 1
  fi
  if harto_is_dry_run; then
    printf '[dry-run] would run mkcert -install\n' >&2
    return 0
  fi
  mkcert -install
  harto_log_info "local certificate authority installed"
}

harto_tls_issue() {
  local domain="$1"
  local dir cert key tmp_cert tmp_key

  dir="${HARTO_PLUGIN_DATA_DIR}/certs"
  cert=$(harto_tls_cert)
  key=$(harto_tls_key)
  if harto_is_dry_run; then
    printf '[dry-run] would issue a certificate for %s and *.%s\n' "$domain" "$domain" >&2
    return 0
  fi
  mkdir -p "$dir"
  tmp_cert=$(mktemp "${dir}/.cert.XXXXXX")
  tmp_key=$(mktemp "${dir}/.key.XXXXXX")
  if ! mkcert -cert-file "$tmp_cert" -key-file "$tmp_key" "$domain" "*.${domain}"; then
    rm -f "$tmp_cert" "$tmp_key"
    return 1
  fi
  mv "$tmp_cert" "$cert"
  mv "$tmp_key" "$key"
  harto_log_info "certificate written for ${domain}"
}

harto_tls_status() {
  local https
  https=$(harto_devhost_get https)
  printf 'https=%s\n' "$https"
  if [ "$https" != "mkcert" ]; then
    return 0
  fi
  if [ -f "$(harto_tls_cert)" ] && [ -f "$(harto_tls_key)" ]; then
    printf 'certificate=present\n'
  else
    printf 'certificate=missing\n'
  fi
}
