# Config And Dotfiles

`dvm init` creates:

```text
~/.config/dvm/config.sh
~/.config/dvm/setup.d/fedora.sh
~/.local/share/dvm/
```

User configuration is shell code by design. Keep local VM behavior in
`~/.config/dvm`, not in the DVM core checkout.

## Common Config

```bash
DVM_PREFIX="dvm"
DVM_CPUS="4"
DVM_MEMORY="8GiB"
DVM_DISK="80GiB"

DVM_PACKAGES="git openssh-clients gpg helix ripgrep fd-find jq"
DVM_SETUP_SCRIPTS="$DVM_CONFIG/setup.d/fedora.sh"
DVM_SETUP_ALL_JOBS="1"
DVM_DOTFILES_DIR="$HOME/.dotfiles"
```

The core targets Lima `template:fedora` and assumes `dnf5` inside the guest.

## Setup Scripts

`DVM_SETUP_SCRIPTS` is a space-separated list of host scripts. Each script is piped
into the VM and runs as the guest user after core setup.

Setup scripts receive:

```text
DVM_NAME
DVM_VM_NAME
DVM_CODE_DIR
DVM_DOTFILES_TARGET
```

Use setup scripts for packages, shell config, editor config, and project-specific
configuration that should be reproducible across VMs.

## Dotfiles Snapshot

If `DVM_DOTFILES_DIR` is set, DVM copies a filtered snapshot of that host directory into
the VM before setup scripts run. DVM does not mount the host directory live.

Defaults:

```bash
DVM_DOTFILES_TARGET="$DVM_GUEST_HOME/.dotfiles"
DVM_DOTFILES_EXCLUDES=".git .ssh .gnupg .env secrets"
```

Safety rules:

- dotfiles sync is opt-in
- source paths such as `/`, `$HOME`, `~/.ssh`, and `~/.gnupg` are refused
- target paths must stay under `DVM_GUEST_HOME`
- target paths must not be `DVM_GUEST_HOME` itself and must not contain `.` or `..`
  path segments
- `.git`, `.ssh`, `.gnupg`, `.env`, and `secrets` are excluded by default

Example setup script:

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$DVM_CODE_DIR"

if [ -x "$DVM_DOTFILES_TARGET/install.sh" ]; then
  "$DVM_DOTFILES_TARGET/install.sh"
fi
```

## Default Config Reference

The generated default config lives in [defaults/config.sh](../defaults/config.sh).
Review that file when adding new VM defaults.
