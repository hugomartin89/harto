#!/usr/bin/env bash
# harto-summary: Fast-forward a clean git checkout and run migrations

harto_cmd_upgrade() {
  [ $# -eq 0 ] || harto_die "unexpected arguments" 2
  harto_upgrade_all
}
