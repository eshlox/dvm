# Security Standards

The operating rules. Short because the implementation is small.

## Isolation

- One project, one VM.
- Host code is never mounted into a guest. Code lives in the VM.
- `~` in DVM config means **guest** home; the script expands it before
  passing paths to Lima.
- Recreate is `dvm rm <vm> --yes && dvm sync <vm>`. No state to
  preserve outside the VM.

## Secrets

- Do not put secrets in `DVM_*` config files or recipes. Host env on
  the host is visible to other processes while `limactl` runs.
- Use `DVM_SECRETS=(NAME ...)` and pass values at sync time:
  `NAME=value dvm sync <vm>`. The value is piped through stdin to a
  mode-`0600` guest temp file (`/tmp/dvm-secret-<NAME>`); it never
  appears in argv, host process env, or a host temp file.
- Recipes read via `dvm_secret <NAME>`, which prints the temp file path.
- Do not copy host SSH/GPG private keys into VMs. Generate VM-local
  keys with `dvm ssh-key <vm>` and `dvm gpg-key <vm>`.
- `ssh-key` creates separate access (`id_ed25519_dvm`) and signing
  (`id_ed25519_dvm_signing`) keys. Don't reuse a deploy key as a
  signing key.
- The VM-local GPG key has no passphrase. It's a disposable signing
  key for VM commits, not a long-lived identity.

## AI

- Hosted AI tools run as `dvm-agent` inside Bubblewrap. There is no
  non-sandboxed mode.
- `dvm-agent` is a system account with no DVM-managed sudo.
- Sandbox mounts: `/workspace` ← `DVM_CODE_DIR`, agent home, runtime
  system bits. The primary user's home is **not** mounted.
- Codex / Claude run unattended (`DVM_CODEX_YOLO=1`, `DVM_CLAUDE_BYPASS=1`)
  by default. The VM + sandbox is the boundary, not per-action prompts.
  Flip to `0` if you want native prompts.
- ACLs on `DVM_CODE_DIR` are defense-in-depth, not isolation. Guest
  root or bad sudo policy can still bypass.
- Treat AI output as untrusted code until reviewed.

## Networking

- Forwarded ports bind to `DVM_HOST_IP` (default `127.0.0.1`).
- `0.0.0.0` only when you really want LAN exposure.
- Service VMs (`llama`, `cloudflared`, `tailscale`) live in their own
  VMs and are reached by other VMs via `lima-dvm-<name>.internal`.

## Deletion

- `dvm rm <vm> --yes` stops and deletes the Lima instance. No dirty
  check. Inspect with `dvm sh <vm>` first if you might lose work.
- The per-VM config in `~/.config/dvm/vms/` is **not** deleted; remove
  by hand.

## Recipes

- Idempotent shell. Same recipe runs on every sync.
- Use `dvm_pkg` for package installs; don't shell out to `dnf` directly.
- Use `dvm_secret <NAME>` to access staged secrets.
- Pinned binary installs use `dvm_install_pinned` with a verified
  sha256. Update version, URL, and sha256 together.
- Recipes never read host paths.

## Host

- Keep host deps small: Lima, bash, flock, envsubst, sudo.
- Install from a reviewed checkout. `install.sh` is a symlink only;
  `git pull` is the update.
- Run `bash tests/smoke.sh` before merging changes.
