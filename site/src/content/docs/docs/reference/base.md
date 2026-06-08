---
title: "Base image"
description: "Bake your tooling once into a base image so every VM boots ready instead of re-provisioning from scratch."
---

A base image bakes your tooling once so every `dvm sync` boots a ready VM
instead of downloading Fedora and re-running a large setup each time. It is the
fix for two problems at once: slow VM creation, and a setup script that has
grown long because every VM installs the same things.

When a base image exists, `dvm sync` boots from it. When it does not, `dvm sync`
falls back to Lima's `template:fedora` and your setup scripts, exactly as
before. The base image is opt-in: nothing breaks without one.

## How it is built

DVM owns a small **plumbing** layer, the `dvm-base` image: compressed swap
(zram), the rootless-docker user service, and a binfmt mask. You never edit it;
it is generated from the installed `dvm`, so updates land on your next build.

Your **Containerfile** starts `FROM dvm-base` and adds your packages and
binaries on top. It is a normal Containerfile, so anything you already know
about Docker or Podman builds applies.

The build itself runs in a throwaway Lima VM (`dvm-builder`) with Podman and
[bootc-image-builder](https://github.com/osbuild/bootc-image-builder). That VM
is the only place Podman is needed, so the host stays Lima-only. The resulting
qcow2 is copied to the host cache and every VM boots from it.

```text
~/.config/dvm/base/Containerfile   # yours: FROM dvm-base + your tools
~/.cache/dvm/base/disk.qcow2        # built image every VM boots from
~/.cache/dvm/base/metadata.json     # build time, arch, bootc base
```

## What is baked vs. per VM

The base image holds only system-wide tooling and config. The developer user,
SSH keys, and dotfiles are still created per VM at `dvm sync`, so each VM keeps
its own identity and state.

| Baked into the image | Created per VM at sync |
| --- | --- |
| packages, upstream binaries, language toolchains, AI CLIs | `DVM_USER` and the project directory |
| zram, sysctl, the rootless-docker unit, binfmt mask | subordinate uid/gid ranges |
| anything in your Containerfile | per-VM `setup.sh` (keys, dotfiles, tunnels) |

This split is deliberate: the slow, identical work is baked once, and the
unique, stateful work stays where it belongs.

## Commands

```bash
dvm base init                      # scaffold ~/.config/dvm/base/Containerfile
dvm base build                     # build the qcow2 in the builder VM
dvm base build --clean             # rebuild from a fresh builder (no podman cache)
dvm base build --no-cache          # rebuild without the podman layer cache
dvm base status                    # show the cached image and builder state
dvm base rm                        # remove the builder VM and cached image
dvm base rm --image                # remove only the cached image
dvm base rm --builder              # remove only the builder VM
```

### init

Writes a starter `~/.config/dvm/base/Containerfile` with a packages layer and a
commented pattern for pinned upstream binaries. Edit it, then build.

### build

Ensures the builder VM exists, installs Podman and bootc-image-builder in it,
ships your base directory in as the build context, builds `dvm-base` then your
image `FROM` it, assembles a qcow2, and swaps it into the cache atomically. A
failed build never replaces a working image.

The builder is **persistent** by default so its Podman layer cache stays warm:
changing one line in your Containerfile rebuilds only the affected layer, not
everything. Use `--clean` to start from a fresh builder when you want a fully
cold build.

## Building the image

The build runs entirely inside the builder VM. bootc-image-builder only
assembles a disk from the image's root filesystem, so no nested virtualization
is required. Give the builder enough disk for the Podman storage plus the
output qcow2 (`DVM_BUILDER_DISK` defaults to 50 GiB).

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_BASE_DIR` | `~/.config/dvm/base` | your Containerfile and build context |
| `DVM_BASE_IMAGE` | `~/.cache/dvm/base/disk.qcow2` | the built image VMs boot from |
| `DVM_BUILDER_LIMA` | `dvm-builder` | name of the builder Lima instance |
| `DVM_BUILDER_MEMORY` | `4` | builder memory in GiB |
| `DVM_BUILDER_DISK` | `50` | builder disk in GiB |
| `DVM_BOOTC_BASE` | `fedora-bootc`, digest-pinned in `bin/dvm` | image `dvm-base` is built from |
| `DVM_BISC_IMAGE` | `bootc-image-builder`, digest-pinned in `bin/dvm` | the disk-image builder |

### Pinning and trust

`dvm base build` builds `dvm-base` from `DVM_BOOTC_BASE` and runs `DVM_BISC_IMAGE`
as a privileged container in the builder; that container's output becomes the
base image every VM boots from. Both are pinned by digest in `bin/dvm` and
maintained there, the same way dvm pins upstream binaries by SHA256, so a moved
tag can never silently change what is baked. A weekly `Update pins` GitHub
Actions workflow runs `scripts/update-pins` and opens a pull request whenever a
tracked tag's digest changes, so the pins stay current without manual SHA
hunting. The tracked tag for each pin is the `# track:` comment beside it. You
do not set these per machine. The base image variables (`DVM_BOOTC_BASE`,
`DVM_BISC_IMAGE`, and the `DVM_BASE_*`/`DVM_BUILDER_*` paths) are read from the
environment only, not `config.sh`; override via the environment for a custom
base.

The privileged container runs only in the throwaway builder VM, never on the
host or in project VMs.

## Reserved names

`base` and the builder instance name (`DVM_BUILDER_LIMA`, default `dvm-builder`)
are reserved. `dvm new`, `dvm sync`, `dvm rm`, and the other VM commands refuse a
VM name that would collide with the base-image workflow, so you cannot
accidentally provision or delete the builder. The builder is also hidden from
`dvm ls` and `dvm stop --all`; manage it with `dvm base`.

## Updating

To change what every VM ships, edit your Containerfile and run `dvm base build`,
then recreate VMs (`dvm rm <vm> --yes` then `dvm sync <vm>`) to boot the new
image. Because VMs use `--mount-none`, project code lives inside the VM, so
recreating a VM discards it; commit or push first.

Updating the dvm-base plumbing happens automatically: each build regenerates it
from the installed `dvm`, so pulling a newer `dvm` and rebuilding is enough.

## Migrating an existing setup script

Shared tooling that used to live in a long per-VM (or formerly global) setup
script maps onto the Containerfile by category. Package installs and upstream
binary downloads move into Containerfile layers; the rest stays per VM:

```dockerfile
# ~/.config/dvm/base/Containerfile
FROM dvm-base

RUN dnf5 install -y --setopt=install_weak_deps=False \
        git git-delta helix bat fzf just chezmoi \
        nodejs npm podman moby-engine moby-engine-rootless-extras \
    && dnf5 clean all

ARG ZELLIJ_VERSION=0.44.3
ARG ZELLIJ_SHA256=replace-with-release-sha256
RUN url="https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-aarch64-unknown-linux-musl.tar.gz" \
 && curl -fsSL "$url" -o /tmp/z.tgz \
 && echo "${ZELLIJ_SHA256}  /tmp/z.tgz" | sha256sum -c - \
 && tar -xzf /tmp/z.tgz -C /usr/local/bin zellij && rm /tmp/z.tgz

RUN npm install -g @anthropic-ai/claude-code @openai/codex
```

SSH keys, dotfiles, and per-tunnel config stay in the per-VM
`~/.config/dvm/vms/<vm>/setup.sh`, since they are unique to each VM. See
[Examples](/docs/examples/) for the snippets.
