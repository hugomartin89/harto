#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} rds doctor" 2

harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/plugin.yml" || true
printf 'vpn=required\n'
harto_log_info "The VPN must be running before a connection can reach the database."

if ! harto_rds_configured; then
  printf 'configured=no\n'
  exit 0
fi

printf 'configured=yes\n'
printf 'region=%s\n' "$(harto_rds_get region)"
if [ -f "$(harto_rds_ca_file)" ]; then
  printf 'ca_bundle=present\n'
else
  printf 'ca_bundle=missing\n'
  harto_log_warn "RDS CA bundle is missing. Run: curl -fsSL -o $(harto_rds_ca_file) $(harto_rds_ca_url)"
fi

harto_rds_ensure_databases_file
file=$(harto_rds_databases_file)
count=$(yq eval '.databases // [] | length' "$file")
index=0
profiles=$(aws configure list-profiles 2>/dev/null || true)
while [ "$index" -lt "$count" ]; do
  profile=$(yq eval ".databases[${index}].profile" "$file")
  if printf '%s\n' "$profiles" | grep -Fxq "$profile"; then
    printf 'profile=%s status=present\n' "$profile"
  else
    printf 'profile=%s status=missing\n' "$profile"
  fi
  index=$((index + 1))
done
exit 0
