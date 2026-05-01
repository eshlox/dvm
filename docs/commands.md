# Commands

## Create And Setup

```bash
dvm init app
dvm edit app
dvm create app
dvm setup app
```

`dvm init app` creates `~/.config/dvm/vms/app.sh`.

`dvm create app` creates the Lima VM, starts it, then runs setup.

`dvm setup app` reruns packages, dotfiles sync, recipes, and inline `dvm_vm_setup()`.

## Enter Or Run

```bash
dvm app
dvm enter app
dvm ssh app
```

All three open an interactive shell in `DVM_CODE_DIR`, which defaults to `~/code`.

Run one command:

```bash
dvm app pnpm test
dvm ssh app sudo dnf5 install -y htop
dvm ssh app journalctl --user -xe
```

Service logs:

```bash
dvm ssh ai sudo journalctl -u dvm-llama.service -f
dvm ssh cloudflared sudo journalctl -u dvm-cloudflared.service -f
```

## Update

```bash
dvm setup-all
dvm upgrade app
dvm upgrade-all
```

`upgrade` runs Fedora package upgrades, then reruns setup.

## Keys

```bash
dvm ssh-key app
dvm gpg-key app
```

Keys are opt-in. VM creation does not create them.

## List And Delete

```bash
dvm list
dvm rm app
dvm rm app --force
```

`dvm rm app` checks for dirty Git work inside `DVM_CODE_DIR` before deleting. Use
`--force` only when you accept losing uncommitted work in that VM.
