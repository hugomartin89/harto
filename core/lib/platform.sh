#!/usr/bin/env bash

harto_platform_os() {
  uname -s | tr '[:upper:]' '[:lower:]'
}

harto_platform_arch() {
  uname -m
}

harto_platform_is_darwin() {
  [ "$(harto_platform_os)" = "darwin" ]
}

harto_platform_require() {
  if harto_platform_is_darwin; then
    return 0
  fi
  harto_die "unsupported operating system: $(harto_platform_os). HARTO supports macOS only." 1
}
