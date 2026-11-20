# localenv troubleshooting

`harto localenv doctor` is read-only. Start there. The lines it prints are in [usage.md](usage.md). Framework problems (Homebrew, yq) are in [the framework troubleshooting guide](../../../docs/troubleshooting.md).

## enable or setup stops on a missing command

`security` or `openssl` is not on `PATH`. Both ship with macOS. See [dependencies.md](dependencies.md). Enable stops before it writes the index or the Keychain item.

## A command says localenv is not set up

`projects.ini` is missing. Run `harto localenv setup`. `doctor` prints `index=missing` in that case.

## No project for this directory

The current directory is not a registered project and is not inside one. `init` records the directory where it runs. Run it from that directory, or pass `--project NAME` to the command that needs a project. `which` prints the project that won. Two registered directories can contain the current one; the longer path wins. A sibling such as `blog-old` does not match `blog`.

## The Keychain key is missing

`doctor` prints `key=missing`. `list` and `which` still work, because they read `projects.ini`. `get`, `set`, `show`, `start`, and `exec` stop on an encrypted project and name the missing key. A project created with `--plain` still reads. `setup` creates the key again, but the new key does not decrypt files written with the old one.

## A project file cannot be decrypted

`doctor` prints `readable=no` for that project. The Keychain item exists and does not match the file, or both `env.ini` and `env.ini.enc` are present. localenv refuses to guess when both files exist. Move one aside. A matching key is the one that was in the Keychain when the file was written.

## A project directory does not exist

`doctor` prints `status=missing` and the path from `projects.ini`. The directory was renamed or removed after `init`. Run `init` again from the new directory and accept the question that points the project at it, or remove the project.

## set in the started shell did not change the variable

`start` reloads bash and zsh only, and only when the command is named `harto`. A full path to the program, or another shell, updates the stored file and leaves the running shell as it was. Leave that shell and `start` again, or run `eval "$(harto localenv export <env>)"`.

## set or remove stops with exit code 3

The command needs a yes and the call was `--non-interactive` without `--yes`. `set` asks only when the variable already exists, and it does not print the old value. `remove` always asks. Pass `--yes` to accept.
