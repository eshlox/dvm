# Dotfiles

The first dotfiles path is chezmoi over public HTTPS.

## Why HTTPS

Public HTTPS avoids copying host SSH private keys into VMs and avoids deploy-key setup
for public dotfiles. If dotfiles must be private, add a separate SSH recipe later.

## Config

```bash
DVM_CHEZMOI_REPO="https://github.com/YOUR_USER/dotfiles.git"

use chezmoi
```

The recipe installs `chezmoi`, writes `DVM_CHEZMOI_CONFIG_TOML` to
`~/.config/chezmoi/chezmoi.toml` when set, initializes `~/.local/share/chezmoi` when
missing, pulls updates when already initialized, and runs `chezmoi apply`.

If your dotfiles need template data, put the config in your global DVM config:

```bash
DVM_CHEZMOI_CONFIG_TOML='[data]
name = "Your Name"
email = "you@example.com"
signingKey = ""
'
```

Only VMs that select `use chezmoi` consume this value. Service VMs such as llama and
cloudflared are unaffected unless you add `use chezmoi` to them.

## Security Rules

- Do not store secrets in public dotfiles.
- Do not commit provider tokens, SSH private keys, GPG private keys, npm tokens, or
  Cloudflare tokens.
- Keep VM-specific secrets in the VM or in the service provider.
- Review dotfiles install hooks as code.

## Recovery

If a first clone fails and leaves a broken chezmoi source directory, remove it inside
the VM and reapply:

```bash
dvm ssh app -- rm -rf ~/.local/share/chezmoi
dvm apply app
```
