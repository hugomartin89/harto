# devhost security

Framework rules for privileges, `eval`, and config writes are in [the framework security guide](../../../docs/security.md). This page is what devhost itself changes.

## Defaults

- Proxy listeners use `bind 127.0.0.1`.
- The Caddy admin listener suggestion is `127.0.0.1:2019`.
- dnsmasq listens on `127.0.0.1` port 53.
- A route target must be an HTTP origin. Non-loopback targets need confirmation.
- A failed proxy reload restores the last file that validated and loaded.

## Privileged writes

devhost asks before each `sudo`:

- creating `/etc/resolver` and writing or removing the per-domain resolver file
- installing `/Library/LaunchDaemons/harto.devhost.caddy.plist` and `/Library/LaunchDaemons/harto.devhost.dnsmasq.plist`
- loading, starting, and stopping those system services
- removing those plists

Caddy runs as root because ports 80 and 443 are reserved. dnsmasq runs as root because port 53 is reserved. Both listen on `127.0.0.1` only. Their own state directory is `/var/root`, not the user home. The Caddyfile, certificates, and dnsmasq config stay in the devhost data directory. The admin API remains on the loopback address chosen at setup. A local process that can reach it can change the proxy configuration.

## Certificate authority

`mkcert -install` adds a local authority to the macOS trust store. Setup states that, names the undo command `mkcert -uninstall`, and waits for a yes. Consent is recorded so later setup runs do not prompt again.

Uninstall does not remove that authority. It asks before deleting the certificate files it generated and before deleting the resolver file.
