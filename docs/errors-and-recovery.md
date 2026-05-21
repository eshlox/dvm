# Errors and recovery

## Stale lock

DVM uses `~/.cache/dvm/<vm>.lock` to avoid overlapping operations. If a process
was interrupted and no DVM command is running, remove the stale directory:

```bash
rmdir ~/.cache/dvm/app.lock
```

## Failed setup

DVM does not roll back partial setup. Fix the setup script and run sync again:

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
```

Setup scripts should be idempotent. Use guards such as:

```bash
test -x /usr/local/bin/tool || sudo install -m 0755 tool /usr/local/bin/tool
```

## Missing setup script

The global setup script path must be absolute when configured:

```bash
DVM_GLOBAL_SETUP="$HOME/.config/dvm/setup.sh"
```

Per-VM setup scripts use `~/.config/dvm/vms/<vm>/setup.sh` when that file is
present.

If DVM reports unsafe permissions:

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh
chmod go-w ~/.config/dvm/vms/app ~/.config/dvm/vms/app/config.sh
chmod go-w ~/.config/dvm/vms/app/setup.sh
```

## Debug

```bash
dvm ls --only-config
dvm ssh app -- true
dvm ssh app -- sudo journalctl -f
```

Use Lima directly for deeper VM inspection:

```bash
limactl list
limactl shell dvm-app
```
