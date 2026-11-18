# Troubleshooting

`harto doctor` is read-only. It reports the operating system and whether Homebrew, git, and yq are available. It does not change the machine. A plugin's own doctor is documented with that plugin.

## setup stops immediately

- `unsupported operating system` means the machine is not macOS.
- `Homebrew (brew) is not installed` means `brew` is not on `PATH`. Install it from https://brew.sh and open a new terminal. HARTO does not install it.
- `yq (mikefarah) >= 4 is required` means the command is missing or it is a different yq. `brew install yq` installs the mikefarah build. The Python package named yq is not accepted.
- `git is not installed` means `git` is not on `PATH`. HARTO does not install it.

## A plugin add stops

`harto plugin add` checks the dependencies declared in that plugin's manifest before it records the plugin or runs its setup. The message names the missing command, the install hint, and the official URL. Nothing is written until those required commands exist.

## Upgrade stopped

`local modifications ... prevent a safe update` means the git checkout is dirty. Commit or stash, then run `harto upgrade` again. HARTO does not reset the checkout. `fast-forward ... failed` means the branch diverged. Merge or rebase it yourself.

## Where the files are

See [configuration.md](configuration.md).
