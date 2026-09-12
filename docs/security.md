# Security

Harto runs as the user who invoked it. Privileged work goes through `harto_run_privileged`, which prints the file or directory it will change, prints the single command, and asks before `sudo`. `--yes` answers the question. `--dry-run` prints the command and does not run it.

A plugin decides which privileged operations it offers. Those operations are documented with the plugin.

## Rules

- Names used in paths and YAML are restricted to letters, digits, and hyphens. Config keys may also contain underscores.
- Plugin entry points cannot be absolute and cannot contain `..`.
- Configuration values are passed to `yq` with `strenv`. Commands are not built with `eval`.
- Important writes use a temporary file in the same directory, then `rename`.
- Uninstall removes the plugin's registered state. It does not delete other plugins' directories or programs the plugin did not create. The plugin's own uninstall hook decides which of its generated files to remove, and it asks first.

## What not to commit

Do not commit `.harto-denylist`, real certificates, or a copy of `~/.config/harto`. The repository check `scripts/check-generic.sh` rejects email addresses and domain names outside the documented allowlist.
