---
title: "Trust tiers & project containers"
description: "Group projects by trust tier in one pool VM, run each as a disposable rootless-podman container, and reset a project in seconds."
---

A VM per project is the strongest isolation DVM offers, but with ten projects it
costs real RAM and per-VM setup. Project containers add a lighter layer on top of
the same boundary: one **pool VM** per trust tier, and one **rootless-podman
container per project** inside it.

```text
VM (trust tier)   durable boundary that protects the host   strong: separate kernel
  └─ container    disposable boundary between projects       weaker: shared kernel
```

The VM is your durable boundary, reset rarely. Containers are disposable and
reset in seconds. Projects are addressed `<vm>/<project>`.

## The model

Instead of ten VMs, keep a few VMs grouped by **trust tier** (`trusted`,
`untrusted`, `clientx`), each running several project containers. Each project
container gets:

- its **own writable workspace** (a named podman volume `dvm-<vm>-<proj>`) that
  survives container recreation, so code and `node_modules` persist across a
  reset unless you wipe the volume too;
- its **own user namespace and filesystem**, so a poisoned `npm install` in one
  project cannot read another project's source, tokens, or keys, and none of
  them can touch the host;
- its **own published ports**, forwarded out through Lima to localhost.

The rule: **a trust tier is a VM; never mix tiers in one VM.** Genuinely hostile
code still gets its own VM (`dvm new untrusted` with a single project, or no
container at all). Containers in one VM share the guest kernel, so a kernel-level
escape from one could reach a sibling. That is fine for "all my own
semi-trusted projects"; it is not a sandbox for untrusted code.

## Walkthrough

```bash
dvm new   trusted                # a pool VM for trusted projects
dvm add   trusted/api            # define a project (a container) in it
dvm add   trusted/web            # and another
dvm sync  trusted                # build the dev-base, bring up every container
dvm sh    trusted/api            # shell into the api container, in its workspace
dvm reset trusted/api --yes      # recreate just api; web and the VM untouched
dvm rm    trusted/web --yes      # drop one project
```

`dvm add` writes `~/.config/dvm/vms/<vm>/projects/<proj>/{project.sh,setup.sh}`.
`project.sh` is a container spec, sourced like `config.sh`; `setup.sh` runs
**inside the container** on every sync (clone the repo, `npm ci`, sign in).

`dvm sync <vm>` brings up every project in the VM. `dvm sync <vm>/<proj>` brings
up one. `dvm ls <vm>` lists a VM's projects with container state and image;
`dvm logs <vm>/<proj> [-f]` tails a container's logs; `dvm stop <vm>/<proj>`
stops one. `dvm sh`, `dvm ssh`, and `dvm cp` all take a `<vm>/<proj>` target and
operate on the container instead of the VM.

## project.sh

```bash
# ~/.config/dvm/vms/trusted/projects/api/project.sh

# Container image. Defaults to the dev-base (or bare Fedora) when unset.
# IMAGE=node:22

# Run this project's own containers (podman/compose for postgres, redis, ...).
# Exposes /dev/fuse and relaxes SELinux so rootless podman can nest. Off by
# default so non-nesting projects stay confined.
# NESTED=1

# Working directory and the mount point of the persistent workspace volume
# dvm-trusted-api (survives container recreation).
# PROJ_WORKDIR=/work

# Ports to publish. Published on the VM's loopback; Lima forwards guest
# 127.0.0.1 ports to the host, so the dev server is reachable at localhost.
# Ports are fixed at create time; change them with `dvm reset`.
# PROJ_PORTS=(3000:3000)
```

`IMAGE` defaults to `DVM_DEV_BASE`: `localhost/dvm-dev-base:latest` when a
dev-base is configured, otherwise bare Fedora. Set `DVM_DEV_BASE` in `config.sh`
or `IMAGE` per project to override.

## reset: the disposable layer

`limactl snapshot` is QEMU-only, so on the `vz` driver DVM defaults to on Apple
Silicon there is no VM snapshot to revert to. `reset` instead recreates the
disposable layer from a clean base, which is the better model anyway since code
is meant to be committed and pushed (`--mount-none`).

```bash
dvm reset trusted/api --yes              # recreate the container, re-clone, re-run setup
dvm reset trusted/api --yes --keep-data  # fresh container, keep the workspace volume
dvm reset trusted --yes                  # rebuild the whole VM from base (the heavy reset)
```

`--keep-data` gives a fresh OS and tools (dropping anything that hooked the
runtime) while keeping the repo and `node_modules`. Omit it for a total wipe
that re-clones from scratch. That is the "something feels off, give me a clean
runtime in five seconds" button, scoped to one project.

The whole-VM form (`dvm reset <vm>`) removes the Lima instance and re-syncs from
the base image. It works on `vz` precisely because it rebuilds rather than
reverting a snapshot.

## dev-base: shared tools, baked once

Project containers run `FROM` a dev-base image so tools are installed once and
shared across containers, instead of per-container installs on every sync.

```bash
dvm base dev-init     # scaffold ~/.config/dvm/base/dev/Containerfile + packages.txt
dvm sync trusted      # builds localhost/dvm-dev-base into the VM, then the projects
```

Tools listed in the shared `packages.txt` are installed into both the VM base
image and the dev-base container image, so the VM and its containers converge on
one tool list. DVM builds `localhost/dvm-dev-base` into each VM on sync and
rebuilds it when the dev directory or `packages.txt` changes (tracked by a hash
label) or when `DVM_REBUILD_DEV_BASE=1`. See the
[base image reference](/docs/reference/base/#dev-base-for-project-containers).

## Nesting (compose)

Set `NESTED=1` in `project.sh` when a project runs its own containers, e.g.
`podman compose` for postgres or redis. It adds `--device /dev/fuse` and
`--security-opt label=disable` so rootless podman can nest. The image must have
`podman` and `fuse-overlayfs` (the dev-base does; for another image, install
them in `setup.sh`). It is off by default because it relaxes SELinux
confinement, so leave non-nesting projects without it.

## Storage and persistence

Containers are created `--restart=always` with `podman-restart` enabled, so they
return after a VM reboot; `sh`, `ssh`, and `cp` also start a stopped container.
Project images and layers live in the VM's disk (`DVM_DISK`, default 30 GiB);
ten Node projects sharing one base is far cheaper than ten VMs, but raise
`DVM_DISK` for a busy pool. To reclaim space, prune dangling images from inside
the VM, e.g. `dvm ssh <vm> -- podman image prune -f`.

## When to use which

- **VM per project** when projects must not share a kernel (untrusted code,
  separate clients, the strongest boundary).
- **Project containers in a pool VM** for several of your own semi-trusted
  projects that you want cheap, granular, per-project reset for.
