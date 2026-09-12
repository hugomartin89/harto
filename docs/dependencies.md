# Dependencies

These are the tools the Harto framework itself needs. A plugin lists its own tools next to its code. Harto does not vendor any of them, and the MIT license does not cover them.

| Tool | Required | License | Install |
| --- | --- | --- | --- |
| Homebrew | yes, for `harto setup` | BSD 2-Clause | https://brew.sh |
| yq (mikefarah) 4+ | yes | MIT | https://github.com/mikefarah/yq |
| bats-core | development only | MIT | https://github.com/bats-core/bats-core |
| shellcheck | development only | GPL-3.0 | https://github.com/koalaman/shellcheck |

`harto setup` checks Homebrew and yq before it writes anything. If either is missing, it prints the install hint and the official URL, then exits. It does not install packages. The Python package named yq is not accepted.

`harto doctor` reports the same gaps and exits 0. `harto plugin install` uses the same checker on the dependencies declared in that plugin's manifest.
