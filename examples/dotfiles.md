# Dotfiles (chezmoi)

Review dotfiles before applying them in a VM that holds credentials.

```bash
sudo dnf5 install -y chezmoi git

sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  if [ ! -d ~/.local/share/chezmoi ]; then
    chezmoi init https://github.com/me/dotfiles.git
  fi
  chezmoi apply
'
```

## With machine-local config

Keep identity in chezmoi's own config, not in the dotfiles repo. On re-runs,
pull instead of re-init:

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  install -d -m 700 ~/.config/chezmoi
  cat >~/.config/chezmoi/chezmoi.toml <<TOML
[data]
role = "vm"
name = "Your Name"
email = "you@example.com"
TOML
  chmod 600 ~/.config/chezmoi/chezmoi.toml

  if [ -d ~/.local/share/chezmoi/.git ]; then
    chezmoi git -- pull --ff-only
  else
    rm -rf ~/.local/share/chezmoi
    chezmoi init https://github.com/me/dotfiles.git
  fi
  chezmoi apply --force
'
```
