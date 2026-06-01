---
title: "Install"
description: "Install the dvm CLI. Requires Bash and Lima 2.0+."
---

DVM is a small Bash wrapper around [Lima](https://lima-vm.io). It creates and
starts Lima instances, keeps host files out of the guest, creates a dev user,
and runs your own setup scripts. Tool installation lives in those scripts.

## Requirements

- Bash
- [Lima](https://lima-vm.io) 2.0 or newer

## Install

```bash
git clone https://github.com/eshlox/dvm.git dvm
cd dvm
./install.sh          # symlinks bin/dvm into ~/.local/bin (override with PREFIX)
```

`install.sh` only creates a symlink to `bin/dvm`. Set `PREFIX` to install
somewhere else:

```bash
PREFIX="$HOME/bin" ./install.sh
```

Make sure the install directory is on your `PATH`, then check the install:

```bash
dvm version
```

## Defaults

- no host mounts
- VM `<name>` maps to Lima instance `dvm-<name>`
- code lives at `/home/<user>/code/<vm>`
- config in `~/.config/dvm`
- setup scripts are ownership/permission checked before they run

Next: [Quickstart](/docs/getting-started/quickstart/).
