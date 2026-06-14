---
title: "Security model"
description: "DVM's security model, the threats it addresses, and the trade-offs to understand."
---

DVM is not a sandbox beyond Lima, the guest OS, Linux permissions, and the code
you run inside the VM. Its host protection is one thing: create Lima VMs with no
host mounts and keep project code inside the guest.

If a setup script installs malicious tools, DVM cannot make them safe. It only
makes the boundary explicit and avoids mounting the host.

## Defaults

- no host mounts (`--mount-none` on the create path)
- project code lives inside the guest
- localhost-style port forwards only
- only configured setup scripts run during sync
- setup scripts must be current-user-owned and not group/world writable
- no automatic repo clone, no secret broker

## Trust boundaries

| Boundary | Meaning |
| --- | --- |
| host | DVM tries not to expose host files to guest code |
| Lima VM | guest compromise should not directly read host home |
| guest root | root inside the VM can read all guest users and projects |
| `DVM_USER` | normal dev user for commands and project work |
| project container | one project isolated from siblings in the same VM (shared kernel) |
| setup script | trusted host-owned provisioning code |
| project code | untrusted unless you reviewed it |

## Threats

| Threat | Mitigation |
| --- | --- |
| host file exposure | `--mount-none` on DVM-created instances |
| config tampering | owner/mode checks before sourcing |
| setup script tampering | owner/mode checks before execution |
| unclear provisioning | `DVM_DRY_RUN=1` prints the setup script order |
| unmanaged `dvm-*` instance | `--only-config` for `ls` and `stop --all` |
| repo-controlled provisioning | no built-in project hooks |
| guest-root compromise | use separate or throwaway VMs for higher-risk work |
| package supply chain | reviewed setup scripts, pinning, checksums |
| Docker root access | documented as guest-root equivalent |

Residual risk: packages, npm lifecycle scripts, downloaded binaries, service
auth, and project code can still run malicious code inside the guest. Treat VMs
as disposable and keep credentials scoped.

## Trust tiers and project containers

The boundary that protects your **host** is the VM (`--mount-none`, separate
kernel). [Project containers](/docs/reference/projects/) add a second, weaker
boundary that protects **projects from each other** inside one VM: separate user
namespaces and filesystems, but a shared guest kernel.

- Group VMs by **trust tier** and never mix tiers in one VM. A container is for
  several of your own semi-trusted projects, not for genuinely hostile code.
- A kernel-level escape from one container could reach a sibling in the same VM.
  Untrusted code still belongs in its own VM (one project, or no container).
- `NESTED=1` exposes `/dev/fuse` and relaxes SELinux confinement so a project can
  run its own podman/compose. Leave it off for projects that do not need it.
- Reset is part of the model: `dvm reset <vm>/<proj> --yes` recreates a clean
  container in seconds, dropping anything that hooked the runtime.

## Setup script review

Before running a setup script, check that it:

- uses `set -Eeuo pipefail`
- installs exact versions where possible
- avoids `curl | sh`
- verifies downloads with SHA-256 (see [binaries.md](/docs/examples/binaries/))
- does not copy host private keys into the guest
- does not add `DVM_USER` to the `docker` group unless needed
- keeps secrets out of config files

Confirm which scripts will run:

```bash
DVM_DRY_RUN=1 dvm sync app
```

## Secrets

DVM does not stage secrets. Do not put long-lived secrets in
`~/.config/dvm/*.sh`. Instead:

- sign in to tools inside the VM
- use VM-local SSH/GPG keys ([ssh-keys.md](/docs/examples/ssh-keys/))
- use `sops` or `age` inside the VM
- inject env vars for one command when needed

## Docker

Prefer rootless Docker or Podman. `docker` group access is guest-root
equivalent. See [rootless-docker.md](/docs/examples/rootless-docker/) and
[rootful-docker.md](/docs/examples/rootful-docker/).

## Throwaway VMs

Use a separate disposable VM for unknown repos, random installers, root-heavy
experiments, Docker-heavy work, or especially sensitive credentials. Remove when
done:

```bash
dvm rm risky --yes --config
```
