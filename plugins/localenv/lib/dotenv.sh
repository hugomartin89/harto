#!/usr/bin/env bash

# Reads a .env file as text. Values are not expanded and nothing in the file
# is executed. Prints KEY=VALUE lines. Exits 2 on a line that is not a
# comment, a blank, or NAME=value.

harto_localenv_parse_env_file() {
  local file="$1"

  [ -f "$file" ] || harto_die "env file not found: ${file}" 1
  awk '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    {
      line = $0
      sub(/\r$/, "", line)
      body = trim(line)
      if (body == "" || substr(body, 1, 1) == "#") next
      if (substr(body, 1, 7) == "export ") body = trim(substr(body, 8))
      i = index(body, "=")
      if (i < 2) {
        printf "line %d: expected NAME=value\n", NR > "/dev/stderr"
        exit 2
      }
      key = trim(substr(body, 1, i - 1))
      if (key !~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
        printf "line %d: invalid variable name\n", NR > "/dev/stderr"
        exit 2
      }
      val = substr(body, i + 1)
      n = length(val)
      q = substr(val, 1, 1)
      if ((q == "\"" || q == "'\''") && n >= 2 && substr(val, n, 1) == q) {
        val = substr(val, 2, n - 2)
      } else {
        sub(/^[ \t]+/, "", val)
        sub(/[ \t]+$/, "", val)
      }
      printf "%s=%s\n", key, val
    }
  ' "$file"
}

# Applies KEY=VALUE lines from stdin to PROJECT.ENV. Runs under the lock.
harto_localenv_import_locked() {
  local project="$1"
  local envname="$2"
  local mode doc new line key val count=0

  mode=$(harto_localenv_project_mode "$project")
  [ "$mode" != none ] || harto_die "project ${project} has no environment file. Run: ${HARTO_PROG} localenv init ${project}" 1
  doc=$(harto_localenv_project_load "$project") || exit $?
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$line" ] || continue
    key=${line%%=*}
    val=${line#*=}
    new=$(printf '%s\n' "$doc" | harto_localenv_ini set-var "$envname" "$key" "$val")
    doc=$new
    count=$((count + 1))
  done
  [ "$count" -gt 0 ] || return 0
  printf '%s\n' "$doc" | harto_localenv_project_write "$project" "$mode"
}
