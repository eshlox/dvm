# Recipes

Recipes are shell scripts run inside the VM.

DVM resolves `DVM_SETUP_SCRIPTS` in this order:

1. `~/.config/dvm/recipes/<name>`
2. `<repo>/recipes/<name>`
3. the value as a path

Example:

```bash
DVM_SETUP_SCRIPTS="common.sh ai.sh"
```

Built-in recipes:

- `llama.sh`: install and run llama.cpp server
- `ai.sh`: install hosted AI CLIs as `dvm-agent` and create wrapper commands
- `agent.sh`: create only the separate `dvm-agent` user
- `cloudflared.sh`: install Cloudflare's `cloudflared` connector and optionally run it as a service

Keep custom recipes small. Use recipes for package installs, repositories, services,
tools, dotfiles, and shell defaults.

Use `dvm_vm_setup()` only for project-local final touches, not package installs:

```bash
dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR/myapp"
}
```

For shared setup used by most VMs, put a recipe such as `common.sh` in
`~/.config/dvm/recipes/` and enable it from `~/.config/dvm/config.sh`:

```bash
DVM_SETUP_SCRIPTS="common.sh"
```

Dotfiles managers such as yadm or chezmoi should also live in user recipes, not DVM
core. See [Dotfiles](dotfiles/README.md).

Use shared recipes for packages that need extra repository setup:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y --nogpgcheck \
	--repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
	terra-release
sudo dnf5 install -y lazygit
```

Set zsh as the default shell for most VMs:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y zsh

zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"

if [ "$current_shell" != "$zsh_path" ]; then
	sudo chsh -s "$zsh_path" "$USER"
fi
```

Keep package installation in recipes so setup has one path.

Special VMs can disable the shared setup:

```bash
DVM_SETUP_SCRIPTS=""
```

For rules on when to add a built-in recipe versus docs only, see
[Extending DVM](extending.md).
