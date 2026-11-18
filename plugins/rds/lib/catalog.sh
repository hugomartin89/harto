#!/usr/bin/env bash

harto_rds_check_region() {
  printf '%s\n' "$1" | grep -Eq '^[a-z][a-z0-9-]*[0-9]$'
}

harto_rds_check_user() {
  printf '%s\n' "$1" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
}

harto_rds_check_profile() {
  printf '%s\n' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_.-]*$'
}

harto_rds_check_host() {
  printf '%s\n' "$1" | grep -Eq '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$'
}

harto_rds_check_database() {
  printf '%s\n' "$1" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$'
}

harto_rds_port() {
  case "$1" in
    mysql) printf '3306\n' ;;
    postgres) printf '5432\n' ;;
    *) return 1 ;;
  esac
}

harto_rds_db_count() {
  local name="$1"
  local file

  file=$(harto_rds_databases_file)
  NAME="$name" yq eval '[.databases // [] | .[] | select(.name == strenv(NAME))] | length' "$file"
}

harto_rds_db_field() {
  local name="$1"
  local field="$2"
  local value

  case "$field" in
    engine|profile|reader|writer) ;;
    *) harto_die "invalid database field: ${field}" 1 ;;
  esac
  value=$(NAME="$name" yq eval ".databases[] | select(.name == strenv(NAME)) | .${field} // \"\"" "$(harto_rds_databases_file)")
  if [ "$value" = "null" ]; then
    value=""
  fi
  printf '%s\n' "$value"
}

harto_rds_require_db() {
  local name="$1"
  harto_rds_require_config
  harto_rds_ensure_databases_file
  harto_valid_name "$name" || harto_die "database name must match ^[a-z][a-z0-9-]*$" 2
  [ "$(harto_rds_db_count "$name")" -eq 1 ] || harto_die "database not found: ${name}" 1
}

harto_rds_add_database() {
  local name="$1"
  local engine="$2"
  local profile="$3"
  local reader="$4"
  local writer="$5"
  local file

  harto_rds_require_config
  harto_rds_ensure_databases_file
  harto_valid_name "$name" || harto_die "database name must match ^[a-z][a-z0-9-]*$" 2
  harto_rds_port "$engine" >/dev/null || harto_die "engine must be mysql or postgres" 2
  harto_rds_check_profile "$profile" || harto_die "invalid AWS profile: ${profile}" 2
  harto_rds_check_host "$reader" || harto_die "invalid reader host: ${reader}" 2
  if [ -n "$writer" ]; then
    harto_rds_check_host "$writer" || harto_die "invalid writer host: ${writer}" 2
  fi
  if [ "$(harto_rds_db_count "$name")" -ne 0 ]; then
    harto_die "database already exists: ${name}" 1
  fi

  if harto_is_dry_run; then
    printf '[dry-run] would add database %s\n' "$name" >&2
    return 0
  fi

  file=$(harto_rds_databases_file)
  harto_with_lock rds-catalog \
    harto_rds_catalog_append "$file" "$name" "$engine" "$profile" "$reader" "$writer"
  harto_log_info "added database ${name}"
}

harto_rds_catalog_append() {
  local file="$1"
  local name="$2"
  local engine="$3"
  local profile="$4"
  local reader="$5"
  local writer="$6"

  NAME="$name" ENGINE="$engine" PROFILE="$profile" READER="$reader" WRITER="$writer" \
    yq eval '
      .databases += [{
        "name": strenv(NAME),
        "engine": strenv(ENGINE),
        "profile": strenv(PROFILE),
        "reader": strenv(READER),
        "writer": strenv(WRITER)
      }]
    ' "$file" | harto_atomic_write "$file"
}

harto_rds_remove_database() {
  local name="$1"
  local file

  harto_rds_require_db "$name"
  if harto_is_dry_run; then
    printf '[dry-run] would remove database %s\n' "$name" >&2
    return 0
  fi
  file=$(harto_rds_databases_file)
  harto_with_lock rds-catalog harto_rds_catalog_delete "$file" "$name"
  harto_log_info "removed database ${name}"
}

harto_rds_catalog_delete() {
  local file="$1"
  local name="$2"

  NAME="$name" yq eval 'del(.databases[] | select(.name == strenv(NAME)))' "$file" \
    | harto_atomic_write "$file"
}

harto_rds_list_databases() {
  local file count index name engine profile writer

  harto_rds_require_config
  harto_rds_ensure_databases_file
  file=$(harto_rds_databases_file)
  count=$(yq eval '.databases // [] | length' "$file")
  if [ "$count" -eq 0 ]; then
    printf 'no databases\n'
    return 0
  fi
  index=0
  while [ "$index" -lt "$count" ]; do
    name=$(yq eval ".databases[${index}].name" "$file")
    engine=$(yq eval ".databases[${index}].engine" "$file")
    profile=$(yq eval ".databases[${index}].profile" "$file")
    writer=$(yq eval ".databases[${index}].writer // \"\"" "$file")
    if [ -n "$writer" ] && [ "$writer" != "null" ]; then
      writer="yes"
    else
      writer="no"
    fi
    printf 'name=%s engine=%s profile=%s writer=%s\n' "$name" "$engine" "$profile" "$writer"
    index=$((index + 1))
  done
}

harto_rds_endpoint() {
  local name="$1"
  local mode="$2"
  local engine host user port

  harto_rds_require_db "$name"
  engine=$(harto_rds_db_field "$name" engine)
  port=$(harto_rds_port "$engine") || harto_die "engine must be mysql or postgres" 1
  if [ "$mode" = "write" ]; then
    host=$(harto_rds_db_field "$name" writer)
    user=$(harto_rds_get write_user)
    if [ -z "$host" ]; then
      harto_die "database ${name} has no writer host" 1
    fi
  else
    host=$(harto_rds_db_field "$name" reader)
    user=$(harto_rds_get read_user)
  fi
  [ -n "$user" ] || harto_die "database user is not configured. Run: ${HARTO_PROG} rds setup" 1
  printf '%s\n' "$host"
  printf '%s\n' "$port"
  printf '%s\n' "$user"
  printf '%s\n' "$(harto_rds_db_field "$name" engine)"
  printf '%s\n' "$(harto_rds_db_field "$name" profile)"
  printf '%s\n' "$(harto_rds_get region)"
}

harto_rds_print_profile() {
  local name="$1"
  local profile region

  harto_rds_require_db "$name"
  profile=$(harto_rds_db_field "$name" profile)
  region=$(harto_rds_get region)
  printf '[profile %s]\n' "$profile"
  printf 'sso_session = <sso-session>\n'
  printf 'sso_account_id = <account-id>\n'
  printf 'sso_role_name = %s\n' "$profile"
  printf 'region = %s\n' "$region"
  harto_log_info "paste this block into the AWS config file. Fill sso_session and sso_account_id from the access portal. This command does not write that file."
}
