---
title: "Troubleshooting"
description: "Common errors and how to recover from them."
---

## Stale lock

DVM uses `~/.cache/dvm/<vm>.lock` to avoid overlapping operations. If a process
was interrupted and no DVM command is running, remove the stale directory:

```bash
rmdir ~/.cache/dvm/app.lock
```

## Failed setup

DVM does not roll back partial setup. Fix the script and sync again. Make setup
scripts idempotent:

```bash
test -x /usr/local/bin/tool || sudo install -m 0755 tool /usr/local/bin/tool
```

## Unsafe permissions

DVM refuses config and setup scripts that are not owned by you or are
group/world writable. Repair:

```bash
chmod go-w ~/.config/dvm ~/.config/dvm/config.sh
chmod go-w ~/.config/dvm/vms/app ~/.config/dvm/vms/app/config.sh
chmod go-w ~/.config/dvm/vms/app/setup.sh
```

The per-VM setup script runs by convention from
`~/.config/dvm/vms/<vm>/setup.sh`. It is not a config variable; create the file
to enable it, remove it to disable it.

## systemd-binfmt failed on aarch64 Lima

On some aarch64 Lima images `systemd-binfmt.service` reports `failed` even though
the VM needs no foreign binary format handlers. It is harmless, but it makes
`systemctl --failed` noisy. Mask it from a setup script to keep boot clean:

```bash
sudo systemctl mask --now systemd-binfmt.service || true
sudo systemctl reset-failed systemd-binfmt.service || true
```

Skip this if you actually run foreign-architecture binaries in the guest.

## Debug

```bash
DVM_DRY_RUN=1 dvm sync app
dvm ls --only-config
dvm ssh app -- true
dvm ssh app -- sudo journalctl -f
```

Use Lima directly for deeper inspection:

```bash
limactl list
limactl shell dvm-app
```
