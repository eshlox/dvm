# Dotfiles

DVM ships a `chezmoi` recipe that clones your public dotfiles repo over
HTTPS and applies them inside the VM. Use it when the identity is the
same across VMs.

## Why HTTPS

Public HTTPS avoids copying host SSH keys into VMs and dodges deploy-key
setup. Private dotfiles? Write your own recipe.

## Config

Put chezmoi settings in `~/.config/dvm/config.sh` since the dotfiles
identity is usually the same everywhere:

```bash
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"
DVM_CHEZMOI_ROLE="vm"
DVM_CHEZMOI_NAME="Your Name"
DVM_CHEZMOI_EMAIL="you@example.com"
```

Opt VMs in via:

```bash
DVM_RECIPES=(chezmoi)        # or append to DVM_DEFAULT_RECIPES
```

The recipe installs chezmoi, writes `~/.config/chezmoi/chezmoi.toml`,
clones into `~/.local/share/chezmoi` (or pulls updates), then runs
`chezmoi apply`.

The generated `[data]` block exposes:

```toml
role       = "<DVM_CHEZMOI_ROLE>"
name       = "<DVM_CHEZMOI_NAME>"
email      = "<DVM_CHEZMOI_EMAIL>"
signingKey = "~/.ssh/id_ed25519_dvm_signing.pub"
deployKey  = "~/.ssh/id_ed25519_dvm.pub"
```

Both key paths default to what `dvm ssh-key <vm>` creates. Override with
`DVM_CHEZMOI_SIGNING_KEY` / `DVM_CHEZMOI_DEPLOY_KEY` if you use custom
names.

For full chezmoi config control, set `DVM_CHEZMOI_CONFIG_TOML` to the
literal TOML body; it replaces the generated `[data]` block.

## Security

- Never commit provider tokens, SSH/GPG private keys, npm tokens, or
  Cloudflare/Tailscale keys to public dotfiles.
- VM-specific secrets stay in `DVM_SECRETS` or in the service provider.
- Review dotfiles install hooks; they run as the primary user.

## Recovery

A failed first clone leaves a broken source dir:

```bash
dvm ssh app -- rm -rf ~/.local/share/chezmoi
dvm sync app
```
