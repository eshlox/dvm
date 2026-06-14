---
title: "Default shell"
description: "Set zsh as the default shell for the dev user."
---

`dvm sh` opens `DVM_USER`'s login shell. The dev user is created with `bash` at
sync, so set a different default in the per-VM setup script. `dvm-base` already
installs zsh; add `util-linux-user` (for `chsh`) in your Containerfile if it is
not present.

```bash
zsh_path="$(command -v zsh)"
grep -Fxq "$zsh_path" /etc/shells || \
  printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null

if [ "$(getent passwd "$DVM_USER" | cut -d: -f7)" != "$zsh_path" ]; then
  sudo chsh -s "$zsh_path" "$DVM_USER"
fi
```
