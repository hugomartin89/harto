# HARTO

HARTO is a small command-line framework for local development tools. A shared core discovers plugins, checks dependencies, and stores configuration outside the repository. Plugins add their own commands and document themselves.

## What it solves

Repeating the same local setup by hand is brittle. HARTO keeps one installation and one configuration, then lets each plugin add its own commands. A plugin keeps its own state in that shared location so a project directory stays free of personal settings.

## Status

HARTO 0.7.0 supports macOS. Other operating systems are rejected with an error. Linux and Windows are not implemented.

## Requirements

- macOS
- Bash 3.2, the Bash shipped with macOS
- [git](https://git-scm.com/downloads)
- [Homebrew](https://brew.sh)
- [yq](https://github.com/mikefarah/yq) 4 or newer, the mikefarah build

Development checks also use [shellcheck](https://github.com/koalaman/shellcheck) and [bats-core](https://github.com/bats-core/bats-core). They are not required to run HARTO. Licenses are in [docs/dependencies.md](docs/dependencies.md).

## Install the framework

```bash
git clone https://github.com/hugomartin89/harto.git
cd harto
git config core.hooksPath .githooks
./bin/harto setup
```

`harto setup` checks the operating system, Homebrew, git, and yq before it writes anything. If Homebrew is missing it prints the official installer page, https://brew.sh, and stops. It does not download Homebrew. After Homebrew is installed:

```bash
brew install yq
./bin/harto setup
```

Setup writes configuration under `~/.config/harto`, state under `~/.local/state/harto`, and data under `~/.local/share/harto`, unless the XDG variables are set. See [docs/configuration.md](docs/configuration.md).

## Choose a local executable name

The program does not care which file name you use. A symlink, alias, or wrapper can point at the same `bin/harto`. This example uses `devx`. Another name works the same way.

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd)/bin/harto" ~/.local/bin/devx
```

Make sure `~/.local/bin` is on `PATH`. These then behave the same, including configuration:

```bash
harto version
devx version

harto doctor
devx doctor
```

`harto setup` can create that symlink for you. Leave the name empty to skip it. With `--yes`, setup does not invent a name.

## First configuration

```bash
harto setup
harto doctor
```

`doctor` prints what is missing and does not change the machine. `setup` is safe to run again.

## Plugins

A plugin that ships in `plugins/` is enabled with `harto plugin enable`. Enable records it and, when it is not already active, runs its setup command. It does not download the plugin's external tools. `harto plugin disable` stops it and removes its registered state. `harto plugin install` will later clone a plugin from a git URL. That command is not available yet.

```bash
harto plugin list
harto plugin enable <name>
harto plugin info <name>
harto plugin doctor <name>
harto plugin disable <name>
```

The included plugin is [devhost](plugins/devhost/README.md).

## Commands

```text
harto version
harto help
harto setup
harto doctor
harto upgrade
harto plugin list
harto plugin info <name>
harto plugin enable <name>
harto plugin disable <name>
harto plugin upgrade <name>
harto plugin doctor <name>
```

`harto help` also lists each installed plugin's commands. Global flags: `--yes`, `--dry-run`, `--debug`, `--non-interactive`, `--json`. `--dry-run` prints the change it would make and does not present that change as done. Agents and scripts should follow [docs/agents.md](docs/agents.md).

## Tests

```bash
brew install bats-core shellcheck
scripts/lint.sh
scripts/test.sh
scripts/check-generic.sh
```

The default test run uses temporary directories and stand-in commands. It does not change the system. A real-machine check is skipped unless `HARTO_INTEGRATION=1`.

## License

HARTO is released under the MIT license. See [LICENSE](LICENSE). That license covers HARTO's own code. It does not cover tools you install separately. Framework tools are listed in [docs/dependencies.md](docs/dependencies.md). A plugin lists its own tools next to its documentation.

## Known limitations

- macOS is the only supported system.
- `harto upgrade` fast-forwards a clean git checkout. It stops when there are local modifications, and it does not reset them.
- The automated tests do not modify system configuration. Those steps need a manual check, described by the plugin that performs them.
