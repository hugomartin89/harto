#!/usr/bin/env bash

harto_rds_sso_expired() {
  local err="$1"
  grep -Eiq 'sso|expired' "$err"
}

harto_rds_auth_token() {
  local profile="$1"
  local region="$2"
  local host="$3"
  local port="$4"
  local user="$5"
  local err token status

  err=$(mktemp)
  status=0
  token=$(aws rds generate-db-auth-token \
    --profile "$profile" \
    --region "$region" \
    --hostname "$host" \
    --port "$port" \
    --username "$user" 2>"$err") || status=$?
  if [ "$status" -ne 0 ]; then
    if harto_rds_sso_expired "$err"; then
      rm -f "$err"
      harto_die "the AWS SSO session for profile ${profile} is not usable. Run it without --non-interactive: aws sso login --profile ${profile}" 3
    fi
    harto_log_error "$(cat "$err")"
    rm -f "$err"
    harto_die "could not generate a database auth token" 1
  fi
  rm -f "$err"
  token=$(printf '%s' "$token" | tr -d '\n')
  [ -n "$token" ] || harto_die "could not generate a database auth token" 1
  printf '%s' "$token"
}

harto_rds_copy_token() {
  local token="$1"

  if ! command -v pbcopy >/dev/null 2>&1; then
    harto_die "pbcopy is not available. Re-run with --print" 1
  fi
  printf '%s' "$token" | pbcopy
  harto_log_info "token copied. It expires in 15 minutes."
}

harto_rds_connect_client() {
  local engine="$1"
  local host="$2"
  local port="$3"
  local user="$4"
  local token="$5"
  local database="$6"
  local ca args conn

  ca=$(harto_rds_ca_file)
  if [ ! -f "$ca" ]; then
    harto_die "RDS CA bundle is missing. Download it with: curl -fsSL -o ${ca} $(harto_rds_ca_url)" 1
  fi

  case "$engine" in
    mysql)
      command -v mysql >/dev/null 2>&1 || harto_die "mysql is not installed" 1
      args=(
        --protocol=TCP
        --host="$host"
        --port="$port"
        --user="$user"
        --enable-cleartext-plugin
        --ssl-mode=VERIFY_IDENTITY
        --ssl-ca="$ca"
      )
      if [ -n "$database" ]; then
        args+=(--database="$database")
      fi
      MYSQL_PWD="$token" mysql "${args[@]}"
      ;;
    postgres)
      command -v psql >/dev/null 2>&1 || harto_die "psql is not installed" 1
      conn="host=${host} port=${port} user=${user} sslmode=verify-full sslrootcert=${ca}"
      if [ -n "$database" ]; then
        conn="${conn} dbname=${database}"
      fi
      PGPASSWORD="$token" psql "$conn"
      ;;
    *)
      harto_die "engine must be mysql or postgres" 1
      ;;
  esac
}
