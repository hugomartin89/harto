#!/usr/bin/env bash

# Color is for a person at a terminal. NO_COLOR, a dumb terminal, and a pipe
# stay plain so scripts and the operations log can read the text.
harto_color_enabled() {
  local fd="${1:-2}"

  case "$fd" in
    1|2) ;;
    *) return 1 ;;
  esac
  [ -t "$fd" ] || return 1
  [ -n "${TERM:-}" ] || return 1
  [ "${TERM}" != "dumb" ] || return 1
  [ -z "${NO_COLOR+x}" ] || return 1
}

harto_paint() {
  local fd="$1"
  local code="$2"
  local text="$3"

  if harto_color_enabled "$fd"; then
    printf '\033[%sm%s\033[0m' "$code" "$text"
  else
    printf '%s' "$text"
  fi
}

harto_log_op() {
  local level="$1"
  shift
  local dir="${HARTO_STATE_DIR:-}/logs"
  local file="${dir}/operations.log"

  [ -d "$dir" ] || return 0
  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$*" >> "$file"
}

harto_log_info() {
  printf '%s: %s\n' "$(harto_paint 2 32 info)" "$*" >&2
  harto_log_op "info" "$*"
}

harto_log_warn() {
  printf '%s: %s\n' "$(harto_paint 2 33 warn)" "$*" >&2
  harto_log_op "warn" "$*"
}

harto_log_error() {
  printf '%s: %s\n' "$(harto_paint 2 31 error)" "$*" >&2
  harto_log_op "error" "$*"
}

harto_log_debug() {
  [ "${HARTO_DEBUG:-0}" = "1" ] || return 0
  printf '%s: %s\n' "$(harto_paint 2 2 debug)" "$*" >&2
}

harto_die() {
  local message="$1"
  local code="${2:-1}"
  harto_log_error "$message"
  exit "$code"
}
