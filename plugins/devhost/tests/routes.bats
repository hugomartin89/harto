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

@test "add derives the host from the configured base domain" {
  run "$(harto_bin)" devhost add app --port 8080
  [ "$status" -eq 0 ]
  run "$(harto_bin)" devhost add api --target http://127.0.0.1:3000
  [ "$status" -eq 0 ]
  HARTO_STUB_ADMIN_BODY='{}'
  export HARTO_STUB_ADMIN_BODY
  run "$(harto_bin)" devhost list
  [[ "$output" == *"name=app host=app.local.test target=http://127.0.0.1:8080 configured=yes applied=no responding=no"* ]]
  [[ "$output" == *"name=api host=api.local.test target=http://127.0.0.1:3000 configured=yes applied=no responding=no"* ]]
}

@test "list reports an applied and responding route only when checks succeed" {
  "$(harto_bin)" devhost add app --port 8080
  HARTO_STUB_ADMIN_BODY='app.local.test'
  HARTO_STUB_CURL_TARGET=0
  HARTO_STUB_CURL_RESOLVE=0
  export HARTO_STUB_ADMIN_BODY HARTO_STUB_CURL_TARGET HARTO_STUB_CURL_RESOLVE
  run "$(harto_bin)" devhost list
  [[ "$output" == *"applied=yes responding=yes"* ]]
}

@test "remove drops the route" {
  "$(harto_bin)" devhost add app --port 8080
  run "$(harto_bin)" devhost remove app
  [ "$status" -eq 0 ]
  run "$(harto_bin)" devhost list
  [[ "$output" == *"no routes"* ]]
}

@test "an invalid proxy configuration does not replace the previous routes" {
  "$(harto_bin)" devhost add app --port 8080
  HARTO_STUB_CADDY_VALIDATE=1
  export HARTO_STUB_CADDY_VALIDATE
  run "$(harto_bin)" devhost add bad --port 9
  [ "$status" -ne 0 ]
  [[ "$output" == *"restored"* ]]
  run "$(harto_bin)" devhost list
  [[ "$output" == *"name=app "* ]]
  [[ "$output" != *"name=bad "* ]]
}

@test "changing the base domain rewrites route hosts" {
  "$(harto_bin)" devhost add app --port 8080
  run "$(harto_bin)" devhost config set domain dev.test
  [ "$status" -eq 0 ]
  run "$(harto_bin)" devhost list
  [[ "$output" == *"host=app.dev.test"* ]]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval '.base_domain' "${XDG_CONFIG_HOME}/harto/plugins/devhost/config.yml"
  [ "$output" = "dev.test" ]
}

@test "a non-loopback target requires confirmation" {
  unset HARTO_YES
  run "$(harto_bin)" devhost add app --target http://10.0.0.8:8080 <<'EOF'
n
EOF
  [ "$status" -ne 0 ]
  run "$(harto_bin)" devhost list
  [[ "$output" == *"no routes"* ]]
}

@test "generated proxy configuration binds to loopback" {
  "$(harto_bin)" devhost add app --port 8080
  run cat "${XDG_DATA_HOME}/harto/plugins/devhost/caddy/Caddyfile"
  [[ "$output" == *"bind 127.0.0.1"* ]]
  [[ "$output" == *"app.local.test"* ]]
  [[ "$output" != *"0.0.0.0"* ]]
}

@test "completion lists route names without probing them" {
  "$(harto_bin)" devhost add app --port 8080
  : > "$HARTO_STUB_LOG"
  run "$(harto_bin)" --non-interactive completion query -- 2 devhost remove ""
  [ "$status" -eq 0 ]
  [ "$output" = "app" ]
  if grep -q curl "$HARTO_STUB_LOG"; then
    false
  fi

  run "$(harto_bin)" --non-interactive completion query -- 2 devhost add ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"app"* ]]
  [[ "$output" == *"--port"* ]]
  [[ "$output" == *"--target"* ]]

  run "$(harto_bin)" --non-interactive completion query -- 2 devhost config ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"show"* ]]
  [[ "$output" == *"set"* ]]

  run "$(harto_bin)" --non-interactive completion query -- 3 devhost config set ""
  [ "$status" -eq 0 ]
  [ "$output" = "domain" ]
}

@test "completion does not create the routes file" {
  rm -f "${XDG_CONFIG_HOME}/harto/plugins/devhost/routes.yml"
  run "$(harto_bin)" --non-interactive completion query -- 2 devhost remove ""
  [ "$status" -eq 0 ]
  [ ! -e "${XDG_CONFIG_HOME}/harto/plugins/devhost/routes.yml" ]
}
