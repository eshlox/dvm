# Codex

Use `ai.sh` and select `codex`.

`~/.config/dvm/vms/app.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="codex"
DVM_AI_YOLO="1"
```

Install or update:

```bash
dvm setup app
```

Run:

```bash
dvm app codex
```

Inside the VM or tmux:

```bash
codex
```

`ai.sh` installs `@openai/codex@latest` with npm under `dvm-agent` and creates a
wrapper that runs Codex from `/home/dvm-agent/.local/bin/codex`. YOLO mode is enabled
by default with `--dangerously-bypass-approvals-and-sandbox`.

Disable YOLO mode:

```bash
DVM_AI_YOLO="0"
```

Reference:

- https://developers.openai.com/codex/cli
