#!/usr/bin/env bash
# Validate Conventional Commits subjects.
# Usage: check-commits.sh --file PATH | --range BASE..HEAD

set -euo pipefail

usage() {
  printf 'usage: %s --file PATH | --range BASE..HEAD\n' "$(basename "$0")" >&2
}

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
header_re="^(${types})(\\([[:lower:]][[:lower:][:digit:]-]*\\))?(!)?: [[:lower:]].+"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

check_subject() {
  local header="$1"
  local subject

  case "$header" in
    Merge\ *)
      return 0
      ;;
  esac

  if ! printf '%s\n' "$header" | grep -Eq "$header_re"; then
    fail "not a conventional commit: ${header}"
  fi

  subject=${header#*: }
  if [ "${#subject}" -gt 72 ]; then
    fail "subject longer than 72 characters: ${header}"
  fi
  case "$subject" in
    *.)
      fail "subject must not end with a period: ${header}"
      ;;
  esac
  if printf '%s\n' "$subject" | grep -Eq '[[:upper:]]'; then
    fail "subject must be lowercase: ${header}"
  fi
  if ! printf '%s\n' "$subject" | grep -Eq '^[[:lower:]]'; then
    fail "subject must start with a lowercase letter: ${header}"
  fi
}

check_file() {
  local file="$1"
  local header
  header=$(sed -n '/^[^#]/ { p; q; }' "$file" | tr -d '\r')
  if [ -z "$header" ]; then
    fail "empty commit message"
  fi
  check_subject "$header"
}

check_range() {
  local range="$1"
  local subject count
  count=0
  while IFS= read -r subject; do
    [ -n "$subject" ] || continue
    check_subject "$subject"
    count=$((count + 1))
  done <<EOF
$(git log --format=%s "$range")
EOF
  if [ "$count" -eq 0 ]; then
    return 0
  fi
}

main() {
  [ $# -eq 2 ] || { usage; exit 2; }
  case "$1" in
    --file) check_file "$2" ;;
    --range) check_range "$2" ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
