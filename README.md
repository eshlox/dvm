# DVM

A small Bash wrapper around Lima for disposable development VMs. It creates and
starts Lima instances, keeps host files out of the guest, creates a dev user,
and runs your own setup scripts. Tool installation lives in those scripts.

Defaults:

- no host mounts
- VM `<name>` maps to Lima instance `dvm-<name>`
- code lives at `/home/<user>/code/<vm>`
- config in `~/.config/dvm`
- setup scripts are ownership/permission checked before they run

## Install

Requirements: Bash and Lima 2.0+.

```bash
git clone <repo-url> dvm
cd dvm
./install.sh          # symlinks bin/dvm into ~/.local/bin (override with PREFIX)
```

## Quickstart

```bash
dvm new app           # writes ~/.config/dvm/vms/app/{config.sh,setup.sh}
```

Edit the config:

```bash
# ~/.config/dvm/vms/app/config.sh
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
```

Edit the setup script:

```bash
# ~/.config/dvm/vms/app/setup.sh
#!/usr/bin/env bash
set -Eeuo pipefail

sudo dnf5 install -y git ripgrep fd-find tmux
```

Build and enter:

```bash
DVM_DRY_RUN=1 dvm sync app   # preview, no Lima contact
dvm sync app
dvm sh app
```

## Commands

```text
dvm sync <vm> | --all
dvm sh <vm>
dvm ssh <vm> -- cmd...
dvm cp <src> <dst>
dvm ls [--only-config] [<vm>]
dvm stop <vm> | --all [--only-config]
dvm rm <vm> --yes [--config]
dvm new <vm>
dvm version
```

See [docs/commands.md](docs/commands.md) for details.

## Docs

- [docs/commands.md](docs/commands.md) - command reference
- [docs/config.md](docs/config.md) - config variables and setup scripts
- [docs/security.md](docs/security.md) - security model and threats
- [docs/lima.md](docs/lima.md) - Lima behavior and limits
- [docs/troubleshooting.md](docs/troubleshooting.md) - errors and recovery
- [examples/](examples/README.md) - copy/paste setup snippets

Development check (runs the smoke test and ShellCheck):

```bash
bash scripts/check
```
