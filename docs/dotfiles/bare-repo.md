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

Do not track VM-local Git signing config in a public bare repo. See
[SSH and GPG](../keys.md).
