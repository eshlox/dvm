# Uninstall

Remove DVM in this order so you can still use `dvm list` before deleting the command.

## Remove DVM VMs

List VMs:

```bash
dvm list
```

Delete each VM:

```bash
dvm rm app
dvm rm ai
dvm rm cloudflared
```

If a VM is broken and cannot start for the dirty-repo check, use `--force` only after
you accept that uncommitted work inside the VM may be lost:

```bash
dvm rm app --force
```

If the `dvm` command is already gone, remove matching Lima instances directly:

```bash
limactl list
limactl delete --force dvm-app
```

## Remove The Command

Default install:

```bash
rm -f "$HOME/.local/bin/dvm"
```

If you installed with a custom `--prefix` or `--name`, remove that symlink instead.

## Remove Config And State

Default paths:

```bash
rm -rf "$HOME/.config/dvm"
rm -rf "$HOME/.local/share/dvm"
```

If you used custom `DVM_CONFIG` or `DVM_STATE`, remove those paths instead.

## Remove The Core Checkout

If you cloned DVM into the suggested path:

```bash
rm -rf "$HOME/.local/share/dvm-core"
```

If the repository lives somewhere else, remove that checkout manually.

## Optional Lima Cleanup

Do this only if you do not use Lima for anything else. These paths are Lima-wide, not
DVM-specific:

```bash
brew uninstall lima
rm -rf "$HOME/.lima"
rm -rf "$HOME/Library/Caches/lima"
```

Cloudflare note: deleting a `cloudflared` VM stops the connector, but it does not
delete the Cloudflare Tunnel, public hostname, DNS record, or token in Cloudflare.
Remove or rotate those in the Cloudflare dashboard if needed.
