# Plugin development

A plugin is a directory named with `^[a-z][a-z0-9-]*$` and a `plugin.yml` file. HARTO reads bundled plugins from `plugins/` and user plugins from `$HARTO_DATA_DIR/plugins`. A bundled plugin wins when both exist.

## Manifest

```yaml
name: example
version: 0.1.0
description: One sentence
harto:
  min: "0.7.0"
  max: "0.7.0"
platforms:
  - darwin
dependencies:
  - name: yq
    command: yq
    min_version: "4.0.0"
    required: true
    install_hint: brew install yq
    install_hint_url: https://github.com/mikefarah/yq
commands:
  - name: run
    description: Do the thing
    entrypoint: commands/run.sh
hooks:
  install: hooks/install.sh
  configure: commands/run.sh
  doctor: commands/doctor.sh
  upgrade: hooks/upgrade.sh
  uninstall: hooks/uninstall.sh
```

`version`, `harto.min`, and `harto.max` are `MAJOR.MINOR.PATCH`. `max` is inclusive. Entry points and hooks are relative paths inside the plugin directory. `..` and absolute paths are rejected. A command entry point must exist.

`required: true` dependencies are checked by `harto plugin add` and must also be checked by the plugin's setup command. A missing required dependency stops the command before it writes configuration or records the plugin as active. Optional dependencies are warnings.

`harto plugin add <name>` is for a plugin that already lives in `plugins/` in this repository. If that plugin is not active yet, add records it and then runs its `setup` command. `harto plugin install <git-url>` is reserved for cloning a plugin from a git repository. That command is not available yet.

## Lifecycle

| Hook | When it runs |
| --- | --- |
| install | `harto plugin add`, after dependency checks and before setup |
| configure | the plugin's own setup command |
| doctor | `harto plugin doctor` and `harto doctor` |
| upgrade | `harto plugin upgrade` and `harto upgrade`, after a clean fast-forward |
| uninstall | `harto plugin uninstall` |

Migrations live in `migrations/NNNN-description.sh`. HARTO runs each one once, records the numeric id in state, and backs up the plugin config directory first. A migration is idempotent. The active version is recorded only after add or upgrade finishes, and before setup runs.

## Command process

Start a command with:

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$HARTO_PLUGIN_DIR/lib/common.sh"
```

`common.sh` loads `$HARTO_LIB/bootstrap.sh` when the core functions are not already defined. Do not source another plugin. Do not `eval` configuration. Call `harto_run_privileged` for the one command that needs `sudo`, and tell the user which file changes.

Use `harto_atomic_write` for config files. Use `--dry-run` (`HARTO_DRY_RUN=1`) on anything that changes the system, and do not claim the change happened.

## Discovery

`harto help` and `harto plugin list` read the manifest. Adding a command does not require a change under `core/`.

## Documentation

`docs/` describes the framework. A plugin documents itself in `plugins/<name>/README.md` and, when that is not enough, in `plugins/<name>/docs/`. Do not add a plugin's tools, commands, or system changes to the framework docs.
