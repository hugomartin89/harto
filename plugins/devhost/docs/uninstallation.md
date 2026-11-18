# Uninstall devhost

```bash
harto plugin disable devhost
harto --dry-run plugin disable devhost
```

`--dry-run` lists the files it would remove and leaves them in place. How the framework forgets a plugin is described in [the framework uninstall guide](../../../docs/uninstallation.md).

devhost disable stops its services and removes:

- `/Library/LaunchDaemons/harto.devhost.caddy.plist` (privileged)
- `/Library/LaunchDaemons/harto.devhost.dnsmasq.plist` (privileged)
- `~/Library/LaunchAgents/harto.devhost.caddy.plist` when an older user agent is still present
- `~/Library/LaunchAgents/harto.devhost.dnsmasq.plist` when an older user agent is still present
- the generated Caddyfile, dnsmasq config, and devhost logs
- the devhost config directory, after the questions below

It asks before removing `/etc/resolver/<domain>` and before removing the certificate files it generated. It does not remove:

- the mkcert certificate authority (`mkcert -uninstall` is separate)
- the Caddy, dnsmasq, or Colima programs
- other plugins' directories
- files that sit next to the devhost data directory

The plugin source under `plugins/devhost` stays. It is part of the git checkout.
