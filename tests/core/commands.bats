#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  harto_test_isolate
}

@test "version prints the project name and VERSION file" {
  run "$(harto_bin)" version
  [ "$status" -eq 0 ]
  [ "$output" = "harto 0.3.0" ]
}

@test "unknown command exits 2" {
  run "$(harto_bin)" nosuch
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown command: nosuch"* ]]
}

@test "unexpected arguments are rejected" {
  run "$(harto_bin)" version extra
  [ "$status" -eq 2 ]
}

@test "help lists core and plugin commands" {
  run "$(harto_bin)" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: harto "* ]]
  [[ "$output" == *"devhost setup"* ]]
  [[ "$output" == *"plugin"* ]]
}

@test "help uses the invoked executable name" {
  ln -s "$(harto_bin)" "${BATS_TEST_TMPDIR}/devx"
  run "${BATS_TEST_TMPDIR}/devx" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: devx "* ]]
}

@test "version is the same through a devx symlink" {
  ln -s "$(harto_bin)" "${BATS_TEST_TMPDIR}/devx"
  run "$(harto_bin)" version
  local first="$output"
  run "${BATS_TEST_TMPDIR}/devx" version
  [ "$output" = "$first" ]
}

@test "plugin list is the same through a devx symlink" {
  ln -s "$(harto_bin)" "${BATS_TEST_TMPDIR}/devx"
  run "$(harto_bin)" plugin list
  local first="$output"
  run "${BATS_TEST_TMPDIR}/devx" plugin list
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
  [[ "$output" == *"devhost"* ]]
}

@test "unsupported operating systems are rejected" {
  mkdir -p "${BATS_TEST_TMPDIR}/uname-bin"
  cat > "${BATS_TEST_TMPDIR}/uname-bin/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'x86_64\n' ;;
  *) printf 'Linux\n' ;;
esac
EOF
  chmod +x "${BATS_TEST_TMPDIR}/uname-bin/uname"
  PATH="${BATS_TEST_TMPDIR}/uname-bin:${PATH}"
  run "$(harto_bin)" version
  [ "$status" -ne 0 ]
  [[ "$output" == *"macOS only"* ]]
}
