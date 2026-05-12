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

- macOS with Lima 2.0.0 or newer installed: `brew install lima`
- Bash 3.2+; the macOS system Bash works

The bundled Lima template uses `vmType: vz`, so Linux hosts are not supported by the
default template. Linux may work with a custom QEMU Lima template, but it is not tested.

Install the wrapper:

```bash
./install.sh --init
```

This installs a small launcher into `~/.local/bin` and copies defaults into
`~/.config/dvm` without overwriting existing files. The launcher runs each invocation
from a temporary snapshot of `bin/dvm` and its shell libraries, so editing or pulling
this repo cannot corrupt a long-running `dvm sync`. Bundled recipes, the Lima
template, and example VM configs stay in the repo under `share/dvm`.

For zsh completion, add the in-repo completion directory before `compinit` in
`~/.zshrc`:

```zsh
fpath=(/path/to/dvm/share/dvm/completions $fpath)
autoload -Uz compinit
compinit
```

If your `~/.zshrc` already runs `compinit`, add only the `fpath=...` line above it.

## Commands

```bash
dvm init app
dvm sync app
dvm sync --all
dvm sh app
dvm ssh app -- pwd
dvm cp ./plan.md app:.
dvm log cloudflared
dvm ssh-key app
dvm gpg-key app
dvm ls
dvm stop app
dvm stop --all
dvm stop --inactive
dvm rm app --yes
```

`dvm sync <name>` creates the Lima VM if missing, starts it, runs
`recipes/baseline.sh`, runs recipes selected by `~/.config/dvm/vms/<name>.sh`, then
runs `~/code/<name>/.dvm/sync.sh` inside the guest if that file exists.
Use `dvm sync --all` after recipe changes or when you want to update recipe-managed
tools such as AI CLIs across every active VM.

`dvm rm` requires `--yes` and checks nested Git repos for dirty work before deleting.
Use `--force` only when you intentionally want to skip that check.

`dvm stop --all` stops every DVM-managed Lima instance listed with the internal
`dvm-` prefix. This releases VM memory without deleting disks or config.
Use `dvm stop --inactive` to stop only VMs without a detected active shell,
`tmux`/`zellij`, or known DVM service unit.

`dvm ssh-key <name>` creates separate VM-local SSH keys for Git hosting access and Git
commit signing. Use the access key as a deploy/authentication key and add the signing
key to your Git hosting account's SSH signing keys, if supported.

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

`dvm init` writes a fully commented template; uncomment what you need. Defaults are
`DVM_CPUS=2`, `DVM_MEMORY=2GiB`, `DVM_DISK=10GiB`, `DVM_CODE_DIR=~/code/$DVM_NAME`,
empty `DVM_PORTS`. The template shows the host's CPU and memory ceilings as inline
comments and calls `use_tools`, a helper defined in your global config that holds the
recipes shared across every app VM. Edit `~/.config/dvm/config.sh` once to choose
your toolset; new VMs pick it up automatically. Per-VM configs can add extra
recipes, define more helpers, or comment the `use_tools` line for a minimal VM.

`~` in DVM variables means the guest user's home. Host project directories are not
mounted into the VM. VM names use lowercase letters, numbers, and hyphens, starting
with a letter. DVM commands use the public project name, for example `eshlox-net`; the
internal Lima instance is named `dvm-eshlox-net`.

## Create VMs

New app VM:

```bash
dvm init myapp
dvm sync myapp
dvm sh myapp
```

Dedicated llama VM:

```bash
dvm init llama llama
dvm sync llama
dvm log llama -f
```

The bundled llama VM opens port `8080` for host access at `http://127.0.0.1:8080` and
VM-to-VM access at `http://lima-dvm-llama.internal:8080`. It skips the dev-tool
baseline and installs only the llama recipe.

Cloudflared tunnel VM:

```bash
dvm init cloudflared cloudflared
CLOUDFLARED_TOKEN="..." dvm sync cloudflared
dvm log cloudflared -f
```

The cloudflared token is staged through a mode `0600` guest temp file during `sync`
instead of being passed as a `limactl shell env` argument.

Tailscale supports two patterns:

**Private dev access** — reach app VMs by hostname from your Mac without
juggling host ports. Add `use tailscale` to each app VM and sync:

```bash
TAILSCALE_AUTH_KEY="tskey-..." dvm sync fida
# then from the host browser: http://fida:5173
```

**Public Funnel URLs** — publish a local service at a public `*.ts.net` URL
on demand:

```bash
# One-time: create the VM and join your tailnet
dvm init tailscale tailscale
TAILSCALE_AUTH_KEY="tskey-..." dvm sync tailscale

# Turn Funnel ON, pointing at another VM's service
DVM_TAILSCALE_FUNNEL_TARGET="http://lima-dvm-app.internal:3000" \
  dvm sync tailscale

# Turn Funnel OFF
dvm sync tailscale
```

Funnel is OFF by default; the recipe resets it on every sync, so leaving the
target unset turns it off. Auth keys get the same mode `0600` guest temp-file
handling as Cloudflare tokens. See [docs/services.md](docs/services.md#tailscale)
for both patterns, the Funnel ACL prerequisite, and auth-key sourcing options
(global config, env var, or macOS Keychain).

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
- `zsh`, `git`, `helix`, `lazygit`, `starship`, `fzf`, `bat`, `git-delta`, `just`,
  `tmux`, `zellij`, `yazi`: optional interactive tools
- `agent-user`: `dvm-agent` plus mandatory Bubblewrap sandboxing for AI tools
- `codex`, `claude`, `opencode`, `mistral`: hosted AI CLIs inside the VM
- `chezmoi`: public HTTPS dotfiles
- `llama`: dedicated llama service VM
- `cloudflared`: dedicated Cloudflare Tunnel VM
- `tailscale`: tailnet membership and optional Funnel public ingress
- `node`, `python`: language basics
- `docker`: Docker Engine and Compose plugin

Codex and Claude default to unattended mode inside the `dvm-agent` Bubblewrap sandbox
so they can edit code and run project commands without prompting. Set
`DVM_CODEX_YOLO=0` or `DVM_CLAUDE_BYPASS=0` in a VM config when you want the tool's own
approval prompts and sandboxing.

## Dedicated Service VMs

```bash
dvm sync llama
CLOUDFLARED_TOKEN="..." dvm sync cloudflared
dvm log cloudflared
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
