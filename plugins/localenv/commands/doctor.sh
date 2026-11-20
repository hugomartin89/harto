#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

[ $# -eq 0 ] || harto_die "usage: ${HARTO_PROG} localenv doctor" 2

harto_dep_check_manifest "${HARTO_PLUGIN_DIR}/plugin.yml" || true

index=$(harto_localenv_index_file)
if [ ! -f "$index" ]; then
  printf 'index=missing\n'
  harto_log_info "localenv is not set up. Run: ${HARTO_PROG} localenv setup"
  exit 0
fi

printf 'index=present\n'
perm=$(stat -f '%Lp' "$index")
printf 'index_mode=%s\n' "$perm"
if [ "$perm" != 600 ]; then
  harto_log_warn "the project index should have mode 600"
fi

if harto_localenv_key_present; then
  printf 'key=present\n'
else
  printf 'key=missing\n'
  harto_log_warn "the localenv key is missing from the Keychain; encrypted projects cannot be read"
fi

harto_localenv_projects | while IFS='=' read -r name path; do
  mode=$(harto_localenv_project_mode "$name")
  if [ -d "$path" ]; then
    dir_status=present
  else
    dir_status=missing
    harto_log_warn "project ${name} points to a directory that does not exist"
  fi
  case "$mode" in
    encrypted)
      readable=no
      enc=$(harto_localenv_project_enc_file "$name")
      if harto_localenv_key_present && ( harto_localenv_decrypt "$enc" >/dev/null ); then
        readable=yes
      else
        harto_log_warn "project ${name} cannot be decrypted"
      fi
      printf 'project=%s mode=encrypted readable=%s status=%s\n' "$name" "$readable" "$dir_status"
      ;;
    plain)
      file=$(harto_localenv_project_plain_file "$name")
      file_mode=$(stat -f '%Lp' "$file")
      printf 'project=%s mode=plain readable=yes file_mode=%s status=%s\n' "$name" "$file_mode" "$dir_status"
      if [ "$file_mode" != 600 ]; then
        harto_log_warn "the environment file for ${name} should have mode 600"
      fi
      ;;
    none)
      printf 'project=%s mode=none readable=no status=%s\n' "$name" "$dir_status"
      harto_log_warn "project ${name} has no environment file"
      ;;
  esac
done

here=$(harto_localenv_project_for_cwd)
printf 'current_project=%s\n' "${here:-none}"
