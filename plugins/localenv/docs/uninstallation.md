# Uninstall localenv

```bash
harto plugin disable localenv
harto --dry-run plugin disable localenv
```

`--dry-run` names the config directory it would remove and, when the key exists, says it would ask about the Keychain. It does not delete either. How the framework forgets a plugin is described in [the framework uninstall guide](../../../docs/uninstallation.md).

Disable removes the localenv config directory: `projects.ini` and every project directory. It then asks whether to delete the `harto-localenv` Keychain item. Declining keeps the key. Without that item, an `env.ini.enc` file cannot be read, so keep the key only while a backup of an encrypted project still matters. A project stored with `--plain` does not need the key.

Disable does not remove:

- `/usr/bin/security` or `/usr/bin/openssl`
- other plugins' directories
- the plugin source under `plugins/localenv`
