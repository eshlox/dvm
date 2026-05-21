# Config

DVM config is Bash.

```text
~/.config/dvm/config.sh
~/.config/dvm/vms/<vm>/config.sh
~/.config/dvm/vms/<vm>/setup.sh
```

Global config loads first. VM config overrides it.

## Example

```bash
# ~/.config/dvm/config.sh
DVM_TEMPLATE=template:fedora
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
| `DVM_TEMPLATE` | `template:fedora` | Lima template name or local template path |
| `DVM_CPUS` | `2` | CPUs |
| `DVM_MEMORY` | `4` | GiB memory |
| `DVM_DISK` | `30` | GiB disk |
| `DVM_USER` | `developer` | main guest user |
| `DVM_PORTS` | `()` | `host:guest` port forwards |
| `DVM_GLOBAL_SETUP` | empty | absolute host path to setup script run for every VM |

Names for VMs and `DVM_USER` must start with a lowercase letter and contain
only lowercase letters, numbers, and hyphens.

The per-VM setup script uses the conventional path:

```text
~/.config/dvm/vms/app/setup.sh
```

## Setup scripts

Setup scripts run during `dvm sync` after the VM is created, started, and the
guest user/project directory exist.

Order:

1. `DVM_GLOBAL_SETUP`
2. `~/.config/dvm/vms/<vm>/setup.sh`, when present

Scripts receive:

| Variable | Meaning |
| --- | --- |
| `DVM_NAME` | VM name from DVM config |
| `DVM_VM` | same as `DVM_NAME` |
| `DVM_LIMA_NAME` | Lima instance name, such as `dvm-app` |
| `DVM_USER` | guest development user |
| `DVM_CODE_DIR` | guest project directory |
| `DVM_PORTS` | comma-separated port forwards |

Setup scripts are trusted provisioning code. DVM checks that configured scripts
are owned by the current host user and are not group/world writable.

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh
chmod go-w ~/.config/dvm/vms/app ~/.config/dvm/vms/app/config.sh
chmod go-w ~/.config/dvm/vms/app/setup.sh
```
