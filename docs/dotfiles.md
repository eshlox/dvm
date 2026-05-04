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

The recipe installs `chezmoi`, writes `~/.config/chezmoi/chezmoi.toml` through a
temporary file when configured, initializes `~/.local/share/chezmoi` when missing,
pulls updates when already initialized, and runs `chezmoi apply`.

For common dotfiles template data, put shared identity values in global DVM config:

```bash
DVM_CHEZMOI_ROLE="vm"
DVM_CHEZMOI_NAME="Your Name"
DVM_CHEZMOI_EMAIL="you@example.com"
```

The generated data uses the default key paths created by `dvm ssh-key <name>`:

```toml
signingKey = "~/.ssh/id_ed25519_dvm_signing.pub"
deployKey = "~/.ssh/id_ed25519_dvm.pub"
```

Override the paths in VM config only when you use custom key names:

```bash
DVM_CHEZMOI_SIGNING_KEY="~/.ssh/id_ed25519_project_signing.pub"
DVM_CHEZMOI_DEPLOY_KEY="~/.ssh/id_ed25519_project_deploy.pub"
```

The recipe writes the data to chezmoi's `[data]` section as `role`, `name`, `email`,
`signingKey`, and `deployKey`. Only VMs that select `use chezmoi` consume these values.
Service VMs such as llama and cloudflared are unaffected unless you add `use chezmoi` to
them.

Do not use the deploy/access key path for account-level commit signing. Use
`DVM_CHEZMOI_SIGNING_KEY` for commit signing and `DVM_CHEZMOI_DEPLOY_KEY` only if your
dotfiles templates need to render SSH config for private repo access.

For advanced chezmoi config, set `DVM_CHEZMOI_CONFIG_TOML` to the full TOML file
contents. When this raw TOML variable is set, it takes over the generated config rather
than merging with the individual variables.

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
