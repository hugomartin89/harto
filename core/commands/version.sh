#!/usr/bin/env bash
# harto-summary: Print the Harto version

harto_cmd_version() {
  [ $# -eq 0 ] || harto_die "unexpected arguments" 2
  printf 'harto %s\n' "$HARTO_VERSION"
}
