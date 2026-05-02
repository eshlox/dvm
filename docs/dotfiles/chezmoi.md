# Chezmoi

Use chezmoi when your dotfiles repo is public but each VM needs local data such as Git
name, email, or role.

## DVM Config

Keep the real values in local DVM config. Do not publish `~/.config/dvm` as-is.

`~/.config/dvm/config.sh`:

```bash
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS dotfiles.sh"
```

For signing, prefer SSH signing with the per-VM key:

```bash
dvm ssh-key app
```

Do not manage `~/.config/git/config` with chezmoi if you want `dvm ssh-key` to own
the VM-local SSH signing config.

## DVM Recipe

`~/.config/dvm/recipes/dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${DVM_GIT_NAME:?set DVM_GIT_NAME in ~/.config/dvm/config.sh}"
: "${DVM_GIT_EMAIL:?set DVM_GIT_EMAIL in ~/.config/dvm/config.sh}"

sudo dnf5 install -y chezmoi git
source_dir="$HOME/.local/share/chezmoi"
repo="https://github.com/YOUR_USER/dotfiles.git"

mkdir -p "$HOME/.config/chezmoi"
cat >"$HOME/.config/chezmoi/chezmoi.toml" <<CHEZMOI
[data]
role = "vm"
name = "$DVM_GIT_NAME"
email = "$DVM_GIT_EMAIL"
CHEZMOI
chmod 600 "$HOME/.config/chezmoi/chezmoi.toml"

if [ -e "$source_dir" ] && ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	rm -rf "$source_dir"
fi
if [ ! -d "$source_dir" ]; then
	chezmoi init "$repo"
fi
chezmoi update --force
```

For private dotfiles, use an SSH URL such as `git@github.com:YOUR_USER/dotfiles.git`,
install `openssh-clients`, call `dvm_recipe_record_ssh_host github.com` before
`chezmoi init`, then add the VM's `dvm ssh-key <name>` public key to GitHub.

The `source_dir` check recovers from a previous failed clone that left
`~/.local/share/chezmoi` behind without a Git repository.

Run it:

```bash
dvm setup app
```

`chezmoi init` only clones the source once. `chezmoi update --force` fetches the latest
dotfiles and applies them every time `dvm setup app` runs.

If you do not want setup to pull from Git every time, use this instead:

```bash
chezmoi apply --force
```

Then update manually when needed:

```bash
dvm ssh app chezmoi update --force
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

## Fix Broken Source Directory

This can happen after a failed first clone:

```text
fatal: not a git repository
chezmoi: git: exit status 128
```

The recipe above removes `~/.local/share/chezmoi` only when that path exists but is not
a Git work tree. To fix an existing VM once:

```bash
dvm ssh app rm -rf ~/.local/share/chezmoi
dvm setup app
```

## Existing File Changed

If setup runs non-interactively, chezmoi cannot ask what to do with changed files:

```text
.zshrc has changed since chezmoi last wrote it?
chezmoi: .zshrc: could not open a new TTY
```

For DVM recipes, use:

```bash
chezmoi update --force
```

This fetches the latest dotfiles and lets the dotfiles repo win during setup. Use it
only if your dotfiles repo is the source of truth.

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
template below, then run `chezmoi update --force`.

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
