#!/usr/bin/env bash

# The store key is one generic password in the login Keychain. The key reaches
# openssl through a file descriptor, never as an argument, and plaintext only
# travels through pipes.

_HARTO_LOCALENV_SERVICE="harto-localenv"

harto_localenv_key_present() {
  security find-generic-password -a "$(id -un)" -s "$_HARTO_LOCALENV_SERVICE" >/dev/null 2>&1
}

harto_localenv_key_read() {
  security find-generic-password -a "$(id -un)" -s "$_HARTO_LOCALENV_SERVICE" -w 2>/dev/null
}

harto_localenv_key_ensure() {
  local key
  if harto_localenv_key_present; then
    return 0
  fi
  key=$(openssl rand -hex 32)
  [ -n "$key" ] || harto_die "could not generate a localenv key" 1
  security add-generic-password -a "$(id -un)" -s "$_HARTO_LOCALENV_SERVICE" -w "$key"
  harto_log_info "created the localenv key in the Keychain"
}

harto_localenv_key_delete() {
  security delete-generic-password -a "$(id -un)" -s "$_HARTO_LOCALENV_SERVICE" >/dev/null 2>&1 || true
}

# Decrypts FILE to stdout.
harto_localenv_decrypt() {
  local file="$1"
  local key

  if ! key=$(harto_localenv_key_read); then
    harto_die "the localenv key is missing from the Keychain, so ${file} cannot be read. Run: ${HARTO_PROG} localenv doctor" 1
  fi
  openssl enc -d -aes-256-cbc -pbkdf2 -pass fd:3 -in "$file" 3< <(printf '%s\n' "$key") 2>/dev/null \
    || harto_die "cannot decrypt ${file}. The Keychain key does not match this file." 1
}

# Encrypts stdin to stdout.
harto_localenv_encrypt() {
  local key

  if ! key=$(harto_localenv_key_read); then
    harto_die "the localenv key is missing from the Keychain. Run: ${HARTO_PROG} localenv doctor" 1
  fi
  openssl enc -aes-256-cbc -pbkdf2 -salt -pass fd:3 3< <(printf '%s\n' "$key")
}
