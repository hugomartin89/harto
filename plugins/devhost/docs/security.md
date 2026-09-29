# devhost security

Framework rules for privileges, `eval`, and config writes are in [the framework security guide](../../../docs/security.md). This page is what devhost itself changes.

## Defaults

- Proxy listeners use `bind 127.0.0.1`.
- The Caddy admin listener suggestion is `127.0.0.1:2019`.
- dnsmasq listens on `127.0.0.1` port 5353.
- A route target must be an HTTP origin. Non-loopback targets need confirmation.
- A failed proxy reload restores the last file that validated and loaded.

## Privileged writes

devhost asks before writing `/etc/resolver` and the per-domain resolver file. That is the only `sudo` it uses. LaunchAgents are written under `~/Library/LaunchAgents` and loaded with `launchctl` for the current user.

## Certificate authority

`mkcert -install` adds a local authority to the macOS trust store. Setup states that, names the undo command `mkcert -uninstall`, and waits for a yes. Consent is recorded so later setup runs do not prompt again.

Uninstall does not remove that authority. It asks before deleting the certificate files it generated and before deleting the resolver file.
