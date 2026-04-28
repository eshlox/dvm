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
- GPG signing subkey creation, export, install, and revocation helpers
- documentation that affects installation or release verification

User setup scripts, dotfiles, packages installed inside a VM, downloaded models, and
services configured by users are user-controlled and out of scope unless DVM itself
handles them insecurely.

DVM does not mount host dotfiles into VMs by default. If dotfiles sync is enabled, DVM
copies a filtered snapshot during setup so project code in the VM does not retain a
persistent read path back to the host.

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
