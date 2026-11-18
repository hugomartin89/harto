# devhost dependencies

devhost does not ship these programs. Install them from the links below. The MIT license on HARTO does not cover them.

| Tool | Required | License | Install |
| --- | --- | --- | --- |
| Caddy 2.6+ | yes | Apache-2.0 | https://caddyserver.com/docs/install |
| dnsmasq | yes | GPL-2.0 | https://thekelleys.org.uk/dnsmasq/doc.html |
| mkcert | only when HTTPS is enabled | BSD 3-Clause | https://github.com/FiloSottile/mkcert |
| Colima | no; recommended when you want containers on macOS | MIT | https://github.com/abiosoft/colima |

`harto plugin add devhost` stops before writing configuration when Caddy or dnsmasq is missing. They print the install hint and the official URL. They do not install packages. mkcert is checked only if you choose HTTPS. Colima is reported and never blocks setup.

`harto devhost doctor` prints the same gaps and exits 0.

Homebrew and yq are requirements of HARTO itself. See [the framework dependencies](../../../docs/dependencies.md).
