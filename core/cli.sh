#!/usr/bin/env bash
# Dispatch a command. This file does not implement commands.

harto_cli_main() {
  local args=()

  HARTO_LIB="$HARTO_ROOT/core/lib"
  export HARTO_LIB

  # shellcheck source=lib/bootstrap.sh
  . "$HARTO_LIB/bootstrap.sh"

  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y)
        HARTO_YES=1
        ;;
      --dry-run)
        HARTO_DRY_RUN=1
        ;;
      --debug)
        HARTO_DEBUG=1
        ;;
      --non-interactive)
        HARTO_NONINTERACTIVE=1
        ;;
      --json)
        HARTO_OUTPUT=json
        ;;
      --)
        shift
        while [ $# -gt 0 ]; do
          args+=("$1")
          shift
        done
        break
        ;;
      *)
        args+=("$1")
        ;;
    esac
    shift
  done

  export HARTO_YES="${HARTO_YES:-0}"
  export HARTO_DRY_RUN="${HARTO_DRY_RUN:-0}"
  export HARTO_DEBUG="${HARTO_DEBUG:-0}"
  export HARTO_NONINTERACTIVE="${HARTO_NONINTERACTIVE:-0}"
  export HARTO_OUTPUT="${HARTO_OUTPUT:-text}"

  if [ "${#args[@]}" -eq 0 ]; then
    set --
    HARTO_INVOCATION=""
  else
    set -- "${args[@]}"
    HARTO_INVOCATION=$(printf '%q ' "$@")
    HARTO_INVOCATION="${HARTO_INVOCATION% }"
  fi
  export HARTO_INVOCATION

  harto_config_init
  harto_platform_require

  local cmd="help"
  if [ $# -gt 0 ]; then
    cmd="$1"
    shift
  fi

  case "$cmd" in
    -h|--help) cmd="help" ;;
  esac

  case "$cmd" in
    *[!a-z0-9-]*)
      harto_die "unknown command: ${cmd}" 2
      ;;
  esac

  if [ -f "$HARTO_ROOT/core/commands/${cmd}.sh" ]; then
    if harto_output_is_json && [ "$(harto_command_output "$HARTO_ROOT/core/commands/${cmd}.sh")" != "json" ]; then
      harto_die "${cmd} does not support --json" 2
    fi
    # shellcheck source=/dev/null
    . "$HARTO_ROOT/core/commands/${cmd}.sh"
    "harto_cmd_${cmd}" "$@"
    return
  fi

  if harto_plugin_dir "$cmd" >/dev/null 2>&1; then
    harto_plugin_dispatch "$cmd" "$@"
    return
  fi

  harto_die "unknown command: ${cmd}" 2
}
