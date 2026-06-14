---
title: "Quickstart"
description: "Create, configure, build, and enter a disposable VM in four commands."
---

This walks through creating a VM, configuring it, provisioning it, and opening a
shell inside it.

## 1. Scaffold a VM

```bash
dvm new app           # writes ~/.config/dvm/vms/app/{config.sh,setup.sh}
                      # and scaffolds ~/.config/dvm/config.sh on first run
```

## 2. Edit the config

Resource and user settings live in the global `~/.config/dvm/config.sh` and apply
to every VM. The per-VM config only holds what this VM needs to differ on:

```bash
# ~/.config/dvm/vms/app/config.sh
DVM_MEMORY=4                       # more RAM than the global default for this VM
DVM_PORTS=(3000:3000 5173:5173)    # extra forwards on top of Lima's automatic ones
```

See the [config reference](/docs/reference/config/) for every variable.

## 3. Edit the setup script

The setup script runs inside the guest during `dvm sync`. Install whatever your
project needs here:

```bash
# ~/.config/dvm/vms/app/setup.sh
#!/usr/bin/env bash
set -Eeuo pipefail

sudo dnf5 install -y git ripgrep fd-find tmux
```

Browse [Examples](/docs/examples/) for copy/paste setup snippets.

## 4. Build and enter

```bash
DVM_DRY_RUN=1 dvm sync app   # preview the Lima argv + setup order, no Lima contact
dvm sync app                 # create/start the VM and run setup scripts
dvm sh app                   # open a shell as the dev user
```

When you're done, stop or destroy the VM:

```bash
dvm stop app
dvm rm app --yes             # add --config to also delete ~/.config/dvm/vms/app
```

## 5. Bake a base image (recommended for many VMs)

If every VM installs the same tooling, the per-sync setup gets slow and the
setup script gets long. Bake that shared tooling once into a base image and
every VM boots from it:

```bash
dvm base init                # writes ~/.config/dvm/base/Containerfile
# edit it: FROM dvm-base, then your packages and binaries
dvm base build               # builds the image in a throwaway builder VM
dvm sync app                 # now boots from the base image, ready in seconds
```

Per-VM `setup.sh` still runs for unique, stateful steps (SSH keys, dotfiles,
tunnels). See the [base image reference](/docs/reference/base/) for the full
workflow.

## 6. Run many projects in one VM (optional)

Instead of a VM per project, group projects by trust tier in one pool VM, each
running as a disposable container you can reset in seconds:

```bash
dvm new trusted              # a pool VM for this trust tier
dvm add trusted/api          # define a project (container) under the VM
dvm sync trusted             # bring up the VM and every project container
dvm sh trusted/api           # shell into the api container
dvm reset trusted/api --yes  # recreate just that container, clean
```

See [Trust tiers & project containers](/docs/reference/projects/) for the model.

See the [Commands reference](/docs/reference/commands/) for the full CLI.
