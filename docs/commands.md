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

`dvm setup app` reruns dotfiles sync, recipes, and inline `dvm_vm_setup()`.

## Enter Or Run

```bash
dvm app
dvm enter app
dvm ssh app
```

All three open an interactive shell in `DVM_CODE_DIR`, which defaults to
`~/code/<vm-name>`.

Run one command:

```bash
dvm app pnpm test
dvm app claude
dvm ssh app sudo dnf5 install -y htop
```

Inspect VMs and service logs:

```bash
dvm status app
dvm logs ai dvm-llama.service -f
dvm logs cloudflared dvm-cloudflared.service -f
```

## Terminal

Some terminals export a custom `TERM`, for example Ghostty, Kitty, Alacritty, WezTerm,
iTerm2, Warp, Hyper, or Wave. Fedora may not have that exact terminfo entry. When that
happens, tmux or curses apps can fail with `missing or unsuitable terminal`.

DVM checks whether the VM knows the host `TERM`. If it does, DVM passes it through. If
not, DVM falls back to `xterm-256color`.

Override the fallback if needed:

```bash
DVM_GUEST_TERM="xterm-256color"
```

If you want exact terminal behavior inside one VM, install that terminal's terminfo.
For Ghostty:

```bash
dvm ssh app sudo dnf5 install -y ncurses
infocmp -x xterm-ghostty | dvm ssh app tic -x -
```

## Update

```bash
dvm setup-all
dvm upgrade app
dvm upgrade-all
dvm doctor
dvm doctor app
```

`upgrade` runs Fedora package upgrades, then reruns setup.

`doctor` checks host tools, Lima, disk space, and optional per-VM config details such
as recipe paths, dotfiles, and port availability.

## Keys

```bash
dvm ssh-key app
dvm gpg-key app
```

Keys are opt-in. VM creation does not create them.

## List And Delete

```bash
dvm list
dvm status app
dvm rm app
dvm rm app --force
dvm version
```

`dvm status app` prints a single-VM summary with Lima state, size, ports, host bind
IP, code directory, setup scripts, dotfiles, and Lima directory.

`dvm rm app` checks for dirty Git work inside `DVM_CODE_DIR` before deleting. Use
`--force` only when you accept losing uncommitted work in that VM.

`dvm version` prints the current Git tag or commit when DVM is run from a checkout.

## Logs

```bash
dvm logs ai
dvm logs cloudflared
dvm logs app dvm-example.service
dvm logs ai dvm-llama.service -f
```

If the VM uses a known service recipe, `dvm logs <name>` infers the service unit.
Otherwise pass the unit name explicitly. Extra arguments are passed to `journalctl`;
without extra arguments DVM uses `--no-pager -n 100`.
