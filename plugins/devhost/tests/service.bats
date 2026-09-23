#!/usr/bin/env bats

load '../../../tests/helpers/setup'

setup() {
  harto_test_isolate
  harto_devhost_env
  "$(harto_bin)" plugin install devhost
  "$(harto_bin)" devhost setup
}

@test "setup writes a per-domain resolver through the privileged helper" {
  [ -f "${HARTO_STUB_FAKE_ROOT}/etc/resolver/local.test" ]
  run cat "${HARTO_STUB_FAKE_ROOT}/etc/resolver/local.test"
  [[ "$output" == *"nameserver 127.0.0.1"* ]]
  [[ "$output" == *"port 5353"* ]]
  [[ "$HARTO_STUB_LOG" != "" ]]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"sudo tee /etc/resolver/local.test"* ]]
}

@test "certificate creation is separate from installing the authority" {
  [ -f "${XDG_DATA_HOME}/harto/plugins/devhost/certs/cert.pem" ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"mkcert -install"* ]]
  [[ "$output" == *"mkcert -cert-file"* ]]
}

@test "services can be started and stopped explicitly" {
  run "$(harto_bin)" devhost up
  [ "$status" -eq 0 ]
  run "$(harto_bin)" devhost down
  [ "$status" -eq 0 ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"launchctl bootstrap"* ]]
  [[ "$output" == *"launchctl bootout"* ]]
}

@test "launchd plists are valid and do not listen publicly" {
  run plutil -lint "${HOME}/Library/LaunchAgents/harto.devhost.caddy.plist"
  [ "$status" -eq 0 ]
  run cat "${HOME}/Library/LaunchAgents/harto.devhost.caddy.plist"
  [[ "$output" == *"harto.devhost.caddy"* ]]
  [[ "$output" != *"0.0.0.0"* ]]
}

@test "dry-run uninstall keeps generated files and does not remove the authority" {
  run "$(harto_bin)" --dry-run plugin uninstall devhost
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ -f "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml" ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" != *"mkcert -uninstall"* ]]
}

@test "uninstall removes devhost files and leaves unrelated data" {
  printf 'keep\n' > "${XDG_DATA_HOME}/harto/shared.txt"
  run "$(harto_bin)" --yes plugin uninstall devhost
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml" ]
  [ ! -f "${HOME}/Library/LaunchAgents/harto.devhost.caddy.plist" ]
  [ -f "${XDG_DATA_HOME}/harto/shared.txt" ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" != *"mkcert -uninstall"* ]]
}

@test "logs fail clearly when the proxy has not written a log" {
  run "$(harto_bin)" devhost logs
  [ "$status" -ne 0 ]
  [[ "$output" == *"no proxy log"* ]]
}
