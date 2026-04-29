# Python

Simple VM config:

```bash
DVM_PACKAGES="git python3 python3-pip python3-virtualenv uv ripgrep jq"
DVM_PORTS="8000:8000"

dvm_vm_setup() {
	mkdir -p "$DVM_CODE_DIR"
}
```

Project example:

```bash
dvm app
cd ~/code/myproject
uv sync
uv run pytest
```
