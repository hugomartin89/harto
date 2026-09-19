#!/usr/bin/env bash

harto_devhost_domain_check() {
  local domain="$1"
  local label tld old_ifs

  if [ -z "$domain" ]; then
    printf 'base domain is required\n' >&2
    return 1
  fi
  if [ "${#domain}" -gt 253 ]; then
    printf 'base domain is longer than 253 characters\n' >&2
    return 1
  fi
  case "$domain" in
    *://*|*/*|*:*|*[[:space:]]*|*'\\'*|*'@'*|*'!'*|*'?'*|*'#'*)
      printf 'base domain must not include a scheme, port, path, or space\n' >&2
      return 1
      ;;
  esac
  if ! printf '%s\n' "$domain" | grep -Eq '^[a-z0-9.-]+$'; then
    printf 'base domain must be lowercase and use only letters, digits, dots, and hyphens\n' >&2
    return 1
  fi
  case "$domain" in
    .*|*.|*..*)
      printf 'base domain has an empty or invalid label\n' >&2
      return 1
      ;;
  esac
  case "$domain" in
    *.*) ;;
    *)
      printf 'base domain needs at least two labels, for example local.test\n' >&2
      return 1
      ;;
  esac

  old_ifs=$IFS
  IFS='.'
  # shellcheck disable=SC2086
  for label in $domain; do
    if [ -z "$label" ] || [ "${#label}" -gt 63 ]; then
      IFS=$old_ifs
      printf 'base domain has an invalid label\n' >&2
      return 1
    fi
    case "$label" in
      -*|*-)
        IFS=$old_ifs
        printf 'a domain label must not start or end with a hyphen\n' >&2
        return 1
        ;;
    esac
  done
  IFS=$old_ifs

  tld=${domain##*.}
  if [ "$tld" = "local" ]; then
    printf 'the .local suffix conflicts with mDNS and is not accepted\n' >&2
    return 1
  fi
  return 0
}

harto_devhost_domain_is_public() {
  local tld="${1##*.}"
  case "$tld" in
    com|net|org|io|dev|app|sh|co|me|info|biz|xyz|ai|cloud)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

harto_devhost_domain_accept() {
  local domain="$1"
  harto_devhost_domain_check "$domain" || return 1
  if harto_devhost_domain_is_public "$domain"; then
    harto_log_warn "${domain} uses a public suffix. A local resolver will not make it trustworthy on its own."
    if ! harto_confirm "Use the public domain ${domain} only on this machine?"; then
      harto_die "base domain declined" 1
    fi
  fi
}

harto_devhost_admin_check() {
  local value="$1"
  local port

  printf '%s\n' "$value" | grep -Eq '^127\.0\.0\.1:[0-9]+$' || return 1
  port=${value##*:}
  [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

harto_devhost_admin_free() {
  local port="$1"
  if ! command -v lsof >/dev/null 2>&1; then
    return 0
  fi
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
