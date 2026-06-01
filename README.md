<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/logo-lockup-dark.svg">
    <img alt="DVM" src="brand/logo-lockup-light.svg" width="280">
  </picture>
</p>

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
git clone https://github.com/eshlox/dvm.git dvm
cd dvm
./install.sh          # symlinks bin/dvm into ~/.local/bin (override with PREFIX)
```

## Quickstart

```bash
dvm new app           # writes ~/.config/dvm/vms/app/{config.sh,setup.sh}
                      # and scaffolds ~/.config/dvm/config.sh on first run
```

Resource and user settings live in the global `~/.config/dvm/config.sh` and apply
to every VM. The per-VM config only holds what this VM needs to differ on:

```bash
# ~/.config/dvm/vms/app/config.sh
DVM_MEMORY=4                       # more RAM than the global default for this VM
DVM_PORTS=(3000:3000 5173:5173)    # extra forwards on top of Lima's automatic ones
```

`DVM_CPUS` auto-detects from host cores and is a time-shared ceiling, not a
reservation: idle VMs cost no host CPU and a busy one can burst to most of the
machine, so a high value is safe. `DVM_MEMORY` is the opposite, reserved up
front, so set it to what each VM actually needs. See the
[config reference](https://dvm.eshlox.net/docs/reference/config/#cpus-vs-memory)
for details.

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

See the [command reference](https://dvm.eshlox.net/docs/reference/commands/) for details.

## Docs

Full documentation lives at **[dvm.eshlox.net](https://dvm.eshlox.net)**:

- [Commands](https://dvm.eshlox.net/docs/reference/commands/) — command reference
- [Config & setup scripts](https://dvm.eshlox.net/docs/reference/config/) — config variables and setup scripts
- [Security model](https://dvm.eshlox.net/docs/guides/security/) — threats and trade-offs
- [Lima behavior](https://dvm.eshlox.net/docs/reference/lima/) — Lima behavior and limits
- [Troubleshooting](https://dvm.eshlox.net/docs/guides/troubleshooting/) — errors and recovery
- [Examples](https://dvm.eshlox.net/docs/examples/) — copy/paste setup snippets

The docs source lives in [`site/src/content/docs/`](site/). The website is an
Astro + Starlight project under [`site/`](site/) — see [`site/README.md`](site/README.md).

Development check (runs the smoke test and ShellCheck):

```bash
bash scripts/check
```
