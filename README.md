# DVM

Keep your friends close, your supply chain in a VM.

DVM is a tiny Bash wrapper around Lima. It creates one Fedora VM per project, runs the
small setup baseline in every VM, lets each project opt into plain shell recipes, and
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

This installs a small launcher into `~/.local/bin` and copies defaults into
`~/.config/dvm` without overwriting existing files. The launcher runs each invocation
from a temporary snapshot of `bin/dvm`, so editing or pulling this repo cannot corrupt a
long-running `dvm apply`. Bundled recipes, the Lima template, and example VM configs
stay in the repo under `share/dvm`.

## Commands

```bash
dvm init app
dvm apply app
dvm apply --all
dvm enter app
dvm ssh app -- pwd
dvm logs cloudflared
dvm ssh-key app
dvm gpg-key app
dvm list
dvm stop app
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

Create a VM config from the bundled app example:

```bash
dvm init app
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
with a letter. DVM commands use the public project name, for example `eshlox-net`; the
internal Lima instance is named `dvm-eshlox-net`.

## Create VMs

New app VM:

```bash
dvm init myapp
dvm apply myapp
dvm enter myapp
```

Dedicated llama VM:

```bash
dvm init llama llama
dvm apply llama
dvm logs llama -f
```

The bundled llama VM opens port `8080` for host access at `http://127.0.0.1:8080` and
VM-to-VM access at `http://lima-dvm-llama.internal:8080`. It skips the dev-tool
baseline and installs only the llama recipe.

Cloudflared tunnel VM:

```bash
dvm init cloudflared cloudflared
CLOUDFLARED_TOKEN="..." dvm apply cloudflared
dvm logs cloudflared -f
```

## Recipes

Bundled recipes live in `share/dvm/recipes` and can be copied or overridden in
`~/.config/dvm/recipes`.

Local recipes override bundled recipes. Keep only recipes you intentionally customize in
`~/.config/dvm/recipes`; otherwise DVM will not see bundled recipe updates.

Add your own tools with recipes. Use individual bundled tool recipes such as
`use helix` and `use lazygit`, or define your own local helper in
`~/.config/dvm/config.sh`.

First-pass recipes include:

- `baseline`: required setup basics only
- `zsh`, `git`, `helix`, `lazygit`, `starship`, `fzf`, `git-delta`, `just`,
  `tmux`, `yazi`: optional interactive tools
- `agent-user`: `dvm-agent` plus mandatory Bubblewrap sandboxing for AI tools
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

- [Commands](docs/commands.md): command reference
- [Config](docs/config.md): global and per-VM Bash variables
- [Lima](docs/lima.md): template and networking decisions
- [Recipes](docs/recipes.md): recipe authoring and bundled recipe behavior
- [AI](docs/ai.md): `dvm-agent` and hosted AI tools
- [Services](docs/services.md): llama and cloudflared VMs
- [Dotfiles](docs/dotfiles.md): chezmoi over HTTPS
- [Security Standards](docs/security-standards.md): operating rules
- [Docs index](docs/README.md)
