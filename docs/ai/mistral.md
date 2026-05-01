# Mistral Vibe

Use `ai.sh` and select `mistral`.

`~/.config/dvm/vms/app.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="mistral"
```

Install or update:

```bash
dvm setup app
```

Run:

```bash
dvm app vibe
```

Inside the VM or tmux:

```bash
vibe
```

`ai.sh` installs `mistral-vibe` with uv under `dvm-agent` and creates `vibe` and
`mistral` wrappers.

Reference:

- https://docs.mistral.ai/mistral-vibe/terminal/install
