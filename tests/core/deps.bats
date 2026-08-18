#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  harto_test_isolate
}

@test "setup refuses to continue when Homebrew is missing" {
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  run "$(harto_bin)" setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"https://brew.sh"* ]]
  [ ! -d "${XDG_CONFIG_HOME}/harto" ]
}

@test "setup refuses to continue when yq is missing" {
  PATH="${HARTO_ROOT}/tests/helpers/stubs:/usr/bin:/bin"
  run "$(harto_bin)" setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"yq (mikefarah)"* ]]
  [ ! -d "${XDG_CONFIG_HOME}/harto" ]
}

@test "setup records configuration outside the repository" {
  run "$(harto_bin)" --yes setup
  [ "$status" -eq 0 ]
  [ -f "${XDG_CONFIG_HOME}/harto/config.yml" ]
  [ -f "${XDG_STATE_HOME}/harto/state.yml" ]
  [[ "$output" != *"/"*"${HARTO_ROOT}/.config"* ]]
}

@test "doctor reports a missing Homebrew without failing" {
  PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin"
  run "$(harto_bin)" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"https://brew.sh"* ]]
  [ ! -d "${XDG_CONFIG_HOME}/harto" ]
}

@test "a second setup does not duplicate core state" {
  "$(harto_bin)" --yes setup
  "$(harto_bin)" --yes setup
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.core_version' "${XDG_STATE_HOME}/harto/state.yml"
  [ "$output" = "0.7.0" ]
}
