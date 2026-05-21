# Errors And Recovery

## Stale Lock

Locks live in:

```text
~/.cache/dvm/<vm>.lock
```

Base operations use `~/.cache/dvm/<DVM_BASE_NAME>.lock`. If a process was
killed and no `dvm` command is running, remove the stale lock:

```bash
rm -r ~/.cache/dvm/app.lock
```

## Failed Sync

DVM does not roll back partial setup. Fix the package, recipe, config, or env
var, then rerun:

```bash
dvm sync app
```

Inspect the VM:

```bash
dvm sh app
dvm log app -f
```

Preview generated commands:

```bash
DVM_DRY_RUN=1 dvm sync app
```

## Secrets

Secrets are cleaned by the guest script and host wrapper. After a hard
interruption, stale guest files may remain under `/run/dvm-secrets`:

```bash
sudo rm -r /run/dvm-secrets/<stale-dir>
```

If a one-use service key was consumed, create a new one and rerun sync.
