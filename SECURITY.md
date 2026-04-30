# Security Policy

## Supported Versions

Only the latest published release is supported for security fixes. The `main` branch is
for development and should not be treated as a stable install target.

## Reporting A Vulnerability

Use GitHub private vulnerability reporting for this repository. Please do not open a
public issue with exploit details, secret material, or a working proof of concept.

If private vulnerability reporting is not available, open a public issue requesting a
private disclosure channel and include no technical details.

Useful report details:

- affected DVM version or commit
- host macOS version and Lima version
- exact command or workflow involved
- impact and whether secrets, SSH keys, GPG keys, or VM isolation are affected

## Security Model

DVM is a small wrapper around Lima. It helps isolate project work into separate Fedora
VMs and keeps user-controlled setup outside the core repository. The core targets Lima
`template:fedora` and assumes `dnf5` in the guest. It is not a sandbox that can
provide stronger guarantees than Lima, QEMU, macOS virtualization, SSH, GPG, or the
packages and scripts that users choose to run.

Security-sensitive behavior in scope:

- installing and updating the DVM core
- VM creation, deletion, and setup commands
- per-VM SSH key creation
- VM-local GPG key creation
- documentation that affects installation or release verification

Per-VM config, recipes, dotfiles, packages installed inside a VM, downloaded models,
AI tools, and services configured by users are user-controlled and out of scope unless
DVM itself handles them insecurely.

DVM does not mount host dotfiles into VMs by default. If dotfiles sync is enabled, DVM
copies a filtered snapshot during setup so project code in the VM does not retain a
persistent read path back to the host.

The default dotfiles exclude list skips common credential paths, but it cannot know
every private file. Review `DVM_DOTFILES_DIR` before enabling dotfiles sync.

Keep host-local private config in `~/.config/dvm/private.sh` and do not commit it.
DVM excludes `private.sh` from copied dotfiles snapshots by default. This prevents
accidental sync, but it is not a secret manager. Any value written into a VM by setup
is readable by code running in that VM.

For GitHub, prefer repository deploy keys over personal account SSH keys when you want
repo-level isolation. Personal account SSH keys are account-scoped; multiple VM keys on
the same GitHub account have the same repo access. Deploy keys are repo-scoped and are
easier to revoke when one VM is compromised.

If you use hosted AI tools, prefer a separate VM user or a small recipe such as
`recipes/agent.sh`. DVM no longer treats AI tool installation as core behavior.

Cloudflare Tunnel tokens are credentials. If you use `recipes/cloudflared.sh`, keep the
token out of project code and dotfiles. The recipe stores it inside the cloudflared VM
at `/etc/cloudflared/dvm.env`; rotate it in Cloudflare if that VM is compromised.

## Safe Installation

Install from a signed release tag, not from an arbitrary branch. Before running
`install.sh`, verify the tag:

```bash
git fetch --tags --force
git tag -v vX.Y.Z
```

If tag verification fails, do not install or update.

## Maintainer Release Rules

- Run `bash scripts/check.sh` before tagging.
- Sign release tags with `git tag -s vX.Y.Z`.
- Publish releases from signed `v*` tags.
- Do not move, delete, or replace published release tags.
- If a release is bad, publish a new fixed release and document the problem.
- Do not add install paths that execute remote scripts directly.
