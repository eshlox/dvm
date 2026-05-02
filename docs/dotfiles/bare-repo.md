# Bare Repo Dotfiles

Use this when your dotfiles live directly in `$HOME`.

`~/.config/dvm/config.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS dotfiles.sh"
```

`~/.config/dvm/recipes/dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo="https://github.com/YOUR_USER/dotfiles.git"
gitdir="$HOME/projects/.dotfiles"

sudo dnf5 install -y git

if [ ! -d "$gitdir" ]; then
	git clone --bare "$repo" "$gitdir"
fi

dot() {
	git --git-dir="$gitdir" --work-tree="$HOME" "$@"
}

dot checkout
dot config status.showUntrackedFiles no
```

Do not track VM-local Git signing config in a public bare repo. Prefer
`dvm ssh-key <name>` for SSH commit signing. See [SSH, GPG, and signing](../keys.md).

For private dotfiles, use an SSH URL, install `openssh-clients`, call
`dvm_recipe_record_ssh_host github.com` before `git clone`, then add the VM's
`dvm ssh-key <name>` public key to GitHub.
