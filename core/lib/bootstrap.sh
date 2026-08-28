#!/usr/bin/env bash
# Load core libraries in a fixed order. Do not put command logic here.

# shellcheck source=logging.sh
. "$HARTO_LIB/logging.sh"
# shellcheck source=platform.sh
. "$HARTO_LIB/platform.sh"
# shellcheck source=utils.sh
. "$HARTO_LIB/utils.sh"
# shellcheck source=config.sh
. "$HARTO_LIB/config.sh"
# shellcheck source=dependencies.sh
. "$HARTO_LIB/dependencies.sh"
# shellcheck source=plugin-manager.sh
. "$HARTO_LIB/plugin-manager.sh"
# shellcheck source=upgrade.sh
. "$HARTO_LIB/upgrade.sh"
