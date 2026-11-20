# Plugin development

A plugin is a directory named with `^[a-z][a-z0-9-]*$` and a `config.yml` file. HARTO reads bundled plugins from `plugins/` and user plugins from `$HARTO_DATA_DIR/plugins`. A bundled plugin wins when both exist.

## Manifest

```yaml
name: example
description: One sentence
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
    usage: "<name> [--force]"
    privileged: false
    json: false
hooks:
  install: hooks/install.sh
  configure: commands/run.sh
  doctor: commands/doctor.sh
  upgrade: hooks/upgrade.sh
  uninstall: hooks/uninstall.sh
```

Entry points and hooks are relative paths inside the plugin directory. `..` and absolute paths are rejected. A command entry point must exist.

`usage`, `privileged`, and `json` are optional. `usage` is the argument text shown after the command name in help. `privileged: true` means the command can reach `harto_run_privileged`. `json: true` means the command honors `--json`. HARTO rejects `--json` for a command that does not declare it. `privileged` and `json` must be booleans. All three appear in `harto help --json`.

`required: true` dependencies are checked by `harto plugin enable` and must also be checked by the plugin's setup command. A missing required dependency stops the command before it writes configuration or records the plugin as active. Optional dependencies are warnings.

`harto plugin enable <name>` is for a plugin that already lives in `plugins/` in this repository. If that plugin is not active yet, enable records it and then runs its `setup` command. `harto plugin disable <name>` runs the uninstall hook and removes the plugin from the active state. `harto plugin install <git-url>` is reserved for cloning a plugin from a git repository. That command is not available yet.

## Lifecycle

| Hook | When it runs |
| --- | --- |
| install | `harto plugin enable`, after dependency checks and before setup |
| configure | the plugin's own setup command |
| doctor | `harto plugin doctor` and `harto doctor` |
| upgrade | `harto plugin upgrade` and `harto upgrade`, after a clean fast-forward |
| uninstall | `harto plugin disable` |

Migrations live in `migrations/NNNN-description.sh`. HARTO runs each one once, records the numeric id in state, and backs up the plugin config directory first. A migration is idempotent. The plugin is recorded as active after enable finishes, and before setup runs.

## Completion

`complete` is an optional hook. It does not run during enable, disable, doctor, or upgrade. `harto completion bash` and `harto completion zsh` print the script a shell loads once. That script calls `harto completion query` and filters the candidates by the prefix the person has typed.

```yaml
hooks:
  complete: hooks/complete.sh
```

HARTO runs the hook when the cursor is past the plugin subcommand:

```bash
hooks/complete.sh <index> <word>...
```

`index` is the cursor, starting at 0, in that word list. The list is the command line after the program name, including leading global flags: `--yes`, `-y`, `--dry-run`, `--debug`, `--non-interactive`, and `--json`. `harto_completion_command_index` prints the index of the first word that is not one of those flags.

Print one candidate per line on stdout. A candidate is a single shell word. Print every candidate for that cursor position. Exit 0 and print nothing when there is nothing to add, including when a lookup fails. Do not write files, prompt, or print secret values.

## Command process

Start a command with:

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$HARTO_PLUGIN_DIR/lib/common.sh"
```

`common.sh` loads `$HARTO_LIB/bootstrap.sh` when the core functions are not already defined. Do not source another plugin. Do not `eval` configuration. Call `harto_run_privileged` for the one command that needs `sudo`, and tell the user which file changes.

Use `harto_atomic_write` for config files. Use `--dry-run` (`HARTO_DRY_RUN=1`) on anything that changes the system, and do not claim the change happened.

Ask for input only through `harto_prompt` and `harto_confirm`, so `--non-interactive` can stop instead of waiting. Pass `harto_prompt` a third argument that names the variable or option that answers it. A `json: true` command checks `harto_output_is_json` and pipes its `key=value` output through `harto_output_records`. [agents.md](agents.md) is the caller's side of that contract.

## Discovery

`harto help` and `harto plugin list` read the manifest. Adding a command does not require a change under `core/`.

## Documentation

`docs/` describes the framework. A plugin documents itself in `plugins/<name>/README.md` and, when that is not enough, in `plugins/<name>/docs/`. Do not add a plugin's tools, commands, or system changes to the framework docs.
