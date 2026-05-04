#!/usr/bin/env bash
set -euo pipefail

: "${DVM_AI_AGENT_USER:=dvm-agent}"
command -v dvm_agent_write_wrapper >/dev/null 2>&1 || {
	printf 'dvm: recipe codex requires use agent-user before use codex\n' >&2
	exit 1
}

sudo dnf5 install -y nodejs npm
sudo -H -u "$DVM_AI_AGENT_USER" bash -lc 'npm config set prefix "$HOME/.local" && npm install -g @openai/codex@latest'
dvm_agent_write_wrapper codex "/home/$DVM_AI_AGENT_USER/.local/bin/codex"
