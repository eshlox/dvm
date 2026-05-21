# DVM

DVM is a small Bash wrapper around Lima for disposable Fedora development VMs.
It creates Lima instances, runs Bash recipes, and keeps project code inside the
guest by default.

Defaults:

- no host mounts
- code under `/home/<user>/code/<vm>`
- config in `~/.config/dvm`
- built-in recipes in `share/dvm/recipes`
- project hooks disabled

## Install

Requirements: Bash, Lima 2.0+, and `$VISUAL` or `$EDITOR`.

```bash
git clone <repo-url> dvm
cd dvm
./install.sh
```

## Create A VM

```bash
dvm config edit
dvm new app
```

Example `~/.config/dvm/vms/app.sh`:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60

DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(git tmux ripgrep)
DVM_RECIPES=(zsh fzf starship node)
```

Run it:

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
dvm sh app
```

## Clone A Private Repo

Private repos usually need a VM-local SSH key first:

```bash
# add to app.sh only when needed
DVM_RECIPES=(zsh fzf starship node ssh-keys)
```

```bash
dvm sync app
dvm sh app
cat ~/.ssh/id_ed25519.pub
```

Add that public key to GitHub/GitLab, then clone inside the VM:

```bash
git clone git@github.com:me/app.git ~/code/app
cd ~/code/app
```

`DVM_GIT_REPO` exists for public repos or VMs that already have Git credentials.
Manual clone is the normal private-repo path.

## Use Codex Or Claude

Add recipes:

```bash
DVM_RECIPES=(zsh fzf starship node codex claude)
```

Then:

```bash
dvm sync app
dvm sh app
codex
claude
```

npm tools are pinned and installed under the guest user's `~/.local/npm`, not
with root-global npm.

## Common Recipes

```bash
DVM_RECIPES=(zsh fzf starship node codex claude ssh-keys gpg-keys)
```

Useful built-ins:

```text
agent-user bat chezmoi cloudflared codex docker fzf gpg-keys node
python ssh-keys starship tailscale zellij zsh
```

List everything:

```bash
dvm recipes
```

## Secrets And Services

Secrets are passed from host env vars during sync, staged in private guest
runtime files, then cleaned up.

```bash
DVM_RECIPES=(tailscale)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
```

```bash
DVM_TAILSCALE_AUTHKEY=tskey-... dvm sync app
```

For local web apps:

```bash
DVM_PORTS=(3000:3000 5173:5173)
```

## Commands

```text
dvm sync <vm> | --all
dvm sh <vm>
dvm ssh <vm> -- cmd...
dvm cp src dst
dvm log <vm> [-f] [args]
dvm ls [--only-config] [<vm>]
dvm stop <vm> | --all [--only-config]
dvm rm <vm> --yes [--config]
dvm new <vm>
dvm edit <vm>
dvm config edit | show
dvm base build | rm
dvm recipes
dvm doctor [--probe <vm>]
dvm version
```

## Docs

- [docs/howto.md](docs/howto.md): common workflows
- [docs/config.md](docs/config.md): config variables
- [docs/recipes.md](docs/recipes.md): built-in recipes and helper API
- [docs/commands.md](docs/commands.md): command reference
- [docs/security-standards.md](docs/security-standards.md): trust boundaries

Development check:

```bash
bash scripts/check
```
