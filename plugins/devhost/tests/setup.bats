#!/usr/bin/env bats

load '../../../tests/helpers/setup'

setup() {
  harto_test_isolate
  harto_devhost_env
  "$(harto_bin)" plugin enable devhost
  "$(harto_bin)" devhost setup
}

@test "setup asks for a base domain and persists it outside the repository" {
  [ -f "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml" ]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.base_domain' "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml"
  [ "$output" = "local.test" ]
  [[ "${XDG_CONFIG_HOME}" != "${HARTO_ROOT}"* ]]
}

@test "a domain with a scheme is rejected and no config is replaced" {
  run env HARTO_YES=1 HARTO_DEVHOST_DOMAIN='http://local.test' "$(harto_bin)" devhost setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"scheme"* ]]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.base_domain' "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml"
  [ "$output" = "local.test" ]
}

@test "the .local suffix is rejected" {
  local domain
  domain="$(printf '%s.%s' app local)"
  run env HARTO_YES=1 HARTO_DEVHOST_DOMAIN="$domain" "$(harto_bin)" devhost setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"mDNS"* ]]
}

@test "a public suffix requires confirmation" {
  local domain
  unset HARTO_YES
  domain="$(printf '%s.%s' app com)"
  run env HARTO_DEVHOST_DOMAIN="$domain" "$(harto_bin)" devhost setup <<'EOF'
n
EOF
  [ "$status" -ne 0 ]
  [[ "$output" == *"declined"* ]]
}

@test "a hyphenated domain is accepted" {
  harto_devhost_env "my-app.test"
  run "$(harto_bin)" devhost setup
  [ "$status" -eq 0 ]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.base_domain' "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml"
  [ "$output" = "my-app.test" ]
}

@test "setup is idempotent" {
  "$(harto_bin)" devhost add app --port 8080
  "$(harto_bin)" devhost setup
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.routes | length' "${XDG_CONFIG_HOME}/harto/plugins/devhost/routes.yml"
  [ "$output" = "1" ]
}

@test "dry-run setup does not rewrite configuration" {
  run "$(harto_bin)" --dry-run devhost setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.base_domain' "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml"
  [ "$output" = "local.test" ]
}

@test "devhost setup stops when caddy is missing and writes nothing new" {
  mkdir -p "${BATS_TEST_TMPDIR}/nocaddy"
  local stub
  for stub in "${HARTO_ROOT}/tests/helpers/stubs"/*; do
    [ "$(basename "$stub")" = "caddy" ] && continue
    ln -s "$stub" "${BATS_TEST_TMPDIR}/nocaddy/$(basename "$stub")"
  done
  PATH="${BATS_TEST_TMPDIR}/nocaddy:${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  local before
  before=$(cksum "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml")
  run "$(harto_bin)" devhost setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"caddy"* ]]
  [ "$(cksum "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml")" = "$before" ]
}

@test "doctor reports a missing dependency without failing" {
  mkdir -p "${BATS_TEST_TMPDIR}/nocaddy"
  local stub
  for stub in "${HARTO_ROOT}/tests/helpers/stubs"/*; do
    [ "$(basename "$stub")" = "caddy" ] && continue
    ln -s "$stub" "${BATS_TEST_TMPDIR}/nocaddy/$(basename "$stub")"
  done
  PATH="${BATS_TEST_TMPDIR}/nocaddy:${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  run "$(harto_bin)" devhost doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"caddy"* ]]
}
