# Errors And Recovery

## Stale Lock

Mutating commands create:

```text
~/.cache/dvm/<vm>.lock
```

DVM also uses `~/.cache/dvm/<DVM_BASE_NAME>.lock` for `dvm base build` and
`dvm base rm`; new clones from a base refuse to start while that base lock is
present. DVM removes locks on normal exit. If the host crashes or the process
is killed hard, the directory can remain. When you are sure no `dvm` process
is running, remove it:

```bash
rm -r ~/.cache/dvm/app.lock
```

## Sync Fails Halfway

Recipes are meant to be idempotent. If a sync fails after some packages or
services were installed, inspect the error, fix the recipe/config/env, then run
the same sync again:

```bash
dvm sync app
```

DVM does not roll recipes back. A partial VM is expected; re-running sync is
the recovery path.

## Inspect A Half-Built VM

```bash
dvm sh app
```

Then inspect `dnf5` logs, systemd units, service state, or files under
`/home/<DVM_USER>/code/<vm>`.

## Preview What Will Run

```bash
DVM_DRY_RUN=1 dvm sync app
DVM_DRY_RUN=1 dvm base build
```

Dry-run prints the Lima argv and guest script without contacting Lima.

## Service Auth Keys

Tailscale and Cloudflare Tunnel recipes skip authentication when their secret
is not staged. Stage secrets only for the sync that needs them:

```bash
DVM_TAILSCALE_AUTHKEY=tskey-... dvm sync demo
```

If a single-use key was already consumed, create a new key and re-run sync.
When a secret is staged and the service authentication command fails, `dvm sync`
fails so the broken setup is visible.

Staged secrets live under randomized `/run/dvm-secrets` paths. DVM renders a
guest cleanup trap and also attempts host-side cleanup after the guest script
exits. If a VM is interrupted mid-sync, inspect `/run/dvm-secrets` inside that
guest and remove stale files with `sudo rm -r /run/dvm-secrets/<stale-dir>`.
