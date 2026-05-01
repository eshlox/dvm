# yadm

Use yadm when you want alternate files for OS, hostname, distro, or VM class.

`~/.config/dvm/config.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS dotfiles.sh"
```

`~/.config/dvm/recipes/dotfiles.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y yadm
if [ ! -d "$HOME/.local/share/yadm/repo.git" ]; then
	yadm clone git@github.com:YOUR_USER/dotfiles.git || true
fi
yadm config local.class vm
yadm alt
```

Reference:

- https://yadm.io/
