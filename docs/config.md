# Config And Dotfiles

`dvm init` creates:

```text
~/.config/dvm/config.sh
~/.config/dvm/setup.d/fedora.sh
~/.local/share/dvm/
```

User configuration is shell code by design. Keep local VM behavior in
`~/.config/dvm`, not in the DVM core checkout.

`config.sh` is an override file. It is intentionally small and mostly commented after
`dvm init`; DVM loads core defaults first, then applies anything you uncomment or add.

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
Every default uses fallback form, so new core defaults can apply to old generated
configs unless the user explicitly pinned a value.

Inspect config paths and defaults:

```bash
dvm config path
dvm config print-defaults
dvm config print-template
dvm config diff
```

`dvm config print-defaults` shows the full runtime defaults from the current core.
`dvm config print-template` shows the small override template used by `dvm init`.
`dvm config diff` compares your user config with that override template. It does not
edit any files.

## Compatibility Rules

DVM treats `~/.config/dvm/config.sh` and setup scripts as user-owned files. Core updates
must not rewrite them automatically.

Compatibility comes from:

- core defaults in `dvm_load_config`
- fallback-form generated config values
- validation and warnings in `dvm doctor`
- upgrade tests under `tests/fixtures`

If a value is missing from an old config, DVM should fill it from the current core
default. If a value is explicitly assigned by the user, DVM should respect it unless it
is invalid.

## Config Reference

| Option | Default | Description |
| --- | --- | --- |
| `DVM_PREFIX` | `dvm` | Prefix for Lima VM names. `dvm new myapp` creates `$DVM_PREFIX-myapp`. |
| `DVM_TEMPLATE` | `template:fedora` | Lima template used for new VMs. |
| `DVM_ARCH` | `aarch64` | Guest architecture passed to Lima. |
| `DVM_CPUS` | `4` | CPU count passed to Lima. |
| `DVM_MEMORY` | `8GiB` | Guest memory passed to Lima. |
| `DVM_DISK` | `80GiB` | Guest disk size passed to Lima. |
| `DVM_GUEST_USER` | `$(id -un)` | Username created inside the VM. |
| `DVM_GUEST_HOME` | `/home/$DVM_GUEST_USER` | Guest home directory. Must be absolute. |
| `DVM_CODE_DIR` | `$DVM_GUEST_HOME/code` | Project code directory inside the VM. Must be absolute. |
| `DVM_PACKAGES` | `git openssh-clients gpg` | Space-separated Fedora packages installed by `dvm setup`. |
| `DVM_SETUP_SCRIPTS` | `$DVM_CONFIG/setup.d/fedora.sh` | Space-separated host scripts piped into the VM after core setup. |
| `DVM_SETUP_ALL_JOBS` | `1` | Number of VMs `dvm setup-all` runs at once. |
| `DVM_DOTFILES_DIR` | empty | Optional host dotfiles directory copied into the VM as a snapshot. |
| `DVM_DOTFILES_TARGET` | `$DVM_GUEST_HOME/.dotfiles` | Guest target for dotfiles snapshots. Must stay under `DVM_GUEST_HOME`. |
| `DVM_DOTFILES_EXCLUDES` | `.git .ssh .gnupg .env secrets` | Space-separated tar exclude patterns for dotfiles snapshots. |
| `DVM_GPG_DIR` | `$DVM_STATE/gpg` | Host directory for GPG metadata, public exports, and temporary secret-subkey bundles. |
| `DVM_AI_NAME` | `ai` | Default VM name for `dvm ai` commands. |
| `DVM_AI_PACKAGES` | `llama-cpp curl` | Fedora packages installed by `dvm ai setup`. |
| `DVM_AI_SERVER_CMD` | `llama-server` | llama.cpp server command inside the VM. |
| `DVM_AI_SERVICE_NAME` | `dvm-llama.service` | systemd unit name for the managed llama.cpp server. |
| `DVM_AI_SYSTEMD_DIR` | `/etc/systemd/system` | Guest systemd unit directory. |
| `DVM_AI_HOST` | `127.0.0.1` | Address llama-server listens on inside the VM. Keep this local unless you intentionally want VM-network exposure. |
| `DVM_AI_PORT` | `8080` | llama-server port inside the VM and the localhost port forwarded on the host by `dvm ai create`/`dvm ai expose`. |
| `DVM_AI_MODELS_DIR` | `$DVM_GUEST_HOME/models` | Guest directory for downloaded GGUF models. |
| `DVM_AI_CURRENT_MODEL` | `$DVM_AI_MODELS_DIR/current.gguf` | Symlink used by the systemd service as the active model. |
| `DVM_AI_DEFAULT_MODEL` | `qwen25-coder-7b-q4` | Alias selected after `dvm ai create`. Must exist in `DVM_AI_MODELS` when models are configured. |
| `DVM_AI_MODELS` | one Qwen2.5 Coder GGUF URL | Space-separated `alias=https://...` entries. Add `#sha256:<64-hex>` for checksum verification. |
| `DVM_AI_EXTRA_ARGS` | empty | Extra arguments appended to llama-server's systemd `ExecStart`. Newlines are rejected. |
| `DVM_AGENT_USER` | `dvm-agent` | Restricted user used by `dvm agent`. |
| `DVM_AGENT_HOME` | `/home/$DVM_AGENT_USER` | Home directory for the restricted agent user. |
| `DVM_AGENT_PACKAGES` | `bubblewrap acl shadow-utils` | Fedora packages installed by `dvm agent setup`. |
| `DVM_AGENT_CLAUDE_CHANNEL` | `stable` | Claude Code RPM repository channel. Use `latest` for the rolling channel. |
