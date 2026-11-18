#!/usr/bin/env bash
# Fail when tracked text contains a non-allowlisted domain or an email address.
# Usage: check-generic.sh [--paths FILE...]

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

tlds='test|example|invalid|localhost|local|com|net|org|io|dev|app|co|me|ai|cloud|xyz|info|biz|uk'
domain_re="([a-zA-Z0-9-]+\\.)+(${tlds})\\b"
email_re='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
failed=0

host_allowed() {
  local host="$1"
  local suffix="${host##*.}"

  case "$suffix" in
    test|example|invalid|localhost) return 0 ;;
  esac

  case "$host" in
    brew.sh|*.brew.sh|\
    github.com|*.github.com|\
    git-scm.com|*.git-scm.com|\
    caddyserver.com|*.caddyserver.com|\
    thekelleys.org.uk|*.thekelleys.org.uk)
      return 0
      ;;
  esac
  return 1
}

scan_file() {
  local file="$1"
  local line_no=0 line matches match

  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))
    matches=$(printf '%s\n' "$line" | grep -Eo "$email_re" || true)
    if [ -n "$matches" ]; then
      printf '%s:%s: email %s\n' "$file" "$line_no" "$matches" >&2
      failed=1
    fi
    matches=$(printf '%s\n' "$line" | grep -Eo "$domain_re" || true)
    if [ -z "$matches" ]; then
      continue
    fi
    while IFS= read -r match; do
      [ -n "$match" ] || continue
      if ! host_allowed "$match"; then
        printf '%s:%s: domain %s\n' "$file" "$line_no" "$match" >&2
        failed=1
      fi
    done <<EOF
$matches
EOF
  done < "$file"
}

scan_denylist() {
  local list="$1"
  local term file

  [ -f "$list" ] || return 0
  while IFS= read -r term || [ -n "$term" ]; do
    case "$term" in
      ''|\#*) continue ;;
    esac
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      if grep -F -i -n -q -- "$term" "$file"; then
        printf '%s: forbidden term from denylist\n' "$file" >&2
        failed=1
      fi
    done <<EOF
$(list_files)
EOF
  done < "$list"
}

list_files() {
  git ls-files --cached --others --exclude-standard
}

main() {
  local files=()
  if [ "${1:-}" = "--paths" ]; then
    shift
    [ "$#" -gt 0 ] || { printf 'usage: %s [--paths FILE...]\n' "$(basename "$0")" >&2; exit 2; }
    files=("$@")
  else
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      files+=("$file")
    done <<EOF
$(list_files)
EOF
  fi

  local file
  for file in "${files[@]}"; do
    scan_file "$file"
  done

  if [ -n "${HARTO_DENYLIST:-}" ]; then
    scan_denylist "$HARTO_DENYLIST"
  elif [ -f "${root}/.harto-denylist" ]; then
    scan_denylist "${root}/.harto-denylist"
  fi

  return "$failed"
}

main "$@"
