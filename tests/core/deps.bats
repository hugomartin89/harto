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

@test "setup refuses to continue when git is missing" {
  local bin tool
  bin="${BATS_TEST_TMPDIR}/no-git"
  mkdir -p "$bin"
  ln -s "${HARTO_ROOT}/tests/helpers/stubs/brew" "$bin/brew"
  for tool in /bin/rm /bin/mkdir /bin/cat /bin/ln /bin/bash \
    /usr/bin/dirname /usr/bin/basename /usr/bin/readlink /usr/bin/uname \
    /usr/bin/env /usr/bin/sed /usr/bin/head /usr/bin/grep /usr/bin/tr; do
    ln -s "$tool" "$bin/$(basename "$tool")"
  done
  PATH="${BATS_TEST_TMPDIR}/bin:${bin}"
  run "$(harto_bin)" setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"git is not installed"* ]]
  [ ! -d "${XDG_CONFIG_HOME}/harto" ]
}

@test "setup refuses to continue when yq is missing" {
  PATH="${HARTO_ROOT}/tests/helpers/stubs:/usr/bin:/bin"
  run "$(harto_bin)" setup
  [ "$status" -ne 0 ]
  [[ "$output" == *"yq (mikefarah)"* ]]
  [ ! -d "${XDG_CONFIG_HOME}/harto" ]
}

@test "setup links harto unless another name is given" {
  run "$(harto_bin)" --yes setup
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.local/bin/harto" ]
  [ "$(readlink "${HOME}/.local/bin/harto")" = "$(harto_bin)" ]
}

@test "setup uses HARTO_LINK_NAME when it is set" {
  export HARTO_LINK_NAME=devx
  run "$(harto_bin)" --yes setup
  [ "$status" -eq 0 ]
  [ -L "${HOME}/.local/bin/devx" ]
  [ ! -e "${HOME}/.local/bin/harto" ]
}

@test "an empty HARTO_LINK_NAME skips the symlink" {
  export HARTO_LINK_NAME=
  run "$(harto_bin)" --yes setup
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.local/bin/harto" ]
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
  run "${BATS_TEST_TMPDIR}/bin/yq" eval 'has("core_version")' "${XDG_STATE_HOME}/harto/state.yml"
  [ "$output" = "false" ]
}
