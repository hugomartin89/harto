#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load '../../../tests/helpers/setup'

setup_file() {
  harto_test_prepare
  export HARTO_YES=1
  export HARTO_RDS_REGION=us-east-1
  export HARTO_RDS_READ_USER=reader
  export HARTO_RDS_WRITE_USER=writer
  "$(harto_bin)" plugin enable rds
  "$(harto_bin)" rds add app --engine mysql --profile readonly --reader db.example.test --writer writer.example.test
}

setup() {
  harto_test_isolate
  export HARTO_YES=1
  export HARTO_RDS_REGION=us-east-1
  export HARTO_RDS_READ_USER=reader
  export HARTO_RDS_WRITE_USER=writer
  harto_test_apply_prepared
  : > "$HARTO_STUB_LOG"
}

@test "token copies the token and does not print it" {
  run "$(harto_bin)" rds token app
  [ "$status" -eq 0 ]
  [[ "$output" == *"15 minutes"* ]]
  [[ "$output" != *"stub-db-auth-token"* ]]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"pbcopy"* ]]
  [[ "$output" == *"stub-db-auth-token"* ]]
  [[ "$output" == *"--hostname db.example.test"* ]]
  [[ "$output" == *"--username reader"* ]]
}

@test "token --print writes the token to stdout" {
  run --separate-stderr "$(harto_bin)" rds token app --print
  [ "$status" -eq 0 ]
  [ "$output" = "stub-db-auth-token" ]
}

@test "dry-run token does not call aws" {
  run "$(harto_bin)" --dry-run rds token app
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" != *"generate-db-auth-token"* ]]
}

@test "token --write uses the writer host and write user" {
  run "$(harto_bin)" rds token app --write
  [ "$status" -eq 0 ]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"--hostname writer.example.test"* ]]
  [[ "$output" == *"--username writer"* ]]
}

@test "token --write fails when the database has no writer host" {
  "$(harto_bin)" rds add read --engine mysql --profile readonly --reader db.example.test
  run "$(harto_bin)" rds token read --write
  [ "$status" -eq 1 ]
  [[ "$output" == *"no writer host"* ]]
}

@test "an expired SSO session exits 3 and names the login command" {
  HARTO_STUB_AWS_SSO=expired
  export HARTO_STUB_AWS_SSO
  run "$(harto_bin)" rds token app
  [ "$status" -eq 3 ]
  [[ "$output" == *"aws sso login --profile readonly"* ]]
}

@test "list --json returns the catalog without the token" {
  run --separate-stderr "$(harto_bin)" --json rds list
  [ "$status" -eq 0 ]
  [[ "$output" != *"stub-db-auth-token"* ]]
  [[ "$output" != *"db.example.test"* ]]
  printf '%s\n' "$output" > "${BATS_TEST_TMPDIR}/list.json"
  run "${BATS_TEST_TMPDIR}/bin/yq" eval -p=json -oy '.[0].name' "${BATS_TEST_TMPDIR}/list.json"
  [ "$output" = "app" ]
  run "${BATS_TEST_TMPDIR}/bin/yq" eval -p=json -oy '.[0].writer' "${BATS_TEST_TMPDIR}/list.json"
  [ "$output" = "yes" ]
}

@test "connect runs mysql with the CA bundle and does not print the token" {
  printf 'bundle\n' > "${XDG_DATA_HOME}/harto/plugins/rds/global-bundle.pem"
  run "$(harto_bin)" rds connect app --database appdb
  [ "$status" -eq 0 ]
  [[ "$output" != *"stub-db-auth-token"* ]]
  run cat "$HARTO_STUB_LOG"
  [[ "$output" == *"mysql --protocol=TCP --host=db.example.test"* ]]
  [[ "$output" == *"--ssl-ca=${XDG_DATA_HOME}/harto/plugins/rds/global-bundle.pem"* ]]
  [[ "$output" == *"mysql_pwd_set=yes"* ]]
  [[ "$output" != *"MYSQL_PWD="* ]]
}

@test "completion lists catalog names and engines, not tokens" {
  run "$(harto_bin)" --non-interactive completion query -- 2 rds remove ""
  [ "$status" -eq 0 ]
  [ "$output" = "app" ]

  run "$(harto_bin)" --non-interactive completion query -- 2 rds token ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"app"* ]]
  [[ "$output" == *"--write"* ]]
  [[ "$output" == *"--print"* ]]
  [[ "$output" != *"stub-db-auth-token"* ]]
  [[ "$output" != *"db.example.test"* ]]

  run "$(harto_bin)" --non-interactive completion query -- 4 rds add app --engine ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"mysql"* ]]
  [[ "$output" == *"postgres"* ]]

  HARTO_STUB_AWS_PROFILES=$'readonly\npersonal'
  export HARTO_STUB_AWS_PROFILES
  run "$(harto_bin)" --non-interactive completion query -- 4 rds add app --profile ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"readonly"* ]]
  [[ "$output" == *"personal"* ]]
}

@test "completion does not create the catalog" {
  rm -f "${XDG_CONFIG_HOME}/harto/plugins/rds/databases.yml"
  run "$(harto_bin)" --non-interactive completion query -- 2 rds remove ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "${XDG_CONFIG_HOME}/harto/plugins/rds/databases.yml" ]
}
