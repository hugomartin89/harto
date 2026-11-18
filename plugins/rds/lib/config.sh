#!/usr/bin/env bash

harto_rds_config_file() {
  printf '%s/config.yml\n' "$HARTO_PLUGIN_CONFIG_DIR"
}

harto_rds_databases_file() {
  printf '%s/databases.yml\n' "$HARTO_PLUGIN_CONFIG_DIR"
}

harto_rds_ca_file() {
  printf '%s/global-bundle.pem\n' "$HARTO_PLUGIN_DATA_DIR"
}

harto_rds_ca_url() {
  printf '%s\n' "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
}

harto_rds_configured() {
  harto_yaml_valid "$(harto_rds_config_file)"
}

harto_rds_require_config() {
  if ! harto_rds_configured; then
    harto_die "rds is not configured. Run: ${HARTO_PROG} rds setup" 1
  fi
}

harto_rds_get() {
  local key="$1"
  local value

  printf '%s\n' "$key" | grep -Eq '^[a-z][a-z0-9_]*$' || harto_die "invalid config key: ${key}" 1
  value=$(yq eval ".${key} // \"\"" "$(harto_rds_config_file)")
  if [ "$value" = "null" ]; then
    value=""
  fi
  printf '%s\n' "$value"
}

harto_rds_ensure_databases_file() {
  local file
  file=$(harto_rds_databases_file)
  if [ ! -f "$file" ]; then
    harto_atomic_write "$file" <<'EOF'
databases: []
EOF
  fi
  harto_yaml_valid "$file" || harto_die "database catalog is unreadable: ${file}" 1
}
