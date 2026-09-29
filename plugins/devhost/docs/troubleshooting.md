# devhost troubleshooting

`harto devhost doctor` is read-only. Start there. Framework problems (Homebrew, yq, upgrades) are in [the framework troubleshooting guide](../../../docs/troubleshooting.md).

## setup stops on a missing command

A missing Caddy or dnsmasq line means that command is not on `PATH`. Install it from [dependencies.md](dependencies.md). Setup does not write configuration in that case. If you chose HTTPS and mkcert is missing, setup stops the same way.

## A route is configured but not applied

`applied=no` means the Caddy admin API did not contain the host. The proxy is stopped, the reload failed, or the admin address is wrong. `harto devhost status` shows `proxy_admin=unreachable` in that case. Start it with `harto devhost up`. `responding=no` means the target or the proxied request did not answer. That is separate from the route file.

## DNS does not resolve

devhost only writes `/etc/resolver/<domain>` after a yes answer, and only in `dnsmasq` mode. `harto devhost doctor` prints `resolver=missing` when that file is absent. A `none` DNS mode leaves resolution to you. Changing the base domain leaves the old resolver file until you confirm its removal.

## HTTPS is not trusted

The certificate file can exist before the authority is in the macOS trust store. Setup asks to run `mkcert -install`. If that was declined, run setup again and accept it, or run `mkcert -install` yourself. Removing the authority later is `mkcert -uninstall`, which uninstall does not run.

## Logs

`harto devhost logs` tails the Caddy error log under the devhost data directory. It exits with an error when that file does not exist yet.
