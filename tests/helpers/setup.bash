#!/usr/bin/env bash
# Shared bats setup. Isolates HOME, XDG directories, and system commands.

harto_test_root() {
  local dir="$BATS_TEST_DIRNAME"
  while [ "$dir" != "/" ]; do
    if [ -f "${dir}/VERSION" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

harto_test_isolate() {
  local root yq_bin bin_dir
  root=$(harto_test_root)
  export HARTO_ROOT="$root"
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME"
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
  export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
  unset HARTO_CONFIG_DIR HARTO_STATE_DIR HARTO_DATA_DIR
  unset HARTO_LINK_NAME
  export HARTO_STUB_LOG="${BATS_TEST_TMPDIR}/stub.log"
  : > "$HARTO_STUB_LOG"
  export HARTO_STUB_FAKE_ROOT="${BATS_TEST_TMPDIR}/fakeroot"
  mkdir -p "$HARTO_STUB_FAKE_ROOT"
  yq_bin=$(command -v yq)
  bin_dir="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "$bin_dir"
  cat > "${bin_dir}/yq" <<EOF
#!/usr/bin/env bash
exec "${yq_bin}" "\$@"
EOF
  chmod +x "${bin_dir}/yq"
  export PATH="${root}/tests/helpers/stubs:${bin_dir}:/usr/bin:/bin"
}

harto_bin() {
  printf '%s/bin/harto\n' "$HARTO_ROOT"
}

harto_devhost_env() {
  local domain="${1:-local.test}"
  export HARTO_YES=1
  export HARTO_DEVHOST_DOMAIN="$domain"
  export HARTO_DEVHOST_DNS="${HARTO_DEVHOST_DNS:-dnsmasq}"
  export HARTO_DEVHOST_HTTPS="${HARTO_DEVHOST_HTTPS:-mkcert}"
  export HARTO_DEVHOST_AUTOSTART="${HARTO_DEVHOST_AUTOSTART:-no}"
  export HARTO_DEVHOST_ADMIN="${HARTO_DEVHOST_ADMIN:-127.0.0.1:2019}"
  export HARTO_DEVHOST_PROXY="${HARTO_DEVHOST_PROXY:-caddy}"
}
