# Node

Recommended: keep Node setup in your VM config or your own recipe. DVM does not ship a
Node recipe because project Node setup varies too much.

Simple VM config:

```bash
DVM_PACKAGES="git nodejs npm ripgrep jq"
DVM_PORTS="3000:3000 5173:5173"

dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR"
}
```

If you prefer `pnpm`:

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

Pin pnpm if you want reproducible setup:

```bash
sudo corepack prepare pnpm@10.20.0 --activate
```

Corepack lets projects with `"packageManager": "pnpm@x.y.z"` control the pnpm version.
