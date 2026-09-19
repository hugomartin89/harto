#!/usr/bin/env bash

harto_devhost_config_file() {
  printf '%s/config.yml\n' "$HARTO_PLUGIN_CONFIG_DIR"
}

harto_devhost_routes_file() {
  printf '%s/routes.yml\n' "$HARTO_PLUGIN_CONFIG_DIR"
}

harto_devhost_configured() {
  harto_yaml_valid "$(harto_devhost_config_file)"
}

harto_devhost_require_config() {
  if ! harto_devhost_configured; then
    harto_die "devhost is not configured. Run: ${HARTO_PROG} devhost setup" 1
  fi
}

harto_devhost_get() {
  local key="$1"
  local value

  printf '%s\n' "$key" | grep -Eq '^[a-z][a-z0-9_]*$' || harto_die "invalid config key: ${key}" 1
  value=$(yq eval ".${key} // \"\"" "$(harto_devhost_config_file)")
  if [ "$value" = "null" ]; then
    value=""
  fi
  printf '%s\n' "$value"
}

harto_devhost_ensure_routes_file() {
  local file
  file=$(harto_devhost_routes_file)
  if [ ! -f "$file" ]; then
    harto_atomic_write "$file" <<'EOF'
routes: []
EOF
  fi
  harto_yaml_valid "$file" || harto_die "routes file is unreadable: ${file}" 1
}
