# Claude Code

Use `ai.sh` and select `claude`.

`~/.config/dvm/vms/app.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="claude"
```

Install or update:

```bash
dvm setup app
```

Run:

```bash
dvm app claude
```

Inside the VM or tmux:

```bash
claude
```

`ai.sh` installs Claude Code from Anthropic's signed Fedora repo and creates a wrapper
that runs `/usr/bin/claude` as `dvm-agent`.

Channel:

```bash
DVM_CLAUDE_CHANNEL="stable"
# DVM_CLAUDE_CHANNEL="latest"
```

Reference:

- https://code.claude.com/docs/en/setup
