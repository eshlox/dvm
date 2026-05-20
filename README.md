# DVM

DVM is a small Bash wrapper around [Lima](https://lima-vm.io/) for disposable
development VMs. DVM owns the VM lifecycle and a tiny Bash recipe runner;
Lima owns virtualization; recipes install the tools you want inside the guest.

The default model is intentionally simple:

- no host mount (`limactl start --mount-none`)
- code lives in the guest at `/home/<user>/code/<vm>`
- global defaults in `~/.config/dvm/config.sh`
- per-VM config in `~/.config/dvm/vms/<vm>.sh`
- built-in recipes live in `share/dvm/recipes`
- user recipe overrides live in `~/.config/dvm/recipes`

## Requirements

- Bash
- Lima 2.0+
- Git, if you use `DVM_GIT_REPO`
- `$VISUAL` or `$EDITOR` for `dvm new`, `dvm edit`, and `dvm config edit`

No Ansible, Python, jq, envsubst, or flock is required by DVM itself.
DVM supports Lima's latest Fedora template and `dnf5` inside the guest only.

Linux hosts need working KVM access. On many distros that means installing
QEMU/KVM packages, adding your user to the `kvm` group, then starting a new
login session. Nested virtualization may be required inside another VM.

## Install

```bash
git clone <repo-url> dvm
cd dvm
./install.sh
```

`install.sh` creates a symlink to `bin/dvm`, so `git pull` updates the tool.

## Quick Start

First-time flow: install Lima, install DVM, set global defaults, create a VM,
then sync it.

```bash
dvm config edit
dvm new app
dvm sync app
dvm sh app
```

A minimal VM config looks like this:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60

DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(git tmux ripgrep)
DVM_RECIPES=(zsh fzf starship node codex)

# Optional: clone code into /home/developer/code/app on first sync.
DVM_GIT_REPO="git@github.com:me/app.git"
```

Global defaults are prepended to every VM:

```bash
DVM_DEFAULT_PACKAGES=(git ripgrep fd-find)
DVM_DEFAULT_RECIPES=(zsh fzf starship)
```

## Recipes

Built-in recipes currently include:

```text
age agent-user bat chezmoi claude cloudflared codex delta docker fzf
gpg-keys helix just lazygit mistral node ollama opencode python sops
ssh-keys starship tailscale yazi zellij zsh
```

Examples:

```bash
# Global defaults for every VM.
DVM_DEFAULT_RECIPES=(zsh fzf starship)

# Extra per-VM tools.
DVM_RECIPES=(node codex claude opencode docker)

# Plain package installs do not need recipes.
DVM_PACKAGES=(git tmux postgresql)
```

To override or add a recipe:

```bash
mkdir -p ~/.config/dvm/recipes
$EDITOR ~/.config/dvm/recipes/my-tool.sh
```

Then use `DVM_RECIPES=(my-tool)`.

## Services And Sharing

Port forwards use Lima's `host_port:guest_port` syntax:

```bash
DVM_PORTS=(3000:3000)
```

Use Tailscale or Cloudflare Tunnel recipes when other people need access.
Lima's short `--port-forward host:guest` form is localhost-oriented; for
direct LAN exposure, configure Lima networking/YAML outside DVM.

Service secrets are staged from host environment variables into guest temp files:

```bash
# ~/.config/dvm/vms/demo.sh
DVM_RECIPES=(tailscale cloudflared)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY DVM_CLOUDFLARED_TOKEN)

# sync
DVM_TAILSCALE_AUTHKEY=tskey-... \
DVM_CLOUDFLARED_TOKEN=... \
dvm sync demo
```

The secret values travel over stdin to the guest and are removed after sync.

## Commands

```text
dvm sync <vm> | --all       create/start VM and run packages + recipes
dvm sh <vm>                 interactive limactl shell
dvm ssh <vm> -- cmd...      non-interactive limactl shell command
dvm cp src dst              copy; one side may be vm:path
dvm log <vm> [-f] [args]    guest journalctl
dvm ls [<vm>]               list DVM Lima instances
dvm stop <vm> | --all       stop running VMs
dvm rm <vm> --yes           delete a Lima instance
dvm new <vm>                write stub config and open editor
dvm edit <vm>               edit per-VM config
dvm config edit | show      edit/show global config
dvm base build | rm         optional reusable base VM
dvm recipes                 list built-in and user recipes
dvm doctor                  check Lima and DVM paths
```

See `docs/` for command, config, recipe, Lima, and security details.
Future safety ideas are tracked in
[docs/future-development.md](docs/future-development.md).

## Development

```bash
bash tests/smoke.sh
```

The smoke test uses a fake `limactl`; it does not start real VMs.
