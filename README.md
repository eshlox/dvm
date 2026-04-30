# DVM

Small Lima helper for disposable Fedora dev VMs.

Requirements:

- macOS 13+
- Bash
- Lima: `brew install lima`

Core idea:

```bash
dvm init myapp
dvm create myapp
dvm myapp
```

Each VM has one shell config:

```text
~/.config/dvm/vms/myapp.sh
```

Example:

```bash
DVM_PACKAGES="git ripgrep jq helix"
DVM_PORTS="3000:3000"

dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR"
}
```

Commands:

```text
dvm init [name]
dvm edit <name>
dvm create <name>
dvm setup <name>
dvm setup-all
dvm upgrade <name>
dvm upgrade-all
dvm enter <name>
dvm ssh <name> [command...]
dvm ssh-key <name>
dvm gpg-key <name>
dvm list
dvm rm <name> [--force]
```

Docs:

- [Dependencies](docs/dependencies.md)
- [Config](docs/config.md)
- [Create VMs](docs/create.md)
- [Dotfiles](docs/dotfiles.md)
- [Recipes](docs/recipes.md)
- [Extending DVM](docs/extending.md)
- [Llama](docs/llama.md)
- [Cloudflared](docs/cloudflared.md)
- [Networking](docs/networking.md)
- [HTTPS](docs/https.md)
- [Commands in VMs](docs/commands.md)
- [AI tools](docs/ai-tools.md)
- [Node](docs/node.md)
- [Python](docs/python.md)
- [SSH and GPG](docs/keys.md)
- [Updates](docs/updates.md)
- [Uninstall](docs/uninstall.md)
