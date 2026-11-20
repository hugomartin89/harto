#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  harto_test_isolate
}

has_line() {
  printf '%s\n' "$output" | grep -qx -e "$1"
}

@test "the first word lists core commands and plugins" {
  run "$(harto_bin)" --non-interactive completion query -- 0 ""
  [ "$status" -eq 0 ]
  has_line help
  has_line plugin
  has_line completion
  has_line devhost
  has_line localenv
  has_line rds
}

@test "a leading flag lists global flags" {
  run "$(harto_bin)" --non-interactive completion query -- 0 --
  [ "$status" -eq 0 ]
  has_line --json
  has_line --dry-run
  has_line --non-interactive
  has_line --debug
  if printf '%s\n' "$output" | grep -qx help; then
    false
  fi
}

@test "a flag before the command still completes the plugin subcommand" {
  run "$(harto_bin)" --non-interactive completion query -- 2 --json devhost ""
  [ "$status" -eq 0 ]
  has_line add
  has_line setup
  has_line remove
}

@test "plugin enable lists repository plugins" {
  run "$(harto_bin)" --non-interactive completion query -- 2 plugin enable ""
  [ "$status" -eq 0 ]
  has_line devhost
  has_line localenv
  has_line rds
}

@test "completion offers bash and zsh" {
  run "$(harto_bin)" --non-interactive completion query -- 1 completion ""
  [ "$status" -eq 0 ]
  has_line bash
  has_line zsh
  if printf '%s\n' "$output" | grep -qx query; then
    false
  fi
}

@test "a core command without arguments adds none" {
  run "$(harto_bin)" --non-interactive completion query -- 1 doctor ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "completion without a shell name is rejected" {
  run "$(harto_bin)" completion
  [ "$status" -eq 2 ]
}

@test "completion bash is valid bash" {
  run "$(harto_bin)" completion bash
  [ "$status" -eq 0 ]
  [[ "$output" == *"completion query"* ]]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/completion.bash"
  bash -n "${BATS_TEST_TMPDIR}/completion.bash"
}

@test "completion zsh is valid zsh" {
  command -v zsh >/dev/null || skip "zsh is not installed"
  run "$(harto_bin)" completion zsh
  [ "$status" -eq 0 ]
  [[ "$output" == *"completion query"* ]]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/completion.zsh"
  zsh -n "${BATS_TEST_TMPDIR}/completion.zsh"
}

@test "an invalid complete hook fails validation" {
  mkdir -p "${XDG_DATA_HOME}/harto/plugins/sample/commands"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${XDG_DATA_HOME}/harto/plugins/sample/commands/run.sh"
  cat > "${XDG_DATA_HOME}/harto/plugins/sample/config.yml" <<'EOF'
name: sample
description: A sample plugin
commands:
  - name: run
    description: Run
    entrypoint: commands/run.sh
hooks:
  complete: ../outside.sh
EOF
  run "$(harto_bin)" plugin info sample
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid complete hook"* ]]
}

@test "a failing complete hook adds no candidates" {
  mkdir -p "${XDG_DATA_HOME}/harto/plugins/sample/commands"
  mkdir -p "${XDG_DATA_HOME}/harto/plugins/sample/hooks"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${XDG_DATA_HOME}/harto/plugins/sample/commands/run.sh"
  printf '#!/usr/bin/env bash\nprintf secret\nexit 1\n' > "${XDG_DATA_HOME}/harto/plugins/sample/hooks/complete.sh"
  cat > "${XDG_DATA_HOME}/harto/plugins/sample/config.yml" <<'EOF'
name: sample
description: A sample plugin
commands:
  - name: run
    description: Run
    entrypoint: commands/run.sh
hooks:
  complete: hooks/complete.sh
EOF
  run "$(harto_bin)" --non-interactive completion query -- 2 sample run ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
