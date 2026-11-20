# localenv

localenv keeps environment variables per project and environment, for example `blog` with `local` and `ci`. The project index is a plain INI file. Each project has its own directory and file, encrypted by default with a key kept in the macOS Keychain. The store is not part of this repository.

Framework behavior is documented in the repository [docs/](../../docs/architecture.md). This directory documents only localenv.

## Start

```bash
harto plugin enable localenv
cd ~/src/blog
harto localenv init blog
harto localenv set local PORT 3000
harto localenv start local
```

`harto plugin enable localenv` runs `harto localenv setup`, which creates the plain project index and the Keychain key. `init` then creates that project's file, encrypted unless `--plain` is given.

## Commands

```text
harto localenv setup
harto localenv init <name> [--plain|--encrypt]
harto localenv set [--project NAME] <env> <var> <value>
harto localenv get [--project NAME] <env> <var>
harto localenv unset [--project NAME] <env> <var>
harto localenv import [--project NAME] <env> <file>
harto localenv start [--project NAME] <env>
harto localenv exec [--project NAME] <env> <command> [args...]
harto localenv which [--project NAME]
harto localenv list [--project NAME]
harto localenv show [--project NAME] <env>
harto localenv export [--project NAME] <env>
harto localenv remove [--project NAME] <env>
harto localenv remove --project [NAME]
harto localenv doctor
```

External tools and their licenses are in [docs/dependencies.md](docs/dependencies.md). The commands and the store format are in [docs/usage.md](docs/usage.md).

## More

- [Usage](docs/usage.md)
- [Dependencies](docs/dependencies.md)
- [Security](docs/security.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Uninstallation](docs/uninstallation.md)
