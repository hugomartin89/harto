#!/usr/bin/env bash

harto_engine_report() {
  harto_log_info "a route can target a process already running on this machine"
  if command -v colima >/dev/null 2>&1; then
    harto_log_info "colima: available (recommended on macOS)"
  else
    harto_log_info "colima: not found. Recommended when you want containers: https://github.com/abiosoft/colima"
    harto_log_info "install: brew install colima"
  fi
}
