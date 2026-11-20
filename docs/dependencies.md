# Dependencies

These are the tools the HARTO framework itself needs. A plugin lists its own tools next to its code. HARTO does not vendor any of them, and the MIT license does not cover them.

| Tool | Required | License | Install |
| --- | --- | --- | --- |
| Homebrew | yes, for `harto setup` | BSD 2-Clause | https://brew.sh |
| git | yes | GPL-2.0 | https://git-scm.com/downloads |
| yq (mikefarah) 4+ | yes | MIT | https://github.com/mikefarah/yq |
| bats-core | development only | MIT | https://github.com/bats-core/bats-core |
| shellcheck | development only | GPL-3.0 | https://github.com/koalaman/shellcheck |
| GNU parallel | development only | GPL-3.0 | https://www.gnu.org/software/parallel/ |

`harto setup` checks Homebrew, git, and yq before it writes anything. If one is missing, it prints the install hint and the official URL, then exits. It does not install packages. The Python package named yq is not accepted.

`harto doctor` reports the same gaps and exits 0. `harto plugin enable` uses the same checker on the dependencies declared in that plugin's manifest.

`scripts/test.sh` runs bats with `--jobs` and needs GNU parallel. Install it with `brew install parallel`.
