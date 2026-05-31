---
title: "SSH keys"
description: "VM-local SSH keys for cloning private repositories."
---

Use VM-local keys. Do not copy host private keys into the guest. Add only the
public key to your Git host. The comment identifies the VM and purpose.

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  install -d -m 700 ~/.ssh
  test -f ~/.ssh/id_ed25519 ||
    ssh-keygen -t ed25519 -N "" -C "${DVM_NAME}-dvm-git-deploy" -f ~/.ssh/id_ed25519
  cat ~/.ssh/id_ed25519.pub
'
```

Separate deploy and signing keys:

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  install -d -m 700 ~/.ssh
  for kind in deploy signing; do
    key="$HOME/.ssh/id_ed25519_$kind"
    test -f "$key" ||
      ssh-keygen -q -t ed25519 -N "" -C "${DVM_NAME}-dvm-git-$kind" -f "$key"
  done
'
```

## Clone a private repo

After the key is added to GitHub/GitLab:

```bash
dvm sh app
git clone git@github.com:me/app.git ~/code/app
cd ~/code/app
```
