---
title: "Quickstart"
description: "Create, configure, build, and enter a disposable VM in four commands."
---

This walks through creating a VM, configuring it, provisioning it, and opening a
shell inside it.

## 1. Scaffold a VM

```bash
dvm new app           # writes ~/.config/dvm/vms/app/{config.sh,setup.sh}
```

## 2. Edit the config

```bash
# ~/.config/dvm/vms/app/config.sh
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
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

See the [Commands reference](/docs/reference/commands/) for the full CLI.
