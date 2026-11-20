#!/usr/bin/env bash

# Two kinds of file. projects.ini is the project index and is always plain
# text. Each project has its own directory and one INI file, env.ini.enc by
# default or env.ini when the project was created with --plain.

harto_localenv_index_file() {
  printf '%s/projects.ini\n' "$HARTO_PLUGIN_CONFIG_DIR"
}

harto_localenv_project_dir() {
  printf '%s/%s\n' "$HARTO_PLUGIN_CONFIG_DIR" "$1"
}

harto_localenv_project_enc_file() {
  printf '%s/env.ini.enc\n' "$(harto_localenv_project_dir "$1")"
}

harto_localenv_project_plain_file() {
  printf '%s/env.ini\n' "$(harto_localenv_project_dir "$1")"
}

# Prints encrypted, plain, or none. Both files at once is a broken store.
harto_localenv_project_mode() {
  local name="$1"
  local enc plain

  enc=$(harto_localenv_project_enc_file "$name")
  plain=$(harto_localenv_project_plain_file "$name")
  if [ -f "$enc" ] && [ -f "$plain" ]; then
    harto_die "both ${enc} and ${plain} exist. Keep one and move the other aside." 1
  fi
  if [ -f "$enc" ]; then
    printf 'encrypted\n'
  elif [ -f "$plain" ]; then
    printf 'plain\n'
  else
    printf 'none\n'
  fi
}

harto_localenv_check_project() {
  [[ "$1" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]
}

harto_localenv_check_env() {
  [[ "$1" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]]
}

harto_localenv_check_var() {
  [[ "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

harto_localenv_require_index() {
  [ -f "$(harto_localenv_index_file)" ] || harto_die "localenv is not set up. Run: ${HARTO_PROG} localenv setup" 1
}

_harto_localenv_write_raw() {
  local dest="$1"
  local dir

  dir=$(dirname "$dest")
  mkdir -p "$dir"
  chmod 700 "$dir"
  harto_atomic_write "$dest"
  chmod 600 "$dest"
}

harto_localenv_index_load() {
  harto_localenv_require_index
  cat "$(harto_localenv_index_file)"
}

harto_localenv_index_write() {
  mkdir -p "$HARTO_PLUGIN_CONFIG_DIR"
  chmod 700 "$HARTO_PLUGIN_CONFIG_DIR"
  _harto_localenv_write_raw "$(harto_localenv_index_file)"
}

harto_localenv_ensure_index() {
  if [ -f "$(harto_localenv_index_file)" ]; then
    return 0
  fi
  printf '[projects]\n' | harto_localenv_index_write
}

# Prints NAME=PATH for every project. The index is plain, so this does not
# need the Keychain key.
harto_localenv_projects() {
  harto_localenv_index_load | harto_localenv_ini projects
}

harto_localenv_project_path() {
  local name="$1"
  local value

  harto_localenv_require_index
  if ! value=$(harto_localenv_index_load | harto_localenv_ini get projects "$name"); then
    return 1
  fi
  printf '%s\n' "$value"
}

harto_localenv_project_load() {
  local name="$1"
  local mode

  mode=$(harto_localenv_project_mode "$name")
  case "$mode" in
    encrypted) harto_localenv_decrypt "$(harto_localenv_project_enc_file "$name")" ;;
    plain) cat "$(harto_localenv_project_plain_file "$name")" ;;
    *) harto_die "project ${name} has no environment file. Run: ${HARTO_PROG} localenv init ${name}" 1 ;;
  esac
}

# Writes stdin to the project file for MODE, replacing only that mode's file.
harto_localenv_project_write() {
  local name="$1"
  local mode="$2"

  case "$mode" in
    encrypted)
      harto_localenv_key_ensure
      harto_localenv_encrypt | _harto_localenv_write_raw "$(harto_localenv_project_enc_file "$name")"
      ;;
    plain)
      _harto_localenv_write_raw "$(harto_localenv_project_plain_file "$name")"
      ;;
    *) harto_die "unknown project mode: ${mode}" 1 ;;
  esac
}

harto_localenv_project_create() {
  local name="$1"
  local mode="$2"

  printf '' | harto_localenv_project_write "$name" "$mode"
}

harto_localenv_project_convert() {
  local name="$1"
  local mode="$2"
  local doc

  doc=$(harto_localenv_project_load "$name")
  printf '%s\n' "$doc" | harto_localenv_project_write "$name" "$mode"
  if [ "$mode" = plain ]; then
    rm -f "$(harto_localenv_project_enc_file "$name")"
  else
    rm -f "$(harto_localenv_project_plain_file "$name")"
  fi
  harto_log_info "project ${name} is now ${mode}"
}

harto_localenv_ini() {
  local op="$1"
  shift
  OP="$op" SEC="${1-}" KEY="${2-}" VAL="${3-}" awk "$(_harto_localenv_ini_program)"
}

# Creates the plain index and the Keychain key. Does not create a project.
# Runs under the lock.
harto_localenv_configure_locked() {
  local created=0

  if [ ! -f "$(harto_localenv_index_file)" ]; then
    created=1
  fi
  harto_localenv_ensure_index
  harto_localenv_key_ensure
  if [ "$created" -eq 1 ]; then
    harto_log_info "created the localenv project index"
  fi
}

_harto_localenv_index_set() {
  local name="$1"
  local path="$2"
  local doc new

  doc=$(harto_localenv_index_load)
  new=$(printf '%s\n' "$doc" | harto_localenv_ini set-var projects "$name" "$path")
  printf '%s\n' "$new" | harto_localenv_index_write
}

_harto_localenv_index_unset() {
  local name="$1"
  local doc new

  doc=$(harto_localenv_index_load)
  new=$(printf '%s\n' "$doc" | harto_localenv_ini unset-var projects "$name")
  printf '%s\n' "$new" | harto_localenv_index_write
}

# Registers NAME at PATH. REQUESTED is plain, encrypted, or empty. Empty keeps
# the project's current mode, and a new project is encrypted. Runs under the lock.
harto_localenv_init_locked() {
  local name="$1"
  local path="$2"
  local requested="${3:-}"
  local owner existing current target

  harto_localenv_ensure_index
  owner=$(harto_localenv_index_load | harto_localenv_ini owner "$path" || true)
  if [ -n "$owner" ] && [ "$owner" != "$name" ]; then
    harto_die "this directory already belongs to project ${owner}. Remove it first: ${HARTO_PROG} localenv remove --project ${owner}" 1
  fi

  existing=$(harto_localenv_index_load | harto_localenv_ini get projects "$name" || true)
  current=$(harto_localenv_project_mode "$name")
  if [ -n "$requested" ]; then
    target=$requested
  elif [ "$current" != none ]; then
    target=$current
  else
    target=encrypted
  fi

  if [ "$owner" = "$name" ]; then
    if [ "$current" = none ]; then
      harto_localenv_project_create "$name" "$target"
      harto_log_info "created the environment file for ${name} (${target})"
      return 0
    fi
    if [ "$current" != "$target" ]; then
      harto_localenv_project_convert "$name" "$target"
      return 0
    fi
    harto_log_info "project ${name} already points to this directory"
    return 0
  fi

  if [ -n "$existing" ]; then
    harto_confirm "Project ${name} points to ${existing}. Point it to ${path}?" || harto_die "init cancelled" 1
  fi

  _harto_localenv_index_set "$name" "$path"
  if [ "$current" = none ]; then
    harto_localenv_project_create "$name" "$target"
  elif [ "$current" != "$target" ]; then
    harto_localenv_project_convert "$name" "$target"
  fi
  harto_log_info "project ${name} points to ${path} (${target})"
}

# Prints the project whose directory is the current one or one of its parents.
# The longest matching path wins.
harto_localenv_project_for_cwd() {
  local here

  here=$(pwd -P)
  harto_localenv_projects | HERE="$here" awk '
    {
      i = index($0, "=")
      name = substr($0, 1, i - 1)
      path = substr($0, i + 1)
      here = ENVIRON["HERE"]
      if ((here == path || path == "/" || index(here, path "/") == 1) && length(path) > best_len) {
        best = name
        best_len = length(path)
      }
    }
    END { if (best != "") print best }
  '
}

# Prints the project name for an explicit NAME, or for the current directory.
harto_localenv_resolve() {
  local explicit="$1"
  local name

  harto_localenv_require_index
  if [ -n "$explicit" ]; then
    harto_localenv_check_project "$explicit" || harto_die "invalid project name: ${explicit}" 2
    harto_localenv_project_path "$explicit" >/dev/null 2>&1 || harto_die "project not found: ${explicit}" 1
    printf '%s\n' "$explicit"
    return 0
  fi
  name=$(harto_localenv_project_for_cwd)
  [ -n "$name" ] || harto_die "no project for this directory. Run: ${HARTO_PROG} localenv init <name>, or pass --project NAME" 1
  printf '%s\n' "$name"
}

harto_localenv_require_env() {
  local project="$1"
  local envname="$2"
  local doc

  doc=$(harto_localenv_project_load "$project") || exit $?
  printf '%s\n' "$doc" | harto_localenv_ini has-section "$envname" >/dev/null \
    || harto_die "environment not found: ${envname} in project ${project}" 1
}

# Prints the value. Returns 1 when the variable is absent.
harto_localenv_var_get() {
  local project="$1"
  local envname="$2"
  local var="$3"
  local doc

  doc=$(harto_localenv_project_load "$project") || exit $?
  printf '%s\n' "$doc" | harto_localenv_ini get "$envname" "$var"
}

# Prints KEY=VALUE lines for one environment.
harto_localenv_pairs() {
  local project="$1"
  local envname="$2"
  local doc

  doc=$(harto_localenv_project_load "$project") || exit $?
  printf '%s\n' "$doc" | harto_localenv_ini show "$envname"
}

# Prints the environment names of one project, one per line.
harto_localenv_env_names() {
  local project="$1"
  local doc

  doc=$(harto_localenv_project_load "$project") || exit $?
  printf '%s\n' "$doc" | harto_localenv_ini sections
}

harto_localenv_apply_env() {
  local project="$1"
  shift
  harto_with_lock localenv-store harto_localenv_apply_env_locked "$project" "$@"
}

harto_localenv_apply_env_locked() {
  local project="$1"
  shift
  local mode doc new

  mode=$(harto_localenv_project_mode "$project")
  [ "$mode" != none ] || harto_die "project ${project} has no environment file. Run: ${HARTO_PROG} localenv init ${project}" 1
  doc=$(harto_localenv_project_load "$project") || exit $?
  new=$(printf '%s\n' "$doc" | harto_localenv_ini "$@")
  printf '%s\n' "$new" | harto_localenv_project_write "$project" "$mode"
}

# Drops the project from the index and removes its directory. Runs under the lock.
harto_localenv_remove_project_locked() {
  local name="$1"
  local dir

  _harto_localenv_index_unset "$name"
  dir=$(harto_localenv_project_dir "$name")
  case "$dir" in
    "${HARTO_PLUGIN_CONFIG_DIR}/"*) rm -rf "$dir" ;;
    *) harto_die "refusing to remove ${dir}" 1 ;;
  esac
}

# Reads KEY=VALUE lines and prints them as JSON through harto_output_records.
# The shape is "object" or "array". Values with spaces cannot be expressed
# through harto_output_records, so they are refused.
harto_localenv_json() {
  local shape="$1"
  local line key value out=""

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key=${line%%=*}
    value=${line#*=}
    case "$value" in
      *[[:space:]]*) harto_die "${key} has spaces in its value, which --json cannot return. Use text output." 1 ;;
    esac
    out="${out}${line}"$'\n'
  done
  printf '%s' "$out" | harto_output_records "$shape"
}

# Runs argv with the variables of PROJECT.ENV exported, from the project
# directory. Replaces the current process.
harto_localenv_exec() {
  local project="$1"
  local envname="$2"
  local path pairs pair
  local args

  shift 2
  path=$(harto_localenv_project_path "$project") || harto_die "project not found: ${project}" 1
  [ -d "$path" ] || harto_die "project directory does not exist: ${path}" 1
  pairs=$(harto_localenv_pairs "$project" "$envname")
  args=()
  while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    args+=("$pair")
  done <<EOF
$pairs
EOF
  cd "$path" || harto_die "cannot enter ${path}" 1
  exec env ${args[@]+"${args[@]}"} "$@"
}

_harto_localenv_ini_program() {
  cat <<'AWK'
# INI model for localenv. Reads an INI document on stdin and applies the
# operation named by OP. SEC, KEY and VAL come from the environment so awk
# never rewrites backslashes in values.
#
# Read operations:
#   get SEC KEY        value; exit 1 when missing
#   show SEC           KEY=VALUE per variable
#   projects           NAME=PATH from the projects section
#   owner SEC          project name whose path equals SEC; exit 1 when none
#   sections           one section name per line
#   has-section SEC    exit 0 when the section has data
# Edit operations print the whole document:
#   set-var SEC KEY VAL
#   unset-var SEC KEY
#   del-section SEC

function trim(s) {
  sub(/^[ \t]+/, "", s)
  sub(/[ \t]+$/, "", s)
  return s
}

function add(s, k, v) {
  if (!(s in known)) {
    known[s] = 1
    order[++ns] = s
  }
  n++
  S[n] = s
  K[n] = k
  V[n] = v
  D[n] = 0
  return n
}

function find(s, k,    i) {
  for (i = 1; i <= n; i++)
    if (!D[i] && S[i] == s && K[i] == k) return i
  return 0
}

function live(s,    i) {
  for (i = 1; i <= n; i++)
    if (!D[i] && S[i] == s) return 1
  return 0
}

function emit(    j, i, s, first) {
  first = 1
  for (j = 1; j <= ns; j++) {
    s = order[j]
    if (!live(s)) continue
    if (!first) print ""
    first = 0
    print "[" s "]"
    for (i = 1; i <= n; i++)
      if (!D[i] && S[i] == s && K[i] != "") print K[i] " = " V[i]
  }
}

BEGIN {
  OP = ENVIRON["OP"]
  SEC = ENVIRON["SEC"]
  KEY = ENVIRON["KEY"]
  VAL = ENVIRON["VAL"]
  n = 0
  ns = 0
}

{ line = trim($0) }

line == "" || substr(line, 1, 1) == "#" || substr(line, 1, 1) == ";" { next }

line ~ /^\[.*\]$/ {
  cur = substr(line, 2, length(line) - 2)
  if (!(cur in known)) add(cur, "", "")
  next
}

{
  if (cur == "") next
  i = index($0, "=")
  if (i < 2) next
  k = trim(substr($0, 1, i - 1))
  if (k == "") next
  v = substr($0, i + 1)
  if (substr(v, 1, 1) == " ") v = substr(v, 2)
  j = find(cur, k)
  if (j) V[j] = v
  else add(cur, k, v)
}

END {
  if (OP == "get") {
    i = find(SEC, KEY)
    if (!i) exit 1
    print V[i]
    exit 0
  }
  if (OP == "show") {
    for (i = 1; i <= n; i++)
      if (!D[i] && S[i] == SEC && K[i] != "") print K[i] "=" V[i]
    exit 0
  }
  if (OP == "projects") {
    for (i = 1; i <= n; i++)
      if (!D[i] && S[i] == "projects" && K[i] != "") print K[i] "=" V[i]
    exit 0
  }
  if (OP == "owner") {
    for (i = 1; i <= n; i++)
      if (!D[i] && S[i] == "projects" && K[i] != "" && V[i] == SEC) {
        print K[i]
        exit 0
      }
    exit 1
  }
  if (OP == "sections") {
    for (j = 1; j <= ns; j++)
      if (live(order[j]) && order[j] != "") print order[j]
    exit 0
  }
  if (OP == "has-section") exit (live(SEC) ? 0 : 1)
  if (OP == "set-var") {
    i = find(SEC, KEY)
    if (i) V[i] = VAL
    else add(SEC, KEY, VAL)
    emit()
    exit 0
  }
  if (OP == "unset-var") {
    i = find(SEC, KEY)
    if (i) D[i] = 1
    emit()
    exit 0
  }
  if (OP == "del-section") {
    for (i = 1; i <= n; i++)
      if (S[i] == SEC) D[i] = 1
    emit()
    exit 0
  }
  exit 2
}
AWK
}
