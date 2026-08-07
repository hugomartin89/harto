#!/usr/bin/env bash

harto_log_op() {
  local level="$1"
  shift
  local dir="${HARTO_STATE_DIR:-}/logs"
  local file="${dir}/operations.log"

  [ -d "$dir" ] || return 0
  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" >> "$file"
}

harto_log_info() {
  printf 'info: %s\n' "$*" >&2
  harto_log_op "info" "$*"
}

harto_log_warn() {
  printf 'warn: %s\n' "$*" >&2
  harto_log_op "warn" "$*"
}

harto_log_error() {
  printf 'error: %s\n' "$*" >&2
  harto_log_op "error" "$*"
}

harto_log_debug() {
  [ "${HARTO_DEBUG:-0}" = "1" ] || return 0
  printf 'debug: %s\n' "$*" >&2
}

harto_die() {
  local message="$1"
  local code="${2:-1}"
  harto_log_error "$message"
  exit "$code"
}
