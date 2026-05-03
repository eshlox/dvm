# DVM

Keep your friends close, your supply chain in a VM.

DVM is a tiny Bash wrapper around Lima. It creates one Fedora VM per project, runs the
same baseline tools in every VM, lets each project opt into plain shell recipes, and
keeps dev tools, AI CLIs, service credentials, and project code inside the VM.

The core rule:

> DVM renders one Lima VM, starts it, sources one VM config on the host, and runs shell
> recipes inside the guest.

## Install

Requirements:

- macOS with Lima installed: `brew install lima`
- Bash 3.2+; the macOS system Bash works

Install the wrapper:

```bash
./install.sh --init
```

This symlinks `bin/dvm` into `~/.local/bin` and copies defaults into
`~/.config/dvm` without overwriting existing files. Example VM configs stay in the repo
under `share/dvm/vms`; copy one into `~/.config/dvm/vms` when you want it to be active.

## Commands

```bash
dvm apply app
dvm apply --all
dvm enter app
dvm ssh app -- pwd
dvm logs cloudflared
dvm ssh-key app
dvm gpg-key app
dvm list
dvm rm app --yes
```

`dvm apply <name>` creates the Lima VM if missing, starts it, runs
`recipes/baseline.sh`, runs recipes selected by `~/.config/dvm/vms/<name>.sh`, then
runs `~/code/<name>/.dvm/apply.sh` inside the guest if that file exists.

`dvm rm` requires `--yes` and checks nested Git repos for dirty work before deleting.
Use `--force` only when you intentionally want to skip that check.

## Config

Global defaults:

```bash
~/.config/dvm/config.sh
```

Per-VM config:

```bash
~/.config/dvm/vms/app.sh
```

Start from an example:

```bash
cp share/dvm/vms/app.sh ~/.config/dvm/vms/app.sh
$EDITOR ~/.config/dvm/vms/app.sh
```

Example:

```bash
DVM_CPUS=4
DVM_MEMORY=8GiB
DVM_DISK=80GiB
DVM_CODE_DIR="~/code/app"
DVM_PORTS="3000:3000 5173:5173"
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"

use node
use python
use agent-user
use codex
use claude
use chezmoi
```

`~` in DVM variables means the guest user's home. Host project directories are not
mounted into the VM. VM names use lowercase letters, numbers, and hyphens, starting
with a letter.

## Recipes

Bundled recipes live in `share/dvm/recipes` and can be copied or overridden in
`~/.config/dvm/recipes`.

First-pass recipes include:

- `baseline`: common shell/dev tools
- `agent-user`: `dvm-agent` with ACL access to project code
- `codex`, `claude`, `opencode`, `mistral`: hosted AI CLIs inside the VM
- `chezmoi`: public HTTPS dotfiles
- `llama`: dedicated llama service VM
- `cloudflared`: dedicated Cloudflare Tunnel VM
- `node`, `python`: language basics

## Dedicated Service VMs

```bash
dvm apply llama
CLOUDFLARED_TOKEN="..." dvm apply cloudflared
dvm logs cloudflared
```

Example service configs live in `share/dvm/vms`. Copy one into `~/.config/dvm/vms`
when you want that VM to be active.

## Docs

- [Plan](docs/plan.md): the design boundary and non-goals
- [Commands](docs/commands.md): command reference
- [Config](docs/config.md): global and per-VM Bash variables
- [Lima](docs/lima.md): template and networking decisions
- [Recipes](docs/recipes.md): recipe authoring and bundled recipe behavior
- [AI](docs/ai.md): `dvm-agent` and hosted AI tools
- [Services](docs/services.md): llama and cloudflared VMs
- [Dotfiles](docs/dotfiles.md): chezmoi over HTTPS
- [Security Standards](docs/security-standards.md): operating rules
- [Docs index](docs/README.md)
