# Security

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

## Setup script review

Before running a setup script, check that it:

- uses `set -Eeuo pipefail`
- installs exact versions where possible
- avoids `curl | sh`
- verifies downloads with SHA-256 (see [binaries.md](../examples/binaries.md))
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
- use VM-local SSH/GPG keys ([ssh-keys.md](../examples/ssh-keys.md))
- use `sops` or `age` inside the VM
- inject env vars for one command when needed

## Docker

Prefer rootless Docker or Podman. `docker` group access is guest-root
equivalent. See [rootless-docker.md](../examples/rootless-docker.md) and
[rootful-docker.md](../examples/rootful-docker.md).

## Throwaway VMs

Use a separate disposable VM for unknown repos, random installers, root-heavy
experiments, Docker-heavy work, or especially sensitive credentials. Remove when
done:

```bash
dvm rm risky --yes --config
```
