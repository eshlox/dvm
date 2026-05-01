# Python

Simple VM config:

```bash
DVM_PORTS="8000:8000"
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS python.sh"
```

`~/.config/dvm/recipes/python.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

sudo dnf5 install -y git python3 python3-pip python3-virtualenv uv ripgrep jq
```

Project example:

```bash
dvm app
cd ~/code/myproject
uv sync
uv run pytest
```
