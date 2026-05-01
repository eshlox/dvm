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

DVM_SETUP_SCRIPTS="common.sh"
```

Per-VM setup defaults `DVM_CODE_DIR` to:

```bash
DVM_CODE_DIR="$DVM_GUEST_HOME/code/$DVM_NAME"
```

So `dvm app`, `dvm ssh app`, and AI wrappers start in the project directory by
default. Override it only when a VM intentionally needs a different workspace:

```bash
DVM_CODE_DIR="$DVM_GUEST_HOME/code"
```

Treat `~/.config/dvm` as private local machine state. It can contain project names,
tunnel names, package choices, email, and other setup details that are not necessarily
secrets but still do not belong in a public repo.

If you use public dotfiles, do not publish `~/.config/dvm` directly. Keep reusable
examples in your dotfiles docs or snippets, then keep the real DVM config local.

It is fine to keep non-secret identity values here:

```bash
# ~/.config/dvm/config.sh
DVM_GIT_NAME="Your Name"
DVM_GIT_EMAIL="you@example.com"
```

Recipes receive `DVM_*` values, so this is useful for generating VM-local config
without putting names, emails, or tokens into a public recipe. It is not a sandbox. If
a recipe writes a value into the VM, code in that VM can read it.

Example use: put Git identity values here, then generate VM-local Git config from a
recipe. Use `dvm ssh-key <name>` for VM-local SSH auth and commit signing. See
[SSH, GPG, and signing](keys.md).

Put shared setup in:

```text
~/.config/dvm/recipes/common.sh
```

Install packages and tools from recipes. DVM intentionally has one setup path instead
of a separate package-install phase plus scripts.

Dotfiles are optional and workflow-specific. See [Dotfiles](dotfiles/README.md) for
snapshot, bare repo, yadm, and chezmoi.

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
```

For Node and pnpm, keep the full setup in [Node](languages/node.md).

## Per-VM Additions

Append to global setup:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS project.sh"
```

Enable hosted AI tools for one VM:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="claude codex"
DVM_AI_YOLO="1"
```

Add inline setup for one VM:

```bash
dvm_vm_setup() {
	git clone git@github.com:you/app.git "$DVM_CODE_DIR"
}
```

## Per-VM Overrides

Replace global defaults:

```bash
DVM_SETUP_SCRIPTS="python.sh"
```

Disable global setup for special VMs like `ai` or `cloudflared`:

```bash
DVM_SETUP_SCRIPTS="llama.sh"
```

## Generated Examples

`dvm init <name>` creates a general per-VM template. Some common names get extra
commented examples:

- `dvm init ai`: llama VM hints
- `dvm init cloudflared`: cloudflared connector VM hints

These are examples only. Nothing is enabled until you uncomment or add values.
