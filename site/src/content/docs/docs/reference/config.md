---
title: "Config & setup scripts"
description: "Config variables, environment, and how the per-VM setup script runs."
---

Config is Bash. Built-in defaults load first, then global config, then per-VM
config, each overriding the last. Set a value once in global config and every VM
inherits it; per-VM config only holds what that one VM needs to differ on. The
first `dvm new` scaffolds the global config for you.

```text
~/.config/dvm/config.sh            # global config
~/.config/dvm/base/Containerfile   # base image definition (optional)
~/.config/dvm/vms/<vm>/config.sh   # per-VM config
~/.config/dvm/vms/<vm>/setup.sh    # per-VM setup script
```

Shared tooling is baked once into the [base image](/docs/reference/base/)
Containerfile. The per-VM `setup.sh` runs for VM-specific, stateful steps (SSH
keys, dotfiles, tunnels).

```bash
# ~/.config/dvm/config.sh
DVM_USER=developer

# DVM_CPUS auto-detects from host cores; memory and disk use the values below.
# Uncomment any line to pin it for every VM.
# DVM_CPUS=2
# DVM_MEMORY=2
# DVM_DISK=30
```

```bash
# ~/.config/dvm/vms/app/config.sh
# Only what this VM needs beyond the global config.
DVM_MEMORY=4
DVM_PORTS=(3000:3000 5173:5173)
```

## Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_CPUS` | host cores minus 1-2 (min 2) | vCPUs, a time-shared ceiling not pinned to host cores |
| `DVM_MEMORY` | `2` | GiB memory (the one knob that reserves host RAM) |
| `DVM_DISK` | `30` | GiB disk (thin-provisioned ceiling, costs only what is used) |
| `DVM_USER` | `developer` | main guest user |
| `DVM_SUBUID_COUNT` | `65536` | subordinate uid range size for `DVM_USER` |
| `DVM_SUBGID_COUNT` | `65536` | subordinate gid range size for `DVM_USER` |
| `DVM_PORTS` | `()` | extra `host:guest` port forwards |
| `DVM_VM_TYPE` | unset | Lima VM type; set `vz` on Apple Silicon for lighter overhead |

The defaults aim at a minimal but workable disposable VM: enough to run editor,
shell, AI CLIs, and a dev server at once. Bump `DVM_MEMORY` per VM for heavy
Docker builds. Lowering `DVM_DISK` saves nothing (the qcow2 disk is thin) and
only risks running out of space, so leave it unless you need a larger ceiling.

### CPUs vs memory

`DVM_CPUS` and `DVM_MEMORY` behave differently, which is why only one of them
auto-detects:

- **CPUs are time-shared, not reserved.** A vCPU is just a host thread that the
  host scheduler runs on a physical core only when the guest has work. An idle
  VM's vCPUs consume effectively no host CPU, and a busy VM can burst up to its
  vCPU count. So `DVM_CPUS` is a per-VM ceiling, not a slice carved out of the
  host: five idle VMs do not stop a sixth from using every core. Because of
  this, the default leaves the host a small reserve (1 core on hosts up to 4
  cores, 2 beyond, floored at 2) so the host and `dvm`/`limactl` stay responsive
  when one VM saturates its share. Oversubscribing is safe; the only cost is
  contention (visible as guest "steal time") when several VMs are busy at once.
- **Memory is reserved.** Depending on the Lima backend, `DVM_MEMORY` is
  committed up front, so it does not auto-scale and `5 × max` would over-commit
  the host and fail to start or push it into swap. Set it to what each VM
  actually needs.

To override the auto-detected CPU count, set `DVM_CPUS` globally or per VM.
Existing VMs keep the value they were created with; changing the default only
affects VMs created afterward.

VM and `DVM_USER` names must start with a lowercase letter and contain only
lowercase letters, numbers, and hyphens.

The default subordinate id ranges support rootless Docker and Podman. Set both
counts to `0` only when the user should get no ranges. If the user already
exists, DVM adds missing ranges on the next sync.

`DVM_VM_TYPE` is empty by default, letting Lima pick its backend (QEMU). On
Apple Silicon, `DVM_VM_TYPE=vz` uses Apple's Virtualization framework, which has
lighter overhead and lets the host reclaim idle VM memory more readily, useful
when running many VMs at once.

## Environment

These are read from the environment at invocation, not from `config.sh`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_VERBOSE` | `0` | `1` streams the full output live instead of running steps behind the spinner |
| `DVM_LIMA_LOG_LEVEL` | `warn` | Lima log level passed to `limactl --log-level` (`info` when `DVM_VERBOSE=1`) |
| `DVM_DRY_RUN` | `0` | `1` prints the `limactl start` argv and setup plan without contacting Lima |
| `NO_COLOR` | unset | set (to anything) to disable colored progress output and the spinner |
| `DVM_CONFIG_DIR` | `~/.config/dvm` | config location |
| `DVM_CACHE_DIR` | `~/.cache/dvm` | lock-file location |
| `DVM_STATE_DIR` | `~/.local/state/dvm` | per-VM log location |
| `DVM_LIMACTL` | `limactl` | path to the `limactl` binary |

These configure the [base image](/docs/reference/base/) build:

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_BASE_DIR` | `~/.config/dvm/base` | Containerfile and build context |
| `DVM_BASE_IMAGE` | `~/.cache/dvm/base/disk.qcow2` | built image VMs boot from |
| `DVM_BUILDER_LIMA` | `dvm-builder` | builder Lima instance name |
| `DVM_BUILDER_MEMORY` | `4` | builder memory (GiB) |
| `DVM_BUILDER_DISK` | `50` | builder disk (GiB) |
| `DVM_BOOTC_BASE` | `fedora-bootc`, digest-pinned in `bin/dvm` | image `dvm-base` is built from |
| `DVM_BISC_IMAGE` | `bootc-image-builder`, digest-pinned in `bin/dvm` | disk-image builder |

## Logs

`dvm sync` shows a one-line spinner per step (`✓` on success, `✗` on failure)
and captures the full output of each step to a log, instead of printing Lima's
and your setup script's output to the terminal. Logs are per VM, under
`${XDG_STATE_HOME:-~/.local/state}/dvm/<vm>/`:

| File | Contents |
| --- | --- |
| `lima.log` | `limactl` instance create/start and guest provisioning |
| `setup.log` | per-VM setup-script output |

`dvm sync` truncates both at the start of each run, so they always reflect the
latest attempt. On failure DVM prints which step failed, the log path, and the
last lines of that log. Set `DVM_VERBOSE=1` to stream everything live (still
written to the logs) when debugging a VM that will not come up.

## Setup scripts

The per-VM setup script, `~/.config/dvm/vms/<vm>/setup.sh`, runs during
`dvm sync` after the VM is created, started, and the user/project directory
exist. It is convention-based and runs when present.

Put VM-specific, stateful steps here (SSH keys, dotfiles, tunnels). Shared
tooling that every VM installs belongs in the [base image](/docs/reference/base/)
Containerfile, baked once, rather than re-run on every sync.

DVM prepends `set -Eeuo pipefail` and exports these variables to the script:

| Variable | Meaning |
| --- | --- |
| `DVM_NAME` | VM name from config |
| `DVM_VM` | same as `DVM_NAME` |
| `DVM_LIMA_NAME` | Lima instance name, such as `dvm-app` |
| `DVM_USER` | guest dev user |
| `DVM_CODE_DIR` | guest project directory |
| `DVM_PORTS` | comma-separated port forwards |
| `DVM_SUBUID_COUNT` | configured subordinate uid range size |
| `DVM_SUBGID_COUNT` | configured subordinate gid range size |

The setup script is trusted provisioning code. DVM checks it is owned by you
and not group/world writable (see [troubleshooting.md](/docs/guides/troubleshooting/) to
repair). For snippets, see [examples](/docs/examples/).
