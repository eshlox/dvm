# AI Tools

Use a separate VM user for hosted AI tools:

```bash
DVM_SETUP_SCRIPTS="agent.sh"
```

Then:

```bash
dvm setup app
dvm app
sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && codex'
```

## Codex

```bash
sudo dnf5 install -y npm
sudo npm install -g @openai/codex
sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && codex'
```

Codex prompts for ChatGPT or API-key auth on first run.

## Claude Code

Fedora package repo:

```bash
sudo tee /etc/yum.repos.d/claude-code.repo <<'EOF'
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
sudo dnf5 install -y claude-code
sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && claude'
```

## OpenCode

```bash
sudo dnf5 install -y npm
sudo npm install -g opencode-ai
sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && opencode'
```

## Mistral Vibe

```bash
sudo dnf5 install -y python3 python3-pip uv
sudo -H -u dvm-agent -- bash -lc 'uv tool install mistral-vibe'
sudo -H -u dvm-agent -- bash -lc 'cd /home/<vm-user>/code && ~/.local/bin/vibe'
```

Refs:

- Codex: https://developers.openai.com/codex/cli
- Claude Code: https://code.claude.com/docs/en/setup
- Mistral Vibe: https://docs.mistral.ai/mistral-vibe/terminal/install
- OpenCode: https://opencode.ai/docs/
