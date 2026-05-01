# AI

DVM supports two AI workflows:

- [Llama](llama.md): local llama.cpp server in an `ai` VM
- Hosted AI CLIs through `dvm-agent`: [Codex](codex.md), [Claude Code](claude.md), [OpenCode](opencode.md), [Mistral Vibe](mistral.md)

Hosted AI tools should run as the `dvm-agent` user, not as your normal VM user. This
keeps AI auth files in `/home/dvm-agent` while still allowing access to `~/code`.

## Agent Setup

`~/.config/dvm/vms/app.sh`:

```bash
DVM_SETUP_SCRIPTS="$DVM_SETUP_SCRIPTS agent.sh"
```

Run setup:

```bash
dvm setup app
```

Replace `<vm-user>` in examples with the normal VM user, usually your macOS username.

## npm Prefix

Run this once before installing npm-based AI tools:

```bash
dvm ssh app sudo dnf5 install -y npm
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm config set prefix "$HOME/.local"'
```

## Security

Do not run hosted AI tools from the normal VM user unless you intentionally want them
to read that user's home directory.

Do not put AI API keys in project code, dotfiles, or `~/.config/dvm`.
