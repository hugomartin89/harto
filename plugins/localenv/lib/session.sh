#!/usr/bin/env bash

# The shell started by `start` defines a harto function. A child process cannot
# change its parent, so set, unset, and import of the active environment ask
# that function to load the store again.

_harto_localenv_session_body() {
  cat <<'EOF'
harto() {
  command harto "$@"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    return "$rc"
  fi
  if [ -z "${HARTO_LOCALENV_ENV-}" ]; then
    return 0
  fi
  if _harto_localenv_wants_reload "$@"; then
    _harto_localenv_reload || return $?
  fi
}

_harto_localenv_wants_reload() {
  local arg phase=0
  for arg in "$@"; do
    if [ "$phase" -eq 0 ]; then
      case "$arg" in
        --yes|--dry-run|--debug|--non-interactive|--json|-y|--) continue ;;
        localenv) phase=1 ;;
        *) return 1 ;;
      esac
      continue
    fi
    case "$arg" in
      --yes|--dry-run|--debug|--non-interactive|--json|-y|--) continue ;;
      set|unset|import) return 0 ;;
      *) return 1 ;;
    esac
  done
  return 1
}

_harto_localenv_reload() {
  local new new_keys old_keys key
  new=$(command harto localenv export --project "$HARTO_LOCALENV_PROJECT" "$HARTO_LOCALENV_ENV") || return $?
  new_keys=$(printf '%s\n' "$new" | sed -n 's/^export \([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p')
  old_keys=${HARTO_LOCALENV_KEYS-}
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    case "
${new_keys}
" in
      *"
${key}
"*) ;;
      *) unset "$key" ;;
    esac
  done <<END_KEYS
${old_keys}
END_KEYS
  if [ -n "$new" ]; then
    eval "$new"
  fi
  HARTO_LOCALENV_KEYS=$new_keys
}
EOF
}

harto_localenv_start_shell() {
  local project="$1"
  local envname="$2"
  local shell base rc dir

  shell="${SHELL:-/bin/bash}"
  [ -n "$shell" ] || shell=/bin/bash
  export HARTO_LOCALENV_PROJECT="$project"
  export HARTO_LOCALENV_ENV="$envname"
  base=$(basename "$shell")
  case "$base" in
    bash)
      rc=$(mktemp "${TMPDIR:-/tmp}/harto-localenv.XXXXXX")
      {
        printf '%s\n' 'if [ -f "$HOME/.bashrc" ]; then'
        printf '%s\n' '  . "$HOME/.bashrc"'
        printf '%s\n' 'fi'
        _harto_localenv_session_body
        printf '%s\n' '_harto_localenv_reload'
        printf 'rm -f %q\n' "$rc"
      } > "$rc"
      harto_log_info "starting ${shell} with ${project}.${envname}. set and unset apply in this shell. Exit the shell to leave."
      harto_localenv_exec "$project" "$envname" "$shell" --rcfile "$rc" -i
      ;;
    zsh)
      dir=$(mktemp -d "${TMPDIR:-/tmp}/harto-localenv.XXXXXX")
      # .zshenv runs before /etc/zshrc. Restore ZDOTDIR first so that file
      # keeps session data in the user's directory, then define the function.
      {
        printf '%s\n' '_harto_tmp=$ZDOTDIR'
        printf '%s\n' 'if [ -n "${HARTO_LOCALENV_OLD_ZDOTDIR-}" ]; then'
        printf '%s\n' '  ZDOTDIR=$HARTO_LOCALENV_OLD_ZDOTDIR'
        printf '%s\n' 'else'
        printf '%s\n' '  unset ZDOTDIR'
        printf '%s\n' 'fi'
        printf '%s\n' '_harto_src=${ZDOTDIR:-$HOME}'
        printf '%s\n' 'if [ -f "$_harto_src/.zshenv" ]; then'
        printf '%s\n' '  . "$_harto_src/.zshenv"'
        printf '%s\n' 'fi'
        _harto_localenv_session_body
        printf '%s\n' '_harto_localenv_reload'
        printf '%s\n' 'if [ -n "${HARTO_LOCALENV_OLD_ZDOTDIR-}" ]; then'
        printf '%s\n' '  ZDOTDIR=$HARTO_LOCALENV_OLD_ZDOTDIR'
        printf '%s\n' 'else'
        printf '%s\n' '  unset ZDOTDIR'
        printf '%s\n' 'fi'
        printf '%s\n' '_harto_localenv_cleanup() { rm -rf "$_harto_tmp"; }'
        printf '%s\n' 'zshexit_functions+=(_harto_localenv_cleanup)'
        printf '%s\n' 'unset _harto_src'
      } > "${dir}/.zshenv"
      export HARTO_LOCALENV_OLD_ZDOTDIR="${ZDOTDIR-}"
      export ZDOTDIR="$dir"
      harto_log_info "starting ${shell} with ${project}.${envname}. set and unset apply in this shell. Exit the shell to leave."
      harto_localenv_exec "$project" "$envname" "$shell" -i
      ;;
    *)
      harto_log_warn "set and unset update the stored file only. This shell does not reload them."
      harto_log_info "starting ${shell} with ${project}.${envname}. Exit the shell to leave."
      harto_localenv_exec "$project" "$envname" "$shell" -i
      ;;
  esac
}
