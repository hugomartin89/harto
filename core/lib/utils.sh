#!/usr/bin/env bash

harto_is_dry_run() {
  [ "${HARTO_DRY_RUN:-0}" = "1" ]
}

harto_is_noninteractive() {
  [ "${HARTO_NONINTERACTIVE:-0}" = "1" ]
}

harto_atomic_write() {
  local dest="$1"
  local dir tmp

  dir=$(dirname "$dest")
  mkdir -p "$dir"
  tmp=$(mktemp "${dir}/.tmp.XXXXXX")
  cat > "$tmp"
  mv "$tmp" "$dest"
}

harto_with_lock() {
  local name="$1"
  shift
  local lockdir status

  case "$name" in
    [a-z]*) ;;
    *) harto_die "invalid lock name: ${name}" 1 ;;
  esac

  harto_config_ensure_dirs
  lockdir="${HARTO_STATE_DIR}/locks/${name}.lock"
  mkdir -p "$(dirname "$lockdir")"

  if ! mkdir "$lockdir" 2>/dev/null; then
    harto_die "another harto process holds the lock: ${name}" 1
  fi

  status=0
  (
    trap 'rmdir "'"$lockdir"'" 2>/dev/null || true' EXIT
    "$@"
  ) || status=$?

  rmdir "$lockdir" 2>/dev/null || true
  return "$status"
}

harto_backup_file() {
  local src="$1"
  local dest

  [ -f "$src" ] || return 0
  harto_config_ensure_dirs
  dest="${HARTO_DATA_DIR}/backups/$(basename "$src").$(date -u +%Y%m%dT%H%M%SZ)"
  cp "$src" "$dest"
  printf '%s\n' "$dest"
}

harto_backup_dir() {
  local src="$1"
  local dest

  [ -d "$src" ] || return 0
  harto_config_ensure_dirs
  dest="${HARTO_DATA_DIR}/backups/$(basename "$src")-$(date -u +%Y%m%dT%H%M%SZ).tar"
  tar -cf "$dest" -C "$(dirname "$src")" "$(basename "$src")"
  printf '%s\n' "$dest"
}

harto_confirm() {
  local prompt="$1"
  local reply

  if [ "${HARTO_YES:-0}" = "1" ]; then
    return 0
  fi
  if harto_is_dry_run; then
    printf '[dry-run] would ask: %s\n' "$prompt" >&2
    return 0
  fi
  if harto_is_noninteractive; then
    harto_die "confirmation required: ${prompt} Pass --yes to accept." 3
  fi

  printf '%s [y/N] ' "$prompt" >&2
  IFS= read -r reply || true
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

harto_prompt() {
  local prompt="$1"
  local default="${2:-}"
  local hint="${3:-}"
  local reply

  if harto_is_noninteractive; then
    if [ "${HARTO_YES:-0}" = "1" ]; then
      printf '%s\n' "$default"
      return 0
    fi
    harto_die "input required: ${prompt}${hint:+. Set ${hint}}" 2
  fi

  if [ -n "$default" ]; then
    printf '%s [%s]: ' "$prompt" "$default" >&2
  else
    printf '%s: ' "$prompt" >&2
  fi

  if [ "${HARTO_YES:-0}" = "1" ]; then
    printf '%s\n' "$default"
    return 0
  fi

  IFS= read -r reply || true
  if [ -z "$reply" ]; then
    printf '%s\n' "$default"
  else
    printf '%s\n' "$reply"
  fi
}

_harto_privileged_prepare() {
  local explanation="$1"
  shift
  local arg

  [ $# -ge 1 ] || harto_die "no privileged command was given" 1

  printf 'privileged: %s\n' "$explanation" >&2
  printf 'command:' >&2
  for arg in "$@"; do
    printf ' %q' "$arg" >&2
  done
  printf '\n' >&2

  if harto_is_dry_run; then
    printf '[dry-run] would run the privileged command above\n' >&2
    return 1
  fi
  if harto_is_noninteractive; then
    harto_die "this step needs sudo and a person. Run it without --non-interactive: ${HARTO_PROG:-harto} ${HARTO_INVOCATION:-}" 3
  fi

  if ! harto_confirm "Apply this privileged change?"; then
    harto_die "privileged operation declined" 1
  fi
  return 0
}

harto_run_privileged() {
  local explanation="$1"
  shift

  _harto_privileged_prepare "$explanation" "$@" || return 0
  sudo "$@"
}

harto_run_privileged_input() {
  local input="$1"
  local explanation="$2"
  shift 2

  _harto_privileged_prepare "$explanation" "$@" || return 0
  printf '%s\n' "$input" | sudo "$@"
}

harto_valid_name() {
  local value="$1"
  printf '%s\n' "$value" | grep -Eq '^[a-z][a-z0-9-]*$'
}

# Prints the index of the first completion word that is not a global flag.
harto_completion_command_index() {
  local i=0
  local word

  for word in "$@"; do
    case "$word" in
      --yes|-y|--dry-run|--debug|--non-interactive|--json)
        i=$((i + 1))
        ;;
      *)
        printf '%s\n' "$i"
        return 0
        ;;
    esac
  done
  return 1
}
