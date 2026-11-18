# Using devhost

## Setup

```bash
harto plugin add devhost
```

`harto plugin add devhost` asks the setup questions when devhost is not already active. Run `harto devhost setup` again to change those answers.

Questions, in order:

1. Base domain. Syntax is checked: lowercase, at least two labels, no scheme, port, or path. The `.local` suffix is rejected because it collides with mDNS. A public suffix needs an extra confirmation. `local.test` is a reasonable choice.
2. Reverse proxy. The only implementation is Caddy.
3. Admin address. The suggestion is `127.0.0.1:2019`. Addresses other than loopback are rejected. A busy port stops setup.
4. DNS. `dnsmasq` or `none`.
5. HTTPS. `mkcert` or `off`. Choosing `mkcert` requires the `mkcert` binary.
6. Start at login. The suggestion is no.

Colima is mentioned when it is missing. It is optional. A route can target a process already running on this machine.

Non-interactive answers can be passed in the environment: `HARTO_DEVHOST_DOMAIN`, `HARTO_DEVHOST_PROXY`, `HARTO_DEVHOST_ADMIN`, `HARTO_DEVHOST_DNS`, `HARTO_DEVHOST_HTTPS`, `HARTO_DEVHOST_AUTOSTART`. `--yes` accepts the suggestions, but the domain has no suggestion and must be set.

Running setup again updates generated files and keeps existing routes. If the domain changed, route hosts are rewritten.

## Routes

```bash
harto devhost add app --port 8080
harto devhost add api --target http://127.0.0.1:3000
harto devhost list
harto devhost remove app
```

A route stores `name`, `host`, `target`, `created_at`, and `updated_at` in `plugins/devhost/routes.yml` under the HARTO config directory. `--port` means `http://127.0.0.1:<port>`. A target that is not loopback asks for confirmation.

`list` columns:

- `configured` is yes when the route is in `routes.yml`
- `applied` is yes when the Caddy admin API response contains the host
- `responding` is yes when both the target and the proxied host answer

## Proxy

devhost writes its own Caddyfile under its data directory and reloads Caddy with `caddy reload`. It does not edit Caddy's global configuration. The apply order is render, `caddy validate`, keep the previous file, reload, read the admin API. If reload or the API check fails, the previous file is restored and reloaded.

Every site is `bind 127.0.0.1`.

## DNS

In `dnsmasq` mode, devhost writes a dnsmasq config that answers the base domain and its subdomains with `127.0.0.1` on port 5353. It then asks before writing `/etc/resolver/<domain>`:

```text
nameserver 127.0.0.1
port 5353
```

That write is the privileged step. `/etc/hosts` is not modified.

## HTTPS

Choosing `mkcert` prints that `mkcert -install` adds a local certificate authority to the macOS trust store, then asks. The certificate for the domain and `*.domain` is written under the data directory. Generating the certificate and installing the authority are separate steps. Uninstall does not run `mkcert -uninstall`.

## Services

Setup explains the LaunchAgents and asks before writing them:

- `~/Library/LaunchAgents/harto.devhost.caddy.plist`
- `~/Library/LaunchAgents/harto.devhost.dnsmasq.plist` when DNS is dnsmasq

`RunAtLoad` follows the login answer. `KeepAlive` restarts a service that exits with an error. `harto devhost up` bootstraps them for the current user. `harto devhost down` boots them out. They are not loaded during setup unless you asked for login start.

## Domain change

```bash
harto devhost config set domain dev.test
```

devhost lists the routes, asks, updates hosts, reissues the certificate, rewrites DNS, and reloads the proxy. If apply fails, the previous config directory is restored and the previous proxy file is loaded again. Removing the old `/etc/resolver` file is a separate question.

## Manual macOS check

The test suite does not touch a real resolver or keychain. On a machine where you want that:

1. Install Caddy, dnsmasq, and mkcert from [dependencies.md](dependencies.md).
2. Run `harto devhost setup` and read each privileged prompt.
3. Run `harto devhost up`.
4. Add a route to a local process and open `https://<name>.<domain>`.
5. Run `harto devhost doctor` and confirm `applied=yes` only while Caddy is up.
6. Run `harto devhost down` and, if you want the files gone, `harto plugin uninstall devhost`.
