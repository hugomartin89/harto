---
name: use-harto
description: Run HARTO commands and plugins (for example devhost routes) on behalf of the user. Use when the user asks to add a local domain, route, proxy, or any task a HARTO plugin covers.
---

# Use HARTO

1. Read [docs/agents.md](../../../docs/agents.md). It is the contract for flags, output, and exit codes.
2. Run `harto help --json` to find the command. Read that plugin's `README.md` for its arguments.
3. Call every command with `--non-interactive`. Preview changes with `--dry-run` first.
4. On exit code 3, stop and show the person the message. Never run the privileged command yourself.
