# Claude Code

Install and run Claude Code as `dvm-agent`.

Prerequisite:

```bash
dvm setup app
dvm ssh app sudo dnf5 install -y npm
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm config set prefix "$HOME/.local"'
```

Install with npm:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm install -g @anthropic-ai/claude-code'
```

Run:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && ~/.local/bin/claude'
```

Claude also publishes signed Fedora packages. Use that route if you prefer package
manager updates, but keep auth and daily usage under `dvm-agent`.

Reference:

- https://docs.claude.com/en/docs/claude-code/setup
