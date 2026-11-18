#!/usr/bin/env bats

load '../../../tests/helpers/setup'
bats_require_minimum_version 1.5.0

setup() {
  harto_test_isolate
  harto_devhost_env
  "$(harto_bin)" plugin enable devhost
  "$(harto_bin)" devhost setup
  : > "$HARTO_STUB_LOG"
}

@test "a privileged step stops with code 3 and does not call sudo even with --yes" {
  run "$(harto_bin)" --non-interactive --yes devhost up
  [ "$status" -eq 3 ]
  [[ "$output" == *"command:"* ]]
  [[ "$output" == *"without --non-interactive: harto devhost up"* ]]
  run grep '^sudo ' "$HARTO_STUB_LOG"
  [ "$status" -eq 1 ]
}

@test "a confirmation stops with code 3 without --yes" {
  unset HARTO_YES
  run "$(harto_bin)" --non-interactive devhost add app --target http://192.0.2.10:8080
  [ "$status" -eq 3 ]
  [[ "$output" == *"Pass --yes"* ]]
}

@test "non-interactive setup without a domain names the variable" {
  unset HARTO_YES HARTO_DEVHOST_DOMAIN
  run "$(harto_bin)" --non-interactive devhost setup
  [ "$status" -eq 2 ]
  [[ "$output" == *"HARTO_DEVHOST_DOMAIN"* ]]
}

@test "list --json returns the routes as an array" {
  run --separate-stderr "$(harto_bin)" --json devhost list
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
  "$(harto_bin)" devhost add app --port 8080
  run --separate-stderr "$(harto_bin)" --json devhost list
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/list.json"
  run "${BATS_TEST_TMPDIR}/bin/yq" eval -p=json -oy '.[0].host' "${BATS_TEST_TMPDIR}/list.json"
  [ "$output" = "app.local.test" ]
}

@test "status --json returns one object" {
  run --separate-stderr "$(harto_bin)" --json devhost status
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/status.json"
  run "${BATS_TEST_TMPDIR}/bin/yq" eval -p=json -oy '.base_domain' "${BATS_TEST_TMPDIR}/status.json"
  [ "$output" = "local.test" ]
}

@test "a command without json output rejects --json" {
  run "$(harto_bin)" --json devhost logs
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not support --json"* ]]
}
