---
title: "Examples"
description: "Copy/paste setup-script snippets for DVM. Review and adapt before use."
---

Copy/paste fragments for user-owned setup scripts. They are **not** DVM runtime
code. Review and adapt before use.

All examples assume the Fedora guest with `dnf5`. They run during `dvm sync`, as
the Lima login user with `sudo` available. DVM prepends `set -Eeuo pipefail` and
exports these variables (see the [config reference](/docs/reference/config/)):

`DVM_NAME` `DVM_VM` `DVM_LIMA_NAME` `DVM_USER` `DVM_CODE_DIR` `DVM_PORTS`
`DVM_SUBUID_COUNT` `DVM_SUBGID_COUNT`

Run a command as the dev user, not root: `sudo -u "$DVM_USER" -H ...`.

## Snippets

| Topic | What it covers |
| --- | --- |
| [Packages](/docs/examples/packages/) | Fedora and Copr packages |
| [Verified binary download](/docs/examples/binaries/) | Verified upstream binary download |
| [Default shell](/docs/examples/shell/) | Set zsh as the default shell |
| [SSH keys](/docs/examples/ssh-keys/) | VM-local SSH keys, private repos |
| [GPG signing key](/docs/examples/gpg-key/) | VM-local GPG signing key |
| [Dotfiles](/docs/examples/dotfiles/) | chezmoi dotfiles |
| [AI CLIs](/docs/examples/ai-clis/) | Claude Code and Codex CLIs |
| [Rootless Docker](/docs/examples/rootless-docker/) | Rootless Docker (recommended) |
| [Rootless Podman](/docs/examples/rootless-podman/) | Rootless Podman |
| [Rootful Docker](/docs/examples/rootful-docker/) | Rootful Docker (guest-root risk) |
| [Tailscale](/docs/examples/tailscale/) | Tailscale |
| [Cloudflare Tunnel](/docs/examples/cloudflare-tunnel/) | Cloudflare Tunnel |
| [One user per project](/docs/examples/per-project-users/) | One VM, one user per project |
