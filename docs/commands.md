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
dvm ssh app journalctl --user -xe
```

Service logs:

```bash
dvm ssh ai sudo journalctl -u dvm-llama.service -f
dvm ssh cloudflared sudo journalctl -u dvm-cloudflared.service -f
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
