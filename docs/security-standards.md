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

Fedora packages come from configured Fedora repositories. That is usually
acceptable for baseline tools such as Git, ripgrep, fd, tmux, or Helix.

Example:

```bash
sudo dnf5 install -y git ripgrep fd-find tmux
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
ssh-keygen -t ed25519 -N "" -C "${DVM_NAME}-dvm-git-deploy" \
  -f ~/.ssh/id_ed25519
```

Add only the public key to GitHub/GitLab. The key comment identifies the VM and
purpose. Do not copy host private keys into the guest.

## Docker

Prefer rootless Docker or rootless Podman for AI development VMs. DVM creates
subordinate uid/gid ranges for `DVM_USER` by default so rootless container
engines can map container root to unprivileged guest ids.

Run rootless containers as `DVM_USER`, without `sudo`:

```bash
docker run --rm hello-world
podman run --rm alpine echo ok
```

This is the intended default because the AI/user account can build and run
normal development containers without access to the guest's root-owned Docker
socket. It is not host-dangerous in DVM's normal model: the containers run
inside the Lima VM, DVM creates VMs with `--mount-none`, and rootless container
root maps to unprivileged guest ids instead of host or guest root.

Rootless containers are still powerful inside the project VM. They can read and
modify project files and user-owned credentials available to `DVM_USER`. Treat
them as project-local execution, not as a boundary against code you deliberately
run in the VM.

Docker group access is different: it is root-equivalent inside the guest. If
`DVM_USER` can talk to the rootful Docker daemon, assume that user can become
guest root and read all guest projects.

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
