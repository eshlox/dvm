---
title: "Config & setup scripts"
description: "Config variables, environment, and how per-VM and global setup scripts run."
---

Config is Bash. Built-in defaults load first, then global config, then per-VM
config, each overriding the last. Set a value once in global config and every VM
inherits it; per-VM config only holds what that one VM needs to differ on. The
first `dvm new` scaffolds the global config for you.

```text
~/.config/dvm/config.sh            # global config
~/.config/dvm/setup.sh             # global setup script (optional)
~/.config/dvm/vms/<vm>/config.sh   # per-VM config
~/.config/dvm/vms/<vm>/setup.sh    # per-VM setup script
```

```bash
# ~/.config/dvm/config.sh
DVM_USER=developer

# Defaults shown; uncomment to change them for every VM.
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
| `DVM_CPUS` | `2` | CPUs (oversubscribed, not pinned to host cores) |
| `DVM_MEMORY` | `2` | GiB memory (the one knob that reserves host RAM) |
| `DVM_DISK` | `30` | GiB disk (thin-provisioned ceiling, costs only what is used) |
| `DVM_USER` | `developer` | main guest user |
| `DVM_SUBUID_COUNT` | `65536` | subordinate uid range size for `DVM_USER` |
| `DVM_SUBGID_COUNT` | `65536` | subordinate gid range size for `DVM_USER` |
| `DVM_PORTS` | `()` | extra `host:guest` port forwards |

The defaults aim at a minimal but workable disposable VM: enough to run editor,
shell, AI CLIs, and a dev server at once. Bump `DVM_MEMORY` per VM for heavy
Docker builds. Lowering `DVM_DISK` saves nothing (the qcow2 disk is thin) and
only risks running out of space, so leave it unless you need a larger ceiling.

VM and `DVM_USER` names must start with a lowercase letter and contain only
lowercase letters, numbers, and hyphens.

The default subordinate id ranges support rootless Docker and Podman. Set both
counts to `0` only when the user should get no ranges. If the user already
exists, DVM adds missing ranges on the next sync.

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

## Logs

`dvm sync` shows a one-line spinner per step (`✓` on success, `✗` on failure)
and captures the full output of each step to a log, instead of printing Lima's
and your setup script's output to the terminal. Logs are per VM, under
`${XDG_STATE_HOME:-~/.local/state}/dvm/<vm>/`:

| File | Contents |
| --- | --- |
| `lima.log` | `limactl` instance create/start and guest provisioning |
| `setup.log` | global and per-VM setup-script output |

`dvm sync` truncates both at the start of each run, so they always reflect the
latest attempt. On failure DVM prints which step failed, the log path, and the
last lines of that log. Set `DVM_VERBOSE=1` to stream everything live (still
written to the logs) when debugging a VM that will not come up.

## Setup scripts

Run during `dvm sync` after the VM is created, started, and the user/project
directory exist. Both are convention-based paths, run in order when present:

1. `~/.config/dvm/setup.sh` (global, runs for every VM)
2. `~/.config/dvm/vms/<vm>/setup.sh` (per-VM)

Put shared provisioning in the global script and VM-specific steps in the per-VM
script. Neither is a config variable, so per-VM config cannot redirect the
global one.

DVM prepends `set -Eeuo pipefail` and exports these variables to each script:

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

Setup scripts are trusted provisioning code. DVM checks they are owned by you
and not group/world writable (see [troubleshooting.md](/docs/guides/troubleshooting/) to
repair). For snippets, see [examples](/docs/examples/).
