#!/usr/bin/env bats

load '../../../tests/helpers/setup'
bats_require_minimum_version 1.5.0

setup_file() {
  harto_test_prepare_devhost
}

setup() {
  harto_test_isolate
  harto_devhost_env
  harto_test_apply_prepared
}

@test "setup succeeds when the proxy is not running and says how to start it" {
  rm -f "${XDG_DATA_HOME}/harto/plugins/devhost/caddy/Caddyfile.last-good"
  HARTO_STUB_CURL_ADMIN=7
  export HARTO_STUB_CURL_ADMIN
  run "$(harto_bin)" devhost setup
  [ "$status" -eq 0 ]
  [[ "$output" == *"proxy is not running"* ]]
  [[ "$output" == *"devhost up"* ]]
  [ -f "${XDG_DATA_HOME}/harto/plugins/devhost/caddy/Caddyfile" ]
  [ ! -f "${XDG_DATA_HOME}/harto/plugins/devhost/caddy/Caddyfile.last-good" ]
}

@test "a resolver write still asks before using its own input" {
  rm -f "${HARTO_STUB_FAKE_ROOT}/etc/resolver/local.test"
  unset HARTO_YES
  run "$(harto_bin)" devhost setup <<'EOF'
y
y
y
y
y
y
y
y
y
y
EOF
  [ "$status" -eq 0 ]
  [ -f "${HARTO_STUB_FAKE_ROOT}/etc/resolver/local.test" ]
  [[ "$output" != *"privileged operation declined"* ]]
}

@test "setup writes a per-domain resolver through the privileged helper" {
  [ -f "${HARTO_STUB_FAKE_ROOT}/etc/resolver/local.test" ]
  run cat "${HARTO_STUB_FAKE_ROOT}/etc/resolver/local.test"
  [[ "$output" == *"nameserver 127.0.0.1"* ]]
  [[ "$output" != *"5353"* ]]
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
  run plutil -lint "${HARTO_STUB_FAKE_ROOT}/Library/LaunchDaemons/harto.devhost.caddy.plist"
  [ "$status" -eq 0 ]
  run cat "${HARTO_STUB_FAKE_ROOT}/Library/LaunchDaemons/harto.devhost.caddy.plist"
  [[ "$output" == *"harto.devhost.caddy"* ]]
  [[ "$output" == *"/var/root"* ]]
  [[ "$output" != *"0.0.0.0"* ]]
  [ ! -f "${HOME}/Library/LaunchAgents/harto.devhost.caddy.plist" ]
  run plutil -lint "${HARTO_STUB_FAKE_ROOT}/Library/LaunchDaemons/harto.devhost.dnsmasq.plist"
  [ "$status" -eq 0 ]
  run cat "${HARTO_STUB_FAKE_ROOT}/Library/LaunchDaemons/harto.devhost.dnsmasq.plist"
  [[ "$output" == *"--conf-file="* ]]
  [[ "$output" != *"<string>--conf-file</string>"* ]]
  [ ! -f "${HOME}/Library/LaunchAgents/harto.devhost.dnsmasq.plist" ]
  run cat "${XDG_DATA_HOME}/harto/plugins/devhost/dnsmasq/dnsmasq.conf"
  [[ "$output" == *"port=53"* ]]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"sudo install -m 644"* ]]
  [[ "$output" == *"/Library/LaunchDaemons/harto.devhost.caddy.plist"* ]]
}

@test "status reports a loaded service as stopped when its process is not running" {
  HARTO_STUB_LAUNCHCTL_STATE="spawn scheduled"
  export HARTO_STUB_LAUNCHCTL_STATE
  run "$(harto_bin)" devhost status
  [ "$status" -eq 0 ]
  [[ "$output" == *"harto.devhost.caddy=stopped"* ]]
  [[ "$output" == *"harto.devhost.dnsmasq=stopped"* ]]
}

@test "a privileged port refusal tells you to start the system service" {
  HARTO_STUB_CADDY_RELOAD=1
  HARTO_STUB_CADDY_RELOAD_MSG="listen tcp 127.0.0.1:443: bind: permission denied"
  export HARTO_STUB_CADDY_RELOAD HARTO_STUB_CADDY_RELOAD_MSG
  run "$(harto_bin)" devhost add app --port 8080
  [ "$status" -ne 0 ]
  [[ "$output" == *"devhost up"* ]]
  [[ "$output" == *"restored"* ]]
}

@test "dry-run disable keeps generated files and does not remove the authority" {
  run "$(harto_bin)" --dry-run plugin disable devhost
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [ -f "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml" ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" != *"mkcert -uninstall"* ]]
}

@test "disable removes devhost files and leaves unrelated data" {
  printf 'keep\n' > "${XDG_DATA_HOME}/harto/shared.txt"
  run "$(harto_bin)" --yes plugin disable devhost
  [ "$status" -eq 0 ]
  [ ! -f "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml" ]
  [ ! -f "${HOME}/Library/LaunchAgents/harto.devhost.caddy.plist" ]
  [ ! -f "${HARTO_STUB_FAKE_ROOT}/Library/LaunchDaemons/harto.devhost.caddy.plist" ]
  [ ! -f "${HARTO_STUB_FAKE_ROOT}/Library/LaunchDaemons/harto.devhost.dnsmasq.plist" ]
  [ -f "${XDG_DATA_HOME}/harto/shared.txt" ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" != *"mkcert -uninstall"* ]]
}

@test "logs fail clearly when the proxy has not written a log" {
  rm -f "${XDG_DATA_HOME}/harto/plugins/devhost/logs/caddy.err.log"
  run "$(harto_bin)" devhost logs
  [ "$status" -ne 0 ]
  [[ "$output" == *"no proxy log"* ]]
}
