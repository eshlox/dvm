---
title: "Commands"
description: "Full command reference for the dvm CLI: sync, sh, ssh, cp, ls, stop, rm, new."
---

```text
dvm sync <vm> | --all              create/start VM and run setup scripts
dvm sh <vm>                        interactive shell as DVM_USER
dvm ssh <vm> -- cmd...             run one command as DVM_USER
dvm cp <src> <dst>                 copy a file; one side is vm:path
dvm ls [--only-config] [<vm>]      list dvm-* Lima instances
dvm stop <vm> | --all [--only-config]   stop instances
dvm rm <vm> --yes [--config]       stop and delete the instance
dvm new <vm>                       write starter config and setup script
dvm version
```

`dvm` with no args runs `dvm ls`.

## sync

Loads config, creates or starts `dvm-<vm>`, ensures `DVM_USER` and
`DVM_CODE_DIR` exist, provisions subordinate uid/gid ranges, then runs the setup
scripts (global, then per-VM). See [config.md](/docs/reference/config/).

```bash
DVM_DRY_RUN=1 dvm sync app   # print Lima argv + setup order, no Lima contact
dvm sync app
dvm sync --all               # sync every VM with a config
```

## sh / ssh

`dvm sh` opens `DVM_USER`'s login shell, starting in the project directory when
it exists. `dvm ssh` runs one command as `DVM_USER`.

```bash
dvm sh app
dvm ssh app -- sudo journalctl -f
```

## cp

One side must be `vm:path`. Relative VM paths resolve under
`/home/<DVM_USER>/code/<vm>` and copy as `DVM_USER`; absolute VM paths are used
as given. Directory copies are not supported. Use `./tmp:notes.txt` for a local
path containing a colon.

```bash
dvm cp ./file app:/tmp/file
dvm cp ./file app:notes.txt
dvm cp app:notes.txt ./file
```

## Lifecycle

`dvm ls` and `dvm stop --all` operate on `dvm-*` Lima instances. Add
`--only-config` to limit them to instances that have
`~/.config/dvm/vms/*/config.sh`.

`dvm rm <vm> --yes` deletes the Lima instance. Add `--config` to also remove
`~/.config/dvm/vms/<vm>`.
