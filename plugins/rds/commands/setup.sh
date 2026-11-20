#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

answer() {
  local provided="$1"
  local is_set="$2"
  local prompt="$3"
  local fallback="$4"
  local hint="${5:-}"

  if [ "$is_set" = "yes" ]; then
    printf '%s\n' "$provided"
    return 0
  fi
  if [ "${HARTO_YES:-0}" = "1" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi
  harto_prompt "$prompt" "$fallback" "$hint"
}

harto_dep_check_core || exit 1
harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/config.yml" || exit 1

if [ -n "${HARTO_RDS_REGION+x}" ]; then
  region=$(answer "$HARTO_RDS_REGION" yes "" "")
else
  region=$(answer "" no "AWS region" "us-east-1" HARTO_RDS_REGION)
fi
harto_rds_check_region "$region" || harto_die "invalid region: ${region}. Set HARTO_RDS_REGION." 2

if [ -n "${HARTO_RDS_READ_USER+x}" ]; then
  read_user=$(answer "$HARTO_RDS_READ_USER" yes "" "")
else
  read_user=$(answer "" no "Read-only database user" "" HARTO_RDS_READ_USER)
fi
harto_rds_check_user "$read_user" || harto_die "read user is required. Set HARTO_RDS_READ_USER." 2

if [ -n "${HARTO_RDS_WRITE_USER+x}" ]; then
  write_user=$(answer "$HARTO_RDS_WRITE_USER" yes "" "")
else
  write_user=$(answer "" no "Write database user" "" HARTO_RDS_WRITE_USER)
fi
harto_rds_check_user "$write_user" || harto_die "write user is required. Set HARTO_RDS_WRITE_USER." 2

if harto_is_dry_run; then
  printf '[dry-run] would write rds configuration\n' >&2
  printf '[dry-run] would download the RDS CA bundle\n' >&2
  exit 0
fi

mkdir -p "$HARTO_PLUGIN_CONFIG_DIR" "$HARTO_PLUGIN_DATA_DIR"
REGION="$region" READ_USER="$read_user" WRITE_USER="$write_user" yq eval -n '
  .region = strenv(REGION) |
  .read_user = strenv(READ_USER) |
  .write_user = strenv(WRITE_USER)
' | harto_atomic_write "$(harto_rds_config_file)"
harto_rds_ensure_databases_file

ca=$(harto_rds_ca_file)
tmp=$(mktemp "$(dirname "$ca")/.tmp.XXXXXX")
if curl -fsSL -o "$tmp" "$(harto_rds_ca_url)"; then
  mv "$tmp" "$ca"
  harto_log_info "RDS CA bundle downloaded"
else
  rm -f "$tmp"
  harto_log_warn "could not download the RDS CA bundle. Run: curl -fsSL -o ${ca} $(harto_rds_ca_url)"
fi

harto_log_info "rds configured"
