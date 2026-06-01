---
title: "Default shell"
description: "Set zsh as the default shell for the dev user."
---

`dvm sh` opens `DVM_USER`'s login shell. Set it to zsh in the setup script.

```bash
sudo dnf5 install -y zsh util-linux-user

zsh_path="$(command -v zsh)"
grep -Fxq "$zsh_path" /etc/shells || \
  printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null

if [ "$(getent passwd "$DVM_USER" | cut -d: -f7)" != "$zsh_path" ]; then
  sudo chsh -s "$zsh_path" "$DVM_USER"
fi
```
