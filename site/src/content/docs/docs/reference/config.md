---
title: "Config & setup scripts"
description: "Config variables, environment, and how per-VM and global setup scripts run."
---

Config is Bash. Global loads first, per-VM config overrides it.

```text
~/.config/dvm/config.sh            # global
~/.config/dvm/vms/<vm>/config.sh   # per-VM
~/.config/dvm/vms/<vm>/setup.sh    # per-VM setup script
```

```bash
# ~/.config/dvm/config.sh
DVM_CPUS=2
DVM_MEMORY=4
DVM_DISK=30
DVM_USER=developer
DVM_GLOBAL_SETUP="$HOME/.config/dvm/setup.sh"
```

```bash
# ~/.config/dvm/vms/app/config.sh
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
```

## Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `DVM_CPUS` | `2` | CPUs |
| `DVM_MEMORY` | `4` | GiB memory |
| `DVM_DISK` | `30` | GiB disk |
| `DVM_USER` | `developer` | main guest user |
| `DVM_SUBUID_COUNT` | `65536` | subordinate uid range size for `DVM_USER` |
| `DVM_SUBGID_COUNT` | `65536` | subordinate gid range size for `DVM_USER` |
| `DVM_PORTS` | `()` | `host:guest` port forwards |
| `DVM_GLOBAL_SETUP` | empty | absolute host path to a setup script run for every VM |

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
directory exist. Order:

1. `DVM_GLOBAL_SETUP`
2. `~/.config/dvm/vms/<vm>/setup.sh`, when present

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
