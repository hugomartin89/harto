#!/usr/bin/env bash

harto_version_ge() {
  local left="$1"
  local right="$2"
  local left_parts right_parts i left_n right_n

  left=${left#v}
  right=${right#v}

  IFS='.' read -r -a left_parts <<EOF
$left
EOF
  IFS='.' read -r -a right_parts <<EOF
$right
EOF

  i=0
  while [ "$i" -lt 3 ]; do
    left_n=${left_parts[$i]:-0}
    right_n=${right_parts[$i]:-0}
    left_n=${left_n%%[^0-9]*}
    right_n=${right_n%%[^0-9]*}
    left_n=${left_n:-0}
    right_n=${right_n:-0}
    if [ "$left_n" -gt "$right_n" ]; then
      return 0
    fi
    if [ "$left_n" -lt "$right_n" ]; then
      return 1
    fi
    i=$((i + 1))
  done
  return 0
}

harto_dep_version_text() {
  local command_name="$1"
  local output

  output=$("$command_name" version 2>&1 || true)
  if ! printf '%s\n' "$output" | grep -Eq '[0-9]+\.[0-9]+'; then
    output=$("$command_name" --version 2>&1 || true)
  fi
  printf '%s\n' "$output" | sed -n 's/.*[^0-9]\([0-9][0-9]*\.[0-9][0-9.]*\).*/\1/p' | head -n 1
}

harto_dep_yq_ok() {
  local output version

  command -v yq >/dev/null 2>&1 || return 1
  output=$(yq --version 2>&1 || true)
  case "$output" in
    *mikefarah*) ;;
    *) return 1 ;;
  esac
  version=$(printf '%s\n' "$output" | sed -n 's/.*version v\{0,1\}\([0-9][0-9.]*\).*/\1/p' | head -n 1)
  [ -n "$version" ] || return 1
  harto_version_ge "$version" "4.0.0"
}

harto_dep_print_missing() {
  local name="$1"
  local command_name="$2"
  local min_version="$3"
  local hint="$4"
  local url="$5"

  if [ -n "$min_version" ]; then
    harto_log_error "missing dependency ${name} (${command_name} >= ${min_version})"
  else
    harto_log_error "missing dependency ${name} (${command_name})"
  fi
  if [ -n "$hint" ]; then
    harto_log_error "install: ${hint}"
  fi
  if [ -n "$url" ]; then
    harto_log_error "official source: ${url}"
  fi
}

harto_dep_check_command() {
  local name="$1"
  local command_name="$2"
  local min_version="${3:-}"
  local hint="${4:-}"
  local url="${5:-}"
  local found

  if ! command -v "$command_name" >/dev/null 2>&1; then
    harto_dep_print_missing "$name" "$command_name" "$min_version" "$hint" "$url"
    return 1
  fi

  if [ -z "$min_version" ]; then
    return 0
  fi

  found=$(harto_dep_version_text "$command_name")
  if [ -z "$found" ] || ! harto_version_ge "$found" "$min_version"; then
    harto_log_error "dependency ${name} is older than ${min_version} (found: ${found:-unknown})"
    if [ -n "$hint" ]; then
      harto_log_error "install: ${hint}"
    fi
    if [ -n "$url" ]; then
      harto_log_error "official source: ${url}"
    fi
    return 1
  fi
  return 0
}

harto_dep_check_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  harto_log_error "Homebrew (brew) is not installed."
  harto_log_error "Install Homebrew from the official installer: https://brew.sh"
  harto_log_error "Run the install command published on that page, then open a new terminal."
  return 1
}

harto_dep_check_yq() {
  if harto_dep_yq_ok; then
    return 0
  fi
  harto_log_error "yq (mikefarah) >= 4 is required."
  harto_log_error "install: brew install yq"
  harto_log_error "official source: https://github.com/mikefarah/yq"
  return 1
}

harto_dep_check_core() {
  local failed=0

  harto_dep_check_brew || failed=1
  harto_dep_check_yq || failed=1
  return "$failed"
}

harto_dep_check_manifest() {
  local manifest="$1"
  local count index required name command_name min_version hint url
  local failed=0

  count=$(yq eval '.dependencies // [] | length' "$manifest")
  index=0
  while [ "$index" -lt "$count" ]; do
    required=$(yq eval ".dependencies[${index}].required" "$manifest")
    name=$(yq eval ".dependencies[${index}].name" "$manifest")
    command_name=$(yq eval ".dependencies[${index}].command" "$manifest")
    min_version=$(yq eval ".dependencies[${index}].min_version // \"\"" "$manifest")
    hint=$(yq eval ".dependencies[${index}].install_hint // \"\"" "$manifest")
    url=$(yq eval ".dependencies[${index}].install_hint_url // \"\"" "$manifest")
    if [ "$min_version" = "null" ]; then
      min_version=""
    fi
    if [ "$hint" = "null" ]; then
      hint=""
    fi
    if [ "$url" = "null" ]; then
      url=""
    fi

    if [ "$required" = "true" ]; then
      harto_dep_check_command "$name" "$command_name" "$min_version" "$hint" "$url" || failed=1
    elif ! command -v "$command_name" >/dev/null 2>&1; then
      harto_log_warn "optional dependency not found: ${name} (${command_name})"
      if [ -n "$hint" ]; then
        harto_log_warn "install: ${hint}"
      fi
    fi
    index=$((index + 1))
  done

  return "$failed"
}
