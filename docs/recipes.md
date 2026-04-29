# Recipes

Recipes are shell scripts run inside the VM.

DVM resolves `DVM_SETUP_SCRIPTS` in this order:

1. `~/.config/dvm/recipes/<name>`
2. `<repo>/recipes/<name>`
3. the value as a path

Example:

```bash
DVM_SETUP_SCRIPTS="llama.sh agent.sh cloudflared.sh"
```

Built-in recipes:

- `llama.sh`: install and run llama.cpp server
- `agent.sh`: create a separate `dvm-agent` user for AI tools
- `cloudflared.sh`: install Cloudflare's `cloudflared` connector and optionally run it as a service

Keep custom recipes small. If it is project-specific, put it in the VM config as
`dvm_vm_setup()`.

For shared setup used by most VMs, put a recipe such as `common.sh` in
`~/.config/dvm/recipes/` and enable it from `~/.config/dvm/config.sh`:

```bash
DVM_SETUP_SCRIPTS="common.sh"
```

Use shared recipes for packages that need extra repository setup:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y --nogpgcheck \
	--repofrompath "terra,https://repos.fyralabs.com/terra$releasever" \
	terra-release
sudo dnf5 install -y lazygit
```

Special VMs can disable the shared setup:

```bash
DVM_SETUP_SCRIPTS=""
```

For rules on when to add a built-in recipe versus docs only, see
[Extending DVM](extending.md).
