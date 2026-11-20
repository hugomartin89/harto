# Using localenv

## Setup

```bash
harto plugin enable localenv
```

`setup` creates two things in the plugin config directory: `projects.ini`, which is always plain text, and a generic password in the login Keychain. The Keychain item uses the service `harto-localenv` and your user name as the account. What that key protects, and what it does not, is in [security.md](security.md). The commands `setup` needs are in [dependencies.md](dependencies.md).

Setup needs no answers and takes no arguments. Running it again does not rewrite an index that already exists. `--dry-run` does not write. The config directory and each project directory are mode `0700`. `projects.ini` and each environment file are mode `0600`.

`projects.ini` lists each project and the directory it was registered from:

```ini
[projects]
blog = /Users/me/src/blog
```

Each project then has its own directory and file. `blog/env.ini.enc` is the default. `blog/env.ini` is the same document in plain text, mode 0600, when the project was created with `--plain`. A project has one of those files, not both. The file holds one section per environment:

```ini
[local]
PORT = 3000

[ci]
PORT = 3000
```

## Projects

```bash
cd ~/src/blog
harto localenv init blog
harto localenv init blog --plain
harto localenv init blog --encrypt
```

`init` records the directory where it runs, resolved with `pwd -P`, in `projects.ini`, and creates that project's environment file. The file is encrypted unless `--plain` is given. `--encrypt` forces the encrypted file. Running `init` again with the same name, directory, and mode changes nothing. Passing the other mode converts that project only and keeps its variables. Running it with the same name and a new directory asks first. A directory that already belongs to another project is refused, and the other project must be removed first. `--plain` and `--encrypt` together are rejected.

Commands that take `--project NAME` use that project. Without it, HARTO uses the project whose directory is the current one or a parent of it. When two match, the longer path wins. A sibling such as `blog-old` does not match `blog`.

## Variables

```bash
harto localenv set local PORT 3000
harto localenv set local MESSAGE "hello world"
harto localenv get local PORT
harto localenv unset local PORT
```

Names: projects and environments match `^[A-Za-z][A-Za-z0-9_-]*$`. Variables match `^[A-Za-z_][A-Za-z0-9_]*$`. A value is one line. Text after the first `=` is the value, and one space right after `=` is not part of it.

`set` creates the environment when needed. When the variable already exists, `set` asks before it replaces the value. The old value is not shown. `--yes` accepts, and `--non-interactive` without `--yes` stops with exit code 3.

`get` prints the value followed by a newline. A missing variable exits with 1.

## Import

```bash
harto localenv import local .env
```

`import` copies a `.env` file into an environment. Blank lines and lines whose first character is `#` are skipped. A leading `export` is skipped. `NAME=value` and `NAME = value` both work. Matching single or double quotes around the whole value are removed, and the text inside them is kept as it is. Nothing in the file is executed, so `$(...)` stays text.

One question covers every variable that already exists. The old values are not shown. New names are added without a question. `--dry-run` does not write. A line that is not a comment or `NAME=value` exits with code 2 and names the line.

## Running with the variables

```bash
harto localenv start local
harto localenv exec local npm test
eval "$(harto localenv export local)"
```

- `start` enters the project directory and runs `$SHELL -i`, or `/bin/bash` when `SHELL` is empty. The variables are set in that shell. Exit the shell to leave. In bash and zsh, that shell defines `harto` so a later `set`, `unset`, or `import` of this environment updates the shell as well as the file. Other shells keep the file update only. `unset` removes the variable from the shell; it does not restore a value from before `start`.
- `exec` runs the command from the project directory with the variables set. The command is the rest of the line, so `--project` must come before the environment name.
- `export` prints `export NAME=value` lines, quoted with `printf %q`. HARTO does not evaluate them.

`--dry-run` on `start` and `exec` describes the directory and the number of variables, and does not run anything.

## Inspecting

```bash
harto localenv list                 # outside a project: projects and directories
harto localenv list                 # inside a project: environment names
harto localenv show local
harto localenv which
harto localenv doctor
```

`show` prints `NAME=value` lines. With `--json`, `show` and `which` return one object, `list` outside a project returns one object of project paths, and `list` inside a project returns an array of environment names. `--json` cannot return a value with spaces, so it exits with 1 and names the variable. Use text output for such values.

`doctor` changes nothing and exits 0. It prints `key=value` lines:

```text
index=present
index_mode=600
key=present
project=blog mode=encrypted readable=yes status=present
current_project=blog
```

`index=missing` means `setup` has not been run. `key` is `present` or `missing`. Each `project` line adds `mode` (`encrypted`, `plain`, or `none`), `readable`, and `status` (`present` when the registered directory exists). A plain project also prints `file_mode`. `current_project=none` means this directory is not inside a registered project. What to do with each gap is in [troubleshooting.md](troubleshooting.md).

## Removing

```bash
harto localenv remove local          # one environment, after confirmation
harto localenv remove --project      # the project for this directory, after confirmation
harto localenv remove --project blog # a project by name
```

Removing a project removes its line from the index and its directory, including every environment.

What is encrypted, and what a backup does not include, is in [security.md](security.md). Disabling the plugin is in [uninstallation.md](uninstallation.md).
