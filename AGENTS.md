# Agent instructions

This repository is intentionally small and audit-friendly. DVM is a Bash +
Lima wrapper with built-in Bash recipes. Keep core behavior focused; prefer
docs or recipes over adding framework code unless the core change is clearly
justified.

After every change:

- Update user-facing docs when behavior, commands, config, recipes, workflows,
  or setup examples change.
- Update `CHANGELOG.md` under `Unreleased` for every user-visible change. If a
  change is internal-only, make that explicit in the final summary.
- Run `bash tests/smoke.sh` before handing work back when possible.

Do not edit unrelated files or generated local notes. In particular, leave
unrelated draft docs alone unless the user asks for them.

Recipe helpers available inside guest recipes:

- `dvm_pkg <pkg...>` installs Fedora packages with `dnf5`.
- `dvm_as_user <cmd...>` runs a command as `DVM_USER`.
- `dvm_as_agent <cmd...>` runs a command as `DVM_AGENT_USER`.
- `dvm_ensure_user <user>` creates a guest user when missing.
- `dvm_user_group <user>` prints a user's primary group.
- `dvm_secret <NAME>` prints the staged secret path or fails.
- `dvm_has_secret <NAME>` tests whether a staged secret path is available.
- `dvm_append_once <file> <line>` appends a user-owned line once.
- `dvm_download_verified <name> <url> <sha256> <dest>` installs a verified
  downloaded binary.
- `dvm_npm_global <package> <version> <script-policy>` installs a pinned npm
  package under a user-owned prefix.
