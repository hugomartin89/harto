# devhost troubleshooting

`harto devhost doctor` is read-only. Start there. Framework problems (Homebrew, yq, upgrades) are in [the framework troubleshooting guide](../../../docs/troubleshooting.md).

## setup stops on a missing command

A missing Caddy or dnsmasq line means that command is not on `PATH`. Install it from [dependencies.md](dependencies.md). Setup does not write configuration in that case. If you chose HTTPS and mkcert is missing, setup stops the same way.

## The proxy refuses port 80 or 443

`bind: permission denied` on `127.0.0.1:443` or `127.0.0.1:80` means Caddy is still the user LaunchAgent. That agent cannot take those ports. Run `harto devhost up`, accept the system service prompts, then add the route again. `harto devhost status` should show `harto.devhost.caddy=running` after that.

## A route is configured but not applied

`applied=no` means the Caddy admin API did not contain the host. The proxy is stopped, the reload failed, or the admin address is wrong. `harto devhost status` shows `proxy_admin=unreachable` in that case. Start it with `harto devhost up`. `responding=no` means the target or the proxied request did not answer. That is separate from the route file.

## DNS does not resolve

devhost only writes `/etc/resolver/<domain>` after a yes answer, and only in `dnsmasq` mode. `harto devhost doctor` prints `resolver=missing` when that file is absent. A `none` DNS mode leaves resolution to you. Changing the base domain leaves the old resolver file until you confirm its removal.

`harto.devhost.dnsmasq=stopped` means the process is not running, even if launchd still has the job loaded. `harto devhost up` installs the system service and starts it. The resolver file sends the base domain and its subdomains to `127.0.0.1` port 53. A file that still names another port is rewritten by that command.

## A development websocket is rejected

The browser sends `Origin: https://<route-host>` on a websocket. Next.js refuses `/_next` upgrades from a host that is not `localhost` until that host is listed in `allowedDevOrigins` and the dev server is restarted. The proxy has already accepted the upgrade when this happens.

## HTTPS is not trusted

The certificate file can exist before the authority is in the macOS trust store. Setup asks to run `mkcert -install`. If that was declined, run setup again and accept it, or run `mkcert -install` yourself. Removing the authority later is `mkcert -uninstall`, which uninstall does not run.

## Logs

`harto devhost logs` tails the Caddy error log under the devhost data directory. It exits with an error when that file does not exist yet.
