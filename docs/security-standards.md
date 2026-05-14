# Security Standards

The operating rules. Short because the implementation is small.

## Isolation

- One project, one VM.
- Host code is **never** mounted into a guest. Code lives at
  `/home/$DVM_USER/code/<vm>` and is cloned by Ansible.
- A compromised guest or AI agent cannot directly rewrite the host checkout.
  Recreate is `dvm rm <vm> --yes && dvm sync <vm>`; no on-host state to
  preserve.

## Secrets

DVM does not handle secrets. It never reads them, stages them, or passes
them on command lines. Handle secrets inside the external Ansible repo:

- **Ansible Vault** for long-lived material (signing keys, persistent
  tokens).
- `lookup('env', 'NAME')` for one-shot secrets you `export` before
  `dvm sync`.
- `no_log: true` on every task that touches a secret value.

DVM rejects entries in `DVM_ANSIBLE_EXTRA_VARS` whose name contains
`token`, `password`, `secret`, or that look like `key=…`. That check is a
guard against accidents, not a security boundary.

`DVM_ANSIBLE_EXTRA_ARGS` is **not** filtered — it's an escape hatch for
flags like `--check --diff`, `-K`, `--ask-vault-pass`. Do not put secret
values there; they'd land directly in the `ansible-playbook` argv.

### Shell history is still a leak vector

`DVM_TAILSCALE_AUTHKEY="actualsecret" dvm sync vm` puts the value in your
shell history if it reaches a child of dvm. Same three options apply as
before DVM:

1. **macOS Keychain (no plaintext on disk):**
   ```bash
   security add-generic-password -a "$USER" -s dvm-ts -w "$TOKEN"
   DVM_TAILSCALE_AUTHKEY="$(security find-generic-password \
       -a "$USER" -s dvm-ts -w)" dvm sync tail
   ```

2. **1Password CLI or similar:**
   ```bash
   DVM_TAILSCALE_AUTHKEY="$(op read op://Personal/ts/key)" dvm sync tail
   ```

3. **Leading-space + `HISTCONTROL=ignorespace`:** type ` DVM_X="..." dvm
   sync vm` (note the leading space).

## VM identity

SSH and GPG identity belong to the Ansible repo, not DVM.

- `dvm_keys_mode: generate` (recommended): the Ansible `keys` role makes
  ed25519 keys inside the VM if missing, prints the public material,
  configures git signing. Private keys never leave the VM.
- `dvm_keys_mode: vault`: the role restores encrypted private keys from
  Ansible Vault with strict file modes and `no_log: true`.

DVM does not back up keys, copy host SSH/GPG keys into the guest, or
re-import on recreate. Recreating a VM either generates a fresh identity
(register the new key with your git host) or restores the vaulted key
material. See [ansible/examples/keys.yml](ansible/examples/keys.yml).

## AI tooling

AI tools (Codex, Claude, OpenCode, …) run as the unprivileged
`dvm-agent` account inside a Bubblewrap sandbox. Two roles, separated
on purpose:

- **`agent_user`** owns identity: it creates the `dvm-agent` user, adds
  it to `{{ dvm_user }}`'s group (so the sandbox can write to project
  code), and writes a sudo rule allowing `dvm_user → dvm-agent` (one
  direction only).
- **`sandbox`** owns runtime: it installs `bubblewrap` and writes
  `/usr/local/bin/dvm-agent`, a wrapper that runs an arbitrary command
  as the agent user inside bwrap.

What the bwrap wrapper actually guarantees:

- `/workspace` (= `dvm_code_dir`) is the only writable path on the
  project side. Code lives there; the agent can edit it.
- The agent's own `$HOME` is private and writable. Tool state
  (`~/.codex`, `~/.claude`, …) lives there.
- Everything else is read-only.
- `/tmp`, `/var/tmp`, `/run` are tmpfs — nothing leaks between calls.
- PID, IPC, and UTS namespaces are unshared.
- Network is shared so AI APIs are reachable. Switch to
  `--unshare-net` for offline-only roles.

The sudo edge runs through `dvm-agent` → bwrap, never the reverse, so a
compromised agent process cannot become `{{ dvm_user }}` and cannot read
the developer's home outside `dvm_code_dir`. Treat AI output as
untrusted code until reviewed.

## Networking

- Forwarded ports bind to `DVM_HOST_IP` (default `127.0.0.1`).
- `0.0.0.0` only when you actually want LAN exposure.
- Service VMs (`llama`, `cloudflared`, `tailscale`) are separate VMs
  reached by other VMs via `lima-dvm-<name>.internal`.

## Deletion

- `dvm rm <vm> --yes` stops and deletes the Lima instance. No dirty check.
- The per-VM config in `~/.config/dvm/vms/` is **not** deleted; remove by
  hand.
- The cached vars file `~/.cache/dvm/<vm>.vars.yml` is removed.

## Host dependencies

Kept small: `bash`, `lima`, `ansible-playbook`, `git`, an `$EDITOR`. No
`envsubst`, no `flock`, no `jq`. Install from a reviewed checkout:
`install.sh` writes one symlink; `git pull` is the update.

Run `bash tests/smoke.sh` before merging changes.
