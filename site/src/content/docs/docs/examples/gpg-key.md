---
title: "GPG signing key"
description: "Create a VM-local GPG key for signing commits."
---

VM-local commit signing key. Generated once, kept inside the guest.

```bash
sudo -u "$DVM_USER" -H bash -lc '
  set -Eeuo pipefail
  if ! gpg --list-secret-keys --with-colons | grep -q "^sec:"; then
    gpg --batch --passphrase "" --quick-generate-key \
      "$USER@$HOSTNAME" ed25519 sign 1y
  fi
'
```
