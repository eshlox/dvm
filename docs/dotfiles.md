# Dotfiles

DVM does not require a dotfiles manager or layout. Use whatever workflow you already
prefer, then call it from global setup or a per-VM config.

No dotfiles are synced by default.

## Option 1: Snapshot A Directory

Use this when your dotfiles are a normal directory, for example `~/.dotfiles`.

Global config:

```bash
DVM_DOTFILES_DIR="$HOME/.dotfiles"
DVM_DOTFILES_TARGET="$DVM_GUEST_HOME/.dotfiles"
DVM_SETUP_SCRIPTS="common.sh"
```

DVM excludes common secret paths by default, including `private.sh`, `.env`, `.ssh`,
`.gnupg`, `.aws`, `.docker`, `.kube`, `.netrc`, `.pypirc`, `.npmrc`, `.config/gh`, and
`.config/op`. Review `DVM_DOTFILES_DIR` before enabling sync because DVM cannot know
every private file name you use.

`~/.config/dvm/recipes/common.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -x "$HOME/.dotfiles/install.sh" ]; then
	"$HOME/.dotfiles/install.sh" vm
fi
```

Disable for special VMs:

```bash
DVM_DOTFILES_DIR=""
DVM_SETUP_SCRIPTS="llama.sh"
```

## Option 2: Bare Repo Or yadm

Bare repo and yadm workflows keep files at their real paths in `$HOME`. DVM's directory
snapshot is not ideal for that because the dotfiles are not collected in one normal
source directory.

For these workflows, install from inside the VM instead:

```bash
DVM_SETUP_SCRIPTS="dotfiles.sh common.sh"
```

Example `~/.config/dvm/recipes/dotfiles.sh` for a bare repo:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo="git@github.com:YOUR_USER/dotfiles.git"
gitdir="$HOME/projects/.dotfiles"

if [ ! -d "$gitdir" ]; then
	git clone --bare "$repo" "$gitdir"
fi

dot() {
	git --git-dir="$gitdir" --work-tree="$HOME" "$@"
}

dot checkout
dot config status.showUntrackedFiles no
```

For yadm, install yadm in your common setup and use yadm's alternate files for OS,
hostname, distro, or VM class:

```bash
sudo dnf5 install -y yadm
yadm clone git@github.com:YOUR_USER/dotfiles.git || true
yadm config local.class vm
yadm alt
```

## Option 3: chezmoi

Use chezmoi if you want templates, host-specific data, and more explicit apply logic.
Keep it in user setup, not DVM core.

Example `~/.config/dvm/recipes/dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y chezmoi
if [ ! -d "$HOME/.local/share/chezmoi" ]; then
	chezmoi init git@github.com:YOUR_USER/dotfiles.git
fi
chezmoi apply
```

Chezmoi is a good fit when the dotfiles repo is public but each machine or VM needs
private local values such as Git name, email, role, or signing key.

Private data option A: keep values out of the repo in the local chezmoi config:

```toml
[data]
role = "vm"
name = "Your Name"
email = "you@example.com"
signingKey = "ABCDEF1234567890"
```

That file is local to the machine or VM, usually:

```text
~/.config/chezmoi/chezmoi.toml
```

Use templates in the public repo:

```gotemplate
[user]
	name = {{ .name | quote }}
	email = {{ .email | quote }}
{{- if .signingKey }}
	signingkey = {{ .signingKey | quote }}
{{- end }}
```

For macOS host versus Fedora VM differences, store a local role and branch in templates:

```gotemplate
{{ if eq .role "vm" }}
# VM-only config
{{ end }}
```

### Private Git Config Recipe

Use this when your public dotfiles include shared Git config, but private values such
as name, email, or signing key must stay out of the repository.

There are three files:

- `~/.config/dvm/private.sh`: private host values, never committed
- `~/.config/dvm/recipes/git-local.sh`: recipe that writes VM-local Git config
- `~/.config/dvm/config.sh` or `~/.config/dvm/vms/<name>.sh`: activation

1. Source the private file from DVM global config:

```bash
# ~/.config/dvm/config.sh
[ -f "$DVM_CONFIG/private.sh" ] && source "$DVM_CONFIG/private.sh"
```

2. Create the private host file:

```bash
# ~/.config/dvm/private.sh
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
DVM_GIT_SIGNING_KEY="ABCDEF1234567890"
```

Lock it down:

```bash
chmod 600 ~/.config/dvm/private.sh
```

3. Put the recipe here:

```text
~/.config/dvm/recipes/git-local.sh
```

Recipe contents:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${DVM_GIT_NAME:?set DVM_GIT_NAME in ~/.config/dvm/private.sh}"
: "${DVM_GIT_EMAIL:?set DVM_GIT_EMAIL in ~/.config/dvm/private.sh}"
: "${DVM_GIT_SIGNING_KEY:=}"

mkdir -p "$HOME/.config/git"
{
	cat <<GITCONFIG
[user]
	name = $DVM_GIT_NAME
	email = $DVM_GIT_EMAIL
GITCONFIG
	if [ -n "$DVM_GIT_SIGNING_KEY" ]; then
		cat <<GITCONFIG
	signingkey = $DVM_GIT_SIGNING_KEY
GITCONFIG
	fi
} >"$HOME/.config/git/local.gitconfig"
chmod 600 "$HOME/.config/git/local.gitconfig"
```

4. Activate the recipe globally if most VMs should get it:

```bash
# ~/.config/dvm/config.sh
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS git-local.sh"
```

Or activate it only for one VM:

```bash
# ~/.config/dvm/vms/app.sh
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS git-local.sh"
```

5. Run setup:

```bash
dvm setup app
```

Your tracked Git config should include the generated local file:

```ini
[include]
	path = ~/.config/git/common.gitconfig
[include]
	path = ~/.config/git/local.gitconfig
```

Do not commit `~/.config/dvm/private.sh`. DVM excludes `private.sh` from copied
dotfiles snapshots by default, but your dotfiles repository should also ignore it if
you keep a file with that name there.

Do not store SSH keys, GPG private keys, tokens, real signing keys, or secret-manager
config in a public chezmoi repo.

## Choosing

- Use `DVM_DOTFILES_DIR` for a simple copied snapshot from a normal directory.
- Use bare repo or yadm when you want files to live directly in `$HOME`.
- Use chezmoi when you want templates and machine-specific logic.
- Use plain shell scripts when you only need to create a few generated config files.

DVM should stay workflow-neutral. Dotfiles are user setup, so configure them in
`~/.config/dvm/config.sh`, `~/.config/dvm/recipes/`, or one VM's config.

## Git Signing

Do not track a VM-specific Git `user.signingkey` in shared dotfiles. Track common Git
settings, then include an untracked VM-local file for the signing key.

Tracked:

```ini
[include]
	path = ~/.config/git/common.gitconfig
[include]
	path = ~/.config/git/local.gitconfig
```

Untracked in each VM:

```text
~/.config/git/local.gitconfig
```

See [SSH and GPG](keys.md) for the full example.

References:

- https://www.chezmoi.io/
- https://yadm.io/
