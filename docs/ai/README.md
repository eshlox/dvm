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
DVM_AI_YOLO="1"
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

The recipe grants `dvm-agent` read/write/execute ACLs on `DVM_CODE_DIR`, including a
default ACL for newly created files. The tools can edit code, run project commands,
install project dependencies, and use packages available in the VM. With YOLO mode,
that also means an AI tool can run Git commands such as commits, pushes, or force
pushes if credentials and remote permissions allow it.

Use normal repository protections for important work: branch protection, protected
remotes, pre-push hooks, and review before pushing generated changes. The tools should
not get the normal VM user's home, SSH keys, GPG keys, or dotfiles unless you
explicitly copy those into `DVM_CODE_DIR`.

## YOLO Mode

`ai.sh` enables YOLO mode by default because the tools run inside the VM as
`dvm-agent`.

What that means:

- Claude runs with `--dangerously-skip-permissions`
- Codex runs with `--dangerously-bypass-approvals-and-sandbox`
- OpenCode gets `permission: allow` through runtime config
- Mistral Vibe runs with the generated `dvm-yolo` agent

Disable YOLO mode for one VM:

```bash
DVM_AI_YOLO="0"
```

DVM is still not a perfect sandbox. YOLO mode is meant for disposable project VMs
without host mounts or copied secrets.

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
