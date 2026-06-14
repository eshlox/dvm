---
title: "Commands"
description: "Full command reference for the dvm CLI: sync, sh, ssh, cp, ls, stop, logs, rm, reset, new, add, base."
---

```text
dvm sync <vm> | <vm>/<proj> | --all   create/start a VM (and its project containers)
dvm sh <vm> | <vm>/<proj>             interactive shell in the VM or a project container
dvm ssh <vm> -- cmd... | <vm>/<proj> -- cmd...   run one command as DVM_USER
dvm cp <src> <dst>                    copy a file; a side may be vm:path or vm/proj:path
dvm ls [--only-config] [<vm>]         list VMs, or a VM's project containers
dvm stop <vm> | <vm>/<proj> | --all [--only-config]   stop a VM or project container
dvm logs <vm>/<proj> [-f]             show a project container's logs
dvm rm <vm> --yes [--config] | <vm>/<proj> --yes [--keep-data] [--config]   delete a VM or project
dvm reset <vm> --yes | <vm>/<proj> --yes [--keep-data]   rebuild a VM, or recreate a container
dvm new <vm>                          write starter VM config and setup script
dvm add <vm>/<proj>                   define a project (container) inside a VM
dvm base <subcommand>                 build/manage the base image VMs boot from
dvm version
```

`dvm` with no args runs `dvm ls`.

A `<vm>/<project>` argument targets a **project container** inside a pool VM. See
[Trust tiers & project containers](/docs/reference/projects/) for the model;
this page is the per-command reference.

## sync

Loads config, creates or starts `dvm-<vm>`, ensures `DVM_USER` and
`DVM_CODE_DIR` exist, provisions subordinate uid/gid ranges, then runs the per-VM
setup script. With a base image it boots from it; otherwise it falls back to
`template:fedora`. See [config.md](/docs/reference/config/).

```bash
DVM_DRY_RUN=1 dvm sync app   # print Lima argv + setup order, no Lima contact
dvm sync app                 # create/start the VM and run its setup
dvm sync --all               # sync every VM with a config
```

When projects are defined under a VM, `dvm sync <vm>` also builds the dev-base
image (if configured) and brings up every project container.

```bash
dvm sync trusted             # the VM + all its project containers
dvm sync trusted/api         # just the api container
```

## sh / ssh

`dvm sh <vm>` opens `DVM_USER`'s login shell, starting in the project directory.
`dvm ssh <vm> -- cmd` runs one command as `DVM_USER`. With a `<vm>/<proj>`
target both run inside that project's container instead (starting it first if it
is stopped).

```bash
dvm sh app
dvm ssh app -- sudo journalctl -f
dvm sh trusted/api                 # shell inside the api container
dvm ssh trusted/api -- npm test    # one command inside the container
```

## cp

Exactly one side must be a `vm:path` or `vm/proj:path`. Relative VM paths resolve
under `/home/<DVM_USER>/code/<vm>` (or the container's `PROJ_WORKDIR`) and copy
as `DVM_USER`; absolute paths are used as given. Directory copies are not
supported. Use `./tmp:notes.txt` for a local path containing a colon.

```bash
dvm cp ./file app:/tmp/file        # to an exact VM path
dvm cp ./file app:notes.txt        # to code/app/notes.txt
dvm cp app:notes.txt ./file
dvm cp ./patch trusted/api:patch   # into the api container's workspace
```

## Lifecycle

`dvm ls` and `dvm stop --all` operate on `dvm-*` Lima instances. Add
`--only-config` to limit them to instances that have a config. The base-image
builder (`dvm-builder`) is hidden from both; manage it with `dvm base`.

`dvm ls <vm>` lists that VM's project containers with each container's state and
image. `dvm stop <vm>/<proj>` stops one container; `dvm logs <vm>/<proj> [-f]`
shows (and with `-f` follows) its logs.

```bash
dvm ls                       # all VMs
dvm ls trusted               # trusted's project containers
dvm stop trusted/api
dvm logs trusted/api -f
```

## rm

`dvm rm <vm> --yes` deletes the Lima instance; add `--config` to also remove
`~/.config/dvm/vms/<vm>`. `dvm rm <vm>/<proj> --yes` removes a project's
container and its workspace volume (the VM and siblings are untouched); add
`--keep-data` to keep the volume, or `--config` to also delete the project's
config directory.

## reset

`dvm reset <vm>/<proj> --yes` recreates a project's container from a clean
image, re-running its setup; the VM and siblings are untouched. Add `--keep-data`
to keep the workspace volume (repo, `node_modules`) while still getting a fresh
runtime. `dvm reset <vm> --yes` is the heavy form: it removes the Lima instance
and re-syncs from the base image. See
[reset](/docs/reference/projects/#reset-the-disposable-layer).

```bash
dvm reset trusted/api --yes              # clean container, re-clone, re-run setup
dvm reset trusted/api --yes --keep-data  # clean container, keep the workspace
dvm reset trusted --yes                  # rebuild the whole VM
```

## new / add

`dvm new <vm>` scaffolds `~/.config/dvm/vms/<vm>/{config.sh,setup.sh}` (and the
global config on first run). `dvm add <vm>/<proj>` scaffolds a project under an
existing VM: `projects/<proj>/{project.sh,setup.sh}`. See
[project.sh](/docs/reference/projects/#projectsh).

## base

Builds and manages the base image every VM boots from, and the dev-base image
project containers run from. See the
[base image reference](/docs/reference/base/) for the full workflow.

```bash
dvm base init                      # scaffold ~/.config/dvm/base/Containerfile
dvm base dev-init                  # scaffold the dev-base Containerfile + packages.txt
dvm base build [--clean] [--no-cache]   # build the qcow2 in the builder VM
dvm base status                    # show the cached image and builder state
dvm base rm [--builder] [--image]  # remove the builder VM and/or cached image
```
