# Chezmoi

Use chezmoi when your dotfiles repo is public but each VM needs local data such as Git
name, email, role, or signing key.

## DVM Config

Keep the real values in local DVM config. Do not publish `~/.config/dvm` as-is.

`~/.config/dvm/config.sh`:

```bash
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
DVM_GIT_SIGNING_KEY=""
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS dotfiles.sh"
```

Leave `DVM_GIT_SIGNING_KEY` empty until you create a VM-local GPG key:

```bash
dvm gpg-key app
```

If each VM has a different signing key, put `DVM_GIT_SIGNING_KEY` in that VM config:

```bash
# ~/.config/dvm/vms/app.sh
DVM_GIT_SIGNING_KEY="ABCDEF1234567890"
```

## DVM Recipe

`~/.config/dvm/recipes/dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${DVM_GIT_NAME:?set DVM_GIT_NAME in ~/.config/dvm/config.sh}"
: "${DVM_GIT_EMAIL:?set DVM_GIT_EMAIL in ~/.config/dvm/config.sh}"
: "${DVM_GIT_SIGNING_KEY:=}"

sudo dnf5 install -y chezmoi

mkdir -p "$HOME/.config/chezmoi"
cat >"$HOME/.config/chezmoi/chezmoi.toml" <<CHEZMOI
[data]
role = "vm"
name = "$DVM_GIT_NAME"
email = "$DVM_GIT_EMAIL"
signingKey = "$DVM_GIT_SIGNING_KEY"
CHEZMOI
chmod 600 "$HOME/.config/chezmoi/chezmoi.toml"

if [ ! -d "$HOME/.local/share/chezmoi" ]; then
	chezmoi init git@github.com:YOUR_USER/dotfiles.git
fi
chezmoi apply --force
```

Run it:

```bash
dvm setup app
```

## Chezmoi Template

In your public dotfiles repo:

```text
dot_config/git/common.gitconfig.tmpl
```

```gotemplate
[user]
	name = {{ .name | quote }}
	email = {{ .email | quote }}
{{- if .signingKey }}
	signingkey = {{ .signingKey | quote }}
{{- end }}

[commit]
	gpgsign = true

[gpg]
	format = openpgp
```

Use `role` for VM-only config:

```gotemplate
{{ if eq .role "vm" }}
# VM-only config
{{ end }}
```

## Fix Missing Data

This error means chezmoi does not have local data:

```text
map has no entry for key "name"
```

Fix:

```bash
dvm ssh app bash -lc 'cat ~/.config/chezmoi/chezmoi.toml'
dvm setup app
```

The file must contain:

```toml
[data]
name = "Your Name"
email = "you@example.com"
```

## Existing File Changed

If setup runs non-interactively, chezmoi cannot ask what to do with changed files:

```text
.zshrc has changed since chezmoi last wrote it?
chezmoi: .zshrc: could not open a new TTY
```

For DVM recipes, use:

```bash
chezmoi apply --force
```

This lets the dotfiles repo win during setup. Use it only if your dotfiles repo is the
source of truth.

To fix an existing VM without recreating it:

```bash
dvm ssh app bash -lc 'cp ~/.zshrc ~/.zshrc.before-chezmoi'
dvm ssh app chezmoi apply --force
```

If you want to inspect the diff first:

```bash
dvm ssh app chezmoi diff
```

If the only unexpected change is Lima's `# Lima BEGIN` block, add that block to the VM
template below, then run `chezmoi apply --force`.

## Lima Shell Block

Lima may add this block to `.zshrc` inside each VM:

```bash
# Lima BEGIN
# Make sure iptables and mount.fuse3 are available
PATH="$PATH:/usr/sbin:/sbin"
export PATH
# Lima END
```

It makes guest helper commands available for Lima features such as port forwarding and
mount support. Do not fight it with chezmoi. Make the VM template include the same
block instead:

```gotemplate
{{ if eq .role "vm" }}
# Lima BEGIN
# Make sure iptables and mount.fuse3 are available
PATH="$PATH:/usr/sbin:/sbin"
export PATH
# Lima END
{{ end }}
```

Then `chezmoi apply` will not see Lima's change as an unmanaged edit.

## Security

Do not put tokens, SSH keys, GPG private keys, or secret-manager config in a public
chezmoi repo.

Do not publish:

```text
~/.config/dvm
~/.config/chezmoi/chezmoi.toml
```

Reference:

- https://www.chezmoi.io/
