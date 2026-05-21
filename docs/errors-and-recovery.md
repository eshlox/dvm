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

Configured setup script paths must be absolute and must exist:

```bash
DVM_SETUP="$DVM_CONFIG_DIR/vms/app.setup.sh"
```

If DVM reports unsafe permissions:

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh
chmod go-w ~/.config/dvm/vms/app.sh ~/.config/dvm/vms/app.setup.sh
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
