# devhost

devhost publishes local processes as `<name>.<base-domain>`. You choose the base domain during setup. The plugin does not hard-code a site name.

Framework behavior (install, configuration directories, upgrades) is documented in the repository [docs/](../../docs/architecture.md). This directory documents only devhost.

## Install

```bash
harto plugin install devhost
harto devhost setup
harto devhost add app --port 8080
harto devhost list
```

With base domain `local.test`, that route is `app.local.test`.

External tools and their licenses are in [docs/dependencies.md](docs/dependencies.md). Setup, routes, DNS, HTTPS, and services are in [docs/usage.md](docs/usage.md).

## Commands

```text
harto devhost setup
harto devhost up
harto devhost down
harto devhost add app --port 8080
harto devhost add api --target http://127.0.0.1:3000
harto devhost remove app
harto devhost list
harto devhost status
harto devhost logs
harto devhost doctor
harto devhost config show
harto devhost config set domain dev.test
```

`list` reports three separate facts: the route is configured, the proxy has loaded it, and an HTTP check got a response.

## More

- [Usage](docs/usage.md)
- [Dependencies](docs/dependencies.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Security](docs/security.md)
- [Uninstallation](docs/uninstallation.md)
