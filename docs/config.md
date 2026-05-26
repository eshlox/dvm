# Config

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
and not group/world writable (see [troubleshooting.md](troubleshooting.md) to
repair). For snippets, see [examples](../examples/README.md).
