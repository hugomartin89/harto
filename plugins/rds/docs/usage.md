# Using rds

## Setup

```bash
harto plugin enable rds
```

`harto plugin enable rds` asks the setup questions when rds is not already active. Run `harto rds setup` again to change those answers.

Questions, in order:

1. AWS region. The suggestion is `us-east-1`.
2. Read-only database user. There is no suggestion.
3. Write database user. There is no suggestion.

Setup then downloads the public RDS CA bundle into the plugin data directory. Without curl, setup still saves the answers and `harto rds doctor` prints the download command. `harto rds connect` stops until that file exists.

Non-interactive answers: `HARTO_RDS_REGION`, `HARTO_RDS_READ_USER`, `HARTO_RDS_WRITE_USER`. `--yes` accepts the region suggestion. The users have no suggestion and must be set.

The VPN has to be running before a connection works. rds does not start it.

## Catalog

```bash
harto rds add app --engine mysql --profile readonly --reader db.example.test
harto rds add app --engine postgres --profile readonly --reader db.example.test --writer writer.example.test
harto rds list
harto rds remove app
```

`--engine mysql` uses port 3306. `--engine postgres` uses port 5432. `--writer` is optional. The same answers can be passed as `HARTO_RDS_ENGINE`, `HARTO_RDS_PROFILE`, `HARTO_RDS_READER`, and `HARTO_RDS_WRITER`.

`list` columns are `name`, `engine`, `profile`, and `writer` (`yes` when a writer host is stored). `--json` returns those fields. Hosts are not printed.

## Profile

```bash
harto rds profile app
```

Prints an AWS config block for the database's profile and region. `sso_session` and `sso_account_id` are placeholders. rds does not write the AWS config file.

## Token

```bash
harto rds token app
harto rds token app --write
harto rds token app --print
```

`token` runs `aws rds generate-db-auth-token` and copies the result to the clipboard. The command output does not include the token. `--print` writes it to stdout instead. `--write` uses the writer host and the write user. A database without a writer host stops with an error.

`--dry-run` does not call AWS. If the AWS SSO session is not usable, rds exits with code 3 and prints `aws sso login --profile <profile>`. It does not open a browser.

The token expires 15 minutes after AWS generates it. rds does not store it.

## Connect

```bash
harto rds connect app
harto rds connect app --write --database appdb
```

Uses the same host and user as `token`, then runs `mysql` or `psql` with the CA bundle. The token is passed in the child process environment. A missing client or a missing CA bundle stops the command.
