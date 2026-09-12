# Agent guide

Harto is a small macOS CLI. The project name is Harto. `devx` is only an example name for a local symlink.

Read [docs/architecture.md](docs/architecture.md) before adding a command, a plugin, or an adapter. Short form:

- A core command is a new file in `core/commands/`. Do not edit `core/cli.sh` to register it.
- A plugin command is a new file in `plugins/<name>/commands/` plus an entry in that plugin's `plugin.yml`.
- A new plugin is a new directory under `plugins/` with a manifest. There is no central registry.
- A replaceable external tool is a new file that defines the same functions as the current adapter. Do not add a provider framework for a single implementation.
- `core/` must not mention a plugin by name. A plugin sources only `$HARTO_LIB`.

## Shell

- Target the Bash shipped with macOS (3.2). Do not use associative arrays, `mapfile`, `${var,,}`, or `readlink -f`.
- Start executable scripts with `set -euo pipefail`.
- Quote expansions. Do not use `eval`. Do not call `sudo` outside `harto_run_privileged`.
- Public functions use the `harto_` prefix. Helpers private to a file use `_`.
- Write config by creating a temporary file in the same directory and renaming it. Take a lock when two processes could write the same state.
- Operations that change the system accept `--dry-run` and must not claim the change happened.
- Keep `shellcheck` clean.

## Commits

Use Conventional Commits. `scripts/check-commits.sh` is the rule. Enable it once per clone:

```bash
git config core.hooksPath .githooks
```

```text
type(scope): subject
```

- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Scope is optional and lowercase, for example `core`, `devhost`, `docs`, `plugins`, `ci`.
- Subject is English, imperative, lowercase, with no trailing period, and at most 72 characters.
- The body explains why. Use a `BREAKING CHANGE:` footer when needed.
- One coherent change per commit. Do not use subjects such as `update`, `fix stuff`, or `wip`.

```text
feat(devhost): persist routes outside the repository
fix(core): stop setup when yq is missing
```

## Tests and checks

- Exercise the public CLI. Stub processes at the system boundary, not internal functions.
- Point `HOME` and the XDG directories at a temporary directory. Do not touch the real DNS resolver, trust store, or LaunchAgents.
- Do not put company names, private hosts, or real environment data in code, docs, fixtures, or tests.
- Before handing work back, run `scripts/lint.sh`, `scripts/test.sh`, and `scripts/check-generic.sh`.

## Documentation

Document the interface a caller uses. Point at the script or the doc that already defines a behavior instead of copying it. Framework docs stay in `docs/`. A plugin's docs stay in that plugin's directory.
