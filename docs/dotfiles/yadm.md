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

repo="https://github.com/YOUR_USER/dotfiles.git"

sudo dnf5 install -y yadm

if [ ! -d "$HOME/.local/share/yadm/repo.git" ]; then
	yadm clone "$repo" || true
fi
yadm config local.class vm
yadm alt
```

For private dotfiles, use an SSH URL, install `openssh-clients`, call
`dvm_recipe_record_ssh_host github.com` before `yadm clone`, then add the VM's
`dvm ssh-key <name>` public key to GitHub.

Reference:

- https://yadm.io/
