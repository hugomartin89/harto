#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  harto_test_isolate
}

@test "plugin info shows the devhost manifest" {
  run "$(harto_bin)" plugin info devhost
  [ "$status" -eq 0 ]
  [[ "$output" == *"Local domains, HTTPS, and reverse-proxy routes"* ]]
  [[ "$output" == *"caddy"* ]]
}

@test "plugin enable stops when a required dependency is missing" {
  mkdir -p "${BATS_TEST_TMPDIR}/nocaddy"
  local stub
  for stub in "${HARTO_ROOT}/tests/helpers/stubs"/*; do
    [ "$(basename "$stub")" = "caddy" ] && continue
    ln -s "$stub" "${BATS_TEST_TMPDIR}/nocaddy/$(basename "$stub")"
  done
  PATH="${BATS_TEST_TMPDIR}/nocaddy:${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  run "$(harto_bin)" plugin enable devhost
  [ "$status" -ne 0 ]
  [[ "$output" == *"caddy"* ]]
  [ ! -f "${XDG_STATE_HOME}/harto/state.yml" ]
}

@test "plugin enable is idempotent and setup runs once" {
  harto_devhost_env
  "$(harto_bin)" plugin enable devhost
  run "$(harto_bin)" plugin enable devhost
  [ "$status" -eq 0 ]
  [[ "$output" == *"already active"* ]]
  [[ "$output" != *"running setup"* ]]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.plugins.devhost.migrations[]' "${XDG_STATE_HOME}/harto/state.yml"
  [ "$output" = "0001" ]
}

@test "an invalid manifest is rejected" {
  mkdir -p "${XDG_DATA_HOME}/harto/plugins/evil"
  cat > "${XDG_DATA_HOME}/harto/plugins/evil/plugin.yml" <<'EOF'
name: evil
description: broken entry
platforms:
  - darwin
commands:
  - name: run
    description: run
    entrypoint: ../secret.sh
EOF
  run "$(harto_bin)" plugin info evil
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid"* ]]
}

@test "plugin install points a bundled plugin at enable" {
  run "$(harto_bin)" plugin install devhost
  [ "$status" -ne 0 ]
  [[ "$output" == *"plugin enable devhost"* ]]
}

@test "plugin install from a git url is not available yet" {
  run "$(harto_bin)" plugin install "https://example.test/plugin.git"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not available yet"* ]]
  [ ! -f "${XDG_STATE_HOME}/harto/state.yml" ]
}

@test "core source does not name a plugin" {
  run grep -R "devhost" "${HARTO_ROOT}/core" "${HARTO_ROOT}/bin"
  [ "$status" -eq 1 ]
}
