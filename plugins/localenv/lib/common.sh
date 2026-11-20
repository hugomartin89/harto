#!/usr/bin/env bash

if ! declare -F harto_log_info >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "$HARTO_LIB/bootstrap.sh"
  harto_config_init
fi

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/crypt.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/store.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/dotenv.sh"
# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/session.sh"
