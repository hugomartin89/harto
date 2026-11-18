# Architecture

HARTO is a Bash program. `bin/harto` resolves symlinks back to this repository and then hands off to `core/cli.sh`. The invoked file name is used only in usage text. Configuration paths come from XDG variables, not from that name.

## Layout

```text
bin/harto                  entrypoint
core/cli.sh                dispatch only
core/commands/*.sh         one core command per file
core/lib/*.sh              shared infrastructure
plugins/<name>/            one removable plugin
  plugin.yml
  README.md
  docs/
  commands/<cmd>.sh
  lib/
  templates/ migrations/ tests/
scripts/                   lint, test, and repository checks
tests/                     core tests and shared stubs
docs/                      framework documentation
```

`bin/harto` loads `core/lib` through `core/lib/bootstrap.sh`, in a fixed order.

## Adding something

- A core command is a new file in `core/commands/`. The first summary line is `# harto-summary: ...`. Do not edit `core/cli.sh`.
- A plugin command is a new file in `plugins/<name>/commands/` and one entry in that plugin's `plugin.yml`.
- A plugin is a new directory with a valid manifest and its own `README.md`. There is no central list of plugins.
- A replaceable external tool belongs to the plugin, as its own file with a small set of functions. Do not add a provider registry for a single implementation.

## Boundaries

`core/` does not name a plugin and does not source `plugins/`. A plugin sources `$HARTO_LIB` and its own files. Plugin commands run in a separate `bash` process. The process receives:

- `HARTO_ROOT`
- `HARTO_VERSION`
- `HARTO_PROG`
- `HARTO_LIB`
- `HARTO_PLUGIN_DIR`
- `HARTO_PLUGIN_CONFIG_DIR`
- `HARTO_PLUGIN_STATE_DIR`
- `HARTO_PLUGIN_DATA_DIR`
- `HARTO_CONFIG_DIR`, `HARTO_STATE_DIR`, `HARTO_DATA_DIR`
- `HARTO_YES`, `HARTO_DRY_RUN`, `HARTO_DEBUG`
- `HARTO_NONINTERACTIVE`, `HARTO_OUTPUT` (`text` or `json`)
- `HARTO_INVOCATION`, the command line after global flags, used in messages

Public shell functions use the `harto_` prefix. The manifest contract is [plugin-development.md](plugin-development.md).
