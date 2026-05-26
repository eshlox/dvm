# Setup examples

Copy/paste fragments for user-owned setup scripts. They are not DVM runtime
code. Review and adapt before use.

All examples assume the Fedora guest with `dnf5`. They run during `dvm sync`,
as the Lima login user with `sudo` available. DVM prepends `set -Eeuo pipefail`
and exports these variables (see [config.md](../docs/config.md)):

`DVM_NAME` `DVM_VM` `DVM_LIMA_NAME` `DVM_USER` `DVM_CODE_DIR` `DVM_PORTS`
`DVM_SUBUID_COUNT` `DVM_SUBGID_COUNT`

Run a command as the dev user, not root: `sudo -u "$DVM_USER" -H ...`.

| File | Topic |
| --- | --- |
| [packages.md](packages.md) | Fedora and Copr packages |
| [binaries.md](binaries.md) | Verified upstream binary download |
| [shell.md](shell.md) | Set zsh as the default shell |
| [ssh-keys.md](ssh-keys.md) | VM-local SSH keys, private repos |
| [gpg-key.md](gpg-key.md) | VM-local GPG signing key |
| [dotfiles.md](dotfiles.md) | chezmoi dotfiles |
| [ai-clis.md](ai-clis.md) | Claude Code and Codex CLIs |
| [rootless-docker.md](rootless-docker.md) | Rootless Docker (recommended) |
| [rootless-podman.md](rootless-podman.md) | Rootless Podman |
| [rootful-docker.md](rootful-docker.md) | Rootful Docker (guest-root risk) |
| [tailscale.md](tailscale.md) | Tailscale |
| [cloudflare-tunnel.md](cloudflare-tunnel.md) | Cloudflare Tunnel |
| [per-project-users.md](per-project-users.md) | One VM, one user per project |
