# Snapshot Dotfiles

Use this when your dotfiles are a normal directory, for example `~/.dotfiles`.

`~/.config/dvm/config.sh`:

```bash
DVM_DOTFILES_DIR="$HOME/.dotfiles"
DVM_DOTFILES_TARGET="$DVM_GUEST_HOME/.dotfiles"
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS dotfiles.sh"
```

`~/.config/dvm/recipes/dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ -x "$HOME/.dotfiles/install.sh" ]; then
	"$HOME/.dotfiles/install.sh" vm
fi
```

DVM copies a filtered snapshot during `dvm setup`. It does not mount the host dotfiles
directory.

Default excludes:

```text
.git .ssh .gnupg .env secrets private.sh .aws .docker .kube .netrc .pypirc .npmrc .config/gh .config/op
```

Disable the snapshot for one VM:

```bash
# ~/.config/dvm/vms/ai.sh
DVM_DOTFILES_DIR=""
DVM_SETUP_SCRIPTS="llama.sh"
```
