# OpenCode

Install and run OpenCode as `dvm-agent`.

Prerequisite:

```bash
dvm setup app
dvm ssh app sudo dnf5 install -y npm
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm config set prefix "$HOME/.local"'
```

Install:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'npm install -g opencode-ai'
```

Run:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && ~/.local/bin/opencode'
```

Reference:

- https://opencode.ai/docs/
