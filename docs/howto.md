# How to

## New VM

```bash
dvm new app
```

Edit `~/.config/dvm/vms/app.sh`:

```bash
DVM_CPUS=4
DVM_MEMORY=8
DVM_DISK=60
DVM_PORTS=(3000:3000 5173:5173)
DVM_PACKAGES=(git tmux ripgrep)
DVM_RECIPES=(zsh fzf starship node)
```

```bash
DVM_DRY_RUN=1 dvm sync app
dvm sync app
dvm sh app
```

## Private repo

Generate a VM-local key only for VMs that need Git SSH access:

```bash
DVM_RECIPES=(zsh fzf starship node ssh-keys)
dvm sync app
dvm sh app
cat ~/.ssh/id_ed25519.pub
```

Add the public key to GitHub/GitLab, then clone inside the VM:

```bash
git clone git@github.com:me/app.git ~/code/app
cd ~/code/app
```

`DVM_GIT_REPO` is useful for public HTTPS repos or VMs that already have Git
credentials:

```bash
DVM_GIT_REPO="https://github.com/me/app.git"
```

## Codex and Claude

```bash
DVM_RECIPES=(zsh fzf starship node codex claude)
dvm sync app
dvm sh app
codex
claude
```

## Guest keys

```bash
DVM_RECIPES=(ssh-keys gpg-keys)
dvm sync app
```

The generated keys stay inside the VM. `gpg-keys` configures Git signing only
for an existing project repo.

## Services

Local ports:

```bash
DVM_PORTS=(3000:3000)
```

Tailscale:

```bash
DVM_RECIPES=(tailscale)
DVM_SECRETS=(DVM_TAILSCALE_AUTHKEY)
DVM_TAILSCALE_AUTHKEY=tskey-... dvm sync app
```

Cloudflare Tunnel:

```bash
DVM_RECIPES=(cloudflared)
DVM_SECRETS=(DVM_CLOUDFLARED_TOKEN)
DVM_CLOUDFLARED_TOKEN=... dvm sync app
```

## Project hooks

Hooks are disabled by default. To run `$DVM_CODE_DIR/.dvm/sync.sh` as
`DVM_USER`:

```bash
DVM_PROJECT_HOOK=1
```

Require repo-local opt-in:

```bash
DVM_PROJECT_HOOK_GIT_CONFIG=1
git config dvm.hook true
```

Privileged hooks are strongly discouraged:

```bash
DVM_PROJECT_HOOK_PRIVILEGED=1
```

## Base VM

Use a base only for slow, stable setup:

```bash
DVM_BASE_PACKAGES=(git ripgrep fd-find)
DVM_BASE_RECIPES=(zsh fzf starship)
dvm base build
```

Then opt in:

```bash
DVM_USE_BASE=1
dvm sync app
```

## Debug

```bash
DVM_DRY_RUN=1 dvm sync app
dvm doctor
dvm doctor --probe app
dvm log app -f
```
