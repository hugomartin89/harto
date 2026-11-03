#!/usr/bin/env bats

load '../helpers/setup'

setup() {
  harto_test_isolate
  mkdir -p "${BATS_TEST_TMPDIR}/git-bin"
  cat > "${BATS_TEST_TMPDIR}/git-bin/git" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
  case "$1" in
    -C) shift 2 ;;
    *) break ;;
  esac
done
case "${1:-}" in
  rev-parse)
    case "${2:-}" in
      --is-inside-work-tree) exit 0 ;;
      --show-toplevel) printf '/tmp/harto-upgrade\n'; exit 0 ;;
      --abbrev-ref) printf 'origin/main\n'; exit 0 ;;
    esac
    ;;
  status)
    if [ "${HARTO_STUB_GIT_DIRTY:-0}" = "1" ]; then
      printf ' M README.md\n'
    fi
    exit 0
    ;;
  fetch|merge)
    exit "${HARTO_STUB_GIT_STATUS:-0}"
    ;;
esac
exit 0
EOF
  chmod +x "${BATS_TEST_TMPDIR}/git-bin/git"
  export PATH="${BATS_TEST_TMPDIR}/git-bin:${PATH}"
}

@test "upgrade stops when the checkout has local changes" {
  "$(harto_bin)" --yes setup
  HARTO_STUB_GIT_DIRTY=1
  export HARTO_STUB_GIT_DIRTY
  "${BATS_TEST_TMPDIR}/bin/yq" eval '.core_version = "0.0.0"' -i "${XDG_STATE_HOME}/harto/state.yml"
  run "$(harto_bin)" upgrade
  [ "$status" -ne 0 ]
  [[ "$output" == *"local modifications"* ]]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.core_version' "${XDG_STATE_HOME}/harto/state.yml"
  [ "$output" = "0.0.0" ]
}

@test "upgrade records the core version only after a clean fast-forward" {
  HARTO_STUB_GIT_DIRTY=0
  export HARTO_STUB_GIT_DIRTY
  run "$(harto_bin)" upgrade
  [ "$status" -eq 0 ]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.core_version' "${XDG_STATE_HOME}/harto/state.yml"
  [ "$output" = "0.5.0" ]
}

@test "a failed fast-forward does not record the new version" {
  "$(harto_bin)" --yes setup
  "${BATS_TEST_TMPDIR}/bin/yq" eval '.core_version = "0.0.0"' -i "${XDG_STATE_HOME}/harto/state.yml"
  HARTO_STUB_GIT_STATUS=1
  export HARTO_STUB_GIT_STATUS
  run "$(harto_bin)" upgrade
  [ "$status" -ne 0 ]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.core_version' "${XDG_STATE_HOME}/harto/state.yml"
  [ "$output" = "0.0.0" ]
}

@test "dry-run upgrade does not rewrite state" {
  "$(harto_bin)" --yes setup
  run "$(harto_bin)" --dry-run upgrade
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] would fast-forward"* ]]
}
