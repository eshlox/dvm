# Security standards

DVM is not a sandbox beyond Lima, the guest OS, Linux permissions, and the code
you run inside the VM.

Its main host-protection default is simple: create Lima VMs with no host mounts
and keep project code inside the guest.

## Defaults

- no host mounts in the DVM create path
- project code lives inside the guest
- only explicit localhost-style port forwards
- setup scripts must be current-user-owned and not group/world writable
- no automatic repo clone
- no secret broker

## Trust boundaries

| Boundary | Meaning |
| --- | --- |
| macOS host | DVM tries not to expose host files to guest code |
| Lima VM | guest compromise should not directly read host home |
| guest root | root inside the VM can read all guest users and projects |
| `DVM_USER` | normal development user for commands and project work |
| setup script | trusted host-owned provisioning code |
| project code | untrusted unless you reviewed it |

If setup scripts install malicious tools, DVM cannot make those tools safe.
DVM can only make the boundary explicit and avoid mounting the host.

## Setup script review

Before running a setup script, check:

- Does it use `set -Eeuo pipefail`?
- Does it install exact versions where possible?
- Does it avoid `curl | sh`?
- Does it verify downloaded binaries with SHA-256?
- Does it avoid copying host private keys into the guest?
- Does it avoid adding `DVM_USER` to the Docker group unless needed?
- Does it keep secrets out of config files?

Use dry-run to confirm which scripts will run:

```bash
DVM_DRY_RUN=1 dvm sync app
```

## Packages

Distro packages come from the guest OS repositories. That is usually acceptable
for baseline tools such as Git, ripgrep, fd, tmux, or Helix.

Example:

```bash
sudo dnf5 install -y git ripgrep fd-find tmux
```

For Ubuntu templates:

```bash
sudo apt-get update
sudo apt-get install -y git ripgrep fd-find tmux
```

## npm and AI tools

Prefer pinned versions and user-owned prefixes:

```bash
sudo -u "$DVM_USER" -H npm install --global \
  --prefix "$HOME/.local/npm" \
  --ignore-scripts \
  @openai/codex@0.132.0
```

Some npm packages require lifecycle scripts. If you allow them, understand that
the package runs code during install as the target user.

Do not store API tokens in DVM config. Configure tool auth inside the VM, under
the project VM or user that should own that credential.

## Downloads

Avoid live installers when possible. Prefer:

1. HTTPS download.
2. Pinned versioned URL.
3. Published SHA-256 checked before install.
4. Root-owned install destination.

Pattern:

```bash
tmp="$(mktemp)"
curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$tmp"
printf '%s  %s\n' "$sha256" "$tmp" | sha256sum -c -
sudo install -m 0755 "$tmp" /usr/local/bin/tool
rm -f "$tmp"
```

## Secrets

DVM does not stage secrets. Use deliberate external flows:

- sign in to tools inside the VM
- use VM-local SSH keys
- use `sops` or `age` inside the VM
- inject env vars for one command when needed
- use a password manager CLI only after reviewing what it exposes

Do not put long-lived secrets in `~/.config/dvm/*.sh`.

## SSH and GPG keys

Prefer VM-local keys:

```bash
install -d -m 700 ~/.ssh
ssh-keygen -t ed25519 -N "" -C "$USER@$HOSTNAME" -f ~/.ssh/id_ed25519
```

Add only the public key to GitHub/GitLab. Do not copy host private keys into the
guest.

## Docker

Docker group access is root-equivalent inside the guest. If `DVM_USER` can talk
to the Docker daemon, assume that user can become guest root and read all guest
projects.

Use a throwaway VM for Docker-heavy or untrusted work when isolation matters.

## Throwaway VMs

Use a separate disposable VM for:

- unknown repositories
- random installer scripts
- root-heavy experiments
- Docker-heavy projects
- projects with especially sensitive credentials

Remove it when done:

```bash
dvm rm risky --yes --config
```
