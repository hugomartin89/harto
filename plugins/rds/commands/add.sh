#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=/dev/null
. "$HARTO_PLUGIN_DIR/lib/common.sh"

name=""
engine=""
profile=""
reader=""
writer=""
writer_set=0

while [ $# -gt 0 ]; do
  case "$1" in
    --engine)
      [ $# -ge 2 ] || harto_die "--engine needs a value" 2
      engine="$2"
      shift 2
      ;;
    --profile)
      [ $# -ge 2 ] || harto_die "--profile needs a value" 2
      profile="$2"
      shift 2
      ;;
    --reader)
      [ $# -ge 2 ] || harto_die "--reader needs a value" 2
      reader="$2"
      shift 2
      ;;
    --writer)
      [ $# -ge 2 ] || harto_die "--writer needs a value" 2
      writer="$2"
      writer_set=1
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      harto_die "unknown option: ${1}" 2
      ;;
    *)
      [ -z "$name" ] || harto_die "unexpected argument: ${1}" 2
      name="$1"
      shift
      ;;
  esac
done

[ $# -eq 0 ] || harto_die "unexpected arguments" 2
[ -n "$name" ] || harto_die "usage: ${HARTO_PROG} rds add <name> --engine mysql|postgres --profile PROFILE --reader HOST [--writer HOST]" 2
harto_rds_require_config

if [ -z "$engine" ]; then
  if [ -n "${HARTO_RDS_ENGINE+x}" ]; then
    engine=$HARTO_RDS_ENGINE
  else
    engine=$(harto_prompt "Database engine: mysql or postgres" "" HARTO_RDS_ENGINE)
  fi
fi
if [ -z "$profile" ]; then
  if [ -n "${HARTO_RDS_PROFILE+x}" ]; then
    profile=$HARTO_RDS_PROFILE
  else
    profile=$(harto_prompt "AWS profile" "" HARTO_RDS_PROFILE)
  fi
fi
if [ -z "$reader" ]; then
  if [ -n "${HARTO_RDS_READER+x}" ]; then
    reader=$HARTO_RDS_READER
  else
    reader=$(harto_prompt "Reader host" "" HARTO_RDS_READER)
  fi
fi
if [ "$writer_set" -eq 0 ]; then
  if [ -n "${HARTO_RDS_WRITER+x}" ]; then
    writer=$HARTO_RDS_WRITER
  elif [ "${HARTO_YES:-0}" = "1" ] || harto_is_noninteractive; then
    writer=""
  else
    writer=$(harto_prompt "Writer host (empty to skip)" "" HARTO_RDS_WRITER)
  fi
fi

harto_rds_add_database "$name" "$engine" "$profile" "$reader" "$writer"
