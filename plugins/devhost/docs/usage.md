# Using devhost

## Setup

```bash
harto plugin enable devhost
```

`harto plugin enable devhost` asks the setup questions when devhost is not already active. Run `harto devhost setup` again to change those answers.

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

If Caddy is not running yet, setup and `devhost add` still save and validate the file, and they say so. Caddy reads that file when `devhost up` starts it, so `applied` stays `no` until then.

Every site is `bind 127.0.0.1`. HTTPS uses port 443 and plain HTTP uses port 80. macOS only lets a system service bind those ports. A refusal that says `bind: permission denied` means the system service is not the process serving the admin API. Run `harto devhost up` and add the route again.

## DNS

In `dnsmasq` mode, devhost writes a dnsmasq config that answers the base domain and its subdomains with `127.0.0.1` on port 53. It then asks before writing `/etc/resolver/<domain>`:

```text
nameserver 127.0.0.1
```

That write is the privileged step. `/etc/hosts` is not modified. macOS sends those queries to port 53. `harto devhost up` starts dnsmasq and rewrites the resolver file when it still names another port. `harto devhost status` reports dnsmasq running only while that process is up.

## HTTPS

Choosing `mkcert` prints that `mkcert -install` adds a local certificate authority to the macOS trust store, then asks. The certificate for the domain and `*.domain` is written under the data directory. Generating the certificate and installing the authority are separate steps. Uninstall does not run `mkcert -uninstall`.

## Services

Setup explains the services and asks before writing them:

- `/Library/LaunchDaemons/harto.devhost.caddy.plist` — Caddy, as root, on `127.0.0.1` ports 80 and 443
- `/Library/LaunchDaemons/harto.devhost.dnsmasq.plist` when DNS is dnsmasq — dnsmasq, as root, on `127.0.0.1` port 53

Installing, starting, stopping, and removing these daemons are privileged. Each step prints the command and asks before `sudo`. A previous user LaunchAgent is removed so it cannot keep the port.

`RunAtLoad` follows the login answer. With that answer set to yes, Caddy and dnsmasq start at boot. `KeepAlive` restarts a service that exits with an error. `harto devhost up` loads them. `harto devhost down` unloads them. They are not loaded during setup unless you asked to start at login.

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
6. Run `harto devhost down` and, if you want the files gone, `harto plugin disable devhost`.
