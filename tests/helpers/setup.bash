#!/usr/bin/env bash
# Shared bats setup. Isolates HOME, XDG directories, and system commands.

harto_test_root() {
  local dir="$BATS_TEST_DIRNAME"
  while [ "$dir" != "/" ]; do
    if [ -f "${dir}/bin/harto" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

harto_test_isolate_at() {
  local base="$1"
  local root yq_bin bin_dir
  root=$(harto_test_root)
  export HARTO_ROOT="$root"
  export HOME="${base}/home"
  mkdir -p "$HOME"
  export XDG_CONFIG_HOME="${base}/config"
  export XDG_STATE_HOME="${base}/state"
  export XDG_DATA_HOME="${base}/data"
  unset HARTO_CONFIG_DIR HARTO_STATE_DIR HARTO_DATA_DIR
  unset HARTO_LINK_NAME
  export HARTO_STUB_LOG="${base}/stub.log"
  : > "$HARTO_STUB_LOG"
  export HARTO_STUB_FAKE_ROOT="${base}/fakeroot"
  mkdir -p "$HARTO_STUB_FAKE_ROOT"
  yq_bin=$(command -v yq)
  bin_dir="${base}/bin"
  mkdir -p "$bin_dir"
  cat > "${bin_dir}/yq" <<EOF
#!/usr/bin/env bash
exec "${yq_bin}" "\$@"
EOF
  chmod +x "${bin_dir}/yq"
  export PATH="${root}/tests/helpers/stubs:${bin_dir}:/usr/bin:/bin"
}

harto_test_isolate() {
  harto_test_isolate_at "$BATS_TEST_TMPDIR"
}

# Build the shared starting state for a file. Tests copy it in setup.
harto_test_prepare() {
  local base="${BATS_FILE_TMPDIR}/prepared"
  rm -rf "$base"
  mkdir -p "$base"
  harto_test_isolate_at "$base"
}

harto_test_prepare_devhost() {
  harto_test_prepare
  harto_devhost_env
  "$(harto_bin)" plugin enable devhost
  "$(harto_bin)" devhost setup
}

harto_test_apply_prepared() {
  local prepared="${BATS_FILE_TMPDIR}/prepared"
  local name

  for name in config state data home fakeroot; do
    [ -d "${prepared}/${name}" ] || continue
    rm -rf "${BATS_TEST_TMPDIR}/${name}"
    cp -R "${prepared}/${name}" "${BATS_TEST_TMPDIR}/${name}"
  done
  if [ -f "${prepared}/stub.log" ]; then
    cp "${prepared}/stub.log" "${BATS_TEST_TMPDIR}/stub.log"
  fi
  if [ -d "${prepared}/keychain" ] && [ -n "${HARTO_STUB_KEYCHAIN:-}" ]; then
    mkdir -p "$HARTO_STUB_KEYCHAIN"
    cp -R "${prepared}/keychain/." "$HARTO_STUB_KEYCHAIN/"
  fi
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
