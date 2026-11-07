#!/usr/bin/env bats

load '../helpers/setup'

@test "real service integration is opt-in" {
  if [ "${HARTO_INTEGRATION:-0}" != "1" ]; then
    skip "set HARTO_INTEGRATION=1 to exercise real Caddy, dnsmasq, mkcert, and launchd"
  fi
  command -v caddy
  command -v dnsmasq
  command -v mkcert
}
