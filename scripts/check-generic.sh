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
    gnu.org|*.gnu.org|\
    git-scm.com|*.git-scm.com|\
    caddyserver.com|*.caddyserver.com|\
    thekelleys.org.uk|*.thekelleys.org.uk|\
    docs.aws.amazon.com|\
    truststore.pki.rds.amazonaws.com)
      return 0
      ;;
  esac
  return 1
}

existing_files() {
  local file
  for file in "$@"; do
    [ -f "$file" ] || continue
    printf '%s\n' "$file"
  done
}

scan_text() {
  local file line line_no match rest
  [ "$#" -gt 0 ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    file=${line%%:*}
    rest=${line#*:}
    line_no=${rest%%:*}
    match=${rest#*:}
    case "$match" in
      *@*)
        printf '%s:%s: email %s\n' "$file" "$line_no" "$match" >&2
        failed=1
        ;;
      *)
        if ! host_allowed "$match"; then
          printf '%s:%s: domain %s\n' "$file" "$line_no" "$match" >&2
          failed=1
        fi
        ;;
    esac
  done <<EOF
$(grep -a -n -E -o -H -e "$email_re" -e "$domain_re" -- "$@" || true)
EOF
}

scan_denylist() {
  local list="$1"
  shift
  local terms file term

  [ "$#" -gt 0 ] || return 0
  [ -f "$list" ] || return 0
  terms=$(mktemp)
  while IFS= read -r term || [ -n "$term" ]; do
    case "$term" in
      ''|\#*) continue ;;
    esac
    printf '%s\n' "$term" >> "$terms"
  done < "$list"
  if [ ! -s "$terms" ]; then
    rm -f "$terms"
    return 0
  fi
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    printf '%s: forbidden term from denylist\n' "$file" >&2
    failed=1
  done <<EOF
$(grep -a -F -i -l -f "$terms" -- "$@" || true)
EOF
  rm -f "$terms"
}

list_files() {
  git ls-files --cached --others --exclude-standard
}

main() {
  local files=()
  local file present=()

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

  if [ "${#files[@]}" -eq 0 ]; then
    return 0
  fi

  while IFS= read -r file; do
    [ -n "$file" ] || continue
    present+=("$file")
  done <<EOF
$(existing_files "${files[@]}")
EOF

  if [ "${#present[@]}" -eq 0 ]; then
    return 0
  fi

  scan_text "${present[@]}"

  if [ -n "${HARTO_DENYLIST:-}" ]; then
    scan_denylist "$HARTO_DENYLIST" "${present[@]}"
  elif [ -f "${root}/.harto-denylist" ]; then
    scan_denylist "${root}/.harto-denylist" "${present[@]}"
  fi

  return "$failed"
}

main "$@"
