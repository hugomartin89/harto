#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} localenv setup" 2

harto_dep_check_core || exit 1
harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/plugin.yml" || exit 1

if harto_is_dry_run; then
  printf '[dry-run] would create the localenv project index and Keychain key\n' >&2
  exit 0
fi

harto_with_lock localenv-store harto_localenv_configure_locked
harto_log_info "next: ${HARTO_PROG} localenv init <name>, from the project directory"
