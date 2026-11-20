#!/usr/bin/env bash
# harto-summary: Print a shell completion script

harto_cmd_completion() {
  local sub="${1:-}"

  case "$sub" in
    bash)
      _harto_completion_script_bash
      ;;
    zsh)
      _harto_completion_script_zsh
      ;;
    query)
      shift
      _harto_completion_query "$@"
      ;;
    *)
      harto_die "usage: ${HARTO_PROG} completion bash|zsh" 2
      ;;
  esac
}

harto_complete_completion() {
  local idx="$1"
  shift
  local -a words=()
  local cmd_at sub_at

  if [ "$#" -gt 0 ]; then
    words=("$@")
  fi
  cmd_at=$(harto_completion_command_index "${words[@]+"${words[@]}"}") || return 0
  sub_at=$((cmd_at + 1))
  [ "$idx" -eq "$sub_at" ] || return 0
  printf '%s\n' bash
  printf '%s\n' zsh
}

_harto_completion_query() {
  local idx="${1-}"
  local cur="" cmd_at cmd file

  case "$idx" in
    ""|*[!0-9]*)
      harto_die "usage: ${HARTO_PROG} completion bash|zsh" 2
      ;;
  esac
  shift

  HARTO_NONINTERACTIVE=1
  export HARTO_NONINTERACTIVE

  local -a words=()
  if [ "$#" -gt 0 ]; then
    words=("$@")
  fi
  if [ "$idx" -lt ${#words[@]} ]; then
    cur="${words[$idx]}"
  fi

  if [ "${#words[@]}" -eq 0 ]; then
    cmd_at=0
  elif ! cmd_at=$(harto_completion_command_index "${words[@]}"); then
    cmd_at=${#words[@]}
  fi

  if [ "$idx" -lt "$cmd_at" ]; then
    _harto_completion_global_flags
    return 0
  fi

  if [ "$idx" -eq "$cmd_at" ]; then
    case "$cur" in
      -*) _harto_completion_global_flags ;;
      *) _harto_completion_commands ;;
    esac
    return 0
  fi

  cmd=${words[$cmd_at]}
  case "$cmd" in
    *[!a-z0-9-]*) ;;
    *)
      file="$HARTO_ROOT/core/commands/${cmd}.sh"
      if [ -f "$file" ]; then
        if ! declare -F "harto_complete_${cmd}" >/dev/null 2>&1; then
          # shellcheck source=/dev/null
          . "$file"
        fi
        if declare -F "harto_complete_${cmd}" >/dev/null 2>&1; then
          "harto_complete_${cmd}" "$idx" "${words[@]}" || true
        fi
      elif harto_plugin_dir "$cmd" >/dev/null 2>&1; then
        _harto_completion_plugin "$cmd" "$idx" "$cmd_at" "${words[@]}"
      fi
      ;;
  esac

  case "$cur" in
    -*) _harto_completion_global_flags ;;
  esac
}

_harto_completion_global_flags() {
  harto_completion_candidate --yes "Accept the suggested answer"
  harto_completion_candidate -y "Accept the suggested answer"
  harto_completion_candidate --dry-run "Report the change without applying it"
  harto_completion_candidate --debug "Print debug messages"
  harto_completion_candidate --non-interactive "Never wait for input"
  harto_completion_candidate --json "Print JSON instead of text"
}

_harto_completion_commands() {
  local file name dir seen description

  for file in "$HARTO_ROOT/core/commands"/*.sh; do
    [ -f "$file" ] || continue
    name=$(basename "$file" .sh)
    description=$(harto_plugin_summary "$file")
    harto_completion_candidate "$name" "$description"
  done

  seen=" "
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    name=$(basename "$dir")
    case "$seen" in
      *" ${name} "*) continue ;;
    esac
    seen="${seen}${name} "
    harto_completion_candidate "$name" "$(harto_plugin_description "$name")"
  done <<EOF
$(harto_plugin_each_dir)
EOF
}

_harto_completion_plugin() {
  local name="$1"
  local idx="$2"
  local cmd_at="$3"
  local sub_at

  shift 3
  sub_at=$((cmd_at + 1))
  if [ "$idx" -le "$sub_at" ]; then
    _harto_completion_plugin_commands "$name"
    return 0
  fi
  _harto_completion_plugin_hook "$name" "$idx" "$@"
}

_harto_completion_plugin_commands() {
  local name="$1"
  local manifest record line kind
  local cname _entry _usage _utag _ptag _jtag _pval _jval desc

  manifest=$(harto_plugin_manifest "$name") || return 0
  record=$(harto_plugin_record_for "$manifest") || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    kind=${line%%$'\037'*}
    [ "$kind" = command ] || continue
    IFS=$'\037' read -r kind cname _entry _usage _utag _ptag _jtag _pval _jval desc <<EOF
$line
EOF
    [ -n "$cname" ] || continue
    harto_completion_candidate "$cname" "$desc"
  done <<EOF
$record
EOF
}

_harto_completion_plugin_hook() {
  local name="$1"
  local idx="$2"
  local manifest dir hook output line

  shift 2
  manifest=$(harto_plugin_manifest "$name") || return 0
  hook=$(harto_plugin_hook_path "$manifest" complete) || return 0
  [ -n "$hook" ] || return 0
  harto_plugin_path_safe "$hook" || return 0
  dir=$(harto_plugin_dir "$name") || return 0
  [ -f "${dir}/${hook}" ] || return 0
  if ! output=$(harto_plugin_run "$name" "$hook" "$idx" "$@" 2>/dev/null); then
    return 0
  fi
  [ -n "$output" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    printf '%s\n' "$line"
  done <<EOF
$output
EOF
}

_harto_completion_script_bash() {
  printf '# Load with: source <(%s completion bash)\n' "$HARTO_PROG"
  cat <<'EOF'
_harto_completion() {
  local idx cur out noglob plain
  local -a words
  words=()
  if [ "${#COMP_WORDS[@]}" -gt 1 ]; then
    words=("${COMP_WORDS[@]:1}")
  fi
  idx=$((COMP_CWORD - 1))
  [ "$idx" -ge 0 ] || return 0
  while [ "${#words[@]}" -le "$idx" ]; do
    words[${#words[@]}]=""
  done
  cur=${words[$idx]}
  out=$(command "${COMP_WORDS[0]}" --non-interactive completion query -- "$idx" "${words[@]}" 2>/dev/null) || return 0
  plain=$(printf '%s\n' "$out" | awk -F '\t' 'NF { print $1 }')
  case $- in
    *f*) noglob=1 ;;
    *) noglob=0; set -f ;;
  esac
  local IFS=$'\n'
  COMPREPLY=( $(compgen -W "$plain" -- "$cur") )
  [ "$noglob" -eq 1 ] || set +f
}
EOF
  printf 'complete -o default -F _harto_completion -- %q\n' "$HARTO_PROG"
}

_harto_completion_script_zsh() {
  printf '# Load with: source <(%s completion zsh)\n' "$HARTO_PROG"
  printf '# The shell needs: autoload -Uz compinit && compinit\n'
  cat <<'EOF'
_harto_completion() {
  emulate -L zsh
  local idx out item word desc
  local -a rest candidates matches descs
  idx=$((CURRENT - 2))
  (( idx < 0 )) && return 0
  rest=("${words[@]:1}")
  if (( idx >= ${#rest[@]} )); then
    rest+=("")
  fi
  out="$(command "${words[1]}" --non-interactive completion query -- "$idx" "${rest[@]}" 2>/dev/null)" || return 0
  candidates=("${(f)out}")
  matches=()
  descs=()
  for item in "${candidates[@]}"; do
    [[ -n "$item" ]] || continue
    word=${item%%$'\t'*}
    if [[ "$item" == *$'\t'* ]]; then
      desc=${item#*$'\t'}
    else
      desc=
    fi
    matches+=("$word")
    descs+=("$desc")
  done
  if (( ${#matches[@]} == 0 )); then
    (( $+functions[_files] )) && _files
    return 0
  fi
  compadd -d descs -- "${matches[@]}"
}
EOF
  printf 'if (( $+functions[compdef] )); then\n  compdef _harto_completion %q\nfi\n' "$HARTO_PROG"
}
