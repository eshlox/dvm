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
chezmoi init --apply git@github.com:YOUR_USER/dotfiles.git
```

If your dotfiles repo needs per-machine data, configure that in chezmoi itself.

## Choosing

- Use `DVM_DOTFILES_DIR` for a simple copied snapshot from a normal directory.
- Use bare repo or yadm when you want files to live directly in `$HOME`.
- Use chezmoi when you want templates and machine-specific logic.
- Use plain shell scripts when you only need to create a few generated config files.

DVM should stay workflow-neutral. Dotfiles are user setup, so configure them in
`~/.config/dvm/config.sh`, `~/.config/dvm/recipes/`, or one VM's config.

References:

- https://www.chezmoi.io/
- https://yadm.io/
