# Codex

Install and run Codex as `dvm-agent`.

Prerequisite:

```bash
dvm setup app
dvm ssh app sudo dnf5 install -y npm
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm config set prefix "$HOME/.local"'
```

Install:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm install -g @openai/codex'
```

Run:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && ~/.local/bin/codex'
```

Codex prompts for ChatGPT or API-key auth on first run.

Reference:

- https://github.com/openai/codex
