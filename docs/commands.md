# Commands

DVM keeps the command surface small. Most day-to-day work should still be `apply`,
`enter`, and `ssh`; the extra helpers cover logs and VM-local keys.

## Apply

```bash
dvm apply app
dvm apply --all
```

`apply` creates the VM if missing, starts it, runs `baseline`, runs recipes selected in
`~/.config/dvm/vms/app.sh`, then runs `$DVM_CODE_DIR/.dvm/apply.sh` inside the guest if
present.

If the VM already exists, `apply` updates Lima port forwards from `DVM_PORTS` without
recreating the VM. Lima may restart the instance when ports change.

`apply --all` applies every active VM config in `~/.config/dvm/vms/*.sh`, continues
after failures, and exits non-zero if any VM failed.

## Enter

```bash
dvm enter app
```

Starts the VM and opens an interactive shell in `DVM_CODE_DIR`. DVM reads the guest
user's login shell from `/etc/passwd`, so recipes can switch it with `chsh`; the `zsh`
recipe sets it to zsh.

## SSH

```bash
dvm ssh app -- pwd
dvm ssh cloudflared -- journalctl -u dvm-cloudflared.service -f
```

Runs one command inside the VM from `DVM_CODE_DIR`.

## Logs

```bash
dvm logs cloudflared
dvm logs cloudflared -f
dvm logs app nginx.service -f
```

Shows `journalctl` output from inside the VM. When the VM config uses exactly one known
service recipe, DVM picks the unit automatically:

- `use cloudflared`: `dvm-cloudflared.service`
- `use llama`: `dvm-llama.service`

Otherwise pass the unit explicitly. With no journal arguments DVM uses
`--no-pager -n 100`; when DVM can infer the unit, journal arguments can follow the VM
name directly.

## VM-Local Keys

```bash
dvm ssh-key app
dvm gpg-key app
```

`ssh-key` creates or reuses `~/.ssh/id_ed25519_dvm` inside the VM, prints the public
key, adds a GitHub SSH config entry, and configures Git SSH signing for that VM.

`gpg-key` creates or reuses a one-year VM-local signing key and prints the public key
plus fingerprint. Neither command copies host private keys into the VM.

## List

```bash
dvm list
```

Shows Lima VMs whose names start with `dvm-`.

## Stop

```bash
dvm stop app
```

Stops the Lima VM.

## Remove

```bash
dvm rm app --yes
dvm rm app --yes --force
```

Deletes the Lima VM. `--yes` is required. Before deleting, DVM starts the VM and scans
nested Git repos under `DVM_CODE_DIR`; dirty repos stop deletion. `--force` skips that
scan. Recreate is intentionally `dvm rm app --yes` followed by `dvm apply app`.
