#!/usr/bin/env bats

load '../helpers/setup'
bats_require_minimum_version 1.5.0

setup() {
  harto_test_isolate
}

catalog() {
  "${BATS_TEST_TMPDIR}/bin/yq" eval -p=json -oy "$1" "${BATS_TEST_TMPDIR}/catalog.json"
}

broken_plugin() {
  mkdir -p "${XDG_DATA_HOME}/harto/plugins/broken/commands"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${XDG_DATA_HOME}/harto/plugins/broken/commands/run.sh"
  cat > "${XDG_DATA_HOME}/harto/plugins/broken/config.yml" <<'EOF'
name: broken
description: privileged is not a boolean
platforms:
  - darwin
commands:
  - name: run
    description: run
    entrypoint: commands/run.sh
    privileged: maybe
EOF
}

@test "help --json describes plugin commands from their manifests" {
  run --separate-stderr "$(harto_bin)" help --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/catalog.json"
  run catalog '.plugins[] | select(.name == "devhost") | .commands[] | select(.name == "add") | .usage'
  [ "$output" = "<name> (--port PORT | --target URL)" ]
  run catalog '.plugins[] | select(.name == "devhost") | .commands[] | select(.name == "up") | .privileged'
  [ "$output" = "true" ]
  run catalog '.plugins[] | select(.name == "devhost") | .commands[] | select(.name == "list") | .json'
  [ "$output" = "true" ]
  run catalog '.core[] | select(.name == "help") | .json'
  [ "$output" = "true" ]
}

@test "help --json leaves out a plugin with an invalid manifest" {
  broken_plugin
  run --separate-stderr "$(harto_bin)" --json help
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/catalog.json"
  run catalog '[.plugins[] | select(.name == "broken")] | length'
  [ "$output" = "0" ]
}

@test "a non-boolean privileged field fails validation" {
  broken_plugin
  run "$(harto_bin)" plugin info broken
  [ "$status" -ne 0 ]
  [[ "$output" == *"invalid privileged"* ]]
}

@test "help shows the usage declared in the manifest" {
  run "$(harto_bin)" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"devhost add <name> (--port PORT | --target URL)"* ]]
}

@test "a core command without json output rejects --json" {
  run "$(harto_bin)" --json doctor
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not support --json"* ]]
}

@test "non-interactive setup stops on a question and names the variable" {
  run "$(harto_bin)" --non-interactive setup
  [ "$status" -eq 2 ]
  [[ "$output" == *"HARTO_LINK_NAME"* ]]
}
