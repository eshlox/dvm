# Node

Recommended: install Node from Fedora and use Corepack for pnpm/yarn. DVM does not
ship a Node recipe because project Node setup varies too much.

VM config:

```bash
DVM_PACKAGES="git nodejs npm ripgrep jq"
DVM_PORTS="3000:3000 5173:5173"

dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR"
	sudo corepack enable
	sudo corepack prepare pnpm@latest --activate
}
```

If `corepack` is missing from Fedora's Node package, install it with npm:

```bash
dvm_vm_setup() {
	sudo dnf5 install -y nodejs npm
	if ! command -v corepack >/dev/null 2>&1; then
		sudo npm install -g corepack@latest
	fi
	sudo corepack enable
	sudo corepack prepare pnpm@latest --activate
}
```

For shared Node tooling in most VMs, put the same block in
`~/.config/dvm/recipes/common.sh`.

## Project Version

For one project per VM, avoid a Node version manager by default. Put the project
requirements in `package.json`:

```json
{
  "engines": {
    "node": ">=22"
  },
  "packageManager": "pnpm@10.20.0"
}
```

Then Corepack uses the package-manager version requested by the project.

If you want the VM setup to pin pnpm explicitly:

```bash
sudo corepack prepare pnpm@10.20.0 --activate
```

## About `.nvmrc`

Do not use `.nvmrc` as the default DVM workflow. A DVM VM usually has one project, so a
single Fedora Node package is simpler and has less moving state than `fnm`, `nvm`, or
another version manager.

Use a version manager only for a project that truly requires an exact legacy Node
version unavailable from Fedora. Keep that in the project's VM config or user recipe,
not in DVM core.
