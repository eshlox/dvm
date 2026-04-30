# Config

DVM has two config layers.

Global defaults:

```text
~/.config/dvm/config.sh
```

Per-VM config:

```text
~/.config/dvm/vms/<name>.sh
```

The global config is loaded first, then the per-VM config. Because config is shell, a
VM can inherit, append, replace, or clear global values.

## Global Defaults

Use global config for settings that apply to most VMs:

```bash
DVM_CPUS="2"
DVM_MEMORY="4GiB"
DVM_DISK="40GiB"
DVM_NETWORK="user-v2"

DVM_PACKAGES="git ripgrep fd-find jq helix yazi"
DVM_SETUP_SCRIPTS="common.sh"
```

Keep private local values in a separate file:

```bash
# ~/.config/dvm/config.sh
[ -f "$DVM_CONFIG/private.sh" ] && source "$DVM_CONFIG/private.sh"
```

Example private file:

```bash
# ~/.config/dvm/private.sh
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
DVM_GIT_SIGNING_KEY="ABCDEF1234567890"
```

Do not commit `private.sh`. Keep it local and lock it down:

```bash
chmod 600 ~/.config/dvm/private.sh
```

Recipes receive `DVM_*` values, so this is useful for generating VM-local config
without putting names, emails, signing keys, or tokens into a public recipe. It is not
a sandbox. If a recipe writes a value into the VM, code in that VM can read it.

Put shared setup in:

```text
~/.config/dvm/recipes/common.sh
```

Use `DVM_PACKAGES` for simple Fedora packages. Use `common.sh` for anything that needs
extra commands, external repos, service setup, or custom logic.

Dotfiles are optional and workflow-specific. See [Dotfiles](dotfiles.md) for plain
snapshot, bare repo, yadm, and chezmoi examples.

Example `~/.config/dvm/recipes/common.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y git ripgrep fd-find jq helix yazi

if ! rpm -q terra-release >/dev/null 2>&1; then
	sudo dnf5 install -y --nogpgcheck \
		--repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
		terra-release
fi
sudo dnf5 install -y lazygit

sudo dnf5 install -y nodejs npm
if ! command -v corepack >/dev/null 2>&1; then
	sudo npm install -g corepack@latest
fi
sudo corepack enable
sudo corepack prepare pnpm@latest --activate
```

## Per-VM Additions

Append to global packages or setup:

```bash
DVM_PACKAGES="$DVM_PACKAGES nodejs pnpm"
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS node.sh"
```

Add inline setup for one VM:

```bash
dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR/myapp"
}
```

## Per-VM Overrides

Replace global defaults:

```bash
DVM_PACKAGES="git python3 uv"
DVM_SETUP_SCRIPTS="python.sh"
```

Disable global setup for special VMs like `ai` or `cloudflared`:

```bash
DVM_PACKAGES=""
DVM_SETUP_SCRIPTS="llama.sh"
```

## Generated Examples

`dvm init <name>` creates a general per-VM template. Some common names get extra
commented examples:

- `dvm init ai`: llama VM hints
- `dvm init cloudflared`: cloudflared connector VM hints

These are examples only. Nothing is enabled until you uncomment or add values.
