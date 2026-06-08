---
title: "Examples"
description: "Copy/paste Containerfile and setup-script snippets for DVM. Review and adapt before use."
---

Copy/paste fragments for your own base image and setup scripts. They are **not**
DVM runtime code, and DVM does not maintain their versions or checksums: pin
them yourself and update when you bump. Review and adapt before use.

In v3 there are two homes for these snippets:

- **Base image** (`~/.config/dvm/base/Containerfile`): shared tooling baked once
  for every VM. These are Dockerfile `RUN`/`ARG` lines that run at build time as
  root. Start the file `FROM dvm-base` and build with `dvm base build`. See the
  [base image reference](/docs/reference/base/).
- **Per-VM** (`~/.config/dvm/vms/<vm>/setup.sh`): VM-specific, stateful steps
  (keys, dotfiles, tunnels). These run during `dvm sync` as the Lima login user
  with `sudo`, with `set -Eeuo pipefail` prepended and the `DVM_*` variables
  exported (see the [config reference](/docs/reference/config/)). Run a command
  as the dev user with `sudo -u "$DVM_USER" -H ...`.

`dvm-base` already installs zsh and the rootless-container dependencies, and
provides compressed swap (zram), the rootless-docker user service, and a binfmt
mask, so you do not need snippets for those. All examples assume the Fedora guest
with `dnf5`.

## In the base image (Containerfile)

| Topic | What it covers |
| --- | --- |
| [Packages](/docs/examples/packages/) | Fedora and Copr packages |
| [Verified binary download](/docs/examples/binaries/) | Upstream binaries not in `dnf` |
| [AI CLIs](/docs/examples/ai-clis/) | Claude Code and Codex CLIs |
| [Rootless Docker](/docs/examples/rootless-docker/) | Engine install on top of dvm-base |
| [Rootless Podman](/docs/examples/rootless-podman/) | Rootless Podman |

## Per-VM (setup.sh)

| Topic | What it covers |
| --- | --- |
| [SSH keys](/docs/examples/ssh-keys/) | VM-local SSH keys, private repos |
| [GPG signing key](/docs/examples/gpg-key/) | VM-local GPG signing key |
| [Dotfiles](/docs/examples/dotfiles/) | chezmoi dotfiles |
| [Cloudflare Tunnel](/docs/examples/cloudflare-tunnel/) | Cloudflare Tunnel |
| [Tailscale](/docs/examples/tailscale/) | Tailscale |
| [Default shell](/docs/examples/shell/) | Override the default shell |
| [Rootful Docker](/docs/examples/rootful-docker/) | Rootful Docker (guest-root risk) |
| [One user per project](/docs/examples/per-project-users/) | One VM, one user per project |
