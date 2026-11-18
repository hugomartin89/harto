# Uninstallation

## A plugin

```bash
harto plugin disable <name>
harto --dry-run plugin disable <name>
```

`--dry-run` lists what the plugin's uninstall hook would remove and leaves those files in place. The hook is part of the plugin. Which files it deletes, and which questions it asks, are documented in that plugin.

Disable removes the plugin from HARTO's state. It does not delete the plugin source in the git checkout, other plugins' directories, or programs you installed separately.

## The framework

Remove the symlink setup created, `~/.local/bin/harto`, or the other name you chose. Then delete the config, state, and data directories from [configuration.md](configuration.md) after you have uninstalled plugins that own system files. Removing the checkout does not remove `~/.config/harto`.

To drop the commit-message hook:

```bash
git config --unset core.hooksPath
```
