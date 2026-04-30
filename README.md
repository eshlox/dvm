# DVM

Keep your friends close, your supply chain in a VM.

DVM is a small Bash wrapper around Lima for creating disposable Fedora development VMs
on macOS. It is meant to keep project code, package scripts, AI tools, language
runtimes, SSH/GPG keys, and random dev dependencies away from the host.

It is intentionally not a full VM platform, package manager, dotfiles framework,
secret manager, or hard sandbox beyond what Lima/macOS virtualization provide. The core
stays small. Most of the project is docs and examples for wiring your own per-VM setup.

The idea: one project, one VM, one shell config. Recreate or remove the VM when you are
done.

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
