# OpenCode

Use `ai.sh` and select `opencode`.

`~/.config/dvm/vms/app.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="opencode"
DVM_AI_YOLO="1"
```

Install or update:

```bash
dvm setup app
```

Run:

```bash
dvm app opencode
```

Inside the VM or tmux:

```bash
opencode
```

`ai.sh` installs `opencode-ai@latest` with npm under `dvm-agent` and creates a wrapper
that runs OpenCode from `/home/dvm-agent/.local/bin/opencode`. YOLO mode is enabled
by default with `permission: allow`.

Disable YOLO mode:

```bash
DVM_AI_YOLO="0"
```

Reference:

- https://opencode.ai/docs/
