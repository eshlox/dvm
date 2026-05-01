# Mistral Vibe

Install and run Mistral Vibe as `dvm-agent`.

Prerequisite:

```bash
dvm setup app
dvm ssh app sudo dnf5 install -y uv
```

Install:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'uv tool install mistral-vibe'
```

Run:

```bash
dvm ssh app sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && ~/.local/bin/vibe'
```

Reference:

- https://docs.mistral.ai/mistral-vibe/terminal/install
