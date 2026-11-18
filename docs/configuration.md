# Configuration

HARTO keeps user state out of the git checkout and out of the projects it serves.

| Kind | Default |
| --- | --- |
| Core and plugin configuration | `${XDG_CONFIG_HOME:-~/.config}/harto` |
| Versions, migrations, logs | `${XDG_STATE_HOME:-~/.local/state}/harto` |
| Generated files and backups | `${XDG_DATA_HOME:-~/.local/share}/harto` |

Each plugin uses `plugins/<name>/` under those directories. Removing one plugin does not remove another's directory. What a plugin stores there is described in that plugin's documentation.

`HARTO_CONFIG_DIR`, `HARTO_STATE_DIR`, and `HARTO_DATA_DIR` override the defaults. Tests set them. The path does not change when the executable is named `harto` or something else.

## Files

- `config.yml` in the config directory is the core file.
- `state.yml` records `core_version` and, per plugin, `version`, `installed_at`, and `migrations`.

An unreadable YAML file is left in place. HARTO reports the path and stops instead of overwriting it.

## Backups

Before a migration, HARTO copies that plugin's config directory into `backups/` under the data directory.

To save a copy yourself:

```bash
tar -czf harto-config.tar.gz -C "${XDG_CONFIG_HOME:-$HOME/.config}" harto
tar -czf harto-data.tar.gz -C "${XDG_DATA_HOME:-$HOME/.local/share}" harto
```

## Locks

Config writers take a directory lock under the state directory so two HARTO processes do not edit the same file together.
