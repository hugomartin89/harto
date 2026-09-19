#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_LIB/bootstrap.sh"
harto_config_init

routes="${HARTO_PLUGIN_CONFIG_DIR}/routes.yml"
if [ ! -f "$routes" ]; then
  exit 0
fi

tmp=$(mktemp "$(dirname "$routes")/.tmp.XXXXXX")
yq eval '.routes //= []' "$routes" > "$tmp"
mv "$tmp" "$routes"
