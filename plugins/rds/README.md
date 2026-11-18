# rds

rds generates a short-lived IAM auth token for a database you registered on this machine. The catalog stays in the HARTO config directory. It is not part of this repository.

Framework behavior is documented in the repository [docs/](../../docs/architecture.md). This directory documents only rds.

## Add

```bash
harto plugin enable rds
harto rds add app --engine mysql --profile readonly --reader db.example.test
harto rds token app
```

`harto plugin enable rds` runs `harto rds setup` when rds is not already active. The token is the database password and expires 15 minutes after it is generated. rds copies it to the clipboard and does not store it.

External tools and their licenses are in [docs/dependencies.md](docs/dependencies.md). The commands are in [docs/usage.md](docs/usage.md).

## Commands

```text
harto rds setup
harto rds add app --engine mysql --profile readonly --reader db.example.test
harto rds remove app
harto rds list
harto rds profile app
harto rds token app
harto rds token app --write
harto rds connect app
harto rds doctor
```

## More

- [Usage](docs/usage.md)
- [Dependencies](docs/dependencies.md)
