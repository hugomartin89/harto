# Calling HARTO from an agent

An agent uses the same CLI as a person. The procedure is [skills/use-harto/SKILL.md](../skills/use-harto/SKILL.md): one directory and one `SKILL.md`, with no vendor path. These global flags make it safe to call without a terminal.

## Discover commands

```bash
harto help --json
```

The output is one JSON object: `version`, `core` (each with `name`, `description`, `json`), and `plugins` (each with `name`, `version`, `description`, and `commands`). A plugin command lists `name`, `description`, `usage`, `privileged`, and `json`. A plugin whose manifest is invalid is left out. A plugin's own docs explain its arguments and environment variables.

## Run without a terminal

Pass `--non-interactive` on every call. HARTO then never waits on stdin:

- A question that has no answer from an option or environment variable stops with exit code 2. The message names the variable to set.
- A confirmation stops with exit code 3. `--yes` accepts it, and accepts each question's suggested answer.
- A step that needs `sudo` always stops with exit code 3, even with `--yes`. The message prints the explanation, the exact privileged command, and the HARTO command a person should run without `--non-interactive`.

`--dry-run` still works in this mode and reports what would change.

## Read structured output

`--json` is accepted only by commands with `json: true` in the catalog. Any other command exits with code 2. Every JSON value is a string.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | The command failed |
| 2 | Wrong usage or a missing answer |
| 3 | A person has to confirm or run a privileged step |

On exit code 3, hand the message to the person. Do not retry with `sudo` or feed answers on stdin.
