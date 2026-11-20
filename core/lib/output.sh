#!/usr/bin/env bash

harto_output_is_json() {
  [ "${HARTO_OUTPUT:-text}" = "json" ]
}

harto_output_text_only() {
  local what="$1"
  if harto_output_is_json; then
    harto_die "${what} does not support --json" 2
  fi
}

# One help row: a bold title, a dim detail, then a blank line.
harto_help_entry() {
  local title="$1"
  local detail="$2"

  printf '  %s\n    %s\n\n' "$(harto_paint 1 1 "$title")" "$(harto_paint 1 2 "$detail")"
}

# Reads key=value tokens from stdin. Values must not contain whitespace.
# Lines without a key=value token are skipped. "array" makes one object per
# line; "object" merges every line into one object.
harto_output_records() {
  local shape="${1:-array}"

  awk -v shape="$shape" '
    function esc(s,   out, c, i) {
      out = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (c == "\\" || c == "\"") {
          out = out "\\" c
        } else {
          out = out c
        }
      }
      return out
    }
    BEGIN { body = ""; n = 0 }
    {
      line = ""
      for (f = 1; f <= NF; f++) {
        i = index($f, "=")
        if (i < 2) continue
        pair = "\"" esc(substr($f, 1, i - 1)) "\":\"" esc(substr($f, i + 1)) "\""
        line = line (line == "" ? "" : ",") pair
      }
      if (line == "") next
      if (shape == "object") {
        body = body (body == "" ? "" : ",") line
      } else {
        body = body (n++ ? "," : "") "{" line "}"
      }
    }
    END {
      if (shape == "object") print "{" body "}"
      else print "[" body "]"
    }
  '
}
