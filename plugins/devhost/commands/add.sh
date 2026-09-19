#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

name=""
port=""
target=""

while [ $# -gt 0 ]; do
  case "$1" in
    --port)
      [ $# -ge 2 ] || harto_die "--port needs a value" 2
      port="$2"
      shift 2
      ;;
    --target)
      [ $# -ge 2 ] || harto_die "--target needs a value" 2
      target="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      harto_die "unknown option: ${1}" 2
      ;;
    *)
      [ -z "$name" ] || harto_die "unexpected argument: ${1}" 2
      name="$1"
      shift
      ;;
  esac
done

[ $# -eq 0 ] || harto_die "unexpected arguments" 2
harto_valid_name "$name" || harto_die "route name must match ^[a-z][a-z0-9-]*$" 2
if [ -n "$port" ] && [ -n "$target" ]; then
  harto_die "pass either --port or --target" 2
fi
if [ -n "$port" ]; then
  target=$(harto_devhost_target_from_port "$port") || harto_die "invalid port: ${port}" 2
fi
[ -n "$target" ] || harto_die "pass --port or --target" 2
harto_devhost_target_check "$target" || harto_die "invalid target: ${target}" 2

harto_devhost_require_config
harto_devhost_ensure_routes_file
base=$(harto_devhost_get base_domain)
host="${name}.${base}"
if [ "${#host}" -gt 253 ]; then
  harto_die "route host is longer than 253 characters" 1
fi
if harto_devhost_host_taken "$host" "$name"; then
  harto_die "host ${host} is already used by another route" 1
fi

backup=$(harto_backup_file "$(harto_devhost_routes_file)")
harto_devhost_save_route "$name" "$host" "$target"
if ! harto_proxy_apply; then
  if [ -n "$backup" ]; then
    cp "$backup" "$(harto_devhost_routes_file)"
    harto_proxy_apply || true
  fi
  harto_die "route was not applied. The previous routes were restored." 1
fi
harto_log_info "route ${name} -> ${host}"
