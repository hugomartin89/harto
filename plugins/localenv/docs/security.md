# localenv security

Framework rules for privileges, `eval`, and config writes are in [the framework security guide](../../../docs/security.md). This page is what localenv itself stores.

localenv does not call `sudo`.

## Files

The store is under the plugin config directory. See [configuration.md](../../../docs/configuration.md) for where that directory is. localenv keeps the config directory and each project directory at mode `0700`. `projects.ini`, `env.ini`, and `env.ini.enc` are mode `0600`.

`projects.ini` is always plain text. It holds project names and directories, not variable values. Each project has one environment file:

- `<name>/env.ini.enc` by default
- `<name>/env.ini` when that project was created or converted with `init --plain`

A project has one of those files, not both. The plain file is readable by anything that can read the config directory. The encrypted file is AES-256-CBC with PBKDF2. The key is not a passphrase you type, and it is not passed to `openssl` as an argument.

## Keychain

The key is one generic password in the login Keychain:

- service: `harto-localenv`
- account: the current user name

`setup` creates it when it is missing: 32 random bytes, stored as hex. Later commands read it back. The first read can ask macOS for permission to use the Keychain.

A backup of the config directory includes `env.ini.enc` and does not include this item. Copy the item yourself if the backup has to be read on another Mac. A project created with `--plain` has no key to copy.

## What encryption does not cover

Encryption protects the project file on disk and in a backup. It does not protect a value once a command prints it. `get`, `show`, `export`, and `start` write values in the clear. A process running as the same user can also read the Keychain, so it can read an encrypted project.

`list` and `which` read only `projects.ini`. They do not need the key and do not print variable values.
