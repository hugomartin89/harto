# rds dependencies

rds does not ship these programs. Install them from the links below. The MIT license on HARTO does not cover them.

| Tool | Required | License | Install |
| --- | --- | --- | --- |
| AWS CLI | yes | Apache-2.0 | https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html |
| curl | only to download the CA bundle | curl | part of macOS |
| mysql | only for `rds connect` to MySQL | GPL-2.0 | `brew install mysql-client` |
| psql | only for `rds connect` to Postgres | PostgreSQL | `brew install libpq` |

`harto plugin enable rds` stops before writing configuration when the AWS CLI is missing. It prints the install hint and the official URL. It does not install packages. curl, mysql, and psql are reported and never block setup.

`harto rds doctor` prints the same gaps and exits 0.

Homebrew and yq are requirements of HARTO itself. See [the framework dependencies](../../../docs/dependencies.md).
