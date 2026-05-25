# DVM

DVM is a small Bash wrapper around Lima for disposable development VMs.

It creates and starts Lima instances, keeps host files out of the guest by
default, creates a development user, and runs user-owned setup scripts. Tool
installation lives in those scripts.

Defaults:

- no host mounts
- VM names map to `dvm-<name>`
- code directory is `/home/<user>/code/<vm>`
- config is in `~/.config/dvm`
- setup scripts are permission checked before execution

## Install

Requirements: Bash and Lima 2.0+.

```bash
git clone <repo-url> dvm
cd dvm
./install.sh
```

## Create a VM

```bash
dvm new app
```

`dvm new app` writes:

```text
~/.config/dvm/vms/app/config.sh
~/.config/dvm/vms/app/setup.sh
```

Example VM config:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
```

Example setup script:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

sudo dnf5 install -y git ripgrep fd-find tmux

sudo -u "$DVM_USER" -H bash -lc '
  mkdir -p "$HOME/.local/bin"
'
```

Run it:

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
dvm sh app
```

## Security model

DVM protects the host mainly by using a VM and passing `--mount-none` when it
creates instances. Setup scripts are trusted provisioning code that you own and
review. DVM refuses config and setup scripts that are not owned by the current
host user or are group/world writable.

Use the docs for secure examples:

- [docs/security-standards.md](docs/security-standards.md)
- [docs/examples.md](docs/examples.md)
- [docs/threat-model.md](docs/threat-model.md)

## Commands

```text
dvm sync <vm> | --all
dvm sh <vm>
dvm ssh <vm> -- cmd...
dvm cp src dst
dvm ls [--only-config] [<vm>]
dvm stop <vm> | --all [--only-config]
dvm rm <vm> --yes [--config]
dvm new <vm>
dvm version
```

## Docs

- [docs/howto.md](docs/howto.md): common workflows
- [docs/config.md](docs/config.md): config variables and setup scripts
- [docs/examples.md](docs/examples.md): secure setup script examples
- [docs/commands.md](docs/commands.md): command reference
- [docs/lima.md](docs/lima.md): Lima behavior and limits
- [docs/security-standards.md](docs/security-standards.md): secure usage guide

Development check:

```bash
bash scripts/check
```
