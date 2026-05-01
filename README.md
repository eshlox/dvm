# DVM

Keep your friends close, your supply chain in a VM.

DVM is a small Bash wrapper around Lima for creating disposable Fedora development VMs
on macOS. It is meant to keep project code, package scripts, AI tools, language
runtimes, SSH/GPG keys, and random dev dependencies away from the host.

DVM targets macOS today. The same VM-isolation idea can make sense on Linux, but Linux
support is not implemented or tested.

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

`dvm myapp` opens `~/code/myapp` inside the VM by default.

Each VM has one shell config:

```text
~/.config/dvm/vms/myapp.sh
```

Example:

```bash
DVM_PORTS="3000:3000"
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS common.sh"

dvm_vm_setup() {
	git clone git@github.com:you/myapp.git "$DVM_CODE_DIR"
}
```

Hosted AI CLIs are a recipe:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="claude codex opencode mistral"
```

Then run `dvm setup myapp` and use `claude`, `codex`, `opencode`, or `vibe`
inside the VM.

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

- Start: [Install](docs/install.md), [Dependencies](docs/dependencies.md), [Create VMs](docs/create.md), [Config](docs/config.md)
- Daily use: [Commands](docs/commands.md), [Recipes](docs/recipes.md), [Updates](docs/updates.md), [Networking](docs/networking.md)
- Setup examples: [Languages](docs/languages/README.md), [Dotfiles](docs/dotfiles/README.md), [SSH and GPG](docs/keys.md)
- Services and AI: [AI](docs/ai/README.md), [Services](docs/services/README.md)
- Project: [Extending DVM](docs/extending.md), [Uninstall](docs/uninstall.md)
