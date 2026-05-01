# AI

DVM supports two AI workflows:

- [Llama](llama.md): local llama.cpp server in a dedicated VM
- Hosted AI CLIs: [Claude Code](claude.md), [Codex](codex.md), [OpenCode](opencode.md), and [Mistral Vibe](mistral.md)

## Hosted AI CLIs

Use the built-in `ai.sh` recipe. It creates a `dvm-agent` user, grants that user
access to `DVM_CODE_DIR`, installs selected tools, and creates wrapper commands in
`/usr/local/bin`.

`~/.config/dvm/vms/app.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="claude codex opencode mistral"
```

Install or update tools:

```bash
dvm setup app
```

Run from inside the VM, including inside tmux:

```bash
dvm app
claude
codex
opencode
vibe
```

Run from the host:

```bash
dvm app claude
dvm app codex
dvm app opencode
dvm app vibe
```

The wrapper keeps the working directory under `DVM_CODE_DIR`. If you start it from
outside the project directory, it falls back to `DVM_CODE_DIR`, which defaults to
`~/code/<vm-name>`.

## Security Model

Hosted AI tools run as `dvm-agent`, not as the normal VM user. Their login files and
tokens live in `/home/dvm-agent`.

The tools can read and write `DVM_CODE_DIR`, run project commands, install project
dependencies, and use packages available in the VM. They should not get the normal VM
user's home, SSH keys, GPG keys, or dotfiles unless you explicitly copy those into
`DVM_CODE_DIR`.

## Tool Selection

Install only what you use:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS ai.sh"
DVM_AI_TOOLS="claude codex"
```

Available tool names:

- `claude`: installs Claude Code from Anthropic's signed Fedora repo
- `codex`: installs `@openai/codex` with npm under `dvm-agent`
- `opencode`: installs `opencode-ai` with npm under `dvm-agent`
- `mistral`: installs `mistral-vibe` with uv under `dvm-agent`

Claude defaults to the `stable` channel:

```bash
DVM_CLAUDE_CHANNEL="stable"
```

Use the rolling channel if you want the newest Claude Code releases:

```bash
DVM_CLAUDE_CHANNEL="latest"
```

## Authentication

Run each tool once and follow its login flow:

```bash
dvm app claude
dvm app codex
dvm app opencode
dvm app vibe
```

Do not put AI API keys in project code, dotfiles, or `~/.config/dvm`.
