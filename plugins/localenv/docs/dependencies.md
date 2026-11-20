# localenv dependencies

localenv does not ship these programs. Both are part of macOS. The MIT license on HARTO does not cover them.

| Tool | Required | License | Where it is |
| --- | --- | --- | --- |
| security | yes | part of macOS | `/usr/bin/security` |
| openssl | yes | LibreSSL, part of macOS | `/usr/bin/openssl` |

`openssl` is the command on `PATH`. macOS provides LibreSSL at `/usr/bin/openssl`. Another `openssl` earlier on `PATH` is used instead when it accepts `enc -aes-256-cbc -pbkdf2`.

`harto plugin enable localenv` checks both commands before it writes the project index or the Keychain item. A missing command prints the install hint from the plugin manifest and stops. localenv does not install packages.

`harto localenv doctor` reports the same gap and exits 0.

Homebrew and yq are requirements of HARTO itself. See [the framework dependencies](../../../docs/dependencies.md).
