#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

harto_devhost_require_config

sub="${1:-show}"
case "$sub" in
  show)
    [ $# -le 1 ] || harto_die "usage: ${HARTO_PROG} devhost config show" 2
    yq eval '.' "$(harto_devhost_config_file)"
    ;;
  set)
    [ $# -eq 3 ] || harto_die "usage: ${HARTO_PROG} devhost config set domain <domain>" 2
    [ "$2" = "domain" ] || harto_die "unsupported setting: ${2}" 2
    harto_devhost_set_domain "$3"
    ;;
  *)
    harto_die "usage: ${HARTO_PROG} devhost config show|set" 2
    ;;
esac
